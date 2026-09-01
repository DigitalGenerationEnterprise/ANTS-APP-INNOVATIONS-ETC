cat > ~/CHRISTOPHER-FRESH-KUBUNTU.sh <<'SCRIPT'
#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# CHRISTOPHER AI-PC
# FRESH KUBUNTU MASTER INSTALLER
#
# This script is intended for a NEW Kubuntu installation.
#
# It installs:
#
# SYSTEM
#   KDE/Kubuntu development environment
#   compilers
#   Python
#   Node
#   Git
#   Docker
#   browsers
#   media tools
#   virtualization/tooling
#
# GPU
#   NVIDIA detection
#   recommended NVIDIA driver installation
#
# LOCAL AI
#   Ollama
#   model warehouse
#   local LLMs
#
# AGENTS
#   OpenClaw
#   Hermes
#   Claude Code
#   OpenAI Codex
#   OpenCode
#   Aider
#
# AUTOMATION
#   Playwright
#   Chromium
#   Docker
#   MCP workspace
#   n8n
#
# MEDIA
#   ComfyUI
#   FFmpeg
#   ImageMagick
#
# WEB
#   Open WebUI
#
# AI MEMORY
#   shared state
#   projects
#   missions
#   agent communication
#
# AUTONOMY
#   Builder
#   Strategist
#   QA
#   Researcher
#
###############################################################################

export DEBIAN_FRONTEND=noninteractive

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$HOME"

AI="$HOME_DIR/AI-PC"

echo
echo "=============================================================="
echo "       CHRISTOPHER — FRESH KUBUNTU AI-PC BUILD"
echo "=============================================================="
echo
echo "USER: $USER_NAME"
echo "HOME: $HOME_DIR"
echo "AI:   $AI"
echo
echo "This is a large installation."
echo "It will download a LOT of software."
echo
read -rp "Press ENTER to begin or Ctrl+C to abort..."

###############################################################################
# FUNCTIONS
###############################################################################

say() {
    echo
    echo "=============================================================="
    echo ">>> $*"
    echo "=============================================================="
}

has() {
    command -v "$1" >/dev/null 2>&1
}

###############################################################################
# 1. CREATE AI FILESYSTEM
###############################################################################

say "Creating Christopher filesystem"

mkdir -p "$AI"/{
    Projects,
    Workspace,
    Models,
    Agents,
    Skills,
    Shared,
    Logs,
    Backups,
    Downloads,
    Output,
    Inbox,
    Missions,
    Scripts,
    Services,
    Knowledge,
    MCP,
    ComfyUI
}

mkdir -p "$AI/Projects"/{
    ACTIVE,
    ARCHIVE,
    Templates
}

mkdir -p "$AI/Shared"/{
    STATE,
    MESSAGES,
    MEMORY,
    EVENTS
}

mkdir -p "$AI/Agents"/{
    Builder,
    Strategist,
    QA,
    Researcher,
    Specialist
}

###############################################################################
# 2. UPDATE KUBUNTU
###############################################################################

say "Updating Kubuntu"

sudo apt-get update
sudo apt-get -y upgrade

###############################################################################
# 3. HUGE BASE SOFTWARE INSTALL
###############################################################################

say "Installing complete development/workstation foundation"

sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    pkg-config \
    autoconf \
    automake \
    libtool \
    git \
    git-lfs \
    subversion \
    mercurial \
    curl \
    wget \
    aria2 \
    rsync \
    unzip \
    zip \
    p7zip-full \
    p7zip-rar \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    zstd \
    jq \
    yq \
    tree \
    file \
    bc \
    htop \
    btop \
    iotop \
    ncdu \
    tmux \
    screen \
    vim \
    neovim \
    nano \
    ripgrep \
    fd-find \
    fzf \
    silversearcher-ag \
    sqlite3 \
    redis-server \
    postgresql \
    postgresql-contrib \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-full \
    pipx \
    python3-tk \
    python-is-python3 \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    ffmpeg \
    imagemagick \
    pandoc \
    poppler-utils \
    ghostscript \
    sox \
    libsndfile1 \
    portaudio19-dev \
    alsa-utils \
    pulseaudio-utils \
    xdotool \
    wmctrl \
    xclip \
    xsel \
    dbus-x11 \
    pciutils \
    usbutils \
    lshw \
    lm-sensors \
    nvtop \
    mesa-utils \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    dkms \
    linux-headers-$(uname -r)

