#!/usr/bin/env bash
# Christopher GUI MAX — local web control hub, Plasma 6 widgets and launchers.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

VERSION="2026.09.02"
AI_ROOT="${AI_ROOT:-$HOME/AI-PC}"
ROOT="${CHRISTOPHER_GUI_ROOT:-$AI_ROOT/gui-max}"
BIN_DIR="$ROOT/bin"
WEB_DIR="$ROOT/web"
WIDGET_SRC="$ROOT/plasmoids"
STATE_DIR="$ROOT/state"
LOG_DIR="$ROOT/logs"
APP_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$HOME/Desktop"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVER="$BIN_DIR/intelligence-gui-server.py"
COMMANDER="$BIN_DIR/gui-command"
PORT="${CHRISTOPHER_GUI_PORT:-8765}"
HUB_URL="http://127.0.0.1:$PORT/"

say() { printf '%s\n' "$*"; }
info() { printf 'INFO: %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
Christopher GUI MAX $VERSION

Usage:
  ./CHRISTOPHER-GUI-MAX.sh install [--no-open]
  ./CHRISTOPHER-GUI-MAX.sh open
  ./CHRISTOPHER-GUI-MAX.sh status
  ./CHRISTOPHER-GUI-MAX.sh widgets
  ./CHRISTOPHER-GUI-MAX.sh remove

GUI Hub: $HUB_URL
OpenClaw Web GUI: openclaw dashboard
EOF
}

ensure_dirs() {
  mkdir -p "$BIN_DIR" "$WEB_DIR" "$WIDGET_SRC" "$STATE_DIR" "$LOG_DIR" \
    "$APP_DIR" "$PLASMOID_DIR" "$SYSTEMD_DIR"
  [[ -d "$DESKTOP_DIR" ]] || mkdir -p "$DESKTOP_DIR"
  chmod 0700 "$ROOT" "$STATE_DIR" "$LOG_DIR"
}

write_server() {
  cat >"$SERVER" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HOME = Path.home()
ROOT = Path(os.environ.get("CHRISTOPHER_GUI_ROOT", HOME / "AI-PC/gui-max")).expanduser()
TOKEN_FILE = ROOT / "state/gui-token"
INDEX_FILE = ROOT / "web/index.html"


def run(args: list[str], timeout: int = 8) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=timeout, check=False, env=os.environ.copy()
        )
        return proc.returncode, proc.stdout[-16000:]
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, str(exc)


def installed(name: str) -> bool:
    return shutil.which(name) is not None


def port_up(port: int, path: str = "/") -> bool:
    import urllib.request
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=0.7):
            return True
    except Exception:
        return False


def status() -> dict:
    gpu = {"available": False, "name": "No NVIDIA data", "util": 0, "memoryUsed": 0,
           "memoryTotal": 0, "temperature": 0, "power": 0}
    if installed("nvidia-smi"):
        code, output = run([
            "nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits"
        ], 3)
        if code == 0 and output.strip():
            parts = [part.strip() for part in output.splitlines()[0].split(",")]
            if len(parts) >= 6:
                try:
                    gpu = {"available": True, "name": parts[0], "util": float(parts[1]),
                           "memoryUsed": float(parts[2]), "memoryTotal": float(parts[3]),
                           "temperature": float(parts[4]), "power": float(parts[5])}
                except ValueError:
                    pass
    services = {
        "openclaw": port_up(18789), "openwebui": port_up(3000),
        "n8n": port_up(5678), "comfyui": port_up(8188),
        "lmstudio": port_up(1234, "/v1/models"), "ollama": port_up(11434, "/api/tags"),
    }
    tools = {name: installed(name) for name in
             ["openclaw", "codex", "claude", "ollama", "lms", "docker", "gh", "git", "nvidia-smi"]}
    return {"gpu": gpu, "services": services, "tools": tools}


ACTIONS = {
    "intelligence_sync": ["intelligence", "sync"],
    "intelligence_doctor": ["intelligence", "doctor"],
    "openclaw_restart": ["openclaw", "gateway", "restart"],
    "openclaw_status": ["openclaw", "gateway", "status", "--deep"],
    "openclaw_doctor": ["openclaw", "doctor"],
    "lmstudio_start": ["intelligence", "models", "serve"],
    "lmstudio_stop": ["intelligence", "models", "stop"],
    "models_status": ["intelligence", "models", "status"],
    "recommend": ["intelligence", "recommend"],
}


