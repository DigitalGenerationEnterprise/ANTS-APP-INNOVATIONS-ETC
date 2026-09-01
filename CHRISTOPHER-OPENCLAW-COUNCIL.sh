#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# CHRISTOPHER-OPENCLAW-COUNCIL.sh
# Second-layer setup for the Christopher AI workstation.
# Run as the normal desktop user, NOT with sudo.

AI_ROOT="${AI_ROOT:-$HOME/AI-PC}"
ROOT="${CHRISTOPHER_ROOT:-$AI_ROOT/christopher}"
BIN="$ROOT/bin"; WORK="$ROOT/work"; LOGS="$ROOT/logs"
AGENTS="$ROOT/agents"; MISSIONS="$ROOT/missions"; REPORTS="$ROOT/reports"
BRIDGES="$ROOT/bridges"; POLICY="$ROOT/policy"
OC_CONFIG="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
PASS=0; WARN=0; FAIL=0
mkdir -p "$BIN" "$WORK" "$LOGS" "$AGENTS" "$MISSIONS" "$REPORTS" "$BRIDGES" "$POLICY"
LOG="$LOGS/council-install.log"; touch "$LOG"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
pass(){ PASS=$((PASS+1)); log "PASS: $*"; }
warn(){ WARN=$((WARN+1)); log "WARN: $*"; }
fail(){ FAIL=$((FAIL+1)); log "FAIL: $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
die(){ fail "$*"; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your normal desktop user, not sudo."
have openclaw || die "OpenClaw is not installed. Run the fresh-Kubuntu installer first."

log "=== CHRISTOPHER OPENCLAW COUNCIL ==="
log "AI_ROOT=$AI_ROOT ROOT=$ROOT"

# -----------------------------------------------------------------------------
# 1. AUDIT THE FOUNDATION
# -----------------------------------------------------------------------------
log "--- OpenClaw ---"
openclaw --version 2>&1 | tee -a "$LOG" || warn "OpenClaw version check failed"
if openclaw gateway status >/tmp/coc-gateway 2>&1; then pass "Gateway reachable"; else warn "Gateway not healthy"; fi
cat /tmp/coc-gateway >> "$LOG" 2>/dev/null || true; rm -f /tmp/coc-gateway
if openclaw doctor >/tmp/coc-doctor 2>&1; then pass "OpenClaw doctor passed"; else warn "OpenClaw doctor reported issues"; fi
cat /tmp/coc-doctor >> "$LOG" 2>/dev/null || true; rm -f /tmp/coc-doctor
[[ -f "$OC_CONFIG" ]] && pass "OpenClaw config exists" || warn "OpenClaw config not found; onboarding may still be required"

log "--- Tools ---"
for c in ollama claude codex node npm docker gh python3 git nvidia-smi; do
  if have "$c"; then pass "$c detected"; else warn "$c not detected"; fi
done
if have ollama; then ollama list >> "$LOG" 2>&1 && pass "Ollama responds" || warn "Ollama failed"; fi
if have nvidia-smi; then nvidia-smi -L >> "$LOG" 2>&1 && pass "NVIDIA GPU visible" || warn "NVIDIA check failed"; fi

log "--- Browser ---"
if openclaw browser --browser-profile openclaw doctor >/tmp/coc-browser 2>&1; then pass "Browser doctor passed"; else warn "Browser doctor failed"; fi
cat /tmp/coc-browser >> "$LOG" 2>/dev/null || true; rm -f /tmp/coc-browser
if openclaw browser --browser-profile openclaw doctor --deep >/tmp/coc-browser-deep 2>&1; then pass "Browser deep check passed"; else warn "Browser deep check failed"; fi
cat /tmp/coc-browser-deep >> "$LOG" 2>/dev/null || true; rm -f /tmp/coc-browser-deep

# -----------------------------------------------------------------------------
# 2. DURABLE PROJECT CONTEXT
# -----------------------------------------------------------------------------
cat > "$WORK/CHRISTOPHER-CONTEXT.md" <<'EOF'
# CHRISTOPHER PROJECT CONTEXT

This is the durable project brief for the Christopher AI-first Linux workstation.
It contains project goals and operating instructions, not hidden model reasoning.

## Big objective
Build an AI-first computer where Anthony sets an outcome and a coordinated team
of agents can research, challenge the plan, execute work, verify it, recover from
failures and report back. Anthony should not be the message courier.

## Architecture
Fresh Kubuntu -> NVIDIA/GPU -> local models -> OpenClaw -> specialist agents ->
browser/computer use -> coding/dev tools -> automation/media -> AI Control Centre
-> eventually a reproducible AI-native Linux ISO.

## Council roles
DIRECTOR / CHRISTOPHER: owns mission, context, delegation and final report.
STRATEGIST: asks what outcome is actually desired and challenges assumptions.
BUILDER: implements and tests code/files.
QA: attempts to break work and demands evidence.
RESEARCHER: checks current primary documentation and alternatives.
OPERATOR: works on the actual desktop, files, terminal and browser.
SYSTEMS: Linux, NVIDIA, Docker, networking, virtualization and cloud.
MEDIA: ComfyUI/image/video production.
SOCIAL: drafts useful content; external publishing requires approval.
MEMORY: maintains durable summaries, decisions, lessons and completed work.

## Execution loop
UNDERSTAND -> RESEARCH -> STRATEGIZE -> DECOMPOSE -> EXECUTE -> VERIFY -> QA
-> RECOVER/FAILOVER -> RECORD -> REPORT.

If method A fails: diagnose it, then try a materially different method B/C/D.
Useful fallbacks include local model, cloud model, CLI tool, browser control,
an alternative tool, installing a missing tool, or human handoff. Do not
endlessly retry the same failure.

## Model routing
Prefer Ollama for private/routine work. Use configured OpenAI/Claude/other
providers for harder reasoning/coding where useful. Use browser control for
user-authorized web interactions. Never expose credentials in prompts/logs.

## Browser/chat strategy
OpenClaw's managed browser is the default isolated browser. Existing signed-in
sessions can use an explicitly configured Chrome/user profile after authorization.
A consumer chat webpage is a computer-use fallback, not an API. Prefer official
APIs/providers where available.

## Long-term ideas
AI mission control, persistent memory, multi-agent conversations, model routing,
browser/computer-use, automatic task decomposition, useful apps, GitHub projects,
articles/media, automation, and a future installable Linux ISO. A retro Platinum /
OS-9-inspired theme can be an optional visual layer using original assets/sounds.

## Human approval
Autonomous by default: research, inspect, code, test, draft, local organization.
Approval required: external publication, messaging real people, spending money,
deleting important data, credentials/passwords, public exposure, irreversible
disk actions, and legal/financial commitments.
EOF

cat > "$WORK/GOAL.md" <<'EOF'
# PRIMARY GOAL
Make the computer useful without requiring Anthony to orchestrate every step.
The Director should keep asking: What should we do next that materially improves
Anthony's work, projects, creativity, systems or quality of life?

"Never stop" means keep producing useful bounded missions, verify results and
ask for approval at policy boundaries. It does not mean blind infinite execution.
EOF

cat > "$WORK/PLAN.md" <<'EOF'
# PLAN
1. Verify foundation.
2. Establish council agents and communication.
3. Verify browser/computer use.
4. Verify model/provider fallbacks.
5. Run an end-to-end harmless mission.
6. Add useful continuous-improvement missions.
7. Build the Control Centre.
8. Freeze the tested system and build an ISO.
EOF

cat > "$WORK/TASK-PROTOCOL.md" <<'EOF'
# TASK PROTOCOL
Every mission: objective -> acceptance criteria -> strategy -> tasks -> owner
-> execution -> evidence -> QA -> fallback if failed -> report -> next action.
Never claim completion without evidence.
EOF

cat > "$WORK/PROVIDER-ROUTING.md" <<'EOF'
# PROVIDER ROUTING
A Local: Ollama for private/routine work.
B Cloud: configured OpenAI/Claude/etc. for hard reasoning/coding.
C CLI: Codex/Claude/other installed coding tools.
D Browser: OpenClaw managed browser or authorized Chrome profile.
E Alternate tool: install/use a better tool if justified.
F Human: credentials, CAPTCHA/2FA, public/irreversible actions, ambiguity.
Do not put secrets in mission files or logs.
EOF
pass "Durable context created"

# -----------------------------------------------------------------------------
# 3. SPECIALIST WORKSPACES
# -----------------------------------------------------------------------------
AGENT_IDS=(director strategist builder qa researcher operator systems media social memory)
for id in "${AGENT_IDS[@]}"; do mkdir -p "$AGENTS/$id"; done

cat > "$AGENTS/director/SOUL.md" <<EOF
# CHRISTOPHER / DIRECTOR
Own the mission. Read $WORK/CHRISTOPHER-CONTEXT.md and $WORK/GOAL.md first.
Ask Strategist to challenge the objective, delegate work, collect evidence,
call QA, use fallbacks and report what is done/failed/next. Never claim work is
complete without verification.
EOF
cat > "$AGENTS/strategist/SOUL.md" <<'EOF'
# STRATEGIST
Challenge the plan. Ask: what are we actually trying to achieve? Identify
simpler alternatives, hidden assumptions, risks and better sequencing.
EOF
cat > "$AGENTS/builder/SOUL.md" <<'EOF'
# BUILDER
Inspect first. Implement. Test. Fix. Retest. Record exact evidence. Never
pretend success because a command returned zero.
EOF
cat > "$AGENTS/qa/SOUL.md" <<'EOF'
# QA
Try to break the work. Reproduce failures. Check real behavior, integrations,
reboots and acceptance criteria. Return evidence-backed PASS/FAIL.
EOF
cat > "$AGENTS/researcher/SOUL.md" <<'EOF'
# RESEARCHER
Use current primary documentation and compare alternatives. Report source,
confidence, compatibility and a recommended path.
EOF
cat > "$AGENTS/operator/SOUL.md" <<'EOF'
# OPERATOR
Operate the computer using files, terminal and browser tools. Use bounded
fallbacks when something fails. Escalate login/CAPTCHA/2FA or risky actions.
EOF
cat > "$AGENTS/systems/SOUL.md" <<'EOF'
# SYSTEMS
Own Linux/KDE/NVIDIA/Docker/networking/virtualization/cloud. Prefer robust,
idempotent, reproducible configuration.
EOF
cat > "$AGENTS/media/SOUL.md" <<'EOF'
# MEDIA
Own ComfyUI, image/video workflows, creative assets and production pipelines.
EOF
cat > "$AGENTS/social/SOUL.md" <<'EOF'
# SOCIAL
Draft articles, posts, outreach and useful content. External publication or
contacting real people is approval-gated.
EOF
cat > "$AGENTS/memory/SOUL.md" <<'EOF'
# MEMORY
Maintain concise durable summaries, decisions, lessons and completed work.
Never invent missing history.
EOF
pass "10 specialist workspaces created"

# -----------------------------------------------------------------------------
# 4. OPENCLAW MULTI-AGENT CONFIG
# Uses documented `openclaw config set` rather than overwriting the config.
# -----------------------------------------------------------------------------
setcfg(){ openclaw config set "$1" "$2" >/dev/null 2>&1; }
for id in "${AGENT_IDS[@]}"; do
  if setcfg "agents.entries.$id.workspace" "$AGENTS/$id"; then pass "Workspace configured: $id"; else warn "Could not configure workspace: $id"; fi
done
setcfg 'tools.sessions.visibility' 'all' && pass "Session visibility=all" || warn "Could not set session visibility"
setcfg 'tools.agentToAgent.enabled' 'true' && pass "Agent-to-agent enabled" || warn "Could not enable agent-to-agent"
ALLOW_JSON='["director","strategist","builder","qa","researcher","operator","systems","media","social","memory"]'
setcfg 'tools.agentToAgent.allow' "$ALLOW_JSON" && pass "Agent allow-list configured" || warn "Could not configure agent allow-list"
setcfg 'browser.enabled' 'true' && pass "Browser enabled" || warn "Could not enable browser"
for id in "${AGENT_IDS[@]}"; do
  setcfg "agents.entries.$id.tools.alsoAllow" '["browser"]' || warn "Browser access not added to $id"
done

# -----------------------------------------------------------------------------
# 5. CONVERSATION PROTOCOL
# -----------------------------------------------------------------------------
cat > "$WORK/COUNCIL-CONVERSATION.md" <<'EOF'
# COUNCIL CONVERSATION PROTOCOL

Director:
  "Here is the objective. Strategist, tell me what we're really trying to
   achieve and challenge my assumptions."

Strategist:
  challenge + alternatives + recommended approach.

Director -> Researcher:
  verify the approach against current documentation.

Researcher:
  evidence + compatibility + fallback routes.

Director -> Builder/Operator:
  execute the smallest useful implementation.

Builder/Operator:
  implementation + evidence.

Director -> QA:
  try to break it.

QA:
  PASS/FAIL + evidence + regression concerns.

If FAIL:
  fix OR switch method/provider/tool. Do not endlessly retry the same thing.

Memory records the durable lesson. Director reports result and next action.
EOF

# -----------------------------------------------------------------------------
# 6. BROWSER / WEB CHAT BRIDGE
# -----------------------------------------------------------------------------
cat > "$BIN/christopher-browser" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
P="${OPENCLAW_BROWSER_PROFILE:-openclaw}"
case "${1:-status}" in
  start) shift; exec openclaw browser --browser-profile "$P" start "$@";;
  stop) shift; exec openclaw browser --browser-profile "$P" stop "$@";;
  status) shift; exec openclaw browser --browser-profile "$P" status "$@";;
  doctor) shift; exec openclaw browser --browser-profile "$P" doctor --deep "$@";;
  tabs) shift; exec openclaw browser --browser-profile "$P" tabs "$@";;
  open) shift; exec openclaw browser --browser-profile "$P" open "$@";;
  snapshot) shift; exec openclaw browser --browser-profile "$P" snapshot --interactive "$@";;
  screenshot) shift; exec openclaw browser --browser-profile "$P" screenshot "$@";;
  *) echo 'Usage: christopher-browser {start|stop|status|doctor|tabs|open URL|snapshot|screenshot}'; exit 2;;
