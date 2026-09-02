#!/usr/bin/env bash
set -Eeuo pipefail

ROUTER_MODEL="${ROUTER_MODEL:-qwen/qwen3.5-4b}"
LOCAL_DEFAULT="${LOCAL_DEFAULT:-lmstudio/qwen/qwen3.5-9b}"
PLUGIN_ID="anthony-cloud-first-router"
PLUGIN_DIR="$HOME/.local/share/$PLUGIN_ID"
BIN="$HOME/.local/bin"
CFG="$HOME/.config/cloudclaw"
SYSTEMD="$HOME/.config/systemd/user"
LOG="$HOME/.openclaw/logs"
ENVFILE="$HOME/.openclaw/.env"

mkdir -p "$PLUGIN_DIR" "$BIN" "$CFG" "$SYSTEMD" "$LOG" "$(dirname "$ENVFILE")"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required."
    exit 1
  }
}

need openclaw
need lms
need curl
need python3

OC="$(command -v openclaw)"
LMS="$(command -v lms)"

echo
echo "============================================================"
echo " CLOUD-FIRST SMART OPENCLAW"
echo "============================================================"
echo "Policy:"
echo "  1. Free / included cloud first"
echo "  2. Authenticated cloud with usable quota"
echo "  3. Best suitable local model"
echo "  4. Tiny CPU router as emergency local model"
echo

# ------------------------------------------------------------
# Preserve the old local-first router but prevent two
# before_model_resolve plugins fighting with each other.
# ------------------------------------------------------------
if "$OC" plugins inspect anthony-smart-router >/dev/null 2>&1; then
  echo "Disabling previous local-first router plugin..."
  "$OC" plugins disable anthony-smart-router >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# Start LM Studio and keep the tiny router alive on CPU.
# ------------------------------------------------------------
echo "[1/8] Starting LM Studio and tiny CPU router..."

"$LMS" daemon up >/dev/null 2>&1 || true
"$LMS" server start --port 1234 >/dev/null 2>&1 || true

for _ in $(seq 1 30); do
  curl -fsS http://127.0.0.1:1234/api/v1/models >/dev/null 2>&1 && break
  sleep 1
done

if ! curl -fsS http://127.0.0.1:1234/api/v1/models >/dev/null 2>&1; then
  echo "ERROR: LM Studio API is not answering on port 1234."
  exit 1
fi

if ! "$LMS" ls --llm --json 2>/dev/null | grep -Fq "$ROUTER_MODEL"; then
  echo "Downloading router model $ROUTER_MODEL ..."
  "$LMS" get "$ROUTER_MODEL"
fi

cat > "$BIN/cloudclaw-router-brain-start" <<EOF
#!/usr/bin/env bash
set -u
LMS="$LMS"
MODEL="$ROUTER_MODEL"

"\$LMS" daemon up >/dev/null 2>&1 || true
"\$LMS" server start --port 1234 >/dev/null 2>&1 || true

for _ in \$(seq 1 30); do
  curl -fsS http://127.0.0.1:1234/api/v1/models >/dev/null 2>&1 && break
  sleep 1
done

if ! "\$LMS" ps 2>/dev/null | grep -Fq "\$MODEL"; then
  "\$LMS" load "\$MODEL" --gpu off --context-length 8192
fi
EOF
chmod +x "$BIN/cloudclaw-router-brain-start"

cat > "$SYSTEMD/cloudclaw-router-brain.service" <<EOF
[Unit]
Description=CloudClaw Tiny CPU Model Router
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$BIN/cloudclaw-router-brain-start

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now cloudclaw-router-brain.service >/dev/null

# ------------------------------------------------------------
# Provider plugin helper. Only install extra packages if the
# user actually appears to have credentials for that provider.
# ------------------------------------------------------------
has_env_key() {
  local name="$1"
  if [ -n "${!name:-}" ]; then return 0; fi
  if [ -f "$ENVFILE" ] && grep -qE "^${name}=" "$ENVFILE"; then return 0; fi
  return 1
}

