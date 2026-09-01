# ANTS-APP-INNOVATIONS-ETC
BETA AND TEST SHIT - I AM AN IDEAS GUY NOT A ENGINEER. - HATE WASTING TIME. 
# Christopher Kubuntu AI Workstation Installer

## 🚀 Turn a Fresh Kubuntu PC Into an AI Workstation

**Christopher Kubuntu AI Workstation Installer** is an automated bootstrap script for building a modern, AI-first Kubuntu desktop.

It is designed for people who want their computer to become a serious local/cloud AI workstation without spending hours manually installing drivers, runtimes, agents, development tools, AI interfaces and supporting infrastructure.

The installer is designed to **discover the computer rather than assume a particular machine**.

It can detect the current user, operating system, architecture and GPU, install what's missing, verify important components, and resume automatically when a reboot is required.

---

# What Does It Install?

The installer builds a broad AI workstation stack including:

### 🧠 Local AI

* Ollama
* Qwen
* Gemma
* DeepSeek-R1
* Embedding models
* Dedicated local model warehouse

### 🤖 AI Agents

* OpenClaw **Beta**
* Hermes
* Claude Code
* OpenAI Codex
* OpenCode
* Aider

### 🎨 Generative AI

* ComfyUI
* NVIDIA PyTorch acceleration
* Image/video generation environment
* FFmpeg
* ImageMagick

### 🌐 AI Web Interfaces

* Open WebUI
* OpenClaw Control UI
* Hermes Desktop

### ⚙️ Automation

* n8n
* Docker
* Browser automation
* Playwright / Chromium

### 💻 Development

* Git
* Git LFS
* GitHub CLI
* Node.js
* Python
* uv
* pipx
* Build tools
* SQLite
* Common Linux development libraries

### 🖥️ Virtualisation

* QEMU
* KVM
* libvirt
* virt-manager
* OVMF
* TPM emulation

This makes the machine suitable for AI development, software development, automation, local LLMs, media generation, browser agents, server administration and experimentation.

---

# Hardware Support

The installer is designed to work across a range of systems.

It automatically checks for:

* NVIDIA GPUs
* AMD GPUs
* Intel graphics
* CPU-only systems

For NVIDIA systems it checks whether the NVIDIA driver is already working.

If it isn't, the installer attempts to install the recommended driver.

### NVIDIA reboot handling

A particularly important feature is automatic recovery from the NVIDIA driver installation.

The process is:

```text
Fresh Kubuntu
      ↓
Detect NVIDIA
      ↓
Install recommended driver
      ↓
Configure resume service
      ↓
Reboot
      ↓
Kubuntu starts
      ↓
Installer resumes
      ↓
Verify NVIDIA
      ↓
Continue AI installation
```

You don't have to manually remember which stage you reached.

---

# Requirements

## Operating System

Recommended:

**Kubuntu**

The installer is intended for Ubuntu/Debian-derived systems using APT.

A relatively recent Kubuntu release is strongly recommended.

## Architecture

Primary target:

```text
x86_64 / amd64
```

ARM64 detection is supported, but some components may not have equivalent binaries.

## Internet

A reasonably fast internet connection is strongly recommended.

The installer downloads:

* Linux packages
* NVIDIA drivers where required
* AI runtimes
* Python packages
* Node packages
* Docker images
* AI models
* ComfyUI dependencies

The initial installation can therefore consume considerable bandwidth and disk space.

## Storage

A **large SSD is strongly recommended**.

AI models can become very large.

A minimum of:

```text
100 GB free
```

is recommended for a basic installation.

For a serious AI workstation:

```text
500 GB+
```

is much more comfortable.

If you intend to maintain a large model library, multiple ComfyUI models and video-generation models, consider:

```text
1 TB – 4 TB+
```

---

# Before You Begin

## ⚠️ Important

This installer is intended to make significant changes to your computer.

It can:

* install system packages
* install graphics drivers
* install Docker
* install development runtimes
* add the current user to system groups
* configure passwordless sudo
* install AI software
* create Docker containers
* download large AI models
* install virtualization software
* reboot the computer

Do not run it on a production server without reviewing the script first.

For a fresh Kubuntu AI workstation, however, this is exactly the environment it was designed for.

---

# Installation

Download or copy:

```text
CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

Make it executable:

```bash
chmod +x CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

Run it as your **normal desktop user**:

```bash
./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

## Do NOT do this

```bash
sudo ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

