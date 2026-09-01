#!/usr/bin/env bash

###############################################################################
# CHRISTOPHER KUBUNTU AI WORKSTATION BOOTSTRAP
#
# Target:
#   Fresh Kubuntu / Ubuntu-based KDE Plasma
#   x86_64
#   NVIDIA RTX 5060 Ti 16GB
#
# Philosophy:
#   - idempotent
#   - logged
#   - verify everything
#   - stop on critical failures
#   - automatically resume after NVIDIA reboot
#   - no root password required
#   - root account remains locked
#   - local AI services bind locally unless explicitly configured otherwise
#
# Major stack:
#   NVIDIA
#   Docker
#   Git / GitHub CLI
#   Node
#   Python / uv
#   Ollama
#   OpenClaw beta
#   Hermes
#   Claude Code
#   OpenAI Codex
#   OpenCode
#   Aider
#   Playwright
#   ComfyUI
#   Open WebUI
#   n8n
#   KVM / QEMU / libvirt
#   AI workspace / agent council structure
###############################################################################

set -Eeuo pipefail

###############################################################################
# GLOBALS
###############################################################################

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

AI_ROOT="$USER_HOME/AI-PC"
AI_MODELS="$AI_ROOT/Models"
AI_PROJECTS="$AI_ROOT/Projects"
AI_WORKSPACE="$AI_ROOT/Workspace"
AI_AGENTS="$AI_ROOT/Agents"
AI_LOGS="$AI_ROOT/Logs"
AI_DOWNLOADS="$AI_ROOT/Downloads"
AI_SHARED="$AI_ROOT/Shared"
AI_OUTPUT="$AI_ROOT/Output"
AI_INBOX="$AI_ROOT/Inbox"
AI_SKILLS="$AI_ROOT/Skills"
AI_BACKUPS="$AI_ROOT/Backups"
AI_MISSIONS="$AI_ROOT/Missions"

STATE_DIR="/var/lib/christopher-ai-bootstrap"
LOG_FILE="$USER_HOME/christopher-kubuntu-install.log"

RESUME_SERVICE="/etc/systemd/system/christopher-kubuntu-resume.service"

MARKER_NVIDIA="$STATE_DIR/nvidia-installed"
MARKER_COMPLETE="$STATE_DIR/complete"

###############################################################################
# COLORS
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

###############################################################################
# LOGGING
###############################################################################

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"
chown "$USER_NAME:$USER_NAME" "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

###############################################################################
# FUNCTIONS
###############################################################################

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo -e "${CYAN}[$(timestamp)]${NC} $*"
}

success() {
    echo -e "${GREEN}✔ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

die() {
    echo -e "${RED}✖ $*${NC}"
    echo
    echo "Installation stopped."
    echo "Log:"
    echo "$LOG_FILE"
    exit 1
}

section() {
    echo
    echo "======================================================================"
    echo -e "${BLUE}$*${NC}"
    echo "======================================================================"
    echo
}

run() {
    log "RUN: $*"
    "$@"
}

as_user() {
    sudo -u "$USER_NAME" -H "$@"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command missing: $1"
}

###############################################################################
# ERROR HANDLING
###############################################################################

trap 'echo -e "${RED}FAILED at line $LINENO: $BASH_COMMAND${NC}"' ERR

###############################################################################
# START
###############################################################################

section "CHRISTOPHER AI PC BOOTSTRAP"

log "User: $USER_NAME"
log "Home: $USER_HOME"
log "Script: $SCRIPT_PATH"
log "Log: $LOG_FILE"

###############################################################################
# VERIFY OS
###############################################################################

section "VERIFY OPERATING SYSTEM"

if [[ ! -f /etc/os-release ]]; then
    die "Cannot identify operating system."
fi

source /etc/os-release

log "Distribution: ${PRETTY_NAME:-unknown}"

if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* && "${ID_LIKE:-}" != *debian* ]]; then
    warn "This does not appear to be Ubuntu/Debian based."
    warn "This installer is designed for Kubuntu."
fi

ARCH="$(dpkg --print-architecture)"

if [[ "$ARCH" != "amd64" ]]; then
    die "This workstation installer currently requires x86_64/amd64."
fi

###############################################################################
# BASIC DIRECTORY STRUCTURE
###############################################################################

section "CREATE AI WORKSPACE"