install_if_key() {
  local var="$1"
  local pkg="$2"
  if has_env_key "$var"; then
    echo "  Found $var -> ensuring $pkg is installed"
    "$OC" plugins install "$pkg" >/dev/null 2>&1 || true
  fi
}

echo
echo "[2/8] Discovering optional cloud-provider credentials..."

install_if_key GROQ_API_KEY '@openclaw/groq-provider'
install_if_key CEREBRAS_API_KEY '@openclaw/cerebras-provider'
install_if_key FIREWORKS_API_KEY '@openclaw/fireworks-provider'

# ------------------------------------------------------------
# Make OpenRouter the easiest broad/free cloud connection.
# Do not force login when a credential/profile already exists.
# ------------------------------------------------------------
auth_has_provider() {
  local provider="$1"
  "$OC" models auth list --agent main --json 2>/dev/null \
    | python3 - "$provider" <<'PY'
import json, sys
provider=sys.argv[1].lower()
try:
    obj=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

found=False
def walk(x):
    global found
    if isinstance(x, dict):
        p=x.get("provider") or x.get("providerId") or x.get("provider_id")
        if isinstance(p,str) and p.lower()==provider:
            found=True
        for v in x.values(): walk(v)
    elif isinstance(x,list):
        for v in x: walk(v)
walk(obj)
raise SystemExit(0 if found else 1)
PY
}

OPENROUTER_READY=0
if auth_has_provider openrouter || has_env_key OPENROUTER_API_KEY; then
  OPENROUTER_READY=1
  echo "  OpenRouter authentication already present."
else
  echo
  echo "OpenRouter gives OpenClaw one connection to a huge model catalog,"
  echo "including OpenRouter's zero-cost Free Models Router."
  echo
  if [ -t 0 ]; then
    read -r -p "Connect OpenRouter with browser OAuth now? [Y/n] " ans
    ans="${ans:-Y}"
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      "$OC" models auth login \
        --provider openrouter \
        --method oauth \
        --agent main || true
    fi
  fi

  if auth_has_provider openrouter || has_env_key OPENROUTER_API_KEY; then
    OPENROUTER_READY=1
  fi
fi

# ------------------------------------------------------------
# Build cloud-first router plugin.
# ------------------------------------------------------------
echo
echo "[3/8] Building cloud-first model router..."

cat > "$PLUGIN_DIR/package.json" <<'JSON'
{
  "name": "anthony-cloud-first-router",
  "version": "2.0.0",
  "type": "module",
  "openclaw": {
    "extensions": ["./index.js"]
  }
}
JSON

cat > "$PLUGIN_DIR/openclaw.plugin.json" <<'JSON'
{
  "id": "anthony-cloud-first-router",
  "name": "Anthony Cloud-First Smart Router",
  "description": "Routes each prompt to free/included cloud first, then other healthy cloud, then local LM Studio.",
  "version": "2.0.0",
  "activation": {
    "onStartup": true
  },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "routerModel": {"type": "string"},
      "lmBaseUrl": {"type": "string"},
      "localDefault": {"type": "string"},
      "openRouterFree": {"type": "string"},
      "maxCloudCandidates": {"type": "number"},
      "routerTimeoutMs": {"type": "number"},
      "privateLocalOnly": {"type": "boolean"},
      "agentIds": {
        "type": "array",
        "items": {"type": "string"}
      }
    }
  }
}
JSON

