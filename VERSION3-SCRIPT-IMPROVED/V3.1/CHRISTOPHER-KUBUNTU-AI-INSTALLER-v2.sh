#!/usr/bin/env bash
set -Eeuo pipefail

# CHRISTOPHER KUBUNTU AI WORKSTATION INSTALLER v2
# Run as normal desktop user. Do not run with sudo.
# v2 fixes the unsupported `ubuntu-drivers autoinstall` assumption and
# several resume/quoting/robustness issues in the original installer.

AI_ROOT="${AI_ROOT:-$HOME/AI-PC}"
INSTALL_OPTIONAL="${INSTALL_OPTIONAL:-1}"
INSTALL_VIRTUALIZATION="${INSTALL_VIRTUALIZATION:-1}"
INSTALL_DOCKER_APPS="${INSTALL_DOCKER_APPS:-1}"
DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-1}"
INSTALL_COMFYUI="${INSTALL_COMFYUI:-1}"
INSTALL_BROWSER_TOOLS="${INSTALL_BROWSER_TOOLS:-1}"
ENABLE_PASSWORDLESS_SUDO="${ENABLE_PASSWORDLESS_SUDO:-1}"
REBOOT_FOR_NVIDIA="${REBOOT_FOR_NVIDIA:-1}"

RESUME=0
[[ "${1:-}" == "--resume" ]] && RESUME=1

if (( EUID == 0 )); then
    [[ -n "${SUDO_USER:-}" ]] || { echo "Run this as your normal desktop user, not root."; exit 1; }
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$USER"
fi
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[[ -d "$REAL_HOME" ]] || { echo "Cannot determine home directory for $REAL_USER"; exit 1; }

AI_ROOT="${AI_ROOT/#\~/$REAL_HOME}"
AI_MODELS="$AI_ROOT/Models"; AI_PROJECTS="$AI_ROOT/Projects"; AI_WORKSPACE="$AI_ROOT/Workspace"
AI_AGENTS="$AI_ROOT/Agents"; AI_LOGS="$AI_ROOT/Logs"; AI_DOWNLOADS="$AI_ROOT/Downloads"
AI_SHARED="$AI_ROOT/Shared"; AI_OUTPUT="$AI_ROOT/Output"; AI_INBOX="$AI_ROOT/Inbox"
AI_SKILLS="$AI_ROOT/Skills"; AI_BACKUPS="$AI_ROOT/Backups"; AI_MISSIONS="$AI_ROOT/Missions"
STATE_DIR="$AI_ROOT/.installer-state"; LOG_FILE="$AI_ROOT/Logs/christopher-install.log"
SCRIPT_PATH="$(readlink -f "$0")"
RESUME_SERVICE="/etc/systemd/system/christopher-ai-resume.service"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
mkdir -p "$AI_LOGS"; touch "$LOG_FILE"; chown "$REAL_USER:$REAL_USER" "$LOG_FILE" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

timestamp(){ date '+%Y-%m-%d %H:%M:%S'; }
log(){ echo -e "${CYAN}[$(timestamp)]${NC} $*"; }
success(){ echo -e "${GREEN}✔ $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $*${NC}"; }
info(){ echo -e "${BLUE}ℹ $*${NC}"; }
section(){ echo; echo "======================================================================"; echo -e "${MAGENTA}$*${NC}"; echo "======================================================================"; echo; }
fatal(){ echo; echo -e "${RED}FATAL ERROR${NC}"; echo "$*"; echo "Log: $LOG_FILE"; exit 1; }
as_user(){ sudo -u "$REAL_USER" -H "$@"; }
trap 'rc=$?; echo; echo -e "${RED}INSTALLER ERROR${NC}"; echo "Line: $LINENO"; echo "Command: $BASH_COMMAND"; echo "Exit code: $rc"; echo "Log: $LOG_FILE"; exit "$rc"' ERR

section "CHECK ADMIN ACCESS"
sudo -n true 2>/dev/null || sudo -v || fatal "This user does not have sudo access."
# Keep the sudo timestamp alive.
( while sleep 45; do sudo -n -v 2>/dev/null || exit 0; done ) & SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
success "Administrative access available."