esac
EOF
chmod +x "$BIN/christopher-browser"

cat > "$BRIDGES/CHAT-WEB-BRIDGE.md" <<'EOF'
# CHAT / WEB BRIDGE

OpenClaw's browser can open pages, inspect snapshots, click and type. This makes
an authorized web chat a fallback computer-use route.

Preferred order:
1. Official API/provider.
2. Local Ollama.
3. Claude/Codex/other configured CLI.
4. OpenClaw managed browser.
5. Authorized existing Chrome profile/extension.
6. Human handoff for login, 2FA, CAPTCHA or blocked interaction.

Do not store website passwords or bypass anti-bot controls. A browser session
is not assumed to be an API.
EOF

# -----------------------------------------------------------------------------
# 7. MISSION RUNNER: DECOMPOSE -> DELEGATE -> VERIFY -> FALLBACK
# -----------------------------------------------------------------------------
cat > "$BIN/christopher-council" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${CHRISTOPHER_ROOT:-$HOME/AI-PC/christopher}"
WORK="$ROOT/work"; MISS="$ROOT/missions"; REPORTS="$ROOT/reports"
mkdir -p "$MISS" "$REPORTS"
[[ $# -gt 0 ]] || { echo 'Usage: christopher-council "objective" | --file mission.md'; exit 2; }
STAMP="$(date +%Y%m%d-%H%M%S)"; M="$MISS/$STAMP.md"; R="$REPORTS/$STAMP-director.txt"
if [[ "$1" == --file ]]; then
  [[ -f "${2:-}" ]] || { echo "Mission file not found"; exit 2; }
  cp "$2" "$M"
else
  cat > "$M" <<EOF2
# CHRISTOPHER MISSION $STAMP

## OBJECTIVE
$*

## OPERATING INSTRUCTIONS
Read:
$WORK/CHRISTOPHER-CONTEXT.md
$WORK/GOAL.md
$WORK/PLAN.md
$WORK/TASK-PROTOCOL.md
$WORK/PROVIDER-ROUTING.md
$WORK/COUNCIL-CONVERSATION.md

Start a council conversation. Ask Strategist to challenge the objective.
Use Researcher to verify. Delegate implementation to Builder/Operator.
Use QA to test. If a method fails, diagnose and switch to a materially
different fallback. Use browser control when a web UI is appropriate.
Record evidence, fallback used, failures, and next action.

External publication, real-world messages, spending, deletion, credentials,
public exposure and irreversible changes require explicit approval.
EOF2
fi

# Primary route: Gateway. If it fails, do not silently repeat the same turn;
# try the embedded local runtime once as a materially different execution path.
if openclaw agent --agent director --message-file "$M" --timeout 900 >"$R" 2>&1; then
  echo "MISSION COMPLETE: $R"; exit 0
fi
rc=$?; echo "Gateway route failed rc=$rc; trying local fallback." | tee -a "$R"
if openclaw agent --local --agent director --message-file "$M" --timeout 900 >>"$R" 2>&1; then
  echo "LOCAL FALLBACK COMPLETE: $R"; exit 0
fi
exit 1
EOF
chmod +x "$BIN/christopher-council"

# -----------------------------------------------------------------------------
# 8. DOCTOR
# -----------------------------------------------------------------------------
cat > "$BIN/christopher-doctor" <<'EOF'
#!/usr/bin/env bash
set -u
ROOT="${CHRISTOPHER_ROOT:-$HOME/AI-PC/christopher}"
OUT="$ROOT/reports/doctor-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$ROOT/reports"
{
 echo '=== CHRISTOPHER DOCTOR ==='; date
 echo '=== OPENCLAW ==='; openclaw --version 2>&1 || true; openclaw gateway status 2>&1 || true; openclaw doctor 2>&1 || true
 echo '=== BROWSER ==='; openclaw browser --browser-profile openclaw status 2>&1 || true; openclaw browser --browser-profile openclaw doctor --deep 2>&1 || true
 echo '=== SESSIONS ==='; openclaw sessions --all-agents --limit 50 2>&1 || true
 echo '=== TOOLS ==='; for c in ollama claude codex docker gh node npm nvidia-smi; do command -v "$c" >/dev/null 2>&1 && echo "PASS $c $(command -v "$c")" || echo "WARN $c missing"; done
 echo '=== OLLAMA ==='; ollama list 2>&1 || true
 echo '=== AGENTS ==='; find "$ROOT/agents" -maxdepth 2 -type f -name SOUL.md -print 2>/dev/null | sort
} | tee "$OUT"
echo "Doctor report: $OUT"
EOF
chmod +x "$BIN/christopher-doctor"

# -----------------------------------------------------------------------------
# 9. BOUNDED CONTINUOUS IMPROVEMENT
# -----------------------------------------------------------------------------
cat > "$BIN/christopher-improve" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${CHRISTOPHER_ROOT:-$HOME/AI-PC/christopher}"; BIN="$ROOT/bin"; WORK="$ROOT/work"
ROUNDS="${CHRISTOPHER_MAX_ROUNDS:-5}"; SLEEP="${CHRISTOPHER_SLEEP_SECONDS:-120}"; n=0
while :; do
  n=$((n+1))
  cat > "$WORK/IMPROVEMENT-MISSION.md" <<EOF2
# CONTINUOUS IMPROVEMENT ROUND $n

Review the current Christopher workstation and project context.

Find one bounded, high-value improvement for Anthony. Consider broken or
unfinished software, useful apps, GitHub projects, articles/content/media,
automation, infrastructure, productivity and improvements to the AI council.

Do not just brainstorm: ask Strategist to challenge the choice, execute one
improvement, verify it with QA, record evidence and report the next action.
Use fallbacks if blocked.

Do not publish, contact real people, spend money, change credentials, delete
important data or make irreversible changes without explicit approval.
EOF2
  "$BIN/christopher-council" --file "$WORK/IMPROVEMENT-MISSION.md" || true
  if [[ "$ROUNDS" -gt 0 && "$n" -ge "$ROUNDS" ]]; then break; fi
  sleep "$SLEEP"
done
EOF
chmod +x "$BIN/christopher-improve"

cat > "$BIN/christopher-chat" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -gt 0 ]] || { echo 'Usage: christopher-chat "message"'; exit 2; }
exec openclaw agent --agent director --message "$*" --timeout 900
EOF
chmod +x "$BIN/christopher-chat"