cat > "$PLUGIN_DIR/index.js" <<'JS'
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { appendFile, mkdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const execFileP = promisify(execFile);

const KNOWN_CLOUD = [
  "openrouter/openrouter/free",
  "openai/gpt-5.6-sol",
  "github-copilot/gpt-5.6-sol",
  "anthropic/claude-sonnet-5",
  "google/gemini-3.5-flash",
  "groq/openai/gpt-oss-120b",
  "cerebras/gpt-oss-120b",
  "fireworks/accounts/fireworks/routers/glm-5p2-fast",
  "mistral/mistral-large-latest",
  "together/moonshotai/Kimi-K2.6",
  "deepseek/deepseek-v4-flash",
  "zai/glm-5.2"
];

const ENV_KEYS = {
  openrouter: ["OPENROUTER_API_KEY"],
  openai: ["OPENAI_API_KEY"],
  anthropic: ["ANTHROPIC_API_KEY"],
  google: ["GEMINI_API_KEY", "GOOGLE_API_KEY"],
  groq: ["GROQ_API_KEY"],
  cerebras: ["CEREBRAS_API_KEY"],
  fireworks: ["FIREWORKS_API_KEY"],
  mistral: ["MISTRAL_API_KEY"],
  together: ["TOGETHER_API_KEY"],
  deepseek: ["DEEPSEEK_API_KEY"],
  zai: ["ZAI_API_KEY"],
  "github-copilot": ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"]
};

function uniq(xs) {
  return [...new Set(xs.filter(Boolean))];
}

function splitRef(ref) {
  const i = String(ref).indexOf("/");
  if (i <= 0) return null;
  return { provider: ref.slice(0, i), model: ref.slice(i + 1) };
}

function envConfigured(provider) {
  return (ENV_KEYS[provider] || []).some((k) => Boolean(process.env[k]));
}

function privateTask(prompt) {
  const s = String(prompt).toLowerCase();
  const terms = [
    "password", "passphrase", "api key", "apikey", "secret",
    "private key", "ssh key", "credential", "access token",
    "refresh token", "confidential", "local only", "keep local",
    "do not upload", "customer private", "personal private"
  ];
  return terms.some((x) => s.includes(x));
}

function category(prompt, hasAttachments) {
  const s = String(prompt).toLowerCase();

  if (hasAttachments &&
      /(image|photo|picture|screenshot|diagram|pdf|look at|what.*see)/i.test(s)) {
    return "vision";
  }
  if (/(code|coding|script|python|bash|javascript|typescript|flutter|dart|react|debug|bug|repo|git|docker|systemd|qml|linux|compile)/i.test(s)) {
    return "coding";
  }
  if (/(latest|today|current|research|compare|investigate|sources|web|news|verify)/i.test(s)) {
    return "research";
  }
  if (/(deep reasoning|architecture|strategy|prove|algorithm|complex|security|root cause|mathemat)/i.test(s)) {
    return "reasoning";
  }
  if (s.length < 220) return "fast";
  return "general";
}

function extractProviders(obj) {
  const out = new Set();
  const walk = (x) => {
    if (Array.isArray(x)) {
      for (const y of x) walk(y);
      return;
    }
    if (x && typeof x === "object") {
      for (const [k,v] of Object.entries(x)) {
        if (/^(provider|providerId|provider_id)$/i.test(k) && typeof v === "string") {
          out.add(v.toLowerCase());
        }
        walk(v);
      }
    }
  };
  walk(obj);
  return out;
}

async function authProviders(agentId) {
  const providers = new Set();
  for (const p of Object.keys(ENV_KEYS)) {
    if (envConfigured(p)) providers.add(p);
  }

  try {
    const { stdout } = await execFileP(
      "openclaw",
      ["models", "auth", "list", "--agent", agentId || "main", "--json"],
      { timeout: 5000, maxBuffer: 8 * 1024 * 1024 }
    );
    const obj = JSON.parse(stdout);
    for (const p of extractProviders(obj)) providers.add(p);
  } catch {}

  return providers;
}

function extractModelRefs(raw) {
  const refs = new Set();
  const accept = (v) => {
    if (typeof v !== "string") return;
    const x = v.trim();
    if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.@:+/-]+$/.test(x)) return;
    if (/(embed|embedding|rerank|tts|speech|whisper|image|video|sora|dall-e)/i.test(x)) return;
    refs.add(x);
  };

  try {
    const obj = JSON.parse(raw);
    const walk = (x, key="") => {
      if (Array.isArray(x)) {
        for (const y of x) walk(y, key);
        return;
      }
      if (x && typeof x === "object") {
        for (const [k,v] of Object.entries(x)) {
          if (/^(key|ref|model|modelRef|model_ref|id)$/i.test(k)) accept(v);
          walk(v, k);
        }
        return;
      }
      if (typeof x === "string" &&
          /^(key|ref|model|modelRef|model_ref|id)$/i.test(key)) {
        accept(x);
      }
    };
    walk(obj);
  } catch {}

  for (const m of String(raw).matchAll(/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.@:+/-]+/g)) {
    accept(m[0]);
  }

  return [...refs];
}