class Handler(BaseHTTPRequestHandler):
    server_version = "ChristopherGUI/1"

    def send_json(self, value: dict, code: int = 200) -> None:
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/status":
            self.send_json(status())
            return
        if path in ("/", "/index.html"):
            html = INDEX_FILE.read_text(encoding="utf-8")
            token = TOKEN_FILE.read_text(encoding="utf-8").strip()
            body = html.replace("__GUI_TOKEN__", token).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:")
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/action":
            self.send_error(404)
            return
        expected = TOKEN_FILE.read_text(encoding="utf-8").strip()
        if self.headers.get("X-Intelligence-Token", "") != expected:
            self.send_json({"ok": False, "output": "Invalid local action token"}, 403)
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            payload = json.loads(self.rfile.read(length))
            action = payload.get("action", "")
        except Exception:
            self.send_json({"ok": False, "output": "Invalid request"}, 400)
            return
        command = ACTIONS.get(action)
        if not command:
            self.send_json({"ok": False, "output": "Action is not allowlisted"}, 400)
            return
        if not installed(command[0]):
            self.send_json({"ok": False, "output": f"{command[0]} is not installed"}, 409)
            return
        code, output = run(command, 90)
        self.send_json({"ok": code == 0, "code": code, "output": output or "Completed"})

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} {fmt % args}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Christopher GUI listening on http://127.0.0.1:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
PY
  chmod 0755 "$SERVER"
}