###############################################################################
# 4. PASSWORDLESS SUDO
###############################################################################

say "Configuring passwordless sudo for the AI workstation"

sudo tee "/etc/sudoers.d/christopher-ai" >/dev/null <<EOF
$USER_NAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF

sudo chmod 440 "/etc/sudoers.d/christopher-ai"

sudo visudo -cf "/etc/sudoers.d/christopher-ai"

###############################################################################
# 5. LOCK DIRECT ROOT PASSWORD
###############################################################################

say "Locking direct root password login"

sudo passwd -l root || true

echo
echo "Testing passwordless sudo:"
sudo -n whoami

###############################################################################
# 6. NVIDIA
###############################################################################

say "Checking NVIDIA hardware"

if lspci | grep -qi nvidia; then

    echo "NVIDIA GPU DETECTED"
    lspci | grep -i nvidia || true

    echo
    echo "Available NVIDIA drivers:"
    ubuntu-drivers devices || true

    echo
    echo "Installing Ubuntu recommended NVIDIA driver"

    sudo ubuntu-drivers autoinstall || true

else

    echo "No NVIDIA PCI device detected."
fi

###############################################################################
# 7. NODE.JS
###############################################################################

say "Installing Node.js"

if ! has node; then

    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs

fi

node --version
npm --version

###############################################################################
# 8. NPM USER ENVIRONMENT
###############################################################################

say "Configuring npm"

mkdir -p "$HOME/.npm-global"

npm config set prefix "$HOME/.npm-global"

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

grep -qxF 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' "$HOME/.bashrc" \
    || echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

###############################################################################
# 9. PIPX
###############################################################################

say "Configuring pipx"

python3 -m pipx ensurepath || true

export PATH="$HOME/.local/bin:$PATH"

###############################################################################
# 10. DOCKER
###############################################################################

say "Installing Docker"

sudo apt-get install -y \
    docker.io \
    docker-compose-v2

sudo systemctl enable --now docker

sudo usermod -aG docker "$USER_NAME"

###############################################################################
# 11. ENABLE REDIS / POSTGRESQL
###############################################################################

say "Starting databases"

sudo systemctl enable --now redis-server || true
sudo systemctl enable --now postgresql || true

###############################################################################
# 12. BROWSERS
###############################################################################

say "Installing browsers"

sudo apt-get install -y \
    chromium-browser 2>/dev/null || \
sudo apt-get install -y chromium

###############################################################################
# 13. OLLAMA
###############################################################################

say "Installing Ollama"

if ! has ollama; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

sudo systemctl enable --now ollama || true

###############################################################################
# 14. OLLAMA MODEL STORAGE
###############################################################################

say "Creating local model warehouse"

mkdir -p "$AI/Models/Ollama"

sudo mkdir -p /etc/systemd/system/ollama.service.d

sudo tee /etc/systemd/system/ollama.service.d/christopher.conf >/dev/null <<EOF
[Service]
Environment="OLLAMA_MODELS=$AI/Models/Ollama"
Environment="OLLAMA_HOST=127.0.0.1:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

sleep 5

###############################################################################
# 15. LOCAL MODELS
###############################################################################

say "Downloading local AI models"

cat > "$AI/Models/README.md" <<'EOF'
# CHRISTOPHER MODEL WAREHOUSE

Models live on the AI-PC rather than cluttering the OS.

The initial installation deliberately uses models appropriate to a
16GB VRAM workstation.

More models can be added later.

The AI agents may choose between:

- local Ollama models
- OpenAI
- Anthropic
- other configured providers

The goal is model routing rather than forcing one model to do everything.
EOF

for MODEL in \
    "qwen3.5:9b" \
    "gemma3:12b" \
    "deepseek-r1:8b"