async function discoverCloud(agentId, providers, maxCount) {
  const discovered = [];

  try {
    const { stdout } = await execFileP(
      "openclaw",
      ["models", "list", "--all", "--agent", agentId || "main", "--json"],
      { timeout: 12000, maxBuffer: 16 * 1024 * 1024 }
    );

    for (const ref of extractModelRefs(stdout)) {
      const p = splitRef(ref);
      if (!p) continue;
      if (p.provider === "lmstudio" || p.provider === "ollama") continue;
      if (!providers.has(p.provider)) continue;
      discovered.push(ref);
    }
  } catch {}

  // Known strong/current models get priority when their provider is authenticated.
  const known = KNOWN_CLOUD.filter((ref) => {
    const p = splitRef(ref);
    return p && providers.has(p.provider);
  });

  return uniq([...known, ...discovered]).slice(0, maxCount);
}

async function discoverLocal() {
  try {
    const { stdout } = await execFileP(
      "lms",
      ["ls", "--llm", "--json"],
      { timeout: 5000, maxBuffer: 8 * 1024 * 1024 }
    );

    const refs = [];
    for (const ref of extractModelRefs(stdout)) {
      // lms keys are usually "publisher/model". Turn them into OpenClaw refs.
      if (!ref.startsWith("lmstudio/")) refs.push(`lmstudio/${ref}`);
      else refs.push(ref);
    }
    return uniq(refs);
  } catch {
    return [];
  }
}

async function routerDecision({
  baseUrl, routerModel, prompt, cloud, local, taskType,
  freeRef, timeoutMs
}) {
  const candidates = uniq([...cloud, ...local]);
  if (!candidates.length) throw new Error("no candidates");

  const rules = `
You are a MODEL ROUTER. You do NOT answer the user's task.
Return ONLY JSON:
{"model":"provider/model","reason":"short reason","confidence":0.0}

POLICY:
1. CLOUD-FIRST.
2. If ${freeRef} is present and capable of the task, strongly prefer it because it costs $0.
3. For hard coding/reasoning/research where a stronger authenticated cloud model is clearly worthwhile,
   select the best cloud model instead of the free router.
4. Use local LM Studio only when:
   - cloud candidates are absent,
   - the task is privacy-sensitive,
   - or local is clearly the safer/better fit.
5. Avoid wasting expensive frontier models on trivial prompts.
6. Prefer models whose names suggest the required capability.
7. Never invent a model. Choose exactly one candidate below.
8. The tiny router model should not answer substantial work if a stronger local exists.

Task type: ${taskType}

CLOUD CANDIDATES:
${cloud.map((x) => "- " + x).join("\n") || "- none"}

LOCAL CANDIDATES:
${local.map((x) => "- " + x).join("\n") || "- none"}
`.trim();

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const headers = {"Content-Type":"application/json"};
    if (process.env.LM_API_TOKEN) {
      headers.Authorization = `Bearer ${process.env.LM_API_TOKEN}`;
    }

    const res = await fetch(
      `${baseUrl.replace(/\/$/,"")}/v1/chat/completions`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          model: routerModel,
          messages: [
            {role:"system", content:rules},
            {role:"user", content:prompt.slice(0,5000)}
          ],
          temperature: 0,
          max_tokens: 120
        }),
        signal: controller.signal
      }
    );

    if (!res.ok) {
      throw new Error(`router HTTP ${res.status}`);
    }

    const obj = await res.json();
    const txt =
      obj?.choices?.[0]?.message?.content ??
      obj?.choices?.[0]?.message?.reasoning_content ?? "";

    const match = String(txt).match(/\{[\s\S]*\}/);
    if (!match) throw new Error("router returned no JSON");

    const d = JSON.parse(match[0]);
    if (!candidates.includes(d.model)) {
      throw new Error(`unknown router choice ${d.model}`);
    }

    return d;
  } finally {
    clearTimeout(timer);
  }
}