mkdir -p \
    "$AI_ROOT" \
    "$AI_MODELS" \
    "$AI_PROJECTS" \
    "$AI_WORKSPACE" \
    "$AI_AGENTS" \
    "$AI_LOGS" \
    "$AI_DOWNLOADS" \
    "$AI_SHARED" \
    "$AI_OUTPUT" \
    "$AI_INBOX" \
    "$AI_SKILLS" \
    "$AI_BACKUPS" \
    "$AI_MISSIONS"

chown -R "$USER_NAME:$USER_NAME" "$AI_ROOT"

###############################################################################
# SYSTEM UPDATE
###############################################################################

section "UPDATE KUBUNTU"

run sudo apt-get update
run sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

###############################################################################
# BASE PACKAGES
###############################################################################

section "INSTALL BASE DEVELOPMENT / AI DEPENDENCIES"

BASE_PACKAGES=(
    build-essential
    ca-certificates
    curl
    wget
    git
    git-lfs
    unzip
    zip
    xz-utils
    bzip2
    jq
    rsync
    tree
    htop
    btop
    nvtop
    tmux
    screen
    ripgrep
    fd-find
    fzf
    bat
    lsof
    pciutils
    usbutils
    dmidecode
    lm-sensors
    net-tools
    dnsutils
    iputils-ping
    openssh-client
    openssh-server
    socat
    sqlite3
    libsqlite3-dev
    pkg-config
    libssl-dev
    libffi-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    liblzma-dev
    libncurses-dev
    tk-dev
    ffmpeg
    imagemagick
    poppler-utils
    pandoc
    python3
    python3-dev
    python3-pip
    python3-venv
    python3-full
    pipx
    software-properties-common
    apt-transport-https
    gnupg
    ca-certificates
    flatpak
    gnome-software-plugin-flatpak
    vlc
    chromium
    libnss3
    libatk-bridge2.0-0
    libgtk-3-0
    libgbm-dev
    libasound2t64
    libxss1
    libxshmfence1
    libxkbcommon0
    libdrm2
    libxcomposite1
    libxdamage1
    libxrandr2
    libu2f-udev
    libvulkan1
    vulkan-tools
)

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "${BASE_PACKAGES[@]}" || \
    warn "Some optional base packages were unavailable; continuing."

###############################################################################
# ROOT / SUDO CONFIG
###############################################################################

section "CONFIGURE PASSWORDLESS ADMIN FOR THE AI WORKSTATION"

SUDO_FILE="/etc/sudoers.d/christopher-ai"

cat <<EOF | sudo tee "$SUDO_FILE" >/dev/null
$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF

sudo chmod 440 "$SUDO_FILE"

if ! sudo visudo -cf "$SUDO_FILE"; then
    sudo rm -f "$SUDO_FILE"
    die "Invalid sudo configuration."
fi

# Lock direct root password rather than trying to eliminate authentication.
sudo passwd -l root >/dev/null 2>&1 || true

success "Passwordless sudo configured for $USER_NAME"
success "Direct root password remains locked"

###############################################################################
# NVIDIA DETECTION
###############################################################################

section "DETECT NVIDIA GPU"

if lspci | grep -Eiq 'NVIDIA|3D controller.*NVIDIA|VGA compatible controller.*NVIDIA'; then

    success "NVIDIA hardware detected."

    lspci | grep -Ei 'NVIDIA|3D controller|VGA compatible controller' || true

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ubuntu-drivers-common \
        nvidia-prime \
        nvidia-utils \
        nvidia-settings \
        nvidia-modprobe \
        nvidia-container-toolkit || true

    if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi >/dev/null 2>&1; then

        section "INSTALL NVIDIA DRIVER"

        log "NVIDIA driver is not operational."
        log "As this is a fresh machine, installing the recommended Ubuntu driver."

        sudo ubuntu-drivers devices || true

        sudo DEBIAN_FRONTEND=noninteractive ubuntu-drivers autoinstall

        touch "$MARKER_NVIDIA"

        #######################################################################
        # CREATE AUTOMATIC RESUME SERVICE
        #######################################################################

        section "PREPARE AUTOMATIC POST-REBOOT RESUME"

        sudo tee "$RESUME_SERVICE" >/dev/null <<EOF
[Unit]
Description=Christopher AI PC Bootstrap Resume
After=network-online.target graphical.target
Wants=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
Group=$USER_NAME
Environment=HOME=$USER_HOME
Environment=USER=$USER_NAME
WorkingDirectory=$USER_HOME
ExecStart=/bin/bash $SCRIPT_PATH --resume
RemainAfterExit=no

