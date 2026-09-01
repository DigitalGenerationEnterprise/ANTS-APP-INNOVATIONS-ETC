# Christopher OpenClaw Autopilot

This is the second-layer coordinator requested for Anthony's Christopher AI-PC.
It audits OpenClaw, creates a seven-agent council, connects OpenClaw to Codex CLI,
Claude Code, Ollama, and the OpenAI Responses API as fallbacks, provides a web
Control UI/browser route, persists all mission conversations, breaks objectives
into tasks, implements bounded project work, runs independent QA, and performs a
limited repair loop.

It is deliberately persistent but not recklessly infinite. A daily timer can
start a fresh bounded round, while every round has time, retry, project-directory,
and external-action limits.

## First run on Kubuntu

```bash
chmod +x CHRISTOPHER-OPENCLAW-AUTOPILOT.sh
./CHRISTOPHER-OPENCLAW-AUTOPILOT.sh install --install-missing
```

`--install-missing` installs OpenClaw, Codex CLI, and Claude Code from their
current official installers when absent. Ollama remains optional and is not
silently installed because its GPU/runtime setup should be selected for the
actual machine. Without `--install-missing`, the installer only creates the
Christopher files and configures tools that are already present.

If OpenClaw has not been authenticated/configured yet, the script will preserve
the installed Christopher files and tell you to run:

```bash
openclaw onboard --install-daemon
./CHRISTOPHER-OPENCLAW-AUTOPILOT.sh install
```

Then run the full audit:

```bash
~/AI-PC/christopher/bin/christopher doctor
```

## Webpage chat and browser

OpenClaw already supplies the proper local webpage rather than requiring a weak
home-made copy of ChatGPT:

```bash
~/AI-PC/christopher/bin/christopher dashboard
```

Start its isolated automation browser:

```bash
~/AI-PC/christopher/bin/christopher browser managed
```

Open ChatGPT in the isolated browser:

```bash
~/AI-PC/christopher/bin/christopher browser chatgpt
```

Login, 2FA, and CAPTCHA must be completed by Anthony. The agents are explicitly
forbidden from reading or copying credentials, cookies, tokens, or auth stores.

To control an already signed-in Chrome session, install OpenClaw's official
extension route:

```bash
~/AI-PC/christopher/bin/christopher browser chrome
```

That command pre-registers OpenClaw's locked native host and then pauses for the
official Chrome Web Store extension or trusted unpacked development copy. This is
safer and more maintainable than a custom extension containing Gateway or account
credentials.

## ChatGPT/Codex ↔ OpenClaw conversation

This sends the message through the best available route and hands the response
to Christopher inside OpenClaw for a second opinion. Both sides are saved:

```bash
~/AI-PC/christopher/bin/christopher chat \
  "Review our AI-PC architecture and tell me the best next step"
```

Default conversation fallback order:

1. Codex CLI using its existing ChatGPT/Codex authentication.
2. OpenAI Responses API when `OPENAI_API_KEY` is available.
3. OpenClaw/Christopher.
4. Claude Code in plan mode.
5. Local Ollama.

The script never extracts or passes Codex/Claude/OpenClaw authentication files.

## Council mode

Council mode makes multiple AIs challenge and improve an idea, with bounded
rounds and a final task list:

```bash
~/AI-PC/christopher/bin/christopher council \
  "Turn myGig into a production-ready marketplace" \
  --rounds 3
```

Council mode is read-only. Its output is written beneath:

```text
~/AI-PC/christopher/missions/<timestamp-id>/
```

## Mission mode

Plan a real repository mission:

```bash
~/AI-PC/christopher/bin/christopher mission \
  "Audit the Flutter app and produce the prioritized repair plan" \
  --project ~/Projects/mygig
```

Authorize local project implementation and QA:

```bash
~/AI-PC/christopher/bin/christopher mission \
  "Fix the highest-priority verified Flutter failure and test it" \
  --project ~/Projects/mygig \
  --execute
```

The primary builder is Codex in `workspace-write` mode with approval escalation
disabled. This permits bounded repository edits but prevents it from escaping
the sandbox for network/system actions. OpenClaw's headless agent is the second
builder route and is scoped to the explicit project working directory.