# -----------------------------------------------------------------------------
# 10. CHROME EXTENSION SCAFFOLD
# -----------------------------------------------------------------------------
EXT="$BRIDGES/christopher-chrome-extension"; mkdir -p "$EXT"
cat > "$EXT/manifest.json" <<'EOF'
{
  "manifest_version": 3,
  "name": "Christopher Mission Bridge",
  "version": "0.1.0",
  "description": "Capture selected page text into a local Christopher handoff.",
  "permissions": ["activeTab", "scripting", "storage"],
  "action": {"default_title": "Send page to Christopher"},
  "background": {"service_worker": "background.js"},
  "options_page": "options.html"
}
EOF
cat > "$EXT/background.js" <<'EOF'
const DEFAULT_ENDPOINT='http://127.0.0.1:18789';
chrome.action.onClicked.addListener(async tab=>{
  const {endpoint=DEFAULT_ENDPOINT}=await chrome.storage.local.get('endpoint');
  const r=await chrome.scripting.executeScript({target:{tabId:tab.id},func:()=>({url:location.href,title:document.title,text:window.getSelection()?.toString()||document.body.innerText.slice(0,20000)})});
  await chrome.storage.local.set({lastPayload:r?.[0]?.result||{},endpoint});
});
EOF
cat > "$EXT/options.html" <<'EOF'
<!doctype html><html><body><h2>Christopher Mission Bridge</h2><p>Local endpoint only. No website passwords are stored.</p><input id=e size=60><button id=s>Save</button><script>chrome.storage.local.get({endpoint:'http://127.0.0.1:18789'},x=>e.value=x.endpoint);s.onclick=()=>chrome.storage.local.set({endpoint:e.value})</script></body></html>
EOF
cat > "$EXT/README.md" <<'EOF'
# Chrome extension scaffold