do
    echo
    echo "PULLING $MODEL"
    ollama pull "$MODEL" || true
done

###############################################################################
# 16. OPENAI CODEX
###############################################################################

say "Installing OpenAI Codex"

npm install -g @openai/codex || true

###############################################################################
# 17. CLAUDE CODE
###############################################################################

say "Installing Claude Code"

npm install -g @anthropic-ai/claude-code || true

###############################################################################
# 18. OPENCODE
###############################################################################

say "Installing OpenCode"

npm install -g opencode-ai || true

###############################################################################
# 19. AIDER
###############################################################################

say "Installing Aider"

pipx install aider-chat || pipx upgrade aider-chat || true

###############################################################################
# 20. HERMES
###############################################################################

say "Installing Hermes Agent"

curl -fsSL \
    https://hermes-agent.nousresearch.com/install.sh \
    | bash

export PATH="$HOME/.local/bin:$PATH"

###############################################################################
# 21. OPENCLAW
###############################################################################

say "Installing OpenClaw"

curl -fsSL \
    --proto '=https' \
    --tlsv1.2 \
    https://openclaw.ai/install.sh \
    | bash -s -- --no-onboard

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

###############################################################################
# 22. OPENCLAW BETA
###############################################################################

say "Switching OpenClaw to beta channel"

if has openclaw; then
    openclaw update --channel beta || true
fi

###############################################################################
# 23. PLAYWRIGHT
###############################################################################

say "Installing Playwright browser automation"

npm install -g playwright || true

npx playwright install chromium || true

sudo npx playwright install-deps chromium || true

###############################################################################
# 24. COMFYUI
###############################################################################

say "Installing ComfyUI"

if [ ! -d "$AI/ComfyUI/.git" ]; then

    git clone \
        https://github.com/comfyanonymous/ComfyUI.git \
        "$AI/ComfyUI" || true

fi

if [ -f "$AI/ComfyUI/requirements.txt" ]; then

    python3 -m venv "$AI/ComfyUI/venv" || true

    "$AI/ComfyUI/venv/bin/pip" \
        install --upgrade pip setuptools wheel || true

    "$AI/ComfyUI/venv/bin/pip" \
        install -r "$AI/ComfyUI/requirements.txt" || true

fi

###############################################################################
# 25. OPEN WEBUI
###############################################################################

say "Installing Open WebUI"

sudo docker pull ghcr.io/open-webui/open-webui:main || true

sudo docker rm -f open-webui 2>/dev/null || true

sudo docker run -d \
    --name open-webui \
    --restart unless-stopped \
    -p 127.0.0.1:3000:8080 \
    -v open-webui:/app/backend/data \
    --add-host=host.docker.internal:host-gateway \
    ghcr.io/open-webui/open-webui:main || true

###############################################################################
# 26. N8N
###############################################################################

say "Installing n8n"

sudo docker pull docker.n8n.io/n8nio/n8n:latest || true

sudo docker rm -f n8n 2>/dev/null || true

sudo docker volume create n8n_data >/dev/null

sudo docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p 127.0.0.1:5678:5678 \
    -v n8n_data:/home/node/.n8n \
    docker.n8n.io/n8nio/n8n:latest || true

###############################################################################
# 27. CREATE MASTER AI STATE
###############################################################################

say "Creating persistent AI memory"

cat > "$AI/Shared/STATE/GOAL.md" <<'EOF'
# CHRISTOPHER MASTER GOAL

Create a fully autonomous AI-first personal computer.

The human should be able to give Christopher a high-level mission.

Christopher should then:

- understand the objective
- plan
- challenge its own plan
- delegate
- research
- code
- use the terminal
- manipulate files
- use Git
- use Docker
- use browsers
- use local models
- use cloud models
- use specialist agents
- test its work
- repair failures
- maintain memory
- maintain project state
- continue unfinished work

The human should NOT have to manually pass messages between agents.

The Builder and Strategist must communicate independently.

QA must independently verify work.

The final interface should be a graphical AI command centre.
EOF

