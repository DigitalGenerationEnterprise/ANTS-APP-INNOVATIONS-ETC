#!/usr/bin/env bash
set -Eeuo pipefail

LOCAL_MODEL="lmstudio/qwen/qwen3.5-9b"
CLOUD_MODEL="openai/gpt-5.6-sol"
GATEWAY_URL="http://127.0.0.1:18789"
LM_URL="http://127.0.0.1:1234"
CFG="$HOME/.config/clawchat"
BIN="$HOME/.local/bin"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required but was not found."
    exit 1
  }
}

need openclaw
need python3
need curl

mkdir -p "$CFG" "$BIN"
chmod 700 "$CFG"

echo
echo "======================================================"
echo " CHRISTOPHER / OPENCLAW HTTP TERMINAL SETUP"
echo "======================================================"

# Back up the active OpenClaw config before changing gateway settings.
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  cp -a "$HOME/.openclaw/openclaw.json" \
    "$HOME/.openclaw/openclaw.json.before-clawchat.$(date +%Y%m%d-%H%M%S)"
fi

echo
echo "[1/7] Starting LM Studio / llmster..."
if command -v lms >/dev/null 2>&1; then
  lms daemon up >/dev/null 2>&1 || true
  lms server start --port 1234 >/dev/null 2>&1 || true

  for _ in $(seq 1 30); do
    curl -fsS "$LM_URL/api/v1/models" >/dev/null 2>&1 && break
    sleep 1
  done

  if curl -fsS "$LM_URL/api/v1/models" >/dev/null 2>&1; then
    echo "  OK: LM Studio API is alive on :1234"
  else
    echo "  WARNING: LM Studio is not answering on :1234 yet."
  fi
else
  echo "  WARNING: 'lms' not found. OpenClaw HTTP setup will continue."
fi

echo
echo "[2/7] Setting OpenClaw local-first routing..."
openclaw models set "$LOCAL_MODEL" >/dev/null || true
openclaw models fallbacks clear >/dev/null || true
openclaw models fallbacks add "$CLOUD_MODEL" >/dev/null || true

echo "  Primary : $LOCAL_MODEL"
echo "  Fallback: $CLOUD_MODEL"

echo
echo "[3/7] Enabling OpenClaw's OpenAI-compatible HTTP endpoint..."
# Keep the operator-capable endpoint local to this PC.
openclaw config set gateway.bind loopback >/dev/null
openclaw config set gateway.http.endpoints.chatCompletions.enabled true >/dev/null

openclaw gateway install --force >/dev/null 2>&1 || true
openclaw gateway restart >/dev/null 2>&1 || \
  systemctl --user restart openclaw-gateway.service >/dev/null 2>&1 || true

sleep 2

echo
echo "[4/7] Getting a usable Gateway bearer token..."

TOKEN=""
DASH_JSON="$(openclaw dashboard --json 2>/dev/null || true)"

if [ -n "$DASH_JSON" ]; then
  TOKEN="$(
    DASH_JSON="$DASH_JSON" python3 - <<'PY'
import json, os
from urllib.parse import urlsplit, parse_qs

raw = os.environ.get("DASH_JSON", "")
try:
    d = json.loads(raw)
except Exception:
    print("")
    raise SystemExit

u = d.get("url") or ""
p = urlsplit(u)

for part in (p.fragment, p.query):
    q = parse_qs(part)
    vals = q.get("token", [])
    if vals and vals[0]:
        print(vals[0])
        raise SystemExit

print("")
PY
  )"
fi

if [ -z "$TOKEN" ]; then
  echo "  Existing shared token was not script-readable."
  echo "  Creating a new persistent loopback Gateway token."
  TOKEN="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(48))
PY
)"
  openclaw config set gateway.auth.mode token >/dev/null
  openclaw config set gateway.auth.token "$TOKEN" >/dev/null
  openclaw gateway restart >/dev/null 2>&1 || \
    systemctl --user restart openclaw-gateway.service >/dev/null 2>&1 || true
  sleep 2
else
  echo "  Reusing the existing Gateway token."
fi

printf '%s' "$TOKEN" > "$CFG/gateway-token"
chmod 600 "$CFG/gateway-token"

cat > "$CFG/settings.json" <<EOF
{
  "gateway": "$GATEWAY_URL",
  "agent": "main",
  "local_model": "$LOCAL_MODEL",
  "cloud_model": "$CLOUD_MODEL"
}
EOF
chmod 600 "$CFG/settings.json"

if [ ! -s "$CFG/session" ]; then
  printf 'terminal-%s-%s\n' "$(date +%Y%m%d-%H%M%S)" "$RANDOM" > "$CFG/session"
fi
chmod 600 "$CFG/session"

echo
echo "[5/7] Installing the persistent HTTP terminal client..."

