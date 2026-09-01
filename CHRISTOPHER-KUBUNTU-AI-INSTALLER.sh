#!/usr/bin/env bash

###############################################################################
#
#       CHRISTOPHER KUBUNTU AI WORKSTATION INSTALLER
#
#       Universal-ish Ubuntu/Kubuntu AI workstation bootstrap
#
#       Designed for:
#         - Fresh Kubuntu
#         - Existing Kubuntu installations
#         - Ubuntu/Debian-derived KDE systems
#         - NVIDIA / AMD / Intel / CPU systems
#
#       Automatically discovers:
#         - current user
#         - home directory
#         - architecture
#         - GPU
#         - Ubuntu/Kubuntu version
#         - installed software
#         - available package managers
#
#       Major stack:
#
#         NVIDIA
#         Docker
#         Git
#         GitHub CLI
#         Node.js
#         Python
#         uv
#         Ollama
#         OpenClaw BETA
#         Hermes
#         Claude Code
#         OpenAI Codex
#         OpenCode
#         Aider
#         Playwright
#         ComfyUI
#         Open WebUI
#         n8n
#         KVM/QEMU/libvirt
#
#       Philosophy:
#
#         DISCOVER
#         INSTALL
#         VERIFY
#         FALL BACK
#         LOG
#         RESUME
#
###############################################################################

set -Eeuo pipefail

###############################################################################
# USER CONFIGURATION
#
# You normally do NOT need to change anything.
#
# Override examples:
#
#   AI_ROOT=/mnt/AI ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
#
#   INSTALL_OPTIONAL=0 ./CHRISTOPHER-KUBUNTU-AI-INSTALLER.sh
#
###############################################################################

AI_ROOT="${AI_ROOT:-$HOME/AI-PC}"

INSTALL_OPTIONAL="${INSTALL_OPTIONAL:-1}"

INSTALL_VIRTUALIZATION="${INSTALL_VIRTUALIZATION:-1}"

INSTALL_DOCKER_APPS="${INSTALL_DOCKER_APPS:-1}"

DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-1}"

INSTALL_COMFYUI="${INSTALL_COMFYUI:-1}"

INSTALL_BROWSER_TOOLS="${INSTALL_BROWSER_TOOLS:-1}"

###############################################################################
# DISCOVER USER
###############################################################################

if [[ "${EUID}" -eq 0 ]]; then

    if [[ -n "${SUDO_USER:-}" ]]; then
        REAL_USER="$SUDO_USER"
    else
        echo
        echo "Please run this installer as your normal desktop user."
        echo
        echo "Do NOT run:"
        echo
        echo "    sudo $0"
        echo
        exit 1
    fi

else
    REAL_USER="$USER"
fi

REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
    echo "Could not determine home directory for $REAL_USER"
    exit 1
fi

###############################################################################
# DERIVED PATHS
###############################################################################

AI_ROOT="${AI_ROOT/#\~/$REAL_HOME}"

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

STATE_DIR="$AI_ROOT/.installer-state"

LOG_FILE="$AI_ROOT/Logs/christopher-install.log"

SCRIPT_PATH="$(readlink -f "$0")"

RESUME_SERVICE="/etc/systemd/system/christopher-ai-resume.service"

###############################################################################
# COLOURS
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

###############################################################################
# LOGGING
###############################################################################

mkdir -p "$AI_ROOT/Logs"

touch "$LOG_FILE"

chown "$REAL_USER:$REAL_USER" "$LOG_FILE"

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

info() {
    echo -e "${BLUE}ℹ $*${NC}"
}

fatal() {
    echo
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}FATAL ERROR${NC}"
    echo -e "${RED}============================================================${NC}"
    echo
    echo "$*"
    echo
    echo "Log:"
    echo "$LOG_FILE"
    echo
    exit 1
}

section() {
    echo
    echo
    echo "======================================================================"
    echo -e "${MAGENTA}$*${NC}"
    echo "======================================================================"
    echo
}

as_user() {
    sudo -u "$REAL_USER" -H "$@"
}

###############################################################################
# ERROR REPORTING
###############################################################################

trap '
    rc=$?
    echo
    echo -e "${RED}INSTALLER ERROR${NC}"
    echo "Line: $LINENO"
    echo "Command: $BASH_COMMAND"
    echo "Exit code: $rc"
    echo
    echo "The installer has STOPPED rather than pretending everything worked."
    echo "Log: $LOG_FILE"
    exit "$rc"
' ERR

###############################################################################
# ROOT ACCESS
###############################################################################

section "CHECK ADMIN ACCESS"

if ! sudo -n true 2>/dev/null; then

    info "sudo authentication is required."

    sudo -v || fatal "This user does not have sudo access."

fi

success "Administrative access available."

###############################################################################
# OS DISCOVERY
###############################################################################

section "DISCOVER OPERATING SYSTEM"

[[ -f /etc/os-release ]] || fatal "Cannot determine operating system."

source /etc/os-release

OS_ID="${ID:-unknown}"
OS_NAME="${NAME:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"

log "User:       $REAL_USER"
log "Home:       $REAL_HOME"
log "OS:         $OS_NAME"
log "Version:    $OS_VERSION"
log "ID:         $OS_ID"
log "Architecture: $ARCH"
log "AI Root:    $AI_ROOT"

###############################################################################
# ARCHITECTURE CHECK
###############################################################################

if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then

    warn "This architecture has not been heavily tested by this installer."

    if [[ "$INSTALL_OPTIONAL" != "1" ]]; then
        fatal "Unsupported architecture."
    fi

fi

###############################################################################
# UBUNTU / DEBIAN FAMILY CHECK
###############################################################################