cat > "$AI/Shared/STATE/STATE.md" <<'EOF'
# CHRISTOPHER CURRENT STATE

BOOTSTRAP IN PROGRESS.

The operating system and AI ecosystem are being installed.

The next system-level objective is:

BUILD CHRISTOPHER AI CONTROL CENTRE.
EOF

cat > "$AI/Shared/STATE/PLAN.md" <<'EOF'
# CHRISTOPHER MASTER PLAN

PHASE 1
Fresh Kubuntu workstation.

PHASE 2
AI runtimes and models.

PHASE 3
OpenClaw.

PHASE 4
Hermes.

PHASE 5
Codex.

PHASE 6
Claude Code.

PHASE 7
Multi-agent council.

PHASE 8
Persistent memory.

PHASE 9
Agent communication.

PHASE 10
GUI.

PHASE 11
Voice/avatar.

PHASE 12
Autonomous long-running projects.
EOF

cat > "$AI/Shared/STATE/TASKS.md" <<'EOF'
# CURRENT TASKS

- [ ] Finish Kubuntu AI installation
- [ ] Verify NVIDIA
- [ ] Verify Ollama
- [ ] Verify local models
- [ ] Verify OpenClaw
- [ ] Verify Hermes
- [ ] Verify Codex
- [ ] Verify Claude Code
- [ ] Verify Docker
- [ ] Verify Open WebUI
- [ ] Verify n8n
- [ ] Install/configure agent council
- [ ] Build Christopher GUI
- [ ] Build Builder chat
- [ ] Build Strategist chat
- [ ] Build visible agent-to-agent conversation
- [ ] Build persistent mission system
- [ ] Build autonomous project runner
- [ ] Add voice
- [ ] Add avatar
EOF

cat > "$AI/Shared/MESSAGES/README.md" <<'EOF'
# CHRISTOPHER AGENT MESSAGE BUS

Builder ↔ Strategist ↔ QA ↔ Researcher

Messages are persistent files so agents do not depend on sharing
one context window.

Important files:

builder-to-strategist.md
strategist-to-builder.md
builder-to-qa.md
qa-to-builder.md
researcher-to-builder.md
EOF

touch "$AI/Shared/MESSAGES/"*.md 2>/dev/null || true

###############################################################################
# 28. AGENT INSTRUCTIONS
###############################################################################

say "Creating agent personalities"

cat > "$AI/Agents/Builder/SOUL.md" <<'EOF'
# BUILDER

You are Christopher Builder.

You are the execution mind.

You do not merely suggest commands.

You perform the work.

Always inspect the current state first.

Read:

~/AI-PC/Shared/STATE/GOAL.md
~/AI-PC/Shared/STATE/STATE.md
~/AI-PC/Shared/STATE/PLAN.md
~/AI-PC/Shared/STATE/TASKS.md

Then work.

You can use:

- terminal
- filesystem
- Git
- Docker
- browsers
- local AI
- cloud AI
- Codex
- Claude
- Hermes
- OpenClaw
- MCP

Test your work.

Fix failures.

Do not stop merely because the first attempt failed.

Do not ask the human what to do next if the mission already makes it clear.

You are responsible for progress.
EOF

cat > "$AI/Agents/Strategist/SOUL.md" <<'EOF'
# STRATEGIST

You are Christopher Strategist.

You are deliberately independent of Builder.

Your first question is:

WHAT ARE WE ACTUALLY TRYING TO ACHIEVE?

Then ask:

WHY ARE WE DOING IT THIS WAY?

You challenge:

- architecture
- assumptions
- wasted work
- missing requirements
- poor UX
- unnecessary complexity
- wrong tools
- wrong models

You are allowed to disagree with Builder.

You must not simply say yes.

Write recommendations to:

~/AI-PC/Shared/MESSAGES/strategist-to-builder.md
EOF

cat > "$AI/Agents/QA/SOUL.md" <<'EOF'
# QA

You are Christopher QA.

Never trust a claim that something works.

Test it.

Inspect:

- files
- services
- processes
- APIs
- ports
- logs
- permissions
- applications
- models
- websites
- builds