cat > "$BIN/clawchat" <<'PY'
#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
import uuid
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
CFG = HOME / ".config" / "clawchat"
TOKEN_FILE = CFG / "gateway-token"
SESSION_FILE = CFG / "session"
MODE_FILE = CFG / "mode"
SETTINGS_FILE = CFG / "settings.json"

settings = {
    "gateway": "http://127.0.0.1:18789",
    "agent": "main",
    "local_model": "lmstudio/qwen/qwen3.5-9b",
    "cloud_model": "openai/gpt-5.6-sol",
}
try:
    settings.update(json.loads(SETTINGS_FILE.read_text()))
except Exception:
    pass

BASE = settings["gateway"].rstrip("/")
AGENT = settings["agent"]
LOCAL_MODEL = settings["local_model"]
CLOUD_MODEL = settings["cloud_model"]

def token():
    try:
        return TOKEN_FILE.read_text().strip()
    except Exception:
        return ""

def session():
    try:
        s = SESSION_FILE.read_text().strip()
    except Exception:
        s = ""
    if not s:
        s = "terminal-" + time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
        SESSION_FILE.write_text(s + "\n")
    return s

def set_new_session():
    s = "terminal-" + time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    SESSION_FILE.write_text(s + "\n")
    return s

def get_mode():
    try:
        m = MODE_FILE.read_text().strip().lower()
    except Exception:
        m = "auto"
    return m if m in ("auto", "local", "cloud") else "auto"

def set_mode(m):
    MODE_FILE.write_text(m + "\n")

def mode_label(m):
    if m == "local":
        return "LOCAL/Qwen forced"
    if m == "cloud":
        return "CLOUD/GPT forced"
    return "AUTO local→cloud fallback"