write_web_ui() {
  cat >"$WEB_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="intelligence-token" content="__GUI_TOKEN__"><title>Christopher Intelligence</title>
<style>
:root{--blue:#00aeff;--pink:#ff3cac;--lime:#9cff00;--yellow:#ffd400;--orange:#ff7a00;--ink:#10131c;--card:#191e2b;--muted:#8d98aa}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 12% 5%,#183e59 0,transparent 32%),radial-gradient(circle at 90% 0,#551b4a 0,transparent 28%),#0b0e15;color:white;font:15px Inter,system-ui,sans-serif;min-height:100vh}.shell{max-width:1500px;margin:auto;padding:24px}.top{display:flex;gap:18px;align-items:center;justify-content:space-between;margin-bottom:22px}.brand h1{font-size:clamp(28px,4vw,58px);margin:0;letter-spacing:-2px}.brand b{color:var(--blue)}.brand p{color:#b9c4d3;margin:6px 0}.live{padding:10px 16px;border:1px solid #30415a;border-radius:999px;background:#101722}.grid{display:grid;grid-template-columns:repeat(12,1fr);gap:15px}.card{background:linear-gradient(145deg,rgba(28,34,49,.96),rgba(17,21,31,.96));border:1px solid #2a3448;border-radius:22px;padding:18px;box-shadow:0 18px 50px #0006}.gpu{grid-column:span 5;border-top:4px solid var(--blue)}.services{grid-column:span 7;border-top:4px solid var(--lime)}.launch{grid-column:span 12}.actions{grid-column:span 7;border-top:4px solid var(--pink)}.tools{grid-column:span 5;border-top:4px solid var(--yellow)}h2{margin:0 0 14px;font-size:18px}.gname{font-size:22px;font-weight:800}.big{font-size:48px;font-weight:900;color:var(--blue)}.meters{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:14px}.meter{background:#0d111a;border-radius:14px;padding:12px}.bar{height:9px;background:#293043;border-radius:9px;overflow:hidden;margin-top:8px}.fill{height:100%;background:linear-gradient(90deg,var(--blue),var(--pink));width:0}.pills{display:flex;flex-wrap:wrap;gap:9px}.pill{padding:9px 12px;background:#101520;border:1px solid #2b3548;border-radius:999px}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:#525d70;margin-right:7px}.on .dot{background:var(--lime);box-shadow:0 0 12px var(--lime)}.launchgrid,.actiongrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(155px,1fr));gap:11px}.tile,button{border:1px solid #33415a;background:#151b27;color:white;border-radius:16px;padding:14px;text-decoration:none;cursor:pointer;text-align:left;transition:.18s}.tile:hover,button:hover{transform:translateY(-2px);border-color:var(--blue);background:#1b2637}.tile span{font-size:25px;display:block;margin-bottom:7px}.tile small{color:var(--muted)}button strong{display:block}button small{color:var(--muted)}pre{white-space:pre-wrap;max-height:320px;overflow:auto;background:#080b11;border-radius:14px;padding:14px;color:#c9f2ff;display:none}.foot{color:#68758a;text-align:center;padding:30px} @media(max-width:850px){.gpu,.services,.actions,.tools{grid-column:span 12}.top{align-items:flex-start;flex-direction:column}}
</style></head><body><main class="shell"><div class="top"><div class="brand"><h1><b>CHRISTOPHER</b> INTELLIGENCE</h1><p>Your visual AI-PC command centre — OpenClaw, models, projects and GPU.</p></div><div class="live">● GUI MAX &nbsp; <span id="clock"></span></div></div>
<section class="grid"><article class="card gpu"><h2>NVIDIA GPU</h2><div class="gname" id="gpuName">Checking GPU…</div><div class="big"><span id="gpuUtil">0</span>%</div><div class="meters"><div class="meter">VRAM <b id="vram">—</b><div class="bar"><div class="fill" id="vramBar"></div></div></div><div class="meter">Temperature <b id="temp">—</b><br>Power <b id="power">—</b></div></div></article>
<article class="card services"><h2>AI SERVICES</h2><div class="pills" id="services"></div></article>
<article class="card launch"><h2>OPEN EVERYTHING</h2><div class="launchgrid">
<a class="tile" href="http://127.0.0.1:18789/" target="_blank"><span>🦞</span><b>OpenClaw Web GUI</b><br><small>Chat, agents, approvals, browser</small></a>
<a class="tile" href="http://127.0.0.1:3000" target="_blank"><span>💬</span><b>Open WebUI</b><br><small>Local model conversations</small></a>
<a class="tile" href="http://127.0.0.1:5678" target="_blank"><span>⚡</span><b>n8n</b><br><small>Visual automations</small></a>
<a class="tile" href="http://127.0.0.1:8188" target="_blank"><span>🎨</span><b>ComfyUI</b><br><small>Images and media workflows</small></a>
<a class="tile" href="https://chatgpt.com/" target="_blank"><span>🧠</span><b>ChatGPT</b><br><small>Main ideas and prompting</small></a>
<a class="tile" href="http://127.0.0.1:1234" target="_blank"><span>🖥️</span><b>LM Studio API</b><br><small>Local model server</small></a>
</div></article>
<article class="card actions"><h2>SAFE CONTROL BUTTONS</h2><div class="actiongrid">
<button data-action="intelligence_sync"><strong>🔄 Sync All Agents</strong><small>Refresh shared awareness</small></button>
<button data-action="intelligence_doctor"><strong>🩺 Full Doctor</strong><small>Audit every tool</small></button>
<button data-action="openclaw_restart"><strong>🦞 Restart OpenClaw</strong><small>Restart local Gateway</small></button>
<button data-action="openclaw_status"><strong>📡 Gateway Status</strong><small>Deep OpenClaw status</small></button>
<button data-action="openclaw_doctor"><strong>🔧 OpenClaw Doctor</strong><small>Read-only diagnosis</small></button>
<button data-action="lmstudio_start"><strong>▶ Start LM Studio</strong><small>Daemon and API server</small></button>
<button data-action="lmstudio_stop"><strong>■ Stop LM Studio</strong><small>Release GPU memory</small></button>
<button data-action="models_status"><strong>🤖 Model Status</strong><small>LM Studio and Ollama</small></button>
<button data-action="recommend"><strong>💡 Recommendations</strong><small>Best next tool setup</small></button>
</div><pre id="output"></pre></article>
<article class="card tools"><h2>INSTALLED BRAINS & HANDS</h2><div class="pills" id="tools"></div></article></section><div class="foot">Bound to 127.0.0.1 only · external actions still require Anthony's approval</div></main>
<script>
const token=document.querySelector('meta[name=intelligence-token]').content,out=document.getElementById('output');
function pill(name,on){return `<span class="pill ${on?'on':''}"><i class="dot"></i>${name}</span>`}
async function refresh(){try{const d=await fetch('/api/status',{cache:'no-store'}).then(r=>r.json()),g=d.gpu;gpuName.textContent=g.name;gpuUtil.textContent=Math.round(g.util);vram.textContent=`${Math.round(g.memoryUsed)} / ${Math.round(g.memoryTotal)} MB`;vramBar.style.width=(g.memoryTotal?Math.min(100,g.memoryUsed/g.memoryTotal*100):0)+'%';temp.textContent=Math.round(g.temperature)+'°C';power.textContent=Math.round(g.power)+' W';services.innerHTML=Object.entries(d.services).map(([n,v])=>pill(n,v)).join('');tools.innerHTML=Object.entries(d.tools).map(([n,v])=>pill(n,v)).join('')}catch(e){gpuName.textContent='GUI service unavailable'}}
document.querySelectorAll('button[data-action]').forEach(b=>b.onclick=async()=>{b.disabled=true;out.style.display='block';out.textContent='Running '+b.dataset.action+'…';try{const r=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json','X-Intelligence-Token':token},body:JSON.stringify({action:b.dataset.action})}).then(x=>x.json());out.textContent=(r.ok?'✓ ':'⚠ ')+r.output}catch(e){out.textContent='Failed: '+e}b.disabled=false;refresh()});
setInterval(()=>clock.textContent=new Date().toLocaleTimeString(),1000);setInterval(refresh,3000);refresh();
</script></body></html>
HTML
}

write_commander() {
  cat >"$COMMANDER" <<EOF
#!/usr/bin/env bash
set -u
action="\${1:-hub}"
case "\$action" in
  hub) xdg-open "$HUB_URL" ;;
  openclaw) openclaw dashboard ;;
  chat) read -r -p "Idea or objective: " p; intelligence chat "\$p" ;;
  council) read -r -p "Council objective: " p; intelligence council "\$p" ;;
  mission) read -r -p "Mission objective: " p; read -r -p "Project path [$AI_ROOT/Projects]: " d; intelligence mission "\$p" --project "\${d:-$AI_ROOT/Projects}" ;;
  doctor) intelligence doctor ;;
  recommendations) intelligence recommend ;;
  models) intelligence models status ;;
  ollama) ollama list; read -r -p "Model to chat with (blank to exit): " m; [[ -n "\$m" ]] && ollama run "\$m" ;;
  gpu) watch -n 1 nvidia-smi ;;
  managed-browser) openclaw browser --browser-profile openclaw start; openclaw browser --browser-profile openclaw status ;;
  chatgpt-browser) openclaw browser --browser-profile openclaw start; openclaw browser --browser-profile openclaw open https://chatgpt.com/ ;;
  social) intelligence social status ;;
  widgets) kcmshell6 kcm_plasmasearch 2>/dev/null || plasma-interactiveconsole ;;
  *) printf 'Unknown GUI action: %s\n' "\$action" >&2; exit 2 ;;