If something fails:

reproduce → diagnose → report → fix → retest.

Record results in:

~/AI-PC/Shared/STATE/TESTS.md
EOF

cat > "$AI/Agents/Researcher/SOUL.md" <<'EOF'
# RESEARCHER

You investigate unknowns.

Use web research and local inspection.

Find:

- current documentation
- better tools
- better models
- compatibility issues
- implementation examples
- security problems
- alternatives

Do not waste time researching things that are already known.

Return actionable findings.
EOF

###############################################################################
# 29. MCP DIRECTORY
###############################################################################

say "Creating MCP infrastructure"

cat > "$AI/MCP/README.md" <<'EOF'
# MCP TOOLBOX

Christopher can progressively connect:

- filesystem
- GitHub
- browser
- Playwright
- Docker
- PostgreSQL
- SQLite
- Redis
- Google Cloud
- Google Drive
- n8n
- ComfyUI
- web research
- media tools
- Kubernetes
- home automation
EOF

###############################################################################
# 30. DESKTOP LAUNCHERS
###############################################################################

say "Creating KDE launchers"

mkdir -p "$HOME/.local/share/applications"

cat > "$HOME/.local/share/applications/christopher.desktop" <<EOF
[Desktop Entry]
Name=Christopher AI
Comment=Christopher AI Control Centre
Exec=xdg-open http://127.0.0.1:3000
Terminal=false
Type=Application
Categories=Utility;Development;AI;
EOF

cat > "$HOME/.local/share/applications/openclaw.desktop" <<EOF
[Desktop Entry]
Name=OpenClaw
Comment=Christopher Agent Gateway
Exec=xdg-open http://127.0.0.1:18789
Terminal=false
Type=Application
Categories=Utility;Development;AI;
EOF

cat > "$HOME/.local/share/applications/n8n.desktop" <<EOF
[Desktop Entry]
Name=n8n AI Automation
Comment=n8n Automation
Exec=xdg-open http://127.0.0.1:5678
Terminal=false
Type=Application
Categories=Utility;Development;AI;
EOF

###############################################################################
# 31. SYSTEM CHECK SCRIPT
###############################################################################

cat > "$AI/Scripts/system-check.sh" <<'EOF'
#!/usr/bin/env bash

echo
echo "=========================================="
echo " CHRISTOPHER AI-PC SYSTEM CHECK"
echo "=========================================="

echo
echo "OS:"
cat /etc/os-release | grep PRETTY_NAME

echo
echo "KERNEL:"
uname -a

echo
echo "GPU:"
nvidia-smi 2>/dev/null || lspci | grep -Ei 'nvidia|amd|vga'

echo
echo "NODE:"
node --version 2>/dev/null || true

echo
echo "PYTHON:"
python3 --version

echo
echo "DOCKER:"
docker --version 2>/dev/null || sudo docker --version

echo
echo "OLLAMA:"
ollama --version 2>/dev/null || true

echo
echo "MODELS:"
ollama list 2>/dev/null || true

echo
echo "OPENCLAW:"
openclaw --version 2>/dev/null || true

echo
echo "HERMES:"
hermes --version 2>/dev/null || true

echo
echo "CODEX:"
codex --version 2>/dev/null || true

echo
echo "CLAUDE:"
claude --version 2>/dev/null || true

echo
echo "DOCKER SERVICES:"
sudo docker ps

echo
echo "=========================================="
EOF

chmod +x "$AI/Scripts/system-check.sh"

###############################################################################
# 32. MASTER COMMAND
###############################################################################

cat > "$AI/christopher" <<'EOF'
#!/usr/bin/env bash

echo
echo "================================================"
echo "        CHRISTOPHER AI COMMAND CENTRE"
echo "================================================"
echo
echo "AI-PC:"
echo "  $HOME/AI-PC"
echo
echo "OPEN WEBUI:"
echo "  http://127.0.0.1:3000"
echo
echo "OPENCLAW:"
echo "  http://127.0.0.1:18789"
echo
echo "N8N:"
echo "  http://127.0.0.1:5678"
echo
echo "LOCAL MODELS:"
ollama list 2>/dev/null || true
echo
echo "Choose:"
echo
echo "1 = Open WebUI"
echo "2 = OpenClaw"
echo "3 = n8n"
echo "4 = Ollama"
echo "5 = System check"
echo "6 = AI workspace"
echo