if command -v apt-get >/dev/null 2>&1; then

    success "APT package manager detected."

else

    fatal "This installer requires an APT-based Linux distribution."

fi

###############################################################################
# CREATE STATE
###############################################################################

mkdir -p "$STATE_DIR"

###############################################################################
# DIRECTORY TREE
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
    "$AI_MISSIONS/ACTIVE" \
    "$AI_MISSIONS/COMPLETED" \
    "$AI_MISSIONS/FAILED"

chown -R "$REAL_USER:$REAL_USER" "$AI_ROOT"

###############################################################################
# UPDATE PACKAGE DATABASE
###############################################################################

section "UPDATE SYSTEM"

sudo apt-get update

###############################################################################
# BASIC PACKAGE INSTALLER
###############################################################################

install_packages() {

    local packages=("$@")

    local available=()

    local package

    for package in "${packages[@]}"; do

        if apt-cache show "$package" >/dev/null 2>&1; then
            available+=("$package")
        else
            warn "Package unavailable: $package"
        fi

    done

    if [[ "${#available[@]}" -gt 0 ]]; then

        sudo DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "${available[@]}"

    fi
}

###############################################################################
# CORE PACKAGES
###############################################################################

section "INSTALL CORE LINUX TOOLS"

CORE_PACKAGES=(

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

    ripgrep
    fd-find
    fzf

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

    python3
    python3-dev
    python3-pip
    python3-venv
    python3-full
    pipx

    ffmpeg

    imagemagick
    poppler-utils

    pandoc

    software-properties-common

    apt-transport-https
    gnupg

    flatpak

    libvulkan1
    vulkan-tools

)

install_packages "${CORE_PACKAGES[@]}"

###############################################################################
# OPTIONAL DESKTOP PACKAGES
###############################################################################

if [[ "$INSTALL_OPTIONAL" == "1" ]]; then

    section "INSTALL DESKTOP / MEDIA TOOLS"

    DESKTOP_PACKAGES=(

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

    )

    install_packages "${DESKTOP_PACKAGES[@]}"

fi

###############################################################################
# PASSWORDLESS SUDO
###############################################################################

section "CONFIGURE AI ADMINISTRATION"

SUDO_FILE="/etc/sudoers.d/christopher-ai"

cat <<EOF | sudo tee "$SUDO_FILE" >/dev/null
$REAL_USER ALL=(ALL:ALL) NOPASSWD: ALL
EOF

sudo chmod 440 "$SUDO_FILE"

if sudo visudo -cf "$SUDO_FILE" >/dev/null; then

    success "Passwordless sudo enabled for $REAL_USER."

else

    sudo rm -f "$SUDO_FILE"

    fatal "Generated sudo configuration failed validation."

fi

###############################################################################
# KEEP ROOT PASSWORD LOCKED
###############################################################################

sudo passwd -l root >/dev/null 2>&1 || true

###############################################################################
# GPU DISCOVERY
###############################################################################

section "DISCOVER GPU"

GPU_INFO="$(lspci 2>/dev/null | grep -Ei 'VGA|3D controller|Display controller' || true)"

echo "$GPU_INFO"

GPU_VENDOR="none"

if echo "$GPU_INFO" | grep -qi nvidia; then
    GPU_VENDOR="nvidia"
elif echo "$GPU_INFO" | grep -Eqi 'AMD|ATI'; then
    GPU_VENDOR="amd"
elif echo "$GPU_INFO" | grep -Eqi 'Intel'; then
    GPU_VENDOR="intel"
fi

log "Detected GPU vendor: $GPU_VENDOR"

###############################################################################
# NVIDIA
###############################################################################

if [[ "$GPU_VENDOR" == "nvidia" ]]; then

    section "NVIDIA GPU DETECTED"

    install_packages \
        ubuntu-drivers-common \
        nvidia-settings \
        nvidia-modprobe

    NVIDIA_WORKING=0

    if command -v nvidia-smi >/dev/null 2>&1; then

        if nvidia-smi >/dev/null 2>&1; then
            NVIDIA_WORKING=1
        fi

    fi

    if [[ "$NVIDIA_WORKING" -eq 1 ]]; then

        success "NVIDIA driver already working."

        nvidia-smi \
            --query-gpu=name,memory.total,driver_version \
            --format=csv,noheader || true

    else

        section "INSTALL RECOMMENDED NVIDIA DRIVER"

        info "NVIDIA hardware exists but the driver is not operational."

        if command -v ubuntu-drivers >/dev/null 2>&1; then

            ubuntu-drivers devices || true

            sudo DEBIAN_FRONTEND=noninteractive \
                ubuntu-drivers autoinstall

        else

            fatal "ubuntu-drivers is unavailable."

        fi

        touch "$STATE_DIR/nvidia-reboot-required"

        #######################################################################
        # AUTOMATIC RESUME
        #######################################################################

        section "CONFIGURE AUTOMATIC RESUME AFTER NVIDIA REBOOT"

        sudo tee "$RESUME_SERVICE" >/dev/null <<EOF
[Unit]
Description=Christopher AI Workstation Installer Resume
After=network-online.target graphical.target
Wants=network-online.target

[Service]
Type=oneshot
User=$REAL_USER
Group=$REAL_USER

Environment=HOME=$REAL_HOME
Environment=USER=$REAL_USER

WorkingDirectory=$REAL_HOME

ExecStart=/bin/bash $SCRIPT_PATH --resume

TimeoutStartSec=infinity

[Install]
WantedBy=graphical.target
EOF

        sudo systemctl daemon-reload

        sudo systemctl enable christopher-ai-resume.service

        success "Automatic resume configured."

        echo
        echo "The NVIDIA driver has been installed."
        echo
        echo "The computer will reboot now."
        echo
        echo "After reboot the installer will continue automatically."
        echo

        sudo systemctl reboot

        exit 0

    fi