async function log(row) {
  try {
    const dir = path.join(os.homedir(), ".openclaw", "logs");
    await mkdir(dir, {recursive:true});
    await appendFile(
      path.join(dir, "cloud-first-router.log"),
      `${new Date().toISOString()} ${JSON.stringify(row)}\n`,
      "utf8"
    );
  } catch {}
}

export default definePluginEntry({
  id: "anthony-cloud-first-router",
  name: "Anthony Cloud-First Smart Router",
  description: "Free/included cloud first, then other authenticated cloud, then local.",

  register(api) {
    const pc = api.pluginConfig ?? {};
    const cfg = {
      routerModel: pc.routerModel || "qwen/qwen3.5-4b",
      lmBaseUrl: pc.lmBaseUrl || "http://127.0.0.1:1234",
      localDefault: pc.localDefault || "lmstudio/qwen/qwen3.5-9b",
      openRouterFree: pc.openRouterFree || "openrouter/openrouter/free",
      maxCloudCandidates: Number(pc.maxCloudCandidates || 18),
      routerTimeoutMs: Number(pc.routerTimeoutMs || 8000),
      privateLocalOnly: pc.privateLocalOnly !== false,
      agentIds: Array.isArray(pc.agentIds) && pc.agentIds.length
        ? pc.agentIds : ["main"]
    };

    api.on("before_model_resolve", async (event, ctx) => {
      const agentId = String(ctx?.agentId || "main");
      if (!cfg.agentIds.includes(agentId)) return;

      const source = String(ctx?.modelOverrideSource || "").toLowerCase();
      if (source === "user" || source === "session") return;

      const prompt = String(event?.prompt || "").trim();
      if (!prompt) return;

      const attachments =
        event?.attachments ??
        event?.attachmentMetadata ??
        event?.media ?? [];
      const hasAttachments = Array.isArray(attachments)
        ? attachments.length > 0 : Boolean(attachments);

      const taskType = category(prompt, hasAttachments);
      const isPrivate = cfg.privateLocalOnly && privateTask(prompt);

      const locals = await discoverLocal();
      if (!locals.includes(cfg.localDefault)) locals.unshift(cfg.localDefault);

      let clouds = [];
      let providers = new Set();

      if (!isPrivate) {
        providers = await authProviders(agentId);
        clouds = await discoverCloud(
          agentId, providers, cfg.maxCloudCandidates
        );
      }

      let chosen;
      let reason;
      let confidence = 0.5;

      if (isPrivate) {
        chosen = cfg.localDefault;
        reason = "privacy guard forced local";
        confidence = 1;
      } else if (!clouds.length) {
        chosen = cfg.localDefault;
        reason = "no authenticated cloud candidates";
      } else {
        try {
          const d = await routerDecision({
            baseUrl: cfg.lmBaseUrl,
            routerModel: cfg.routerModel,
            prompt,
            cloud: clouds,
            local: locals,
            taskType,
            freeRef: cfg.openRouterFree,
            timeoutMs: cfg.routerTimeoutMs
          });
          chosen = d.model;
          reason = String(d.reason || "router choice").slice(0,140);
          confidence = Number(d.confidence ?? 0.7);
        } catch (e) {
          // Cloud-first deterministic fallback if the tiny classifier is sick.
          chosen = clouds.includes(cfg.openRouterFree)
            ? cfg.openRouterFree
            : clouds[0];
          reason = `router unavailable; deterministic cloud-first: ${String(e?.message || e).slice(0,80)}`;
        }
      }

      const parsed = splitRef(chosen);
      if (!parsed) return;

      await log({
        agentId,
        taskType,
        chosen,
        reason,
        confidence,
        private: isPrivate,
        cloudCandidates: clouds.length,
        localCandidates: locals.length,
        authenticatedProviders: [...providers]
      });

      api.logger?.info?.(
        `[cloud-first-router] ${taskType} -> ${chosen} (${reason})`
      );

      return {
        providerOverride: parsed.provider,
        modelOverride: parsed.model
      };
    });
  }
});
JS