Claude is used for planning and review by default. Claude execution is disabled
because its `auto` mode is not a hard filesystem sandbox. Advanced users can opt
in locally by creating:

```text
~/AI-PC/christopher/approvals/CLAUDE_AUTO
```

That opt-in still does not authorize publishing, messaging, spending, pushing,
deployment, credential work, or system installation.

## Bounded continuous improvement

Run up to three plan-only rounds:

```bash
~/AI-PC/christopher/bin/christopher improve \
  --project ~/Projects \
  --rounds 3
```

Allow local project work:

```bash
~/AI-PC/christopher/bin/christopher improve \
  --project ~/Projects \
  --rounds 3 \
  --execute
```

The coordinator prefers finishing useful existing work over generating endless
new ideas. Each task goes through Plan → Review → Build → QA → bounded repair.
It stops after repeated failure and leaves evidence for Anthony.

## Daily safe continuation

Enable one plan-only improvement round per day:

```bash
~/AI-PC/christopher/bin/christopher schedule enable
```

Enable one local-execution round per day:

```bash
~/AI-PC/christopher/bin/christopher schedule enable --execute
```

Inspect or disable it:

```bash
~/AI-PC/christopher/bin/christopher schedule status
~/AI-PC/christopher/bin/christopher schedule disable
```

The timer uses `NoNewPrivileges`, a one-hour limit, and one bounded round. It does
not publish, message people, spend, delete irreplaceable data, change credentials,
expose services, push, merge, or deploy.

## Model failover

OpenClaw's normal configured primary/fallback chain is respected. For its
headless project worker, an explicit chain can be supplied:

```bash
export CHRISTOPHER_PRIMARY_MODEL='openai/gpt-5.6-sol'
export CHRISTOPHER_FALLBACK_MODELS='anthropic/claude-sonnet-4-6,ollama/qwen3.5:9b'
```

Local Ollama fallback defaults to `qwen3.5:9b` and can be changed:

```bash
export CHRISTOPHER_OLLAMA_MODEL='your-installed-model'
```

OpenAI API fallback defaults to `gpt-5.6` and can be changed:

```bash
export CHRISTOPHER_OPENAI_MODEL='model-available-to-your-account'
```

## What the doctor checks

The doctor creates a timestamped report and checks:

- OS, disk, RAM, and NVIDIA GPU visibility.
- OpenClaw, Codex, Claude, Ollama, Git/GitHub CLI, Node/npm, and Python.
- OpenClaw config validation, overall status, deep Gateway status, Doctor,
  models, agents, sessions, channels, managed browser, Chrome extension, and
  security audit when supported.
- Ollama models, Codex auth status, and GitHub CLI auth status.

Run it any time after an upgrade:

```bash
~/AI-PC/christopher/bin/christopher doctor
```

The doctor never runs `doctor --fix`; repairs should follow the evidence instead
of silently rewriting a working configuration.

## Safety boundary

The system is designed to do substantial local work without interrupting Anthony
for every file edit. It intentionally refuses to become an unbounded agent with
permanent authority over Anthony's accounts or relationships.

It may create drafts and proposals. It may not autonomously:

- Contact family, friends, customers, or social networks.
- Impersonate Anthony.
- Publish articles, releases, posts, or apps.
- Push/merge to GitHub or deploy.
- Spend money, trade, subscribe, or accept terms.
- Read/copy credentials, cookies, tokens, or private keys.
- Delete irreplaceable data or weaken security.
- Install system-wide tools during an agent mission.

Those actions need a separate, exact instruction from Anthony after he reviews
the prepared result.

## Official references used

- OpenClaw Control UI, CLI, Gateway, agents, sessions, browser, Chrome extension,
  model fallback, config validation, and automations: <https://docs.openclaw.ai/>
- Codex non-interactive scripting and sandbox modes:
  <https://developers.openai.com/codex/non-interactive-mode>
- OpenAI Responses API: <https://developers.openai.com/api/reference/responses/overview>
- Claude Code headless and permission modes:
  <https://docs.anthropic.com/en/docs/claude-code/headless>