read -rp "Choice: " C

case "$C" in
1) xdg-open http://127.0.0.1:3000 ;;
2) xdg-open http://127.0.0.1:18789 ;;
3) xdg-open http://127.0.0.1:5678 ;;
4) ollama list ;;
5) "$HOME/AI-PC/Scripts/system-check.sh" ;;
6) cd "$HOME/AI-PC"; bash ;;
esac
EOF

chmod +x "$AI/christopher"

###############################################################################
# 33. GIT
###############################################################################

say "Creating AI-PC Git repository"

cd "$AI"

git init

cat > .gitignore <<'EOF'
Models/
Logs/
Backups/
.env
.env.*
*.key
*.pem
credentials*
node_modules/
.venv/
venv/
__pycache__/
EOF

git add .
git commit -m "Initial Christopher AI-PC" || true

###############################################################################
# 34. ENABLE LINGER
###############################################################################

say "Enabling persistent user services"

sudo loginctl enable-linger "$USER_NAME" || true

###############################################################################
# 35. RELOAD SYSTEMD
###############################################################################

systemctl --user daemon-reload || true

###############################################################################
# 36. FINAL DIAGNOSTICS
###############################################################################

say "Running final diagnostics"

"$AI/Scripts/system-check.sh" || true

###############################################################################
# 37. WRITE BOOTSTRAP COMPLETE STATE
###############################################################################

cat > "$AI/Shared/STATE/STATE.md" <<EOF
# CHRISTOPHER CURRENT STATE

BOOTSTRAP COMPLETE

Completed:
$(date)

The fresh Kubuntu AI workstation has been prepared.

Installed/attempted:

- base development environment
- NVIDIA detection/driver installation
- Docker
- Python
- Node.js
- Git
- Ollama
- local models
- OpenClaw
- Hermes
- Codex
- Claude Code
- OpenCode
- Aider
- Playwright
- Chromium
- ComfyUI
- Open WebUI
- n8n
- persistent AI filesystem
- agent personalities
- shared message bus
- project state

NEXT:

OpenClaw onboarding must be completed.

Then Christopher should inspect the entire machine and build:

CHRISTOPHER AI CONTROL CENTRE

The control centre must contain:

- main Christopher chat
- Builder chat
- Strategist chat
- QA
- Researcher
- visible agent conversations
- missions
- projects
- files
- terminal
- browser
- models
- memory
- tools
- logs
- automation
- voice
- avatar

The human should not manually relay prompts between agents.

The agents should communicate through persistent shared state.
EOF

###############################################################################
# 38. COMPLETE
###############################################################################

echo
echo
echo "################################################################"
echo "#                                                              #"
echo "#       CHRISTOPHER AI-PC FRESH KUBUNTU BUILD COMPLETE         #"
echo "#                                                              #"
echo "################################################################"
echo
echo "AI DIRECTORY:"
echo
echo "    $AI"
echo
echo "COMMAND CENTRE:"
echo
echo "    $AI/christopher"
echo
echo "SYSTEM CHECK:"
echo
echo "    $AI/Scripts/system-check.sh"
echo
echo "OPEN WEBUI:"
echo
echo "    http://127.0.0.1:3000"
echo
echo "OPENCLAW:"
echo
echo "    http://127.0.0.1:18789"
echo
echo "N8N:"
echo
echo "    http://127.0.0.1:5678"
echo
echo "################################################################"
echo
echo "IMPORTANT:"
echo
echo "REBOOT NOW."
echo
echo "After reboot, run:"
echo
echo "    ~/AI-PC/Scripts/system-check.sh"
echo
echo "Then:"
echo
echo "    openclaw onboard --install-daemon"
echo
echo "And:"
echo
echo "    hermes setup --portal"
echo
echo "################################################################"