# ------------------------------------------------------------
# Install/enable router plugin.
# ------------------------------------------------------------
echo
echo "[4/8] Installing Cloud-First Router plugin..."

if "$OC" plugins inspect "$PLUGIN_ID" >/dev/null 2>&1; then
  "$OC" plugins enable "$PLUGIN_ID" --accept-capabilities >/dev/null 2>&1 || true
else
  "$OC" plugins install \
    --link "$PLUGIN_DIR" \
    --force \
    --accept-capabilities
fi

"$OC" config set \
  "plugins.entries.$PLUGIN_ID.hooks.allowConversationAccess" \
  true --strict-json

PLUGIN_CONFIG="$(python3 - <<PY
import json
print(json.dumps({
  "routerModel": "$ROUTER_MODEL",
  "lmBaseUrl": "http://127.0.0.1:1234",
  "localDefault": "$LOCAL_DEFAULT",
  "openRouterFree": "openrouter/openrouter/free",
  "maxCloudCandidates": 18,
  "routerTimeoutMs": 8000,
  "privateLocalOnly": True,
  "agentIds": ["main"]
}))
PY
)"

"$OC" config set \
  "plugins.entries.$PLUGIN_ID.config" \
  "$PLUGIN_CONFIG" --strict-json

# ------------------------------------------------------------
# Create provider connection menu.
# ------------------------------------------------------------
echo
echo "[5/8] Installing cloud provider connection menu..."

cat > "$BIN/cloudclaw-connect" <<'SH'
#!/usr/bin/env bash
set -u

OC="$(command -v openclaw)"
AGENT="main"

while true; do
  clear
  cat <<'EOF'
============================================================
 CLOUDCLAW — CONNECT ONLINE AI PROVIDERS
============================================================

 1) OpenRouter OAuth      (BEST FIRST: free router + huge catalog)
 2) OpenAI ChatGPT/Codex  (subscription OAuth/device login)
 3) GitHub Copilot        (uses your Copilot plan)
 4) Anthropic / Claude    (Claude CLI login or API/setup token)
 5) Google Gemini         (AI Studio API key)
 6) Groq                  (API key)
 7) Cerebras              (API key)
 8) Fireworks             (API key)
 9) Mistral               (API key)
10) Together AI           (API key)
11) DeepSeek              (API key)
12) Z.AI / GLM            (API key)
13) Generic OpenClaw provider auth helper
14) Show current auth/providers
15) Probe providers now
 0) Exit