[Install]
WantedBy=graphical.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable christopher-kubuntu-resume.service

        success "Automatic resume service installed."

        echo
        echo "======================================================================"
        echo -e "${GREEN}NVIDIA DRIVER INSTALLED${NC}"
        echo "======================================================================"
        echo
        echo "The machine MUST reboot so the NVIDIA kernel module can load."
        echo
        echo "The installer has registered an automatic resume service."
        echo
        echo "After reboot:"
        echo "  - Kubuntu will start normally"
        echo "  - the bootstrap will resume automatically"
        echo "  - NVIDIA will be verified"
        echo "  - the AI stack installation will continue"
        echo
        echo "Log:"
        echo "$LOG_FILE"
        echo

        sudo systemctl reboot

        exit 0
    fi

    success "NVIDIA driver is operational."

    nvidia-smi || true

else
    warn "No NVIDIA GPU detected."
    warn "Continuing in CPU-safe mode."
fi

###############################################################################
# VERIFY GPU
###############################################################################

section "GPU VERIFICATION"

if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
        success "NVIDIA GPU is working."

        nvidia-smi --query-gpu=name,memory.total,driver_version \
            --format=csv,noheader || true
    else
        die "NVIDIA hardware exists but nvidia-smi failed."
    fi
fi

###############################################################################
# DOCKER
###############################################################################

section "INSTALL DOCKER"

if ! command -v docker >/dev/null 2>&1; then

    sudo apt-get install -y \
        docker.io \
        docker-compose-v2

else
    success "Docker already installed."
fi

sudo systemctl enable --now docker

sudo usermod -aG docker "$USER_NAME"

docker_version="$(sudo docker --version)"
success "$docker_version"

###############################################################################
# GITHUB CLI
###############################################################################

section "INSTALL GITHUB CLI"

if ! command -v gh >/dev/null 2>&1; then

    type -p curl >/dev/null || sudo apt-get install -y curl

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
        status=none

    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    sudo apt-get update
    sudo apt-get install -y gh

fi

gh --version || true

###############################################################################
# NODE.JS
###############################################################################

section "INSTALL NODE.JS"

# OpenClaw currently supports Node 22.22.3+, 24.15+ and 25.9+.
# Node 24 LTS is a conservative system choice.

if ! command -v node >/dev/null 2>&1 || \
   ! node -e 'process.exit(parseInt(process.versions.node) >= 22 ? 0 : 1)' 2>/dev/null; then

    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

fi

node --version
npm --version

###############################################################################
# UV
###############################################################################

section "INSTALL UV PYTHON TOOLING"

if ! command -v uv >/dev/null 2>&1; then
    as_user bash -c \
        'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

export PATH="$USER_HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    warn "uv not visible yet; Hermes installer will install/manage its own uv."
else
    uv --version
fi

###############################################################################
# OLLAMA
###############################################################################

section "INSTALL OLLAMA"

if ! command -v ollama >/dev/null 2>&1; then

    curl -fsSL https://ollama.com/install.sh | sh

fi

sudo systemctl enable --now ollama

ollama --version || true

###############################################################################
# OLLAMA MODEL WAREHOUSE
###############################################################################

section "CONFIGURE LOCAL MODEL WAREHOUSE"

mkdir -p "$AI_MODELS"
chown -R "$USER_NAME:$USER_NAME" "$AI_MODELS"

# Configure Ollama to use the dedicated AI model warehouse.
# Keep the systemd service local and let Ollama manage model loading.

sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/christopher-models.conf >/dev/null <<EOF
[Service]
Environment="OLLAMA_MODELS=$AI_MODELS"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

sleep 3

###############################################################################
# LOCAL MODEL DOWNLOADS
###############################################################################

section "DOWNLOAD INITIAL LOCAL AI MODELS"

log "These are starter models for the 16GB RTX workstation."
log "They are downloaded sequentially and are NOT all loaded into VRAM simultaneously."

MODELS=(
    "qwen3.5:9b"
    "gemma3:12b"
    "deepseek-r1:8b"
    "nomic-embed-text"
)

for MODEL in "${MODELS[@]}"; do
    if ollama list | awk '{print $1}' | grep -Fxq "$MODEL"; then
        success "Already installed: $MODEL"
    else
        log "Pulling: $MODEL"
        ollama pull "$MODEL" || warn "Could not pull $MODEL; continuing."
    fi
done

###############################################################################
# OLLAMA GPU TEST
###############################################################################