esac
EOF
  chmod 0755 "$COMMANDER"
}

write_service() {
  if [[ ! -s "$STATE_DIR/gui-token" ]]; then
    if have openssl; then
      openssl rand -hex 32 >"$STATE_DIR/gui-token"
    else
      od -An -N32 -tx1 /dev/urandom | tr -d ' \n' >"$STATE_DIR/gui-token"
    fi
  fi
  chmod 0600 "$STATE_DIR/gui-token"
  cat >"$SYSTEMD_DIR/intelligence-gui.service" <<EOF
[Unit]
Description=Christopher Intelligence visual control hub
After=graphical-session.target network-online.target

[Service]
Type=simple
Environment=CHRISTOPHER_GUI_ROOT=$ROOT
Environment=PATH=$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.claude/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 $SERVER --port $PORT
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
UMask=0077

[Install]
WantedBy=default.target
EOF
  if [[ "${CHRISTOPHER_GUI_TEST:-0}" != "1" ]]; then
    systemctl --user daemon-reload
    systemctl --user enable --now intelligence-gui.service
  fi
}

write_widget_metadata() {
  local dir="$1" id="$2" name="$3" description="$4" icon="$5"
  mkdir -p "$dir/contents/ui"
  cat >"$dir/metadata.json" <<EOF
{
  "KPlugin": {
    "Authors": [{"Name": "Anthony P Blomfield + Christopher"}],
    "Category": "System Information",
    "Description": "$description",
    "Icon": "$icon",
    "Id": "$id",
    "Name": "$name",
    "Version": "1.0"
  },
  "X-Plasma-API-Minimum-Version": "6.0",
  "KPackageStructure": "Plasma/Applet"
}
EOF
}