def request_chat(text):
    t = token()
    if not t:
        raise RuntimeError("No Gateway token. Re-run CHRISTOPHER-HTTP-TERMINAL.sh")

    m = get_mode()
    body = {
        "model": f"openclaw/{AGENT}",
        "messages": [{"role": "user", "content": text}],
        "stream": False,
    }

    headers = {
        "Authorization": "Bearer " + t,
        "Content-Type": "application/json",
        "x-openclaw-session-key": session(),
    }

    if m == "local":
        headers["x-openclaw-model"] = LOCAL_MODEL
    elif m == "cloud":
        headers["x-openclaw-model"] = CLOUD_MODEL

    req = urllib.request.Request(
        BASE + "/v1/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=900) as r:
            raw = r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {raw}")
    except Exception as e:
        raise RuntimeError(str(e))

    try:
        obj = json.loads(raw)
        choice = obj.get("choices", [{}])[0]
        msg = choice.get("message", {})
        content = msg.get("content", "")
        if isinstance(content, list):
            chunks = []
            for part in content:
                if isinstance(part, dict):
                    chunks.append(str(part.get("text", part.get("content", ""))))
                else:
                    chunks.append(str(part))
            content = "".join(chunks)
        if content:
            return str(content)
        return json.dumps(obj, indent=2)
    except Exception:
        return raw

def http_models():
    t = token()
    req = urllib.request.Request(
        BASE + "/v1/models",
        headers={"Authorization": "Bearer " + t},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode("utf-8", errors="replace")

def print_help():
    print("""
Commands:
  /new        start a clean OpenClaw conversation
  /session    show the exact shared OpenClaw session key
  /auto       local Qwen first, then configured cloud fallback
  /local      FORCE lmstudio/qwen/qwen3.5-9b
  /cloud      FORCE openai/gpt-5.6-sol
  /status     check the OpenClaw HTTP endpoint
  /models     show OpenClaw model status
  /dashboard  open the OpenClaw web GUI
  /help       show this help
  /quit       exit

Everything you type normally is sent over HTTP to OpenClaw agent 'main'.
That means it follows that agent's normal tools, permissions, memory and routing.
""".strip())

print()
print("╔══════════════════════════════════════════════════════╗")
print("║  CHRISTOPHER / OPENCLAW HTTP TERMINAL              ║")
print("╚══════════════════════════════════════════════════════╝")
print(f"Gateway : {BASE}")
print(f"Agent   : {AGENT}")
print(f"Session : {session()}")
print(f"Route   : {mode_label(get_mode())}")
print("Type /help for commands.")
print()

while True:
    try:
        text = input("You › ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\nBye.")
        break

    if not text:
        continue

    if text in ("/quit", "/exit"):
        break
    if text == "/help":
        print_help()
        continue
    if text == "/new":
        print("New session:", set_new_session())
        continue
    if text == "/session":
        print("Session:", session())
        print("OpenClaw canonical form will be under agent main, e.g. agent:main:<session>.")
        continue
    if text == "/auto":
        set_mode("auto")
        print("Route:", mode_label("auto"))
        continue
    if text == "/local":
        set_mode("local")
        print("Route:", mode_label("local"))
        continue
    if text == "/cloud":
        set_mode("cloud")
        print("Route:", mode_label("cloud"))
        continue
    if text == "/status":
        try:
            print(http_models())
        except Exception as e:
            print("ERROR:", e)
        continue
    if text == "/models":
        subprocess.run(["openclaw", "models", "status", "--agent", AGENT])
        continue
    if text == "/dashboard":
        subprocess.Popen(
            ["openclaw", "dashboard", "--yes"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print("Dashboard launch requested.")
        continue

    try:
        print("\nAssistant › ", end="", flush=True)
        ans = request_chat(text)
        print(ans)
        print()
    except Exception as e:
        print(f"\nERROR: {e}\n")
PY

chmod +x "$BIN/clawchat"

echo
echo "[6/7] Installing one-command start and health tools..."

cat > "$BIN/clawstatus" <<'SH'
#!/usr/bin/env bash
set +e

TOKEN_FILE="$HOME/.config/clawchat/gateway-token"
TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null)"

echo "================ LM STUDIO ================"
curl -fsS http://127.0.0.1:1234/api/v1/models >/tmp/claw-lm-models.$$ 2>/dev/null
if [ $? -eq 0 ]; then
  echo "OK  http://127.0.0.1:1234"
  cat /tmp/claw-lm-models.$$
else
  echo "FAIL http://127.0.0.1:1234"
fi
rm -f /tmp/claw-lm-models.$$
echo

echo "================ OPENCLAW =================="
openclaw gateway status --require-rpc
echo

echo "================ MODEL ROUTE ================"
openclaw models status --agent main
echo

echo "================ HTTP API =================="
if [ -n "$TOKEN" ]; then
  curl -fsS http://127.0.0.1:18789/v1/models \
    -H "Authorization: Bearer $TOKEN"
  echo
else
  echo "No clawchat Gateway token found."
fi
SH
chmod +x "$BIN/clawstatus"

cat > "$BIN/clawup" <<'SH'
#!/usr/bin/env bash
set -e

if command -v lms >/dev/null 2>&1; then
  lms daemon up >/dev/null 2>&1 || true
  lms server start --port 1234 >/dev/null 2>&1 || true
fi

openclaw gateway restart >/dev/null 2>&1 || \
  systemctl --user restart openclaw-gateway.service >/dev/null 2>&1 || true

for _ in $(seq 1 20); do
  openclaw gateway status --require-rpc >/dev/null 2>&1 && break
  sleep 1
done

echo
echo "OpenClaw + LM Studio stack:"
"$HOME/.local/bin/clawstatus" || true

echo
echo "Opening OpenClaw dashboard..."
openclaw dashboard --yes >/dev/null 2>&1 &

echo
echo "Entering shared HTTP terminal chat..."
exec "$HOME/.local/bin/clawchat"
SH
chmod +x "$BIN/clawup"

# Ensure ~/.local/bin is in PATH for new shells.
PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qsF "$PROFILE_LINE" "$HOME/.profile" 2>/dev/null; then
  printf '\n%s\n' "$PROFILE_LINE" >> "$HOME/.profile"
fi
export PATH="$HOME/.local/bin:$PATH"

echo
echo "[7/7] Smoke testing OpenClaw HTTP endpoint..."

HTTP_OK=0
for _ in $(seq 1 20); do
  if curl -fsS "$GATEWAY_URL/v1/models" \
      -H "Authorization: Bearer $TOKEN" >/tmp/claw-http-models.$$ 2>/dev/null; then
    HTTP_OK=1
    break
  fi
  sleep 1
done

if [ "$HTTP_OK" -eq 1 ]; then
  echo "  OK: $GATEWAY_URL/v1/models"
  cat /tmp/claw-http-models.$$
  echo
else
  echo "  WARNING: OpenClaw HTTP API did not answer yet."
  echo "  Run: openclaw gateway status --require-rpc"
fi
rm -f /tmp/claw-http-models.$$

echo
echo "======================================================"
echo " INSTALLED"
echo "======================================================"
echo
echo "Commands:"
echo "  clawchat    - ChatGPT-style persistent terminal chat"
echo "  clawstatus  - Prove LM Studio/OpenClaw/HTTP/model route"
echo "  clawup      - Start everything + dashboard + terminal chat"
echo
echo "Terminal route:"
echo "  clawchat -> HTTP :18789 -> OpenClaw main agent"
echo "           -> local Qwen :1234"
echo "           -> OpenAI GPT-5.6 Sol fallback if needed/available"
echo
echo "Web GUI:"
echo "  http://127.0.0.1:18789/"
echo
echo "Start it now with:"
echo "  clawup"
echo