section "OLLAMA GPU TEST"

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then

    log "Running a local model test."

    ollama run qwen3.5:9b \
        "Reply with exactly: CHRISTOPHER LOCAL GPU ONLINE" \
        --verbose 2>&1 | tee "$AI_LOGS/ollama-gpu-test.log" || \
        warn "Ollama model test returned an error."

fi

###############################################################################
# OPENCLAW
###############################################################################

section "INSTALL OPENCLAW BETA"

if command -v openclaw >/dev/null 2>&1; then

    success "OpenClaw already installed."
    openclaw --version || true

else

    curl -fsSL --proto '=https' --tlsv1.2 \
        https://openclaw.ai/install.sh |
        bash -s -- --beta --no-onboard --verify

fi

export PATH="$USER_HOME/.local/bin:$USER_HOME/.npm-global/bin:$PATH"

if command -v openclaw >/dev/null 2>&1; then
    openclaw --version || true
else
    warn "OpenClaw installed but is not yet visible in PATH."
fi

###############################################################################
# HERMES
###############################################################################

section "INSTALL HERMES AGENT"

if command -v hermes >/dev/null 2>&1; then

    success "Hermes already installed."

else

    curl -fsSL \
        https://hermes-agent.nousresearch.com/install.sh |
        bash

fi

export PATH="$USER_HOME/.local/bin:$PATH"

if command -v hermes >/dev/null 2>&1; then
    hermes --version || true
fi

###############################################################################
# HERMES BROWSER DEPENDENCIES
###############################################################################

section "INSTALL BROWSER AUTOMATION DEPENDENCIES"

if command -v npx >/dev/null 2>&1; then

    npx playwright install-deps chromium || \
        warn "Playwright system dependencies returned warnings."

fi

###############################################################################
# PLAYWRIGHT
###############################################################################

section "INSTALL PLAYWRIGHT"

as_user npm install -g playwright || \
    warn "Global Playwright install failed."

as_user npx playwright install chromium || \
    warn "Playwright Chromium install failed."

###############################################################################
# CLAUDE CODE
###############################################################################

section "INSTALL CLAUDE CODE"

if ! command -v claude >/dev/null 2>&1; then

    as_user npm install -g @anthropic-ai/claude-code

fi

claude --version || true

###############################################################################
# OPENAI CODEX
###############################################################################

section "INSTALL OPENAI CODEX"

if ! command -v codex >/dev/null 2>&1; then

    as_user npm install -g @openai/codex

fi

codex --version || true

###############################################################################
# OPENCODE
###############################################################################

section "INSTALL OPENCODE"

if ! command -v opencode >/dev/null 2>&1; then

    as_user npm install -g opencode-ai || \
        warn "OpenCode package was unavailable."
fi

opencode --version 2>/dev/null || true

###############################################################################
# AIDER
###############################################################################

section "INSTALL AIDER"

if ! command -v aider >/dev/null 2>&1; then

    as_user pipx install aider-chat || \
        warn "Aider installation returned a warning."
fi

###############################################################################
# COMFYUI
###############################################################################

section "INSTALL COMFYUI"

COMFY_ROOT="$AI_ROOT/ComfyUI"

if [[ ! -d "$COMFY_ROOT/.git" ]]; then

    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_ROOT"

else

    git -C "$COMFY_ROOT" pull --ff-only || true

fi

chown -R "$USER_NAME:$USER_NAME" "$COMFY_ROOT"

###############################################################################
# COMFYUI PYTHON ENVIRONMENT
###############################################################################

section "CREATE COMFYUI PYTHON ENVIRONMENT"

if [[ ! -d "$COMFY_ROOT/.venv" ]]; then

    as_user uv venv \
        --python 3.13 \
        "$COMFY_ROOT/.venv"

fi

COMFY_PIP="$COMFY_ROOT/.venv/bin/pip"
COMFY_PYTHON="$COMFY_ROOT/.venv/bin/python"

as_user "$COMFY_PIP" install --upgrade pip wheel setuptools

###############################################################################
# COMFYUI NVIDIA PYTORCH
###############################################################################

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then

    section "INSTALL NVIDIA PYTORCH FOR COMFYUI"

    as_user "$COMFY_PIP" install \
        torch torchvision torchaudio \
        --extra-index-url https://download.pytorch.org/whl/cu130

else

    warn "No operational NVIDIA GPU. Installing standard ComfyUI dependencies."
fi

###############################################################################
# COMFYUI REQUIREMENTS
###############################################################################

section "INSTALL COMFYUI REQUIREMENTS"

