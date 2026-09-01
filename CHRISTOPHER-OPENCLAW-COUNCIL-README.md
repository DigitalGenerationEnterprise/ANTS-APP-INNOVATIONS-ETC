# Christopher OpenClaw Council

Second-layer setup for the Christopher AI-first Kubuntu workstation.

## What it does

- Audits OpenClaw, gateway, browser, Ollama, NVIDIA and major AI/dev tools.
- Creates durable project context so the council sees the architecture, goals, roles, task protocol and fallback strategy.
- Creates Director/Christopher, Strategist, Builder, QA, Researcher, Operator, Systems, Media, Social and Memory workspaces.
- Configures OpenClaw's documented multi-agent/session controls without replacing the existing config file.
- Gives agents browser access where supported.
- Creates a managed-browser bridge for opening, snapshotting, clicking and typing on web pages.
- Creates a mission runner with task decomposition, verification and a local-runtime fallback.
- Creates model/provider fallback routing.
- Creates a bounded continuous-improvement loop.
- Creates a safe Chrome-extension scaffold for page-text handoff.
- Creates KDE launchers and a doctor report.

## Install

Run as the normal desktop user, not with sudo:

```bash
chmod +x CHRISTOPHER-OPENCLAW-COUNCIL.sh
./CHRISTOPHER-OPENCLAW-COUNCIL.sh
```

Then:

```bash
~/AI-PC/christopher/bin/christopher-doctor
~/AI-PC/christopher/bin/christopher-council --file ~/AI-PC/christopher/missions/000-BOOTSTRAP-COUNCIL.md
```

Or:

```bash
~/AI-PC/christopher/bin/christopher-council "Audit the workstation and decide what useful improvement we should build next."
```

Bounded improvement loop:

```bash
CHRISTOPHER_MAX_ROUNDS=5 ~/AI-PC/christopher/bin/christopher-improve
```

## Web / ChatGPT-style operation

Current OpenClaw supports a dedicated managed browser profile with navigation,
snapshots, screenshots and click/type actions. It also supports configured
Chrome/user profiles for existing signed-in sessions. Prefer the managed browser
for isolated automation; use an existing signed-in profile only after authorization.

A ChatGPT-like webpage can therefore be used as a computer-use fallback. Prefer
official API/provider integrations when available. Do not store passwords, bypass
CAPTCHA/2FA, or treat browser automation as an API.

## Continuous improvement

The system asks the Strategist to challenge each improvement, delegates execution,
uses QA, records evidence and uses fallbacks when blocked. "Never stop" means
persistent useful work within bounded missions; it does not bypass approval gates.

External publication, contacting real people, spending money, credentials,
important deletion, public exposure and irreversible actions remain approval-gated.