write_gpu_widget() {
  local dir="$WIDGET_SRC/com.anthony.intelligence.gpu"
  write_widget_metadata "$dir" "com.anthony.intelligence.gpu" "Christopher GPU Monitor" "Live NVIDIA GPU, VRAM and temperature" "video-display"
  cat >"$dir/contents/ui/main.qml" <<EOF
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    width: 340; height: 185
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    property var gpu: ({name:"Checking NVIDIA…",util:0,memoryUsed:0,memoryTotal:0,temperature:0,power:0})
    function refresh() { var x=new XMLHttpRequest(); x.onreadystatechange=function(){if(x.readyState===4&&x.status===200){try{gpu=JSON.parse(x.responseText).gpu}catch(e){}}}; x.open("GET","http://127.0.0.1:$PORT/api/status"); x.send() }
    Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Rectangle { anchors.fill: parent; radius: 20; color: "#151a26"; border.color: "#00aeff"; border.width: 2
        MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally("$HUB_URL") }
        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 7
            Text { text: "NVIDIA · CHRISTOPHER"; color: "#73d6ff"; font.bold: true; font.pixelSize: 14 }
            Text { text: root.gpu.name; color: "white"; font.bold: true; font.pixelSize: 16; elide: Text.ElideRight; Layout.fillWidth: true }
            RowLayout { Layout.fillWidth: true
                Text { text: Math.round(root.gpu.util)+"%"; color: "#00aeff"; font.bold: true; font.pixelSize: 38 }
                ColumnLayout { Layout.fillWidth: true
                    Text { text: Math.round(root.gpu.memoryUsed)+" / "+Math.round(root.gpu.memoryTotal)+" MB VRAM"; color: "#d7e6f7" }
                    Text { text: Math.round(root.gpu.temperature)+"°C  ·  "+Math.round(root.gpu.power)+" W"; color: "#9cff00"; font.bold: true }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 9; radius: 5; color: "#30384b"
                Rectangle { width: parent.width*Math.min(1,root.gpu.util/100); height: parent.height; radius: 5; color: "#00aeff" }
            }
            Text { text: "Click for Intelligence GUI"; color: "#7f8da3"; font.pixelSize: 11 }
        }
    }
}
EOF
}

write_services_widget() {
  local dir="$WIDGET_SRC/com.anthony.intelligence.services"
  write_widget_metadata "$dir" "com.anthony.intelligence.services" "Christopher AI Services" "Live status for OpenClaw and local AI services" "preferences-system"
  cat >"$dir/contents/ui/main.qml" <<EOF
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    width: 340; height: 210
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    property var services: ({openclaw:false,openwebui:false,n8n:false,comfyui:false,lmstudio:false,ollama:false})
    property var names: ({openclaw:"OpenClaw",openwebui:"Open WebUI",n8n:"n8n",comfyui:"ComfyUI",lmstudio:"LM Studio",ollama:"Ollama"})
    function refresh(){var x=new XMLHttpRequest();x.onreadystatechange=function(){if(x.readyState===4&&x.status===200){try{services=JSON.parse(x.responseText).services}catch(e){}}};x.open("GET","http://127.0.0.1:$PORT/api/status");x.send()}
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Rectangle { anchors.fill: parent; radius: 20; color: "#151a26"; border.color: "#9cff00"; border.width: 2
        MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally("$HUB_URL") }
        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 7
            Text { text: "AI SERVICES"; color: "#9cff00"; font.bold: true; font.pixelSize: 16 }
            Repeater { model: ["openclaw","openwebui","n8n","comfyui","lmstudio","ollama"]
                RowLayout { Layout.fillWidth: true
                    Rectangle { width: 10; height: 10; radius: 5; color: root.services[modelData] ? "#9cff00" : "#596276" }
                    Text { text: root.names[modelData]; color: "white"; Layout.fillWidth: true }
                    Text { text: root.services[modelData] ? "ONLINE" : "OFF"; color: root.services[modelData] ? "#9cff00" : "#7f8da3"; font.bold: true }
                }
            }
        }
    }
}
EOF
}