as_user "$COMFY_PIP" install \
    -r "$COMFY_ROOT/requirements.txt"

###############################################################################
# COMFYUI GPU VERIFICATION
###############################################################################

if [[ -x "$COMFY_PYTHON" ]]; then

    "$COMFY_PYTHON" - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("CUDA:", torch.version.cuda)
    print("GPU:", torch.cuda.get_device_name(0))
    print("VRAM GB:",
          round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2))
PY

fi

###############################################################################
# COMFYUI START SCRIPT
###############################################################################

cat > "$COMFY_ROOT/start-comfyui.sh" <<EOF
#!/usr/bin/env bash
cd "$COMFY_ROOT"
exec "$COMFY_PYTHON" main.py --listen 127.0.0.1 --port 8188
EOF

chmod +x "$COMFY_ROOT/start-comfyui.sh"
chown "$USER_NAME:$USER_NAME" "$COMFY_ROOT/start-comfyui.sh"

###############################################################################
# OPEN WEBUI
###############################################################################

section "INSTALL OPEN WEBUI"

sudo docker pull ghcr.io/open-webui/open-webui:main

sudo docker rm -f open-webui 2>/dev/null || true

sudo docker run -d \
    --name open-webui \
    --restart unless-stopped \
    -p 127.0.0.1:3000:8080 \
    --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -v open-webui:/app/backend/data \
    ghcr.io/open-webui/open-webui:main

###############################################################################
# N8N
###############################################################################

section "INSTALL N8N"

sudo docker pull docker.n8n.io/n8nio/n8n

sudo docker rm -f n8n 2>/dev/null || true

sudo docker volume create n8n_data >/dev/null

sudo docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p 127.0.0.1:5678:5678 \
    -v n8n_data:/home/node/.n8n \
    docker.n8n.io/n8nio/n8n

###############################################################################
# KVM / VIRTUALIZATION
###############################################################################

section "INSTALL VIRTUALIZATION STACK"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    qemu-kvm \
    qemu-utils \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    ovmf \
    swtpm

sudo usermod -aG libvirt "$USER_NAME"
sudo usermod -aG kvm "$USER_NAME"

sudo systemctl enable --now libvirtd || true

###############################################################################
# AI DIRECTORY STRUCTURE
###############################################################################

section "BUILD AI AGENT ARCHITECTURE"

mkdir -p \
    "$AI_AGENTS/Builder" \
    "$AI_AGENTS/Strategist" \
    "$AI_AGENTS/QA" \
    "$AI_AGENTS/Researcher" \
    "$AI_AGENTS/Operator" \
    "$AI_AGENTS/Media" \
    "$AI_AGENTS/Systems" \
    "$AI_AGENTS/Memory" \
    "$AI_MISSIONS/ACTIVE" \
    "$AI_MISSIONS/COMPLETED" \
    "$AI_MISSIONS/FAILED"

###############################################################################
# SHARED STATE
###############################################################################

cat > "$AI_ROOT/GOAL.md" <<'EOF'
# CHRISTOPHER AI PC

## Primary Goal

Create a local-first AI operating environment that can:

- understand a high-level mission
- plan the work
- challenge assumptions
- execute tasks
- use local and cloud models
- operate files
- operate browsers
- write and run code
- manage projects
- create media
- operate automation
- inspect its own work
- verify results
- recover from failures
- maintain persistent project state

The user should not have to act as the message courier between agents.

## Agent Council

Builder:
Does the work.

Strategist:
Challenges the objective and proposes better approaches.

QA:
Tests and verifies.

Researcher:
Finds information and alternatives.

Operator:
Handles system operations.

Media:
Handles image/video/audio generation pipelines.

Systems:
Handles Linux, Docker, networking, VMs and infrastructure.

Memory:
Maintains useful persistent project knowledge.
EOF

cat > "$AI_ROOT/STATE.md" <<'EOF'
# AI PC STATE

Status: BOOTSTRAPPING

Hardware:
- NVIDIA RTX 5060 Ti 16GB
- Kubuntu / KDE Plasma

Local AI:
- Ollama
- Qwen
- Gemma
- DeepSeek-R1
- embeddings

Agents:
- OpenClaw
- Hermes
- Claude Code
- OpenAI Codex
- OpenCode
- Aider

Automation:
- n8n

Media:
- ComfyUI

GUI:
- Open WebUI
- Hermes Desktop
- OpenClaw Control UI

Virtualisation:
- KVM
- QEMU
- libvirt
- virt-manager
EOF