Captures selected page text (or a bounded page-text excerpt) into local
extension storage. It deliberately does not invent OpenClaw authentication.
For production, use OpenClaw's built-in Chrome profile/extension integration or
an authenticated local bridge rather than putting gateway tokens in an extension.
EOF
pass "Chrome bridge scaffold created"

# -----------------------------------------------------------------------------
# 11. BOOTSTRAP MISSION + KDE LAUNCHERS
# -----------------------------------------------------------------------------
cat > "$MISSIONS/000-BOOTSTRAP-COUNCIL.md" <<EOF
# BOOTSTRAP COUNCIL MISSION

Read:
$WORK/CHRISTOPHER-CONTEXT.md
$WORK/GOAL.md
$WORK/PLAN.md
$WORK/TASK-PROTOCOL.md
$WORK/PROVIDER-ROUTING.md
$WORK/COUNCIL-CONVERSATION.md

Prove agent-to-agent collaboration without Anthony acting as the courier:
1. Director asks Strategist what the real objective should be.
2. Strategist challenges it and proposes alternatives.
3. Researcher verifies one path.
4. Builder creates a harmless tiny artifact.
5. QA tests it.
6. If QA fails, Builder fixes it and QA retests.
7. Memory records the lesson.
8. Director reports evidence, failures, fallbacks and the next useful action.