section "DISCOVER OPERATING SYSTEM"
[[ -f /etc/os-release ]] || fatal "Cannot determine operating system."
source /etc/os-release
OS_ID="${ID:-unknown}"; OS_NAME="${NAME:-unknown}"; OS_VERSION="${VERSION_ID:-unknown}"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
log "User: $REAL_USER"; log "OS: $OS_NAME $OS_VERSION"; log "Architecture: $ARCH"; log "AI root: $AI_ROOT"
command -v apt-get >/dev/null || fatal "APT is required."

mkdir -p "$STATE_DIR" "$AI_ROOT" "$AI_MODELS" "$AI_PROJECTS" "$AI_WORKSPACE" "$AI_AGENTS" "$AI_LOGS" "$AI_DOWNLOADS" "$AI_SHARED" "$AI_OUTPUT" "$AI_INBOX" "$AI_SKILLS" "$AI_BACKUPS" "$AI_MISSIONS/ACTIVE" "$AI_MISSIONS/COMPLETED" "$AI_MISSIONS/FAILED"
chown -R "$REAL_USER:$REAL_USER" "$AI_ROOT"

install_packages(){
    local available=() pkg
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then available+=("$pkg"); else warn "Package unavailable: $pkg"; fi
    done
    ((${#available[@]})) && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}"
}
apt_package_exists(){ apt-cache show "$1" >/dev/null 2>&1; }

section "UPDATE SYSTEM"
sudo apt-get update

section "INSTALL CORE LINUX TOOLS"
install_packages build-essential ca-certificates curl wget git git-lfs unzip zip xz-utils bzip2 jq rsync tree htop btop nvtop tmux ripgrep fd-find fzf lsof pciutils usbutils dmidecode lm-sensors net-tools dnsutils iputils-ping openssh-client openssh-server socat sqlite3 libsqlite3-dev pkg-config libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev liblzma-dev libncurses-dev python3 python3-dev python3-pip python3-venv python3-full pipx ffmpeg imagemagick poppler-utils pandoc software-properties-common apt-transport-https gnupg flatpak libvulkan1 vulkan-tools

if [[ "$INSTALL_OPTIONAL" == 1 ]]; then
    section "INSTALL DESKTOP / MEDIA TOOLS"
    install_packages vlc chromium libnss3 libatk-bridge2.0-0 libgtk-3-0 libgbm-dev libasound2t64 libxss1 libxshmfence1 libxkbcommon0 libdrm2 libxcomposite1 libxdamage1 libxrandr2
fi

if [[ "$ENABLE_PASSWORDLESS_SUDO" == 1 ]]; then
    section "CONFIGURE AI ADMINISTRATION"
    SUDO_FILE="/etc/sudoers.d/christopher-ai"
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$REAL_USER" | sudo tee "$SUDO_FILE" >/dev/null
    sudo chmod 440 "$SUDO_FILE"
    sudo visudo -cf "$SUDO_FILE" >/dev/null || { sudo rm -f "$SUDO_FILE"; fatal "Invalid sudo configuration."; }
    success "Passwordless sudo enabled for $REAL_USER."
fi
sudo passwd -l root >/dev/null 2>&1 || true

section "DISCOVER GPU"
GPU_INFO="$(lspci 2>/dev/null | grep -Ei 'VGA|3D controller|Display controller' || true)"; echo "$GPU_INFO"
GPU_VENDOR=none
if grep -qi nvidia <<<"$GPU_INFO"; then GPU_VENDOR=nvidia; elif grep -Eqi 'AMD|ATI' <<<"$GPU_INFO"; then GPU_VENDOR=amd; elif grep -qi Intel <<<"$GPU_INFO"; then GPU_VENDOR=intel; fi
log "Detected GPU vendor: $GPU_VENDOR"

select_nvidia_driver(){
    local info="${1:-}" selected=""
    # ubuntu-drivers output: driver : nvidia-driver-595-open - distro non-free recommended
    selected="$(awk '/driver[[:space:]]*:/ && /recommended/ { for(i=1;i<=NF;i++) if($i==":"){print $(i+1); exit} }' <<<"$info")"
    [[ -n "$selected" ]] || selected="$(grep -Eo 'nvidia-driver-[0-9]+(-open)?' <<<"$info" | head -n1 || true)"
    [[ -n "$selected" ]] || selected="$(apt-cache search '^nvidia-driver-[0-9]+-open$' 2>/dev/null | awk '{print $1}' | sort -V | tail -1 || true)"
    [[ -n "$selected" ]] || selected="$(apt-cache search '^nvidia-driver-[0-9]+$' 2>/dev/null | awk '{print $1}' | sort -V | tail -1 || true)"
    printf '%s' "$selected"
}

if [[ "$GPU_VENDOR" == nvidia ]]; then
    section "NVIDIA GPU"
    install_packages ubuntu-drivers-common nvidia-settings nvidia-modprobe
    NVIDIA_WORKING=0
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then NVIDIA_WORKING=1; fi
    if (( NVIDIA_WORKING )); then
        success "NVIDIA driver already working."; nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv || true
    else
        section "INSTALL RECOMMENDED NVIDIA DRIVER"
        command -v ubuntu-drivers >/dev/null || fatal "ubuntu-drivers is unavailable."
        DRIVER_INFO="$(ubuntu-drivers devices 2>/dev/null || true)"; echo "$DRIVER_INFO"
        NVIDIA_DRIVER="$(select_nvidia_driver "$DRIVER_INFO")"
        [[ -n "$NVIDIA_DRIVER" ]] || fatal "Could not determine an installable NVIDIA driver."
        apt_package_exists "$NVIDIA_DRIVER" || fatal "Selected NVIDIA package is unavailable: $NVIDIA_DRIVER"
        info "Installing $NVIDIA_DRIVER"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$NVIDIA_DRIVER" nvidia-settings nvidia-modprobe
        echo "$NVIDIA_DRIVER" > "$STATE_DIR/nvidia-driver-selected"
        touch "$STATE_DIR/nvidia-reboot-required"
        if [[ "$REBOOT_FOR_NVIDIA" == 1 ]]; then
            section "CONFIGURE NVIDIA RESUME"
            sudo tee "$RESUME_SERVICE" >/dev/null <<SERVICE
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
SERVICE
            sudo systemctl daemon-reload
            sudo systemctl enable christopher-ai-resume.service
            success "Automatic resume configured."
            echo "NVIDIA driver installed: $NVIDIA_DRIVER"
            echo "Rebooting now; the installer will resume automatically."
            sync
            sudo systemctl reboot
            exit 0
        fi
    fi
fi

if [[ "$GPU_VENDOR" == amd ]]; then install_packages mesa-vulkan-drivers mesa-utils vulkan-tools; fi
if [[ "$GPU_VENDOR" == intel ]]; then install_packages mesa-vulkan-drivers mesa-utils intel-media-va-driver vulkan-tools; fi

section "GPU VERIFICATION"
if [[ "$GPU_VENDOR" == nvidia ]]; then
    if nvidia-smi >/dev/null 2>&1; then success "NVIDIA GPU operational."; nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv || true; else fatal "NVIDIA driver verification failed. Reboot and rerun if necessary."; fi
elif [[ "$GPU_VENDOR" != none ]] && command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo --summary 2>/dev/null | head -50 || true; fi

section "INSTALL DOCKER"
if ! command -v docker >/dev/null 2>&1; then install_packages docker.io docker-compose-v2; fi
if command -v docker >/dev/null 2>&1; then sudo systemctl enable --now docker || warn "Docker service did not start."; sudo usermod -aG docker "$REAL_USER" || true; sudo docker --version || true; else warn "Docker unavailable."; fi

section "INSTALL GITHUB CLI"
if command -v gh >/dev/null 2>&1; then success "GitHub CLI already installed."; elif apt_package_exists gh; then sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh; else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh
fi
gh --version || true

section "INSTALL NODE.JS"
NODE_OK=0
if command -v node >/dev/null 2>&1; then NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"; (( NODE_MAJOR >= 22 )) && NODE_OK=1; fi
if (( ! NODE_OK )); then curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs; fi
node --version; npm --version
export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"

section "INSTALL UV"
if command -v uv >/dev/null 2>&1; then success "uv already installed."; else as_user bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' || warn "uv installation failed."; fi
export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"
command -v uv >/dev/null 2>&1 && uv --version || warn "uv not visible in PATH."

section "INSTALL OLLAMA"
if command -v ollama >/dev/null 2>&1; then success "Ollama already installed."; else curl -fsSL https://ollama.com/install.sh | sh; fi
if command -v ollama >/dev/null 2>&1; then
    sudo systemctl enable --now ollama || warn "Ollama service did not start."
    mkdir -p "$AI_MODELS"; chown -R "$REAL_USER:$REAL_USER" "$AI_MODELS"
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/ai-models.conf >/dev/null <<OLLAMA
[Service]
Environment="OLLAMA_MODELS=$AI_MODELS"
OLLAMA
    sudo systemctl daemon-reload; sudo systemctl restart ollama || warn "Could not restart Ollama."
    ollama --version || true
fi

if [[ "$DOWNLOAD_MODELS" == 1 ]] && command -v ollama >/dev/null 2>&1 && systemctl is-active --quiet ollama; then
    section "DOWNLOAD STARTER LOCAL MODELS"
    for MODEL in qwen3.5:9b gemma3:12b deepseek-r1:8b nomic-embed-text; do
        if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$MODEL"; then success "Already installed: $MODEL"; else ollama pull "$MODEL" || { warn "Could not download $MODEL"; echo "$MODEL" >> "$AI_LOGS/model-download-failures.txt"; }; fi
    done
fi

if command -v ollama >/dev/null 2>&1 && systemctl is-active --quiet ollama; then
    section "TEST LOCAL AI"
    if ollama list | grep -q qwen3.5; then ollama run qwen3.5:9b 'Reply with exactly: CHRISTOPHER LOCAL AI ONLINE' 2>&1 | tee "$AI_LOGS/ollama-test.log" || warn "Ollama model test failed."; else warn "Qwen model unavailable."; fi
fi

section "INSTALL OPENCLAW"
if command -v openclaw >/dev/null 2>&1; then success "OpenClaw already installed."; else
    if ! as_user bash -c "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --beta --no-onboard --verify"; then warn "OpenClaw installer reported a failure."; fi
fi
export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"
command -v openclaw >/dev/null 2>&1 && openclaw --version || warn "OpenClaw command not visible yet."

section "INSTALL HERMES"
if command -v hermes >/dev/null 2>&1; then success "Hermes already installed."; else curl -fsSL https://hermes-agent.nousresearch.com/install.sh | as_user bash || warn "Hermes installer reported a failure."; fi
export PATH="$REAL_HOME/.local/bin:$PATH"
if command -v hermes >/dev/null 2>&1; then hermes --version || true; hermes doctor || warn "Hermes doctor reported configuration items needing attention."; else warn "Hermes command not visible yet."; fi

if [[ "$INSTALL_BROWSER_TOOLS" == 1 ]]; then
    section "INSTALL BROWSER AUTOMATION"
    if command -v npx >/dev/null 2>&1; then
        as_user npx playwright install chromium || warn "Playwright Chromium installation failed."
        sudo npx playwright install-deps chromium || warn "Some Chromium dependencies could not be installed."
    else warn "npx unavailable; browser automation skipped."; fi
fi

section "INSTALL CLAUDE CODE"
if ! command -v claude >/dev/null 2>&1; then
    as_user npm install -g @anthropic-ai/claude-code || as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || warn "Claude Code could not be installed."
else success "Claude Code already installed."; fi
export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.npm-global/bin:$PATH"; claude --version 2>/dev/null || true

section "INSTALL OPENAI CODEX"
if ! command -v codex >/dev/null 2>&1; then as_user npm install -g @openai/codex || warn "Codex installation failed."; else success "Codex already installed."; fi
codex --version 2>/dev/null || true

section "INSTALL OPENCODE"
if ! command -v opencode >/dev/null 2>&1; then as_user npm install -g opencode-ai || warn "OpenCode installation failed."; else success "OpenCode already installed."; fi
opencode --version 2>/dev/null || true

section "INSTALL AIDER"
if ! command -v aider >/dev/null 2>&1; then as_user pipx install aider-chat || warn "Aider installation failed."; else success "Aider already installed."; fi

if [[ "$INSTALL_COMFYUI" == 1 ]]; then
    section "INSTALL COMFYUI"
    COMFY_ROOT="$AI_ROOT/ComfyUI"
    if [[ -d "$COMFY_ROOT/.git" ]]; then git -C "$COMFY_ROOT" pull --ff-only || warn "ComfyUI update skipped."; else as_user git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_ROOT" || { warn "ComfyUI clone failed."; COMFY_ROOT=""; }; fi
    if [[ -n "$COMFY_ROOT" && -d "$COMFY_ROOT" ]]; then
        chown -R "$REAL_USER:$REAL_USER" "$COMFY_ROOT"
        COMFY_PYTHON="$COMFY_ROOT/.venv/bin/python"
        if [[ ! -x "$COMFY_PYTHON" ]]; then
            if command -v uv >/dev/null 2>&1; then as_user uv venv --python 3.13 "$COMFY_ROOT/.venv" || as_user uv venv --python 3.12 "$COMFY_ROOT/.venv" || true; fi
            [[ -x "$COMFY_PYTHON" ]] || as_user python3 -m venv "$COMFY_ROOT/.venv" || true
        fi
        if [[ -x "$COMFY_PYTHON" ]]; then
            COMFY_PIP="$COMFY_ROOT/.venv/bin/pip"
            as_user "$COMFY_PIP" install --upgrade pip setuptools wheel || warn "ComfyUI Python tooling upgrade failed."
            if [[ "$GPU_VENDOR" == nvidia ]]; then
                as_user "$COMFY_PIP" install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130 || as_user "$COMFY_PIP" install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu128 || warn "CUDA PyTorch installation failed."
            else as_user "$COMFY_PIP" install torch torchvision torchaudio || warn "PyTorch installation failed."; fi
            as_user "$COMFY_PIP" install -r "$COMFY_ROOT/requirements.txt" || warn "ComfyUI dependencies failed."
            as_user "$COMFY_PYTHON" - <<PYTORCH
import torch
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("CUDA version:", torch.version.cuda)
    for i in range(torch.cuda.device_count()):
        p=torch.cuda.get_device_properties(i)
        print("GPU:",p.name,"VRAM:",round(p.total_memory/1024**3,2),"GB")
PYTORCH
            cat > "$COMFY_ROOT/start.sh" <<STARTCOMFY
#!/usr/bin/env bash
cd "$COMFY_ROOT"
exec "$COMFY_PYTHON" main.py --listen 127.0.0.1 --port 8188
STARTCOMFY
            chmod +x "$COMFY_ROOT/start.sh"; chown "$REAL_USER:$REAL_USER" "$COMFY_ROOT/start.sh"
        fi
    fi
fi

if [[ "$INSTALL_DOCKER_APPS" == 1 ]] && command -v docker >/dev/null 2>&1; then
    section "INSTALL OPEN WEBUI"
    if sudo docker ps -a --format '{{.Names}}' | grep -qx open-webui; then success "Open WebUI container exists."; else sudo docker pull ghcr.io/open-webui/open-webui:main || warn "Open WebUI image pull failed."; sudo docker run -d --name open-webui --restart unless-stopped -p 127.0.0.1:3000:8080 --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main || warn "Open WebUI container failed."; fi
    section "INSTALL N8N"
    if sudo docker ps -a --format '{{.Names}}' | grep -qx n8n; then success "n8n container exists."; else sudo docker pull docker.n8n.io/n8nio/n8n || warn "n8n image pull failed."; sudo docker volume create n8n_data >/dev/null || true; sudo docker run -d --name n8n --restart unless-stopped -p 127.0.0.1:5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n || warn "n8n container failed."; fi
fi

if [[ "$INSTALL_VIRTUALIZATION" == 1 ]]; then
    section "INSTALL VIRTUALIZATION"
    install_packages qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf swtpm
    sudo usermod -aG libvirt "$REAL_USER" || true; sudo usermod -aG kvm "$REAL_USER" || true; sudo systemctl enable --now libvirtd 2>/dev/null || true
fi

section "CREATE AI AGENT WORKSPACE"
mkdir -p "$AI_AGENTS"/{Builder,Strategist,QA,Researcher,Operator,Media,Systems,Memory}
cat > "$AI_ROOT/GOAL.md" <<GOAL
# CHRISTOPHER AI COMPUTER

Build an AI-first Linux workstation where the user gives outcomes rather than manually coordinating tools.

Builder executes. Strategist challenges assumptions. Researcher investigates. QA verifies. Operator operates the computer. Systems manages infrastructure. Media handles creative AI. Memory maintains useful project knowledge.

The eventual system supports local and cloud AI, model switching, multiple agents, agent-to-agent communication, browser control, file control, code execution, administration, media generation, automation, persistent memory, project state, voice, avatar and autonomous missions.
GOAL
cat > "$AI_ROOT/STATE.md" <<STATE
# STATE
Installation date: $(date)
OS: $OS_NAME $OS_VERSION
Architecture: $ARCH
User: $REAL_USER
AI root: $AI_ROOT
GPU: $GPU_VENDOR
STATE
cat > "$AI_ROOT/PLAN.md" <<PLAN
# MASTER PLAN

- [x] Base system
- [x] GPU setup
- [x] Docker
- [x] Ollama
- [x] AI tools
- [ ] OpenClaw council
- [ ] Persistent agent memory
- [ ] Browser/computer control
- [ ] Christopher Control Centre GUI
- [ ] Voice/avatar
- [ ] Reproducible AI Linux ISO
PLAN
for agent in Builder Strategist QA Researcher Operator Media Systems Memory; do
    printf '# %s\n\nRead GOAL.md and STATE.md first. Inspect before changing anything. Verify results and record important changes.\n' "$agent" > "$AI_AGENTS/$agent/ROLE.md"
done
cat > "$AI_ROOT/MISSIONS/MASTER-MISSION.md" <<MISSION
# MASTER CHRISTOPHER MISSION

Build the AI-first Linux computer. The user gives a high-level objective. Strategist asks what we are actually trying to achieve; Researcher investigates; Builder executes; Operator operates; Systems manages infrastructure; Media handles creative work; QA tries to break the result; Memory records durable knowledge.

Use shared mission state and agent sessions rather than forcing the user to relay messages.
MISSION
chown -R "$REAL_USER:$REAL_USER" "$AI_ROOT"

section "CREATE HEALTH CHECK"
cat > "$AI_ROOT/health-check.sh" <<'HEALTH'
#!/usr/bin/env bash
set +e
echo '=== CHRISTOPHER AI COMPUTER HEALTH CHECK ==='
echo; echo 'SYSTEM'; uname -a
echo; echo 'GPU'
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv; else echo 'No working NVIDIA GPU detected.'; fi
echo; echo 'OLLAMA'; systemctl is-active ollama 2>/dev/null; command -v ollama >/dev/null 2>&1 && ollama list || true
echo; echo 'DOCKER'; command -v docker >/dev/null 2>&1 && sudo docker ps || true
for cmd in openclaw hermes codex claude opencode aider; do echo; echo "$cmd"; command -v "$cmd" >/dev/null 2>&1 && "$cmd" --version 2>/dev/null || echo 'Not found'; done
echo; echo 'SERVICES'; for port in 3000 5678 8188 18789; do ss -ltn 2>/dev/null | grep -q ":$port " && echo "$port ACTIVE" || echo "$port inactive"; done
echo; echo 'AI ROOT'; echo "$HOME/AI-PC"; echo '=== END ==='
HEALTH
chmod +x "$AI_ROOT/health-check.sh"; chown "$REAL_USER:$REAL_USER" "$AI_ROOT/health-check.sh"

section "CREATE KDE LAUNCHERS"
DESKTOP="$REAL_HOME/Desktop"; mkdir -p "$DESKTOP"
create_launcher(){ local file="$1" name="$2" url="$3" icon="$4"; cat > "$DESKTOP/$file.desktop" <<LAUNCH
[Desktop Entry]
Type=Application
Name=$name
Comment=Christopher AI Workstation
Exec=xdg-open $url
Icon=$icon
Terminal=false
Categories=AI;Development;
LAUNCH
chmod +x "$DESKTOP/$file.desktop"; }
create_launcher Open-WebUI 'Open WebUI' 'http://127.0.0.1:3000' applications-internet
create_launcher n8n 'n8n Automation' 'http://127.0.0.1:5678' applications-system
create_launcher ComfyUI 'ComfyUI' 'http://127.0.0.1:8188' applications-graphics
create_launcher OpenClaw 'OpenClaw Control' 'http://127.0.0.1:18789' applications-internet
chown -R "$REAL_USER:$REAL_USER" "$DESKTOP"

cat > "$AI_ROOT/START-HERE.md" <<START
# CHRISTOPHER AI COMPUTER

AI root: $AI_ROOT

Health check: $AI_ROOT/health-check.sh

Open WebUI: http://127.0.0.1:3000
n8n: http://127.0.0.1:5678
ComfyUI: http://127.0.0.1:8188
OpenClaw: http://127.0.0.1:18789

Cloud authentication is intentionally user-controlled:
openclaw onboard --install-daemon
hermes setup --portal
claude
codex
START
chown "$REAL_USER:$REAL_USER" "$AI_ROOT/START-HERE.md"

if [[ "$RESUME" == 1 || -f "$STATE_DIR/nvidia-reboot-required" ]]; then
    if [[ -f "$RESUME_SERVICE" ]]; then sudo systemctl disable christopher-ai-resume.service 2>/dev/null || true; sudo rm -f "$RESUME_SERVICE"; sudo systemctl daemon-reload; fi
    rm -f "$STATE_DIR/nvidia-reboot-required"
fi

date > "$STATE_DIR/complete"

section "FINAL VERIFICATION"
FAILURES=0
check(){ local n="$1" c="$2"; if command -v "$c" >/dev/null 2>&1; then success "$n"; else warn "$n missing"; ((FAILURES++)); fi; }
check Git git; check Node node; check npm npm; check Python python3; check Ollama ollama; check OpenClaw openclaw; check Hermes hermes; check Codex codex; check 'Claude Code' claude
if command -v docker >/dev/null 2>&1; then success Docker; else warn 'Docker missing'; ((FAILURES++)); fi
if [[ "$GPU_VENDOR" == nvidia ]]; then if nvidia-smi >/dev/null 2>&1; then success NVIDIA; else warn 'NVIDIA verification failed'; ((FAILURES++)); fi; fi

echo; echo "AI root: $AI_ROOT"; echo "Log: $LOG_FILE"; echo "Health: $AI_ROOT/health-check.sh"
echo "Open WebUI: http://127.0.0.1:3000"; echo "n8n: http://127.0.0.1:5678"; echo "ComfyUI: http://127.0.0.1:8188"; echo "OpenClaw: http://127.0.0.1:18789"
if (( FAILURES == 0 )); then success 'ALL CORE INSTALLATION CHECKS PASSED.'; else warn "$FAILURES component(s) need attention. Run $AI_ROOT/health-check.sh"; fi
echo; echo 'Log out/in once so Docker/libvirt group membership is refreshed.'