cat > "$AI_ROOT/PLAN.md" <<'EOF'
# MASTER PLAN

1. Finish operating-system bootstrap.
2. Verify NVIDIA.
3. Verify Ollama GPU acceleration.
4. Verify ComfyUI GPU acceleration.
5. Complete OpenClaw onboarding.
6. Complete Hermes provider setup.
7. Authenticate Codex.
8. Authenticate Claude Code.
9. Build agent council.
10. Build unified AI dashboard.
11. Add browser automation.
12. Add persistent mission state.
13. Add voice/avatar interface.
14. Add autonomous project execution.
EOF

cat > "$AI_ROOT/TASKS.md" <<'EOF'
# TASKS

- [ ] Complete first boot
- [ ] Verify NVIDIA
- [ ] Verify Ollama
- [ ] Verify ComfyUI
- [ ] Authenticate OpenClaw
- [ ] Authenticate Hermes
- [ ] Authenticate Codex
- [ ] Authenticate Claude Code
- [ ] Build Builder agent
- [ ] Build Strategist agent
- [ ] Build QA agent
- [ ] Build unified AI GUI
- [ ] Add voice
- [ ] Add avatar
- [ ] Add browser control
- [ ] Add persistent memory
- [ ] Add autonomous mission runner
EOF

###############################################################################
# AGENT ROLE FILES
###############################################################################

cat > "$AI_AGENTS/Builder/ROLE.md" <<'EOF'
# BUILDER

You are the execution agent.

Your job is to turn the mission into working results.

Do not blindly execute a bad plan.

Before significant work:
1. Read GOAL.md
2. Read STATE.md
3. Read PLAN.md
4. Check the current filesystem
5. Check what is already installed
6. Identify dependencies
7. Execute
8. Test
9. Report exactly what changed

Never claim something works without verifying it.
EOF

cat > "$AI_AGENTS/Strategist/ROLE.md" <<'EOF'
# STRATEGIST

You are the challenge and architecture agent.

Your first question is:

"What are we actually trying to achieve?"

Challenge unnecessary complexity.

Look for:
- simpler approaches
- better tools
- cheaper approaches
- more reliable approaches
- architecture problems
- hidden dependencies
- opportunities for automation

You are not here merely to agree with Builder.
EOF

cat > "$AI_AGENTS/QA/ROLE.md" <<'EOF'
# QA

You are the verification agent.

Assume Builder may be wrong.

Test:
- installation
- configuration
- network access
- services
- GPU acceleration
- APIs
- files
- permissions
- expected outputs

Do not mark a task complete until there is evidence.
EOF

cat > "$AI_AGENTS/Researcher/ROLE.md" <<'EOF'
# RESEARCHER

Find current documentation and reliable technical information.

Prefer:
1. Official documentation
2. Official GitHub repositories
3. Primary sources
4. High-quality technical references

Record useful findings in project state.
EOF

###############################################################################
# MISSION TEMPLATE
###############################################################################

cat > "$AI_MISSIONS/MASTER-MISSION.md" <<'EOF'
# CHRISTOPHER MASTER MISSION

We are building an AI-first Linux workstation.

The objective is NOT merely to install applications.

The objective is to create a computer that can act as an AI operating environment.

The system should have:

- local LLMs
- cloud LLMs
- multiple AI agents
- agent-to-agent communication
- browser control
- file control
- code execution
- system administration
- media generation
- automation
- persistent memory
- project state
- GUI
- voice
- avatar
- autonomous long-running missions

The user gives a high-level objective.

Strategist should challenge the objective.

Builder executes.

QA verifies.

Researcher investigates alternatives.

No agent should require the user to relay messages between agents.

Prefer GUI interfaces.

Use terminal commands underneath the GUI where necessary, but do not make the user live in terminals.

The system must be observable, recoverable and auditable.
EOF

chown -R "$USER_NAME:$USER_NAME" "$AI_ROOT"

###############################################################################
# DESKTOP LAUNCHERS
###############################################################################

section "CREATE KDE DESKTOP LAUNCHERS"

DESKTOP_DIR="$USER_HOME/Desktop"

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_DIR/Open-WebUI.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Open WebUI
Comment=Local AI Chat Interface
Exec=xdg-open http://127.0.0.1:3000
Icon=applications-internet
Terminal=false
Categories=AI;Development;
EOF