Nothing here creates paid accounts or invents credentials.
Use providers you already have access to or want to sign into.
EOF

  read -r -p "Choice: " c

  case "$c" in
    1)
      "$OC" models auth login --provider openrouter --method oauth --agent "$AGENT"
      ;;
    2)
      "$OC" models auth login --provider openai --device-code --agent "$AGENT"
      ;;
    3)
      "$OC" models auth login-github-copilot --agent "$AGENT"
      ;;
    4)
      if command -v claude >/dev/null 2>&1; then
        echo "Trying Claude CLI status..."
        claude auth status --text || true
        echo
        read -r -p "Reuse Claude CLI login through OpenClaw? [Y/n] " a
        a="${a:-Y}"
        if [[ "$a" =~ ^[Yy]$ ]]; then
          "$OC" models auth login --provider anthropic --method cli --agent "$AGENT"
        else
          "$OC" models auth add --agent "$AGENT"
        fi
      else
        "$OC" models auth add --agent "$AGENT"
      fi
      ;;
    5)
      "$OC" models auth login --provider google --agent "$AGENT" || \
        "$OC" onboard --auth-choice gemini-api-key
      ;;
    6)
      "$OC" plugins install @openclaw/groq-provider || true
      "$OC" models auth login --provider groq --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    7)
      "$OC" plugins install @openclaw/cerebras-provider || true
      "$OC" models auth login --provider cerebras --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    8)
      "$OC" plugins install @openclaw/fireworks-provider || true
      "$OC" models auth login --provider fireworks --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    9)
      "$OC" models auth login --provider mistral --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    10)
      "$OC" models auth login --provider together --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    11)
      "$OC" models auth login --provider deepseek --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    12)
      "$OC" models auth login --provider zai --agent "$AGENT" || \
        "$OC" models auth add --agent "$AGENT"
      ;;
    13)
      "$OC" models auth add --agent "$AGENT"
      ;;
    14)
      "$OC" models auth list --agent "$AGENT"
      echo
      "$OC" models status --agent "$AGENT"
      ;;
    15)
      "$OC" models status --agent "$AGENT" --probe \
        --probe-max-tokens 1 --probe-timeout 8000 || true
      ;;
    0)
      exit 0
      ;;
    *)
      echo "Unknown choice."
      ;;
  esac

  echo
  read -r -p "Press Enter to continue..." _
done
SH
chmod +x "$BIN/cloudclaw-connect"

# ------------------------------------------------------------
# Build fallback chain from whatever auth exists NOW.
# This is separate from the intelligent per-turn router and
# gives OpenClaw something sensible when a selected cloud
# provider returns auth/quota/rate-limit errors.
# ------------------------------------------------------------
cat > "$BIN/cloudclaw-refresh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

OC="$(command -v openclaw)"
LOCAL="lmstudio/qwen/qwen3.5-9b"
ROUTER="lmstudio/qwen/qwen3.5-4b"

AUTH="$("$OC" models auth list --agent main --json 2>/dev/null || echo '{}')"

provider_present() {
  local provider="$1"
  AUTH_JSON="$AUTH" python3 - "$provider" <<'PY'
import json, os, sys
p=sys.argv[1].lower()
try:
    x=json.loads(os.environ["AUTH_JSON"])
except Exception:
    raise SystemExit(1)
found=False
def walk(v):
    global found
    if isinstance(v,dict):
        q=v.get("provider") or v.get("providerId") or v.get("provider_id")
        if isinstance(q,str) and q.lower()==p: found=True
        for z in v.values(): walk(z)
    elif isinstance(v,list):
        for z in v: walk(z)
walk(x)
raise SystemExit(0 if found else 1)
PY
}

"$OC" models fallbacks clear

# Free broad router first when available.
provider_present openrouter && \
  "$OC" models fallbacks add openrouter/openrouter/free || true

# Subscription / credit routes. Only include providers with stored auth.
provider_present openai && \
  "$OC" models fallbacks add openai/gpt-5.6-sol || true

provider_present github-copilot && \
  "$OC" models fallbacks add github-copilot/gpt-5.6-sol || true

provider_present anthropic && \
  "$OC" models fallbacks add anthropic/claude-sonnet-5 || true

provider_present google && \
  "$OC" models fallbacks add google/gemini-3.5-flash || true

provider_present groq && \
  "$OC" models fallbacks add groq/openai/gpt-oss-120b || true

provider_present cerebras && \
  "$OC" models fallbacks add cerebras/gpt-oss-120b || true

# Local is always the safety net.
"$OC" models fallbacks add "$LOCAL"
"$OC" models fallbacks add "$ROUTER"

echo
echo "Fallback chain rebuilt:"
"$OC" models fallbacks list
echo
echo "Live auth probe:"
"$OC" models status --agent main --probe \
  --probe-max-tokens 1 --probe-timeout 8000 || true

"$OC" gateway restart >/dev/null 2>&1 || \
  systemctl --user restart openclaw-gateway.service
SH
chmod +x "$BIN/cloudclaw-refresh"