install_widgets() {
  write_gpu_widget
  write_services_widget
  local id source target
  for id in com.anthony.intelligence.gpu com.anthony.intelligence.services; do
    source="$WIDGET_SRC/$id"; target="$PLASMOID_DIR/$id"
    if have kpackagetool6; then
      if [[ -d "$target" ]]; then
        kpackagetool6 --type Plasma/Applet --upgrade "$source" >/dev/null 2>&1 || true
      else
        kpackagetool6 --type Plasma/Applet --install "$source" >/dev/null 2>&1 || true
      fi
    fi
    if [[ ! -d "$target" ]]; then
      mkdir -p "$target"
      cp -a "$source/." "$target/"
    fi
  done

  cat >"$STATE_DIR/add-widgets.js" <<'JS'
var ds = desktops();
if (ds.length > 0) {
  var d = ds[0];
  var types = ["com.anthony.intelligence.gpu", "com.anthony.intelligence.services"];
  for (var t = 0; t < types.length; ++t) {
    var found = false;
    var ids = d.widgetIds;
    for (var i = 0; i < ids.length; ++i) {
      if (d.widgetById(ids[i]).type === types[t]) { found = true; break; }
    }
    if (!found) { d.addWidget(types[t]); }
  }
}
JS
  local qdbus=""
  have qdbus6 && qdbus="qdbus6"
  [[ -z "$qdbus" ]] && have qdbus && qdbus="qdbus"
  if [[ -n "$qdbus" ]] && pgrep -x plasmashell >/dev/null 2>&1; then
    "$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(<"$STATE_DIR/add-widgets.js")" >/dev/null 2>&1 || \
      warn "Widgets installed; right-click the desktop → Add Widgets to place them."
  else
    warn "Widgets installed; log into Plasma, right-click desktop → Add Widgets, and search Christopher."
  fi
}

write_desktop() {
  local file="$1" name="$2" comment="$3" exec_line="$4" icon="$5" terminal="$6"
  cat >"$APP_DIR/$file.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_line
Icon=$icon
Terminal=$terminal
Categories=Development;Utility;
StartupNotify=true
EOF
  chmod 0755 "$APP_DIR/$file.desktop"
  cp -f "$APP_DIR/$file.desktop" "$DESKTOP_DIR/$file.desktop"
  chmod 0755 "$DESKTOP_DIR/$file.desktop"
  have gio && gio set "$DESKTOP_DIR/$file.desktop" metadata::trusted true >/dev/null 2>&1 || true
}