cat > "$DESKTOP_DIR/OpenClaw-Control.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=OpenClaw Control
Comment=OpenClaw AI Control Centre
Exec=xdg-open http://127.0.0.1:18789
Icon=applications-internet
Terminal=false
Categories=AI;Development;
EOF

cat > "$DESKTOP_DIR/n8n.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=n8n Automation
Comment=AI Automation
Exec=xdg-open http://127.0.0.1:5678
Icon=applications-system
Terminal=false
Categories=Development;
EOF

cat > "$DESKTOP_DIR/ComfyUI.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ComfyUI
Comment=AI Image and Video Generation
Exec=xdg-open http://127.0.0.1:8188
Icon=applications-graphics
Terminal=false
Categories=Graphics;AI;
EOF

cat > "$DESKTOP_DIR/Hermes.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hermes AI
Comment=Hermes AI Desktop
Exec=$USER_HOME/.local/bin/hermes desktop
Icon=applications-development
Terminal=false
Categories=AI;Development;
EOF

chmod +x "$DESKTOP_DIR"/*.desktop
chown -R "$USER_NAME:$USER_NAME" "$DESKTOP_DIR"

###############################################################################
# HEALTH CHECK SCRIPT
###############################################################################

section "CREATE AI HEALTH CHECK"

cat > "$AI_ROOT/health-check.sh" <<'EOF'
#!/usr/bin/env bash

echo
echo "=============================================="
echo " CHRISTOPHER AI PC HEALTH CHECK"
echo "=============================================="
echo

echo "SYSTEM"
uname -a
echo

echo "GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.total,driver_version \
        --format=csv,noheader
else
    echo "NVIDIA SMI unavailable"
fi
echo

echo "OLLAMA"
systemctl is-active ollama || true
ollama list || true
echo

echo "DOCKER"
sudo docker ps || true
echo

echo "OPENCLAW"
command -v openclaw && openclaw --version || true
echo

echo "HERMES"
command -v hermes && hermes --version || true
echo

echo "CODEX"
command -v codex && codex --version || true
echo

echo "CLAUDE"
command -v claude && claude --version || true
echo

echo "COMFYUI PYTORCH"
if [[ -x "$HOME/AI-PC/ComfyUI/.venv/bin/python" ]]; then
    "$HOME/AI-PC/ComfyUI/.venv/bin/python" - <<'PY'
import torch
print("Torch:", torch.__version__)
print("CUDA:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
PY
fi

echo
echo "SERVICES"
echo "Open WebUI: http://127.0.0.1:3000"
echo "n8n:        http://127.0.0.1:5678"
echo "ComfyUI:    http://127.0.0.1:8188"
echo "OpenClaw:   http://127.0.0.1:18789"
echo
EOF

chmod +x "$AI_ROOT/health-check.sh"
chown "$USER_NAME:$USER_NAME" "$AI_ROOT/health-check.sh"

###############################################################################
# OPENCLAW BASIC PREPARATION
###############################################################################

section "PREPARE OPENCLAW"

if command -v openclaw >/dev/null 2>&1; then

    mkdir -p "$USER_HOME/.openclaw"

    # These settings are intentionally conservative:
    # local gateway only; no public exposure.

    openclaw config set gateway.bind "loopback" || true

    # Make local Ollama models discoverable where supported.
    openclaw config set agents.defaults.models \
        '{"ollama/*":{}}' \
        --strict-json \
        --merge || true

fi

###############################################################################
# SYSTEMD / USER SERVICES
###############################################################################

section "ENABLE USER SERVICE LINGER"

sudo loginctl enable-linger "$USER_NAME" || true

###############################################################################
# FINAL VERIFICATION
###############################################################################

section "FINAL SYSTEM VERIFICATION"

FAILURES=0

check() {
    local name="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        success "$name"
    else
        warn "$name FAILED"
        FAILURES=$((FAILURES + 1))
    fi
}

check "Docker" sudo docker info
check "Ollama" systemctl is-active --quiet ollama

if command -v nvidia-smi >/dev/null 2>&1; then
    check "NVIDIA" nvidia-smi
fi

if command -v openclaw >/dev/null 2>&1; then
    success "OpenClaw present"
else
    warn "OpenClaw missing"
    FAILURES=$((FAILURES + 1))
fi

if command -v hermes >/dev/null 2>&1; then
    success "Hermes present"
else
    warn "Hermes missing"
    FAILURES=$((FAILURES + 1))
fi

if command -v codex >/dev/null 2>&1; then
    success "Codex present"
else
    warn "Codex missing"
    FAILURES=$((FAILURES + 1))
fi

if command -v claude >/dev/null 2>&1; then
    success "Claude Code present"
else
    warn "Claude Code missing"
    FAILURES=$((FAILURES + 1))
fi

if sudo docker ps --format '{{.Names}}' | grep -qx open-webui; then
    success "Open WebUI container"
else
    warn "Open WebUI container missing"
    FAILURES=$((FAILURES + 1))
fi

if sudo docker ps --format '{{.Names}}' | grep -qx n8n; then
    success "n8n container"
else
    warn "n8n container missing"
    FAILURES=$((FAILURES + 1))
fi

###############################################################################
# WRITE INSTALL SUMMARY
###############################################################################

section "WRITE INSTALL SUMMARY"

cat > "$AI_ROOT/INSTALL-SUMMARY.md" <<EOF
# CHRISTOPHER AI PC INSTALLATION

Date:
$(date)

Operating System:
${PRETTY_NAME:-unknown}

Architecture:
$ARCH

User:
$USER_NAME

AI root:
$AI_ROOT

Model warehouse:
$AI_MODELS

## Local GUIs

Open WebUI
http://127.0.0.1:3000

n8n
http://127.0.0.1:5678

ComfyUI
http://127.0.0.1:8188

OpenClaw Control
http://127.0.0.1:18789

Hermes
Launch from KDE menu or:
hermes desktop

## Major installed components

NVIDIA
Docker
Git
GitHub CLI
Node
Python
uv
Ollama
OpenClaw beta
Hermes
Claude Code
OpenAI Codex
OpenCode
Aider
Playwright
ComfyUI
Open WebUI
n8n
KVM/QEMU/libvirt

## Local models

qwen3.5:9b
gemma3:12b
deepseek-r1:8b
nomic-embed-text

## Agent architecture

Builder
Strategist
QA
Researcher
Operator
Media
Systems
Memory

## Health check

$AI_ROOT/health-check.sh

## Important

Cloud AI providers still require user authentication/API credentials.

Run OpenClaw onboarding:

openclaw onboard --install-daemon

Run Hermes setup:

hermes setup --portal

Then authenticate Codex and Claude Code normally.
EOF

chown "$USER_NAME:$USER_NAME" "$AI_ROOT/INSTALL-SUMMARY.md"

###############################################################################
# MARK COMPLETE
###############################################################################

date > "$MARKER_COMPLETE"

###############################################################################
# REMOVE RESUME SERVICE
###############################################################################

if [[ -f "$RESUME_SERVICE" ]]; then
    sudo systemctl disable christopher-kubuntu-resume.service || true
    sudo rm -f "$RESUME_SERVICE"
    sudo systemctl daemon-reload
fi

###############################################################################
# FINAL REPORT
###############################################################################

section "CHRISTOPHER AI PC BOOTSTRAP COMPLETE"

echo
echo "=============================================================="
echo -e "${GREEN}        AI WORKSTATION BOOTSTRAP FINISHED${NC}"
echo "=============================================================="
echo

echo "AI ROOT:"
echo "  $AI_ROOT"
echo

echo "LOG:"
echo "  $LOG_FILE"
echo

echo "HEALTH CHECK:"
echo "  $AI_ROOT/health-check.sh"
echo

echo "LOCAL AI:"
echo "  Open WebUI   http://127.0.0.1:3000"
echo "  ComfyUI      http://127.0.0.1:8188"
echo "  n8n          http://127.0.0.1:5678"
echo "  OpenClaw     http://127.0.0.1:18789"
echo

echo "HERMES DESKTOP:"
echo "  hermes desktop"
echo

echo "OPENCLAW:"
echo "  openclaw onboard --install-daemon"
echo

echo "HERMES:"
echo "  hermes setup --portal"
echo

echo "MODELS:"
ollama list || true

echo
echo "=============================================================="

if [[ "$FAILURES" -eq 0 ]]; then
    echo -e "${GREEN}NO CRITICAL INSTALLATION FAILURES DETECTED.${NC}"
else
    echo -e "${YELLOW}$FAILURES COMPONENT(S) NEED ATTENTION.${NC}"
    echo "Run:"
    echo "  $AI_ROOT/health-check.sh"
fi

echo
echo "IMPORTANT:"
echo "A new login/session may be required for Docker/libvirt group membership."
echo
echo "The machine is now ready for the next phase:"
echo
echo "  AI COUNCIL + UNIFIED AI GUI + AUTONOMOUS MISSIONS"
echo
echo "=============================================================="