fi

###############################################################################
# AMD / INTEL
###############################################################################

if [[ "$GPU_VENDOR" == "amd" ]]; then

    section "AMD GPU"

    info "AMD GPU detected."

    info "No proprietary driver installation is required by this installer."

    install_packages \
        mesa-vulkan-drivers \
        mesa-utils \
        vulkan-tools

fi

if [[ "$GPU_VENDOR" == "intel" ]]; then

    section "INTEL GPU"

    info "Intel graphics detected."

    install_packages \
        mesa-vulkan-drivers \
        mesa-utils \
        intel-media-va-driver \
        vulkan-tools

fi

###############################################################################
# GPU FINAL CHECK
###############################################################################

section "GPU VERIFICATION"

if [[ "$GPU_VENDOR" == "nvidia" ]]; then

    if command -v nvidia-smi >/dev/null 2>&1 &&
       nvidia-smi >/dev/null 2>&1; then

        success "NVIDIA GPU operational."

    else

        fatal "NVIDIA GPU detected but driver verification failed."

    fi

elif [[ "$GPU_VENDOR" != "none" ]]; then

    if command -v vulkaninfo >/dev/null 2>&1; then
        vulkaninfo --summary 2>/dev/null | head -50 || true
    fi

else

    warn "No dedicated GPU detected."

fi

###############################################################################
# DOCKER
###############################################################################

section "INSTALL DOCKER"

if command -v docker >/dev/null 2>&1; then

    success "Docker already installed."

else

    install_packages \
        docker.io \
        docker-compose-v2

fi

sudo systemctl enable --now docker

sudo usermod -aG docker "$REAL_USER"

sudo docker --version

###############################################################################
# GITHUB CLI
###############################################################################

section "INSTALL GITHUB CLI"

if command -v gh >/dev/null 2>&1 then
    success "GitHub CLI already installed."
else

    if apt-cache show gh >/dev/null 2>&1; then

        sudo apt-get install -y gh

    else

        info "Installing GitHub CLI from official repository."

        curl -fsSL \
            https://cli.github.com/packages/githubcli-archive-keyring.gpg |
            sudo dd \
            of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
            status=none

        sudo chmod go+r \
            /usr/share/keyrings/githubcli-archive-keyring.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
            sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

        sudo apt-get update

        sudo apt-get install -y gh

    fi

fi

gh --version || true

###############################################################################
# NODE.JS
###############################################################################

section "INSTALL NODE.JS"

NODE_OK=0

if command -v node >/dev/null 2>&1; then

    NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"

    if [[ "$NODE_MAJOR" -ge 22 ]]; then
        NODE_OK=1
    fi

fi

if [[ "$NODE_OK" -eq 0 ]]; then

    info "Installing Node.js 24 LTS."

    curl -fsSL \
        https://deb.nodesource.com/setup_24.x |
        sudo -E bash -

    sudo DEBIAN_FRONTEND=noninteractive \
        apt-get install -y nodejs

fi

node --version

npm --version

###############################################################################
# UV
###############################################################################

section "INSTALL UV"

if command -v uv >/dev/null 2>&1; then

    success "uv already installed."

else

    as_user bash -c \
        'curl -LsSf https://astral.sh/uv/install.sh | sh'

fi

export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"

if command -v uv >/dev/null 2>&1; then
    uv --version
else
    warn "uv not visible in current PATH. Hermes will provide its own environment."
fi

###############################################################################
# OLLAMA
###############################################################################

section "INSTALL OLLAMA"

if command -v ollama >/dev/null 2>&1; then

    success "Ollama already installed."

else

    curl -fsSL https://ollama.com/install.sh | sh

fi

sudo systemctl enable --now ollama

ollama --version

###############################################################################
# OLLAMA MODEL LOCATION
###############################################################################

section "CONFIGURE MODEL WAREHOUSE"

mkdir -p "$AI_MODELS"

chown -R "$REAL_USER:$REAL_USER" "$AI_MODELS"

sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/ai-models.conf >/dev/null <<EOF
[Service]
Environment="OLLAMA_MODELS=$AI_MODELS"
EOF

sudo systemctl daemon-reload

sudo systemctl restart ollama

sleep 3

###############################################################################
# OLLAMA GPU CHECK
###############################################################################

section "VERIFY OLLAMA"

if ! systemctl is-active --quiet ollama; then

    fatal "Ollama service failed to start."

fi

success "Ollama service running."

###############################################################################
# LOCAL MODELS
###############################################################################

if [[ "$DOWNLOAD_MODELS" == "1" ]]; then

    section "DOWNLOAD STARTER LOCAL MODELS"

    info "Models are installed sequentially."
    info "They are not all loaded into VRAM simultaneously."

    MODELS=(
        "qwen3.5:9b"
        "gemma3:12b"
        "deepseek-r1:8b"
        "nomic-embed-text"
    )

    for MODEL in "${MODELS[@]}"; do

        if ollama list 2>/dev/null |
            awk '{print $1}' |
            grep -Fxq "$MODEL"; then

            success "Already installed: $MODEL"

        else

            info "Downloading $MODEL"

            if ! ollama pull "$MODEL"; then

                warn "Could not download $MODEL."

                echo "$MODEL" >> "$AI_ROOT/Logs/model-download-failures.txt"

            fi

        fi

    done

else

    info "Model downloads disabled."

fi

###############################################################################
# OLLAMA TEST
###############################################################################

section "TEST LOCAL AI"