The installer needs sudo internally, but it needs to know which normal desktop user owns the AI environment.

---

# What Happens During Installation?

The installer proceeds approximately like this:

```text
1. Discover computer
        ↓
2. Detect operating system
        ↓
3. Detect user/home directory
        ↓
4. Create AI workspace
        ↓
5. Update Kubuntu
        ↓
6. Install core Linux tools
        ↓
7. Configure administration
        ↓
8. Detect GPU
        ↓
9. Install/verify graphics driver
        ↓
10. Reboot if necessary
        ↓
11. Resume automatically
        ↓
12. Install Docker
        ↓
13. Install Node
        ↓
14. Install Python/uv
        ↓
15. Install Ollama
        ↓
16. Download starter models
        ↓
17. Install OpenClaw Beta
        ↓
18. Install Hermes
        ↓
19. Install Claude Code
        ↓
20. Install Codex
        ↓
21. Install OpenCode
        ↓
22. Install Aider
        ↓
23. Install browser automation
        ↓
24. Install ComfyUI
        ↓
25. Install GPU PyTorch
        ↓
26. Install Open WebUI
        ↓
27. Install n8n
        ↓
28. Install virtualization
        ↓
29. Create AI agent architecture
        ↓
30. Create KDE launchers
        ↓
31. Run health checks
        ↓
32. Finish
```

---

# Where Does Everything Go?

By default the installer creates:

```text
~/AI-PC/
```

Inside:

```text
AI-PC/
│
├── Agents/
│   ├── Builder/
│   ├── Strategist/
│   ├── QA/
│   ├── Researcher/
│   ├── Operator/
│   ├── Media/
│   ├── Systems/
│   └── Memory/
│
├── Backups/
│
├── ComfyUI/
│
├── Downloads/
│
├── Inbox/
│
├── Logs/
│
├── Missions/
│   ├── ACTIVE/
│   ├── COMPLETED/
│   └── FAILED/
│
├── Models/
│
├── Output/
│
├── Projects/
│
├── Shared/
│
├── Skills/
│
├── Workspace/
│
├── GOAL.md
├── STATE.md
├── PLAN.md
├── TASKS.md
├── MISSIONS/
├── START-HERE.md
├── INSTALL-SUMMARY.md
└── health-check.sh
```

This directory is intended to become the persistent workspace for the AI computer.

---

# Model Storage

Ollama is configured to use:

```text
~/AI-PC/Models
```

The initial models include:

```text
qwen3.5:9b
gemma3:12b
deepseek-r1:8b
nomic-embed-text
```

These are deliberately starter models rather than attempting to download every available model.

A 16 GB GPU can run useful models in this range while leaving room for the rest of the system.

Additional models can be added later.

For example:

```bash
ollama pull <model>
```

---

# Local AI Interfaces

After installation, several local interfaces are available.

## Open WebUI

```text
http://127.0.0.1:3000
```

Open WebUI provides a graphical interface for local AI models.

---

## n8n

```text
http://127.0.0.1:5678
```

n8n provides visual workflow automation.

It can eventually connect:

```text
AI
 ↓
n8n
 ↓
APIs
 ↓
Web
 ↓
Files
 ↓
Servers
 ↓
Notifications
```

---

## ComfyUI

```text
http://127.0.0.1:8188
```

ComfyUI provides node-based generative media workflows.

It is intended for:

* image generation
* image processing
* video workflows
* AI pipelines
* custom models
* automation

---

## OpenClaw

```text
http://127.0.0.1:18789
```

OpenClaw provides an AI agent/control environment.

The installer deliberately installs the **Beta** channel rather than the moving development branch.

---

## Hermes

Hermes includes a desktop interface.

Launch it with:

```bash
hermes desktop
```

The desktop interface is intended to provide a more graphical experience for agent conversations, projects, artifacts and tool activity.

---

# AI Agents

The workstation includes several different AI coding/agent systems.

## OpenClaw

Installed from the Beta channel.

Check:

```bash
openclaw --version
```

Complete its setup:

```bash
openclaw onboard --install-daemon
```

---

## Hermes

Check:

```bash
hermes --version
```

Run diagnostics:

```bash
hermes doctor
```

Set up a provider:

```bash
hermes setup --portal
```

Launch the graphical application:

```bash
hermes desktop
```

---

## Claude Code

Run:

```bash
claude
```

---

## OpenAI Codex

Run:

```bash
codex
```

---