No external publication or irreversible action.
EOF

DESK="$HOME/.local/share/applications"; mkdir -p "$DESK"
cat > "$DESK/christopher-council.desktop" <<EOF
[Desktop Entry]
Name=Christopher AI Council
Comment=Mission control and multi-agent council
Exec=$BIN/christopher-council
Terminal=true
Type=Application
Categories=Utility;Development;AI;
EOF
cat > "$DESK/christopher-doctor.desktop" <<EOF
[Desktop Entry]
Name=Christopher Doctor
Comment=Audit OpenClaw and the AI workstation
Exec=$BIN/christopher-doctor
Terminal=true
Type=Application
Categories=System;Utility;
EOF
cat > "$DESK/christopher-browser.desktop" <<EOF
[Desktop Entry]
Name=Christopher Browser
Comment=OpenClaw managed browser
Exec=$BIN/christopher-browser start
Terminal=true
Type=Application
Categories=Network;WebBrowser;AI;
EOF
pass "KDE launchers created"

cat > "$ROOT/README.md" <<EOF
# Christopher OpenClaw Council

Doctor:
$BIN/christopher-doctor

Bootstrap:
$BIN/christopher-council --file $MISSIONS/000-BOOTSTRAP-COUNCIL.md

Mission:
$BIN/christopher-council "Inspect the workstation and decide what useful improvement we should build next."

Bounded improvement:
CHRISTOPHER_MAX_ROUNDS=5 $BIN/christopher-improve

Browser:
$BIN/christopher-browser start
$BIN/christopher-browser open https://chatgpt.com/
$BIN/christopher-browser snapshot
EOF

cat > "$ROOT/INSTALL-SUMMARY.md" <<EOF
# Christopher OpenClaw Council Setup
Date: $(date)
PASS=$PASS WARN=$WARN FAIL=$FAIL
Root: $ROOT
OpenClaw config: $OC_CONFIG

Run:
$BIN/christopher-doctor
Then:
$BIN/christopher-council --file $MISSIONS/000-BOOTSTRAP-COUNCIL.md
EOF

log "=== COMPLETE PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
log "Doctor: $BIN/christopher-doctor"
log "Bootstrap: $BIN/christopher-council --file $MISSIONS/000-BOOTSTRAP-COUNCIL.md"
(( FAIL == 0 ))