if ollama list >/dev/null 2>&1; then

    if ollama list | grep -q 'qwen3.5'; then

        info "Testing Qwen local model."

        ollama run qwen3.5:9b \
            "Reply with exactly: CHRISTOPHER LOCAL AI ONLINE" \
            2>&1 |
            tee "$AI_LOGS/ollama-test.log" || \
            warn "Ollama model test failed."

    else

        warn "Qwen model not available for test."

    fi

fi

###############################################################################
# OPENCLAW
###############################################################################

section "INSTALL OPENCLAW BETA"

export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"

if command -v openclaw >/dev/null 2>&1; then

    success "OpenClaw already installed."

    openclaw --version || true

else

    info "Installing OpenClaw using the official beta channel."

    curl -fsSL \
        --proto '=https' \
        --tlsv1.2 \
        https://openclaw.ai/install.sh |
        bash -s -- \
        --beta \
        --no-onboard \
        --verify

fi

export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"

if command -v openclaw >/dev/null 2>&1; then

    openclaw --version || true

else

    warn "OpenClaw installed but command is not yet visible."
    warn "A new shell/login may be required."

fi

###############################################################################
# HERMES
###############################################################################

section "INSTALL HERMES"

if command -v hermes >/dev/null 2>&1; then

    success "Hermes already installed."

else

    curl -fsSL \
        https://hermes-agent.nousresearch.com/install.sh |
        bash

fi

export PATH="$REAL_HOME/.local/bin:$PATH"

if command -v hermes >/dev/null 2>&1; then

    hermes --version || true

else

    warn "Hermes command not visible yet."

fi

###############################################################################
# HERMES DIAGNOSTIC
###############################################################################

if command -v hermes >/dev/null 2>&1; then

    section "CHECK HERMES"

    hermes doctor || \
        warn "Hermes doctor reported configuration items that need attention."

fi

###############################################################################
# PLAYWRIGHT
###############################################################################

if [[ "$INSTALL_BROWSER_TOOLS" == "1" ]]; then

    section "INSTALL BROWSER AUTOMATION"

    if command -v npx >/dev/null 2>&1; then

        as_user npx playwright install chromium || \
            warn "Playwright Chromium installation failed."

        sudo npx playwright install-deps chromium || \
            warn "Some Chromium system dependencies could not be installed."

    else

        warn "npm/npx unavailable; browser automation skipped."

    fi

fi

###############################################################################
# CLAUDE CODE
###############################################################################

section "INSTALL CLAUDE CODE"

if command -v claude >/dev/null 2>&1; then

    success "Claude Code already installed."

else

    as_user npm install -g @anthropic-ai/claude-code || {

        warn "npm Claude Code install failed."

        info "Trying official Claude installer."

        as_user bash -c \
            'curl -fsSL https://claude.ai/install.sh | bash' ||
            warn "Claude Code could not be installed."

    }

fi

export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"

claude --version 2>/dev/null || true

###############################################################################
# CODEX
###############################################################################

section "INSTALL OPENAI CODEX"

if command -v codex >/dev/null 2>&1; then

    success "Codex already installed."

else

    as_user npm install -g @openai/codex ||
        warn "Codex installation failed."

fi

codex --version 2>/dev/null || true

###############################################################################
# OPENCODE
###############################################################################

section "INSTALL OPENCODE"

if command -v opencode >/dev/null 2>&1; then

    success "OpenCode already installed."

else

    as_user npm install -g opencode-ai ||
        warn "OpenCode package unavailable."

fi

opencode --version 2>/dev/null || true

###############################################################################
# AIDER
###############################################################################

section "INSTALL AIDER"

if command -v aider >/dev/null 2>&1; then

    success "Aider already installed."

else

    as_user pipx install aider-chat ||
        warn "Aider installation failed."

fi

###############################################################################
# COMFYUI
###############################################################################

if [[ "$INSTALL_COMFYUI" == "1" ]]; then

    section "INSTALL COMFYUI"

    COMFY_ROOT="$AI_ROOT/ComfyUI"

    if [[ -d "$COMFY_ROOT/.git" ]]; then

        info "ComfyUI repository already exists."

        git -C "$COMFY_ROOT" pull --ff-only ||
            warn "ComfyUI update skipped."

    else

        git clone \
            https://github.com/comfyanonymous/ComfyUI.git \
            "$COMFY_ROOT"

    fi

    chown -R "$REAL_USER:$REAL_USER" "$COMFY_ROOT"

    ###########################################################################
    # PYTHON ENVIRONMENT
    ###########################################################################

    section "CREATE COMFYUI PYTHON ENVIRONMENT"

    COMFY_PYTHON="$COMFY_ROOT/.venv/bin/python"

    if [[ ! -x "$COMFY_PYTHON" ]]; then

        if command -v uv >/dev/null 2>&1; then

            as_user uv venv \
                --python 3.13 \
                "$COMFY_ROOT/.venv"

        else

            as_user python3 -m venv \
                "$COMFY_ROOT/.venv"

        fi

    fi

    COMFY_PIP="$COMFY_ROOT/.venv/bin/pip"

    "$COMFY_PIP" install --upgrade \
        pip \
        setuptools \
        wheel

    ###########################################################################
    # NVIDIA PYTORCH
    ###########################################################################

    if [[ "$GPU_VENDOR" == "nvidia" ]]; then

        section "INSTALL COMFYUI NVIDIA PYTORCH"

        info "Trying current stable CUDA 13 PyTorch build."

        if ! as_user "$COMFY_PIP" install \
            torch torchvision torchaudio \
            --extra-index-url \
            https://download.pytorch.org/whl/cu130; then

            warn "CUDA 13 PyTorch installation failed."

            info "Trying documented CUDA 12.8 fallback."

            if ! as_user "$COMFY_PIP" install \
                torch torchvision torchaudio \
                --extra-index-url \
                https://download.pytorch.org/whl/cu128; then

                fatal "Could not install a working NVIDIA PyTorch build."

            fi

        fi

    else

        section "INSTALL COMFYUI PYTORCH"

        as_user "$COMFY_PIP" install \
            torch torchvision torchaudio ||
            warn "PyTorch installation failed."

    fi

    ###########################################################################
    # COMFYUI DEPENDENCIES
    ###########################################################################

    section "INSTALL COMFYUI DEPENDENCIES"

    as_user "$COMFY_PIP" install \
        -r "$COMFY_ROOT/requirements.txt"

    ###########################################################################
    # GPU TEST
    ###########################################################################

    section "VERIFY COMFYUI PYTORCH"

    "$COMFY_PYTHON" <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():

    print("CUDA version:", torch.version.cuda)

    for i in range(torch.cuda.device_count()):

        props = torch.cuda.get_device_properties(i)

        print(
            "GPU:",
            i,
            props.name,
            "VRAM:",
            round(props.total_memory / 1024**3, 2),
            "GB"
        )