## OpenCode

Run:

```bash
opencode
```

---

## Aider

Run:

```bash
aider
```

---

# Authentication

The installer deliberately does **not** attempt to automatically authenticate cloud AI services.

You will need to authenticate services such as:

* OpenClaw providers
* Hermes
* Claude
* Codex
* GitHub

This is intentional.

**Never put API keys, passwords or OAuth credentials directly into this installer.**

---

# The AI Agent Architecture

The installer creates an initial architecture for a future multi-agent AI system.

```text
                    ┌──────────────┐
                    │   STRATEGIST │
                    │              │
                    │ What are we  │
                    │ really trying│
                    │ to achieve?  │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │    BUILDER   │
                    │              │
                    │    Execute   │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │      QA      │
                    │              │
                    │    Verify    │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │    MEMORY    │
                    │              │
                    │   Persist    │
                    └──────────────┘
```

Supporting agents include:

```text
Researcher
Operator
Systems
Media
Memory
```

The installer creates the role definitions, but **does not pretend that the complete autonomous council has already been built**.

That is the next development layer.

---

# Health Check

After installation run:

```bash
~/AI-PC/health-check.sh
```

It checks:

* operating system
* GPU
* NVIDIA
* Ollama
* installed models
* Docker
* OpenClaw
* Hermes
* Codex
* Claude
* ComfyUI
* PyTorch
* CUDA
* local services
* AI workspace

This is the first command to run if something doesn't look right.

---

# Logs

The main installation log is:

```text
~/AI-PC/Logs/christopher-install.log
```

If the installer stops because of an unexpected problem, **read this file first**.

The installer intentionally stops on serious failures instead of displaying a fake "everything installed successfully" message.

---

# Running the Installer Again

The installer is designed to be substantially **idempotent**.

Running it again should generally:

* detect installed software
* skip components that already exist
* verify existing components
* repair or complete incomplete stages
* continue missing installations

This is useful if:

* the internet dropped out
* a package failed
* a model download failed
* you rebooted manually
* installation was interrupted

Simply run:

```bash
./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

again.

---

# Changing the AI Storage Location

By default:

```text
~/AI-PC
```

If you have a dedicated AI SSD mounted at:

```text
/mnt/ai
```

you can use:

```bash
AI_ROOT=/mnt/ai/AI-PC ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

This is recommended if your operating-system SSD is small.

---

# Optional Installation Controls

The installer supports environment variables.

## Disable optional packages

```bash
INSTALL_OPTIONAL=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

## Don't install virtualization

```bash
INSTALL_VIRTUALIZATION=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

## Don't install Docker AI applications

```bash
INSTALL_DOCKER_APPS=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

## Don't install ComfyUI

```bash
INSTALL_COMFYUI=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

## Don't download local models

```bash
DOWNLOAD_MODELS=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
```

These options are useful for smaller machines.

---

# Troubleshooting

## NVIDIA isn't working

Run:

```bash
nvidia-smi
```

If that fails:

```bash
ubuntu-drivers devices
```

Then:

```bash
sudo ubuntu-drivers autoinstall
```

Reboot:

```bash
sudo reboot
```

Then:

```bash
nvidia-smi
```

---

# Ollama isn't working

Check:

```bash
systemctl status ollama
```

Restart:

```bash
sudo systemctl restart ollama
```

Test:

```bash
ollama list
```

Then:

```bash
ollama run qwen3.5:9b
```

---

# Docker isn't working

Check:

```bash
sudo systemctl status docker
```

Restart:

```bash
sudo systemctl restart docker
```

You may also need to log out and back in because the installer adds the user to the Docker group.

---

# ComfyUI isn't working

Check the Python environment:

```bash
~/AI-PC/ComfyUI/.venv/bin/python --version
```

Check PyTorch:

```bash
~/AI-PC/ComfyUI/.venv/bin/python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

If CUDA reports:

```text
True
```

GPU acceleration is available.

---

# Open WebUI isn't working

Check:

```bash
sudo docker ps
```

Look for:

```text
open-webui
```

Restart:

```bash
sudo docker restart open-webui
```

Then visit:

```text
http://127.0.0.1:3000
```

---

# n8n isn't working

Check:

```bash
sudo docker ps
```

Restart:

```bash
sudo docker restart n8n
```

Then visit:

```text
http://127.0.0.1:5678
```

---

# Security

The installer intentionally configures:

```text
Passwordless sudo for the current desktop user
```

This is useful for an AI workstation where agents need to perform system administration without constantly stopping for a password prompt.

The root account's direct password remains locked.

Local AI interfaces are bound to:

```text
127.0.0.1
```

rather than being exposed directly to the internet.

### Important

Passwordless sudo means an AI agent operating under your account has extremely powerful access to the computer.

**Do not run untrusted AI agents or arbitrary scripts with this account.**

The design assumes this is a dedicated AI workstation where the owner deliberately wants high automation.

---

# What This Installer Does NOT Do

It does not:

* magically authenticate your cloud accounts
* download every AI model ever created
* install every obscure AI package
* expose your AI services to the internet
* remove all Linux security
* guarantee every third-party package will remain compatible forever
* claim that the multi-agent autonomous system is already finished

Instead, it creates a strong foundation.

---

# After Installation

Start with:

```bash
~/AI-PC/health-check.sh
```

Then authenticate the major AI systems:

```bash
openclaw onboard --install-daemon
```

```bash
hermes setup --portal
```

Then:

```bash
claude
```

and:

```bash
codex
```

Open the graphical interfaces:

```text
Open WebUI
http://127.0.0.1:3000

n8n
http://127.0.0.1:5678

ComfyUI
http://127.0.0.1:8188

OpenClaw
http://127.0.0.1:18789
```

And launch:

```bash
hermes desktop
```

---

# 🚀 What Comes Next?

The installer is deliberately only **Phase 1**.

The really interesting project is building the **Christopher AI Control Centre** on top of this foundation.

The intended architecture is:

```text
                         CHRISTOPHER
                              │
                     ┌────────┴────────┐
                     │                 │
                 STRATEGIST          USER
                     │                 │
                     └────────┬────────┘
                              │
                         MISSION BUS
                              │
              ┌───────────────┼────────────────┐
              │               │                │
           BUILDER           QA            RESEARCHER
              │               │                │
              └───────────────┼────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                 OLLAMA              CLOUD AI
                    │                   │
             ┌──────┴──────┐      ┌─────┴─────┐
             │             │      │           │
           QWEN          GEMMA  CODEX      CLAUDE
             │             │      │           │
             └─────────────┴──────┴───────────┘
                              │
                         TOOL LAYER
                              │
       ┌──────────┬───────────┼──────────┬──────────┐
       │          │           │          │          │
     FILES      BROWSER     TERMINAL   DOCKER    MEDIA
       │          │           │          │          │
       └──────────┴───────────┼──────────┴──────────┘
                              │
                          AUTOMATION
                              │
                             n8n
                              │
                         PERSISTENT STATE
                              │
                         MEMORY / PROJECTS
```

Eventually the user should be able to sit in front of **one graphical application** and say:

> "Build me this."

Christopher should then be able to:

1. Understand the objective.
2. Ask whether the proposed approach is actually the best way.
3. Research alternatives.
4. Create a plan.
5. Delegate tasks.
6. Write code.
7. Operate the filesystem.
8. Operate a browser.
9. Run applications.
10. Use local models.
11. Use cloud models.
12. Generate media.
13. Run automation.
14. Test the result.
15. Fix failures.
16. Maintain project state.
17. Report what happened.

The human should **not** have to manually copy messages from one AI to another.

---

# Philosophy

This project is based on a simple idea:

> **Don't build a computer that merely has AI applications installed. Build a computer that AI can actually operate.**

The terminal, Docker, Python, Node, Ollama, ComfyUI, n8n and the various agents are the machinery underneath.

The ultimate goal is a **graphical AI computer**.

The GUI should become the place where the human interacts with the system.

The agents should handle the machinery.

---

# License

Add your preferred project license here.

For example:

```text
MIT License
```

if you intend to release the installer as open source.

---

# Project Status

**Bootstrap installer:** Active

**Target:** Kubuntu AI Workstation

**GPU:** Hardware autodetected

**Local AI:** Ollama

**Agent layer:** OpenClaw Beta + Hermes + coding agents

**Creative AI:** ComfyUI

**Automation:** n8n

**GUI layer:** Open WebUI + Hermes Desktop + OpenClaw Control

**Future:** Christopher AI Control Centre

---

## ❤️ The Goal

This isn't intended to be another Linux setup script.

It's the beginning of an **AI-native workstation**.

Install Kubuntu.

Run the installer.

Let the computer build the foundation.

Then build the AI that operates the computer.