install_launchers() {
  write_desktop ai-control-centre "AI Control Centre" "Christopher visual command hub" "$COMMANDER hub" preferences-system false
  write_desktop openclaw-web-gui "OpenClaw Web GUI" "OpenClaw chat, agents, approvals and browser" "$COMMANDER openclaw" applications-internet false
  write_desktop intelligence-chat "Chat with Intelligence" "ChatGPT/Codex plus OpenClaw review" "$COMMANDER chat" chat true
  write_desktop intelligence-council "AI Council" "Ask all specialist agents" "$COMMANDER council" system-users true
  write_desktop intelligence-mission "New AI Mission" "Plan a project mission" "$COMMANDER mission" task-new true
  write_desktop intelligence-doctor "AI Tool Doctor" "Audit every AI component" "$COMMANDER doctor" tools-report-bug true
  write_desktop gpu-live-monitor "NVIDIA GPU Live" "Live RTX GPU monitor" "$COMMANDER gpu" video-display true
  write_desktop nvidia-settings "NVIDIA Settings" "Graphics driver control panel" "nvidia-settings" nvidia-settings false
  write_desktop plasma-system-monitor "Plasma System Monitor" "CPU, memory, network and GPU" "plasma-systemmonitor" utilities-system-monitor false
  write_desktop open-webui "Open WebUI" "Local AI chat interface" "xdg-open http://127.0.0.1:3000" internet-chat false
  write_desktop n8n-automations "n8n Visual Automations" "Build visual workflows" "xdg-open http://127.0.0.1:5678" applications-system false
  write_desktop comfyui "ComfyUI Image Studio" "Visual AI image workflows" "xdg-open http://127.0.0.1:8188" applications-graphics false
  write_desktop chatgpt "ChatGPT" "Open ChatGPT" "xdg-open https://chatgpt.com/" chatgpt false
  write_desktop lm-studio-models "LM Studio Models" "Local model status and controls" "$COMMANDER models" computer true
  write_desktop ollama-models "Ollama Models" "List and chat with local Ollama models" "$COMMANDER ollama" network-server true
  write_desktop openclaw-managed-browser "OpenClaw Managed Browser" "Start isolated browser control" "$COMMANDER managed-browser" internet-web-browser true
  write_desktop openclaw-chatgpt-browser "ChatGPT in OpenClaw Browser" "Open ChatGPT for visible browser control" "$COMMANDER chatgpt-browser" internet-web-browser true
  write_desktop ai-social-connections "AI Social Connections" "Inspect OpenClaw channels and plugins" "$COMMANDER social" network-connect true
  write_desktop ai-recommendations "AI Recommendations" "Suggested next tools and improvements" "$COMMANDER recommendations" help-hint true
  write_desktop ai-projects "AI Projects" "Open projects folder" "xdg-open $AI_ROOT/Projects" folder-development false
  write_desktop ai-model-files "AI Model Files" "Open model warehouse" "xdg-open $AI_ROOT/Models" folder-download false
  write_desktop ai-install-logs "AI Installation Logs" "Open logs folder" "xdg-open $AI_ROOT/Logs" folder-log false
  write_desktop ai-conversations "AI Conversations" "Open saved Intelligence conversations" "xdg-open $AI_ROOT/intelligence/conversations" folder-txt false
  write_desktop ai-workspace "AI Workspace" "Open complete AI-PC folder" "xdg-open $AI_ROOT" folder-favorites false
  have update-desktop-database && update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
}

install_all() {
  local open_after=true
  [[ "${1:-}" == "--no-open" ]] && open_after=false
  ensure_dirs
  write_server
  write_web_ui
  write_commander
  write_service
  install_widgets
  install_launchers
  install -m 0755 "$0" "$BIN_DIR/CHRISTOPHER-GUI-MAX.sh"
  if [[ "${CHRISTOPHER_GUI_TEST:-0}" != "1" ]]; then
    sleep 1
    curl --silent --fail --max-time 3 "http://127.0.0.1:$PORT/api/status" >/dev/null || \
      warn "GUI service is installed but not answering yet. Check: systemctl --user status intelligence-gui"
  fi
  say
  say "GUI MAX installed."
  say "Intelligence Hub: $HUB_URL"
  say "OpenClaw Web GUI: run openclaw dashboard"
  say "Plasma widgets: Christopher GPU Monitor + Christopher AI Services"
  say "Desktop launchers: 24"
  $open_after && xdg-open "$HUB_URL" >/dev/null 2>&1 || true
}

remove_all() {
  systemctl --user disable --now intelligence-gui.service 2>/dev/null || true
  local file
  for file in "$APP_DIR"/{ai-control-centre,openclaw-web-gui,intelligence-chat,intelligence-council,intelligence-mission,intelligence-doctor,gpu-live-monitor,nvidia-settings,plasma-system-monitor,open-webui,n8n-automations,comfyui,chatgpt,lm-studio-models,ollama-models,openclaw-managed-browser,openclaw-chatgpt-browser,ai-social-connections,ai-recommendations,ai-projects,ai-model-files,ai-install-logs,ai-conversations,ai-workspace}.desktop; do
    rm -f -- "$file" "$DESKTOP_DIR/$(basename "$file")"
  done
  warn "GUI service and launchers removed. Plasmoids were retained so Plasma does not lose an active widget."
}

main() {
  case "${1:-help}" in
    install) shift; install_all "$@" ;;
    open) xdg-open "$HUB_URL" ;;
    status) systemctl --user status intelligence-gui.service --no-pager || true; curl --silent "http://127.0.0.1:$PORT/api/status" || true; say ;;
    widgets) ensure_dirs; install_widgets ;;
    remove) remove_all ;;
    help|-h|--help) usage ;;
    *) usage; die "Unknown command: $1" ;;
  esac
}

main "$@"