PY

    ###########################################################################
    # COMFYUI START SCRIPT
    ###########################################################################

    cat > "$COMFY_ROOT/start.sh" <<EOF
#!/usr/bin/env bash

cd "$COMFY_ROOT"

exec "$COMFY_PYTHON" main.py \
    --listen 127.0.0.1 \
    --port 8188
EOF

    chmod +x "$COMFY_ROOT/start.sh"

    chown "$REAL_USER:$REAL_USER" \
        "$COMFY_ROOT/start.sh"

fi

###############################################################################
# OPEN WEBUI
###############################################################################

if [[ "$INSTALL_DOCKER_APPS" == "1" ]]; then

    section "INSTALL OPEN WEBUI"

    if sudo docker ps -a \
        --format '{{.Names}}' |
        grep -qx open-webui; then

        success "Open WebUI container already exists."

    else

        sudo docker pull \
            ghcr.io/open-webui/open-webui:main

        sudo docker run -d \
            --name open-webui \
            --restart unless-stopped \
            -p 127.0.0.1:3000:8080 \
            --add-host=host.docker.internal:host-gateway \
            -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
            -v open-webui:/app/backend/data \
            ghcr.io/open-webui/open-webui:main

    fi

fi

###############################################################################
# N8N
###############################################################################

if [[ "$INSTALL_DOCKER_APPS" == "1" ]]; then

    section "INSTALL N8N"

    if sudo docker ps -a \
        --format '{{.Names}}' |
        grep -qx n8n; then

        success "n8n container already exists."

    else

        sudo docker pull \
            docker.n8n.io/n8nio/n8n

        sudo docker volume create \
            n8n_data >/dev/null

        sudo docker run -d \
            --name n8n \
            --restart unless-stopped \
            -p 127.0.0.1:5678:5678 \
            -v n8n_data:/home/node/.n8n \
            docker.n8n.io/n8nio/n8n

    fi

fi

###############################################################################
# VIRTUALIZATION
###############################################################################

if [[ "$INSTALL_VIRTUALIZATION" == "1" ]]; then

    section "INSTALL VIRTUALIZATION"

    VIRT_PACKAGES=(

        qemu-kvm
        qemu-utils

        libvirt-daemon-system
        libvirt-clients

        bridge-utils

        virt-manager

        ovmf
        swtpm

    )

    install_packages "${VIRT_PACKAGES[@]}"

    sudo usermod -aG libvirt "$REAL_USER" || true

    sudo usermod -aG kvm "$REAL_USER" || true

    sudo systemctl enable --now libvirtd 2>/dev/null || true

fi

###############################################################################
# AGENT ARCHITECTURE
###############################################################################

section "CREATE AGENT ARCHITECTURE"

mkdir -p \
    "$AI_AGENTS/Builder" \
    "$AI_AGENTS/Strategist" \
    "$AI_AGENTS/QA" \
    "$AI_AGENTS/Researcher" \
    "$AI_AGENTS/Operator" \
    "$AI_AGENTS/Media" \
    "$AI_AGENTS/Systems" \
    "$AI_AGENTS/Memory"

###############################################################################
# GOAL
###############################################################################

cat > "$AI_ROOT/GOAL.md" <<'EOF'
# CHRISTOPHER AI COMPUTER

The goal is to turn this Linux computer into an AI-first workstation.

The computer should eventually be able to:

- understand high-level missions
- plan projects
- challenge plans
- write code
- operate files
- operate browsers
- run software
- use local AI
- use cloud AI
- create images
- create video
- automate workflows
- manage virtual machines
- manage servers
- maintain project memory
- test its own work
- recover from errors
- coordinate multiple agents
- present the user with a graphical interface

The user should give objectives rather than manually coordinate every tool.

Builder executes.

Strategist challenges.

Researcher investigates.

QA verifies.

Operator operates the computer.

Systems handles infrastructure.

Media handles creative AI.

Memory maintains useful persistent knowledge.
EOF

###############################################################################
# STATE
###############################################################################

cat > "$AI_ROOT/STATE.md" <<EOF
# CHRISTOPHER AI COMPUTER STATE

Installation date:
$(date)

Operating system:
$OS_NAME $OS_VERSION

Architecture:
$ARCH

User:
$REAL_USER

Home:
$REAL_HOME

AI root:
$AI_ROOT

GPU vendor:
$GPU_VENDOR

Status:
BOOTSTRAPPED
EOF

###############################################################################
# MASTER PLAN
###############################################################################