# ------------------------------------------------------------
# Status / test helpers.
# ------------------------------------------------------------
cat > "$BIN/cloudclaw-status" <<'SH'
#!/usr/bin/env bash
set +e
echo
echo "================ AUTH / QUOTA PROBE ================="
openclaw models status --agent main --probe \
  --probe-max-tokens 1 --probe-timeout 8000
echo
echo "================ FALLBACKS =========================="
openclaw models fallbacks list
echo
echo "================ LOCAL ROUTER ======================="
systemctl --user --no-pager status cloudclaw-router-brain.service | sed -n '1,14p'
echo
lms ps
echo
echo "================ ROUTER PLUGIN ======================"
openclaw plugins inspect anthony-cloud-first-router --runtime
echo
echo "================ RECENT ROUTES ======================"
tail -20 "$HOME/.openclaw/logs/cloud-first-router.log" 2>/dev/null || true
SH
chmod +x "$BIN/cloudclaw-status"

cat > "$BIN/cloudclaw-test" <<'SH'
#!/usr/bin/env bash
set -e
S="cloudclaw-proof-$(date +%s)"

echo "Sending a trivial request. Free cloud should usually win when OpenRouter is connected..."
openclaw agent \
  --agent main \
  --session-key "$S" \
  --message "Reply in one sentence: what is a Linux process?" \
  --json

echo
echo "Router decision:"
tail -1 "$HOME/.openclaw/logs/cloud-first-router.log" 2>/dev/null || true
SH
chmod +x "$BIN/cloudclaw-test"

# ------------------------------------------------------------
# Make Gateway wait for router brain.
# ------------------------------------------------------------
mkdir -p "$SYSTEMD/openclaw-gateway.service.d"
cat > "$SYSTEMD/openclaw-gateway.service.d/30-cloudclaw.conf" <<EOF
[Unit]
Wants=cloudclaw-router-brain.service
After=cloudclaw-router-brain.service
EOF

systemctl --user daemon-reload

echo
echo "[6/8] Setting local safety-net defaults..."

# The plugin chooses cloud on each turn; this default protects startup/plugin failure.
"$OC" models set "$LOCAL_DEFAULT" || true
"$OC" config set agents.defaults.utilityModel "lmstudio/$ROUTER_MODEL" || true
"$OC" config set models.providers.lmstudio.params.preload false --strict-json || true

echo
echo "[7/8] Building the current fallback chain..."
"$BIN/cloudclaw-refresh" || true

echo
echo "[8/8] Validating + restarting..."
"$OC" config validate
"$OC" gateway install --force >/dev/null 2>&1 || true
"$OC" gateway restart >/dev/null 2>&1 || \
  systemctl --user restart openclaw-gateway.service
sleep 2

PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qsF "$PROFILE_LINE" "$HOME/.profile" 2>/dev/null; then
  printf '\n%s\n' "$PROFILE_LINE" >> "$HOME/.profile"
fi

echo
echo "============================================================"
echo " CLOUD-FIRST SMART OPENCLAW INSTALLED"
echo "============================================================"
echo
echo "Main commands:"
echo "  cloudclaw-connect   add/sign into more online providers"
echo "  cloudclaw-refresh   rebuild fallbacks + probe availability"
echo "  cloudclaw-status    see cloud/local/router health"
echo "  cloudclaw-test      run one proof request"
echo
echo "Watch every routing decision:"
echo "  tail -f ~/.openclaw/logs/cloud-first-router.log"
echo
echo "Current architecture:"
echo
echo "  USER PROMPT"
echo "      |"
echo "      v"
echo "  tiny Qwen CPU router"
echo "      |"
echo "      +--> OpenRouter FREE (when connected/suitable)"
echo "      +--> authenticated cloud models/subscriptions"
echo "      +--> LM Studio strong local model"
echo "      '--> tiny Qwen emergency local"
echo
echo "IMPORTANT:"
echo "  No script can create provider accounts, paid credits, or API keys for you."
echo "  cloudclaw-connect uses official OpenClaw auth flows for accounts you own."