cat > "$AI_ROOT/PLAN.md" <<'EOF'
# MASTER PLAN

## Phase 1 — Operating System

- [x] Base packages
- [x] GPU detection
- [x] NVIDIA / graphics setup
- [x] Docker
- [x] Development tools

## Phase 2 — AI Engines

- [x] Ollama
- [x] Local models
- [x] ComfyUI
- [x] Open WebUI

## Phase 3 — AI Agents

- [x] OpenClaw
- [x] Hermes
- [x] Claude Code
- [x] Codex
- [x] OpenCode
- [x] Aider

## Phase 4 — Agent Council

- [ ] Builder
- [ ] Strategist
- [ ] QA
- [ ] Researcher
- [ ] Operator
- [ ] Systems
- [ ] Media
- [ ] Memory

## Phase 5 — Christopher Control Centre

- [ ] unified GUI
- [ ] model selector
- [ ] agent selector
- [ ] mission system
- [ ] persistent state
- [ ] live tool activity
- [ ] files
- [ ] browser
- [ ] terminal
- [ ] voice
- [ ] avatar

## Phase 6 — Autonomous Missions

- [ ] mission queue
- [ ] planning loop
- [ ] Builder execution
- [ ] Strategist challenge
- [ ] QA verification
- [ ] automatic recovery
- [ ] long-running projects
EOF

###############################################################################
# TASKS
###############################################################################

cat > "$AI_ROOT/TASKS.md" <<'EOF'
# CURRENT TASKS

- [ ] Authenticate cloud AI providers
- [ ] Complete OpenClaw onboarding
- [ ] Configure Hermes provider
- [ ] Test Hermes Desktop
- [ ] Test Open WebUI
- [ ] Test ComfyUI
- [ ] Test n8n
- [ ] Build agent council
- [ ] Build Christopher GUI
EOF

###############################################################################
# AGENT ROLES
###############################################################################

cat > "$AI_AGENTS/Builder/ROLE.md" <<'EOF'
# BUILDER

You execute the actual work.

Before working:

1. Read GOAL.md
2. Read STATE.md
3. Read PLAN.md
4. Inspect the current system
5. Inspect existing files
6. Avoid duplicating existing work

Then:

1. Build
2. Test
3. Verify
4. Record changes

Never claim success without evidence.
EOF

cat > "$AI_AGENTS/Strategist/ROLE.md" <<'EOF'
# STRATEGIST

Your first question is:

WHAT ARE WE ACTUALLY TRYING TO ACHIEVE?

Do not blindly accept the proposed implementation.

Look for:

- simpler solutions
- better architectures
- cheaper solutions
- faster solutions
- reliability problems
- unnecessary complexity
- hidden dependencies
- better AI models
- better tools

Challenge Builder when necessary.

Your purpose is to improve the outcome, not merely agree.
EOF

cat > "$AI_AGENTS/QA/ROLE.md" <<'EOF'
# QA

Assume the implementation may be wrong.

Verify:

- software versions
- services
- permissions
- network
- APIs
- GPU acceleration
- expected outputs
- generated files
- browser automation
- AI responses

Do not mark work complete without evidence.
EOF

cat > "$AI_AGENTS/Researcher/ROLE.md" <<'EOF'
# RESEARCHER

Research current information.

Prefer:

1. official documentation
2. official repositories
3. primary sources
4. reliable technical sources

Record useful discoveries in project state.

Avoid outdated instructions.
EOF

cat > "$AI_AGENTS/Operator/ROLE.md" <<'EOF'
# OPERATOR

You operate the computer.

Responsibilities include:

- files
- processes
- applications
- services
- browsers
- desktop
- system configuration

Always understand the desired outcome before changing the machine.
EOF

cat > "$AI_AGENTS/Systems/ROLE.md" <<'EOF'
# SYSTEMS

You are responsible for:

- Linux
- NVIDIA
- Docker
- networking
- storage
- VMs
- servers
- cloud infrastructure
- security boundaries
- backups
- monitoring
EOF

cat > "$AI_AGENTS/Media/ROLE.md" <<'EOF'
# MEDIA

You operate the creative AI stack.

Responsibilities:

- ComfyUI
- image generation
- video generation
- audio
- media processing
- workflows
- model management
EOF

cat > "$AI_AGENTS/Memory/ROLE.md" <<'EOF'
# MEMORY

Maintain useful persistent project knowledge.

Record:

- important decisions
- architecture
- working configurations
- lessons
- failed approaches
- successful approaches
- project-specific knowledge

Do not store unnecessary secrets.
EOF

###############################################################################
# MASTER MISSION
###############################################################################

cat > "$AI_ROOT/MISSIONS/MASTER-MISSION.md" <<'EOF'
# MASTER CHRISTOPHER MISSION

We are building an AI-first Linux computer.

This is more than an application collection.

The final system should behave like an AI operating environment.

The user gives a high-level objective.

Strategist asks:

"What are we actually trying to achieve?"

Strategist proposes the best architecture.

Builder executes.

Researcher investigates unknowns.

Operator operates the computer.

Systems manages infrastructure.

Media handles creative AI.

QA tests the result.

Memory maintains useful project knowledge.

Agents communicate through shared mission state rather than forcing the user to relay messages.

Prefer graphical interfaces.

The terminal is infrastructure underneath the experience, not the user's primary interface.

The system should eventually support:

- local models
- cloud models
- model switching
- multiple agents
- agent-to-agent communication
- browser control
- file control
- code execution
- system administration
- media generation
- automation
- persistent memory
- project state
- voice
- avatar
- autonomous missions
EOF

###############################################################################
# HEALTH CHECK
###############################################################################

section "CREATE HEALTH CHECK"

cat > "$AI_ROOT/health-check.sh" <<'EOF'
#!/usr/bin/env bash

set +e

echo
echo "======================================================"
echo " CHRISTOPHER AI COMPUTER HEALTH CHECK"
echo "======================================================"
echo

echo "SYSTEM"
echo "------------------------------------------------------"
uname -a
echo

echo "OS"
cat /etc/os-release | grep -E '^(NAME|VERSION)='
echo

echo "GPU"
echo "------------------------------------------------------"

if command -v nvidia-smi >/dev/null 2>&1 &&
   nvidia-smi >/dev/null 2>&1; then

    nvidia-smi \
        --query-gpu=name,memory.total,driver_version \
        --format=csv

else

    echo "No working NVIDIA GPU detected."

fi

echo

echo "OLLAMA"
echo "------------------------------------------------------"

systemctl is-active ollama
ollama list

echo

echo "DOCKER"
echo "------------------------------------------------------"

sudo docker ps

echo

echo "OPENCLAW"
echo "------------------------------------------------------"

if command -v openclaw >/dev/null 2>&1; then
    openclaw --version
else
    echo "Not found"
fi

echo

echo "HERMES"
echo "------------------------------------------------------"

if command -v hermes >/dev/null 2>&1; then
    hermes --version
else
    echo "Not found"
fi

echo

echo "CODEX"
echo "------------------------------------------------------"

if command -v codex >/dev/null 2>&1; then
    codex --version
else
    echo "Not found"
fi

echo

echo "CLAUDE"
echo "------------------------------------------------------"

if command -v claude >/dev/null 2>&1; then
    claude --version
else
    echo "Not found"
fi

echo

echo "COMFYUI"
echo "------------------------------------------------------"

if [[ -x "$HOME/AI-PC/ComfyUI/.venv/bin/python" ]]; then

    "$HOME/AI-PC/ComfyUI/.venv/bin/python" <<'PY'

import torch

print("PyTorch:", torch.__version__)
print("CUDA:", torch.cuda.is_available())

if torch.cuda.is_available():

    print("CUDA version:", torch.version.cuda)

    for i in range(torch.cuda.device_count()):

        gpu = torch.cuda.get_device_properties(i)

        print(
            "GPU:",
            gpu.name,
            "VRAM:",
            round(gpu.total_memory / 1024**3, 2),
            "GB"
        )

PY

else

    echo "ComfyUI not installed."

fi

echo

echo "LOCAL WEB SERVICES"
echo "------------------------------------------------------"

for PORT in 3000 5678 8188 18789; do

    if command -v ss >/dev/null 2>&1 &&
       ss -ltn 2>/dev/null |
       grep -q ":$PORT "; then

        echo "PORT $PORT : ACTIVE"

    else

        echo "PORT $PORT : not currently listening"

    fi

done

echo

echo "AI WORKSPACE"
echo "------------------------------------------------------"

echo "$HOME/AI-PC"

find "$HOME/AI-PC" \
    -maxdepth 2 \
    -type f \
    2>/dev/null |
    head -30

echo

echo "======================================================"
echo " END HEALTH CHECK"
echo "======================================================"
EOF

chmod +x "$AI_ROOT/health-check.sh"

chown "$REAL_USER:$REAL_USER" \
    "$AI_ROOT/health-check.sh"

###############################################################################
# KDE DESKTOP SHORTCUTS
###############################################################################

section "CREATE KDE LAUNCHERS"

DESKTOP="$REAL_HOME/Desktop"

mkdir -p "$DESKTOP"

create_launcher() {

    local file="$1"
    local name="$2"
    local url="$3"
    local icon="$4"

    cat > "$DESKTOP/$file.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=Christopher AI Workstation
Exec=xdg-open $url
Icon=$icon
Terminal=false
Categories=AI;Development;
EOF

    chmod +x "$DESKTOP/$file.desktop"

}

create_launcher \
    "Open-WebUI" \
    "Open WebUI" \
    "http://127.0.0.1:3000" \
    "applications-internet"

create_launcher \
    "n8n" \
    "n8n Automation" \
    "http://127.0.0.1:5678" \
    "applications-system"

create_launcher \
    "ComfyUI" \
    "ComfyUI" \
    "http://127.0.0.1:8188" \
    "applications-graphics"

create_launcher \
    "OpenClaw" \
    "OpenClaw Control" \
    "http://127.0.0.1:18789" \
    "applications-internet"

chown -R "$REAL_USER:$REAL_USER" "$DESKTOP"

###############################################################################
# HERMES DESKTOP LAUNCHER
###############################################################################

if command -v hermes >/dev/null 2>&1; then

    cat > "$DESKTOP/Hermes.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hermes AI
Comment=Hermes Agent Desktop
Exec=$REAL_HOME/.local/bin/hermes desktop
Icon=applications-development
Terminal=false
Categories=AI;Development;
EOF

    chmod +x "$DESKTOP/Hermes.desktop"

    chown "$REAL_USER:$REAL_USER" \
        "$DESKTOP/Hermes.desktop"

fi

###############################################################################
# SYSTEM STARTUP NOTES
###############################################################################

section "CREATE STARTUP GUIDE"

cat > "$AI_ROOT/START-HERE.md" <<EOF
# CHRISTOPHER AI COMPUTER

## Main workspace

$AI_ROOT

## Health check

$AI_ROOT/health-check.sh

## Local AI

Open WebUI:

http://127.0.0.1:3000

Ollama:

http://127.0.0.1:11434

## Automation

n8n:

http://127.0.0.1:5678

## Creative AI

ComfyUI:

http://127.0.0.1:8188

## OpenClaw

http://127.0.0.1:18789

## Hermes

Launch:

hermes desktop

## Complete cloud authentication

OpenClaw:

openclaw onboard --install-daemon

Hermes:

hermes setup --portal

Claude:

claude

Codex:

codex

## Useful diagnostic

$AI_ROOT/health-check.sh

## Agent workspaces

Builder:
$AI_ROOT/Agents/Builder

Strategist:
$AI_ROOT/Agents/Strategist

QA:
$AI_ROOT/Agents/QA

Researcher:
$AI_ROOT/Agents/Researcher

Operator:
$AI_ROOT/Agents/Operator

Systems:
$AI_ROOT/Agents/Systems

Media:
$AI_ROOT/Agents/Media

Memory:
$AI_ROOT/Agents/Memory
EOF

chown "$REAL_USER:$REAL_USER" \
    "$AI_ROOT/START-HERE.md"

###############################################################################
# INSTALLATION SUMMARY
###############################################################################

cat > "$AI_ROOT/INSTALL-SUMMARY.md" <<EOF
# CHRISTOPHER KUBUNTU AI INSTALLATION

Date:
$(date)

User:
$REAL_USER

Home:
$REAL_HOME

OS:
$OS_NAME $OS_VERSION

Architecture:
$ARCH

GPU:
$GPU_VENDOR

AI Root:
$AI_ROOT

## Installed

Core Linux tools
Docker
Git
GitHub CLI
Node.js
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

## Local GUIs

Open WebUI
http://127.0.0.1:3000

n8n
http://127.0.0.1:5678

ComfyUI
http://127.0.0.1:8188

OpenClaw
http://127.0.0.1:18789

Hermes Desktop
hermes desktop

## Authentication still required

OpenClaw
Hermes
Claude
Codex

This is intentional.

Cloud credentials should never be embedded into this installer.

## Health check

$AI_ROOT/health-check.sh
EOF

chown "$REAL_USER:$REAL_USER" \
    "$AI_ROOT/INSTALL-SUMMARY.md"

###############################################################################
# REMOVE NVIDIA RESUME SERVICE
###############################################################################

if [[ -f "$RESUME_SERVICE" ]]; then

    sudo systemctl disable \
        christopher-ai-resume.service \
        2>/dev/null || true

    sudo rm -f "$RESUME_SERVICE"

    sudo systemctl daemon-reload

fi

###############################################################################
# WRITE COMPLETION MARKER
###############################################################################

date > "$STATE_DIR/complete"

###############################################################################
# FINAL CHECKS
###############################################################################

section "FINAL VERIFICATION"

FAILURES=0

check_command() {

    local name="$1"
    local command_name="$2"

    if command -v "$command_name" >/dev/null 2>&1; then

        success "$name"

    else

        warn "$name not installed"

        FAILURES=$((FAILURES + 1))

    fi

}

check_command "Git" git
check_command "Node" node
check_command "npm" npm
check_command "Python" python3
check_command "Ollama" ollama
check_command "OpenClaw" openclaw
check_command "Hermes" hermes
check_command "Codex" codex
check_command "Claude Code" claude

if command -v docker >/dev/null 2>&1; then

    success "Docker"

else

    warn "Docker missing"

    FAILURES=$((FAILURES + 1))

fi

if [[ "$GPU_VENDOR" == "nvidia" ]]; then

    if nvidia-smi >/dev/null 2>&1; then
        success "NVIDIA"
    else
        warn "NVIDIA verification failed"
        FAILURES=$((FAILURES + 1))
    fi

fi

###############################################################################
# FINAL REPORT
###############################################################################

section "CHRISTOPHER AI COMPUTER READY"

echo
echo -e "${GREEN}"
echo "       ██████╗██╗  ██╗██████╗ ██╗███████╗████████╗ ██████╗ ██████╗"
echo "      ██╔════╝██║  ██║██╔══██╗██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗"
echo "      ██║     ███████║██████╔╝██║███████╗   ██║   ██║   ██║██████╔╝"
echo "      ██║     ██╔══██║██╔══██╗██║╚════██║   ██║   ██║   ██║██╔═══╝"
echo "      ╚██████╗██║  ██║██████╔╝██║███████║   ██║   ╚██████╔╝██║"
echo "       ╚═════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝"
echo -e "${NC}"

echo
echo "AI COMPUTER:"
echo
echo "  $AI_ROOT"
echo

echo "LOG:"
echo
echo "  $LOG_FILE"
echo

echo "HEALTH:"
echo
echo "  $AI_ROOT/health-check.sh"
echo

echo "LOCAL SERVICES:"
echo
echo "  Open WebUI   http://127.0.0.1:3000"
echo "  n8n          http://127.0.0.1:5678"
echo "  ComfyUI      http://127.0.0.1:8188"
echo "  OpenClaw     http://127.0.0.1:18789"
echo

echo "HERMES:"
echo
echo "  hermes desktop"
echo

echo "NEXT AUTHENTICATION:"
echo
echo "  openclaw onboard --install-daemon"
echo "  hermes setup --portal"
echo "  claude"
echo "  codex"
echo

echo "=============================================================="

if [[ "$FAILURES" -eq 0 ]]; then

    echo -e "${GREEN}"
    echo "ALL CORE INSTALLATION CHECKS PASSED."
    echo -e "${NC}"

else

    echo -e "${YELLOW}"
    echo "$FAILURES optional/core component(s) need attention."
    echo -e "${NC}"

    echo
    echo "Run:"
    echo
    echo "  $AI_ROOT/health-check.sh"

fi

echo
echo "IMPORTANT:"
echo
echo "If this was your first installation, log out and back in"
echo "once so Docker/libvirt group membership is refreshed."
echo
echo "=============================================================="
echo
