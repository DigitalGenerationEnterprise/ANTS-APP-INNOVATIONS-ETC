#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="anthony-local-ai-manager"
PLUGIN_DIR="$HOME/.local/share/$PLUGIN_ID"
SKILL_DIR="$HOME/.openclaw/workspace/skills/local-ai-manager"
BIN="$HOME/.local/bin"
SYSTEMD="$HOME/.config/systemd/user"
LOG_DIR="$HOME/.openclaw/logs"

ROUTER_MODEL="${ROUTER_MODEL:-qwen/qwen3.5-2b}"
DEFAULT_MODEL="${DEFAULT_MODEL:-qwen/qwen3.5-9b}"
LM_URL="${LM_URL:-http://127.0.0.1:1234}"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"

mkdir -p "$PLUGIN_DIR" "$SKILL_DIR" "$BIN" "$SYSTEMD" "$LOG_DIR"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required."
    exit 1
  }
}

need openclaw
need lms
need node
need npm
need curl
need python3

OC="$(command -v openclaw)"
LMS="$(command -v lms)"

echo
echo "=============================================================="
echo " OPENCLAW LOCAL AI MANAGER"
echo "=============================================================="
echo
echo "This installs a REAL agent tool:"
echo "  local_ai_manager"
echo
echo "It can:"
echo "  - classify a local fallback task"
echo "  - choose from models already downloaded in LM Studio"
echo "  - preserve a tiny CPU routing model"
echo "  - unload old heavy models"
echo "  - estimate memory"
echo "  - load the selected model onto GPU"
echo "  - return the exact lmstudio/<model> ref for sessions_spawn"
echo "  - prepare local ComfyUI image mode when configured"
echo

# ------------------------------------------------------------------
# LM Studio baseline
# ------------------------------------------------------------------
echo "[1/8] Starting LM Studio..."
"$LMS" daemon up >/dev/null 2>&1 || true
"$LMS" server start --port 1234 >/dev/null 2>&1 || true

for _ in $(seq 1 30); do
  curl -fsS "$LM_URL/api/v1/models" >/dev/null 2>&1 && break
  sleep 1
done

if ! curl -fsS "$LM_URL/api/v1/models" >/dev/null 2>&1; then
  echo "ERROR: LM Studio API is not answering at $LM_URL"
  exit 1
fi

echo "LM Studio API: OK"

# ------------------------------------------------------------------
# Tiny CPU brain
# ------------------------------------------------------------------
echo
echo "[2/8] Ensuring tiny CPU routing model exists..."

if ! "$LMS" ls --llm --json 2>/dev/null | grep -Fq "$ROUTER_MODEL"; then
  echo "Downloading $ROUTER_MODEL ..."
  "$LMS" get "$ROUTER_MODEL"
fi

cat > "$BIN/local-ai-router-start" <<EOF
#!/usr/bin/env bash
set -u
LMS="$LMS"
MODEL="$ROUTER_MODEL"

"\$LMS" daemon up >/dev/null 2>&1 || true
"\$LMS" server start --port 1234 >/dev/null 2>&1 || true

for _ in \$(seq 1 30); do
  curl -fsS "$LM_URL/api/v1/models" >/dev/null 2>&1 && break
  sleep 1
done

if ! "\$LMS" ps --json 2>/dev/null | grep -Fq "\$MODEL"; then
  "\$LMS" load "\$MODEL" \
    --gpu off \
    --context-length 4096
fi
EOF
chmod +x "$BIN/local-ai-router-start"

cat > "$SYSTEMD/local-ai-router.service" <<EOF
[Unit]
Description=OpenClaw Tiny CPU Local AI Router
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$BIN/local-ai-router-start

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now local-ai-router.service >/dev/null

# ------------------------------------------------------------------
# Plugin metadata/dependency
# ------------------------------------------------------------------
echo
echo "[3/8] Building OpenClaw tool plugin..."

cat > "$PLUGIN_DIR/package.json" <<'JSON'
{
  "name": "anthony-local-ai-manager",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "typebox": "1.3.16"
  },
  "peerDependencies": {
    "openclaw": ">=2026.3.24-beta.2"
  },
  "openclaw": {
    "extensions": ["./index.js"]
  }
}
JSON

cat > "$PLUGIN_DIR/openclaw.plugin.json" <<'JSON'
{
  "id": "anthony-local-ai-manager",
  "name": "Anthony Local AI Manager",
  "description": "Selects, loads, unloads and prepares local LM Studio models and local ComfyUI fallback capacity.",
  "version": "1.0.0",
  "contracts": {
    "tools": ["local_ai_manager"]
  },
  "activation": {
    "onStartup": true
  },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "routerModel": {"type": "string"},
      "defaultModel": {"type": "string"},
      "lmUrl": {"type": "string"},
      "comfyUrl": {"type": "string"},
      "defaultTtlSeconds": {"type": "number"},
      "defaultContextLength": {"type": "number"}
    }
  }
}
JSON

cat > "$PLUGIN_DIR/index.js" <<'JS'
import { Type } from "typebox";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { appendFile, mkdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const execFileP = promisify(execFile);

function splitRef(ref) {
  const s = String(ref || "");
  const i = s.indexOf("/");
  if (i <= 0) return null;
  return { provider: s.slice(0, i), model: s.slice(i + 1) };
}

function uniq(xs) {
  return [...new Set(xs.filter(Boolean))];
}

function textOf(v) {
  if (typeof v === "string") return v;
  try { return JSON.stringify(v); } catch { return String(v); }
}

function modelKeyFromString(v) {
  if (typeof v !== "string") return null;
  const x = v.trim();
  if (!x.includes("/")) return null;
  if (x.startsWith("/") || x.includes(" ")) return null;
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.@:+-]+$/.test(x)) return null;
  return x;
}

function extractModelKeys(raw) {
  const keys = new Set();

  const accept = (v) => {
    const k = modelKeyFromString(v);
    if (!k) return;
    if (k.startsWith("lmstudio/")) {
      keys.add(k.slice("lmstudio/".length));
    } else {
      keys.add(k);
    }
  };

  try {
    const obj = JSON.parse(raw);
    const walk = (x, key = "") => {
      if (Array.isArray(x)) {
        for (const y of x) walk(y, key);
        return;
      }
      if (x && typeof x === "object") {
        for (const [k, v] of Object.entries(x)) {
          if (/^(key|modelKey|model_key|identifier|id|model|name)$/i.test(k)) {
            accept(v);
          }
          walk(v, k);
        }
        return;
      }
      if (typeof x === "string" &&
          /^(key|modelKey|model_key|identifier|id|model|name)$/i.test(key)) {
        accept(x);
      }
    };
    walk(obj);
  } catch {}

  for (const m of String(raw).matchAll(/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.@:+-]+/g)) {
    accept(m[0]);
  }

  return [...keys];
}

function paramsB(name) {
  const s = String(name).toLowerCase();

  // Common total-parameter naming patterns.
  const ms = [
    ...s.matchAll(/(?:^|[-_/])(\d+(?:\.\d+)?)b(?:$|[-_@])/g)
  ];
  if (!ms.length) return 0;

  return Math.max(...ms.map((m) => Number(m[1]) || 0));
}

function classifyHard(task, requested) {
  if (requested && requested !== "auto") return requested;

  const s = String(task || "").toLowerCase();

  if (/(generate|create|draw|render|make).{0,30}(image|picture|photo|art|illustration|logo|poster)|text.to.image|image generation/.test(s)) {
    return "image";
  }

  if (/(embedding|embed vectors|semantic search|vector database|vectorize)/.test(s)) {
    return "embedding";
  }

  if (/(look at|inspect|analyse|analyze|describe|read).{0,30}(image|photo|picture|screenshot)|vision|ocr/.test(s)) {
    return "vision";
  }

  if (/(code|coding|program|script|python|javascript|typescript|dart|flutter|react|bash|shell|debug|bug|compile|repo|git|docker|systemd|qml|sql|regex|api implementation)/.test(s)) {
    return "code";
  }

  if (/(proof|deep reasoning|architecture|root cause|complex analysis|algorithm|mathemat|strategy|security audit|reason carefully)/.test(s)) {
    return "reasoning";
  }

  if (s.length < 180) return "fast";
  if (s.length > 1800) return "reasoning";

  return "general";
}

function scoreModel(key, capability, routerModel, defaultModel) {
  const s = key.toLowerCase();
  const size = paramsB(s);
  let score = 0;

  // Avoid embeddings/media names in LLM selection.
  if (/(embed|embedding|rerank|tts|whisper|stable.diffusion|flux.*schnell)/.test(s)) {
    score -= 1000;
  }

  if (capability === "code") {
    if (/(coder|code|devstral|codestral)/.test(s)) score += 260;
    if (/glm[-_.]?(4\.7|5|5\.2|5\.3)/.test(s)) score += 130;
    if (/qwen3\.?5/.test(s)) score += 100;
    if (/gpt[-_.]?oss/.test(s)) score += 100;
    if (/nemotron/.test(s)) score += 70;
    score += Math.min(size, 45) * 3;
  }

  if (capability === "reasoning") {
    if (/(reason|deepseek|r1)/.test(s)) score += 220;
    if (/qwen3\.?5/.test(s)) score += 150;
    if (/gpt[-_.]?oss/.test(s)) score += 140;
    if (/nemotron|glm/.test(s)) score += 110;
    score += Math.min(size, 45) * 4;
  }

  if (capability === "vision") {
    if (/(vision|[-_.]vl[-_.]|vlm|omni)/.test(s)) score += 260;
    if (/qwen3\.?5/.test(s)) score += 220;
    if (/gemma[-_.]?4|glm.*v/.test(s)) score += 170;
    score += Math.min(size, 35) * 3;
  }

  if (capability === "fast") {
    // Small capable models win.
    if (/qwen3\.?5/.test(s)) score += 150;
    if (size > 0) score += Math.max(0, 130 - size * 12);
    if (key === routerModel) score += 40;
  }

  if (capability === "general") {
    if (/qwen3\.?5/.test(s)) score += 140;
    if (/gemma|mistral|llama|glm|gpt[-_.]?oss|nemotron/.test(s)) score += 60;
    // Sweet spot for normal local work.
    if (size >= 7 && size <= 20) score += 100;
    else score += Math.min(size, 30) * 2;
  }

  if (key === defaultModel) score += 35;
  if (key === routerModel && capability !== "fast") score -= 120;

  return score;
}

function chooseModel(keys, capability, routerModel, defaultModel) {
  const pool = uniq(keys);

  if (!pool.length) return defaultModel;

  return [...pool].sort(
    (a, b) =>
      scoreModel(b, capability, routerModel, defaultModel) -
      scoreModel(a, capability, routerModel, defaultModel)
  )[0] || defaultModel;
}

async function cmd(bin, args, timeout = 120000) {
  try {
    const { stdout, stderr } = await execFileP(
      bin,
      args,
      { timeout, maxBuffer: 16 * 1024 * 1024 }
    );
    return { ok: true, stdout: stdout || "", stderr: stderr || "" };
  } catch (e) {
    return {
      ok: false,
      stdout: e?.stdout || "",
      stderr: e?.stderr || "",
      error: String(e?.message || e),
    };
  }
}

async function lmsKeys(kind = "llm") {
  const args =
    kind === "embedding"
      ? ["ls", "--embedding", "--json"]
      : ["ls", "--llm", "--json"];

  const r = await cmd("lms", args, 10000);
  if (!r.ok) return [];
  return extractModelKeys(r.stdout);
}

async function loadedKeys() {
  const r = await cmd("lms", ["ps", "--json"], 10000);
  if (!r.ok) return [];
  return extractModelKeys(r.stdout);
}

async function callTinyRouter({
  lmUrl, routerModel, task, candidates, heuristic, capability
}) {
  if (!task || candidates.length < 2) return heuristic;

  const headers = { "Content-Type": "application/json" };
  if (process.env.LM_API_TOKEN) {
    headers.Authorization = `Bearer ${process.env.LM_API_TOKEN}`;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6000);

  try {
    const rules = `
You are a tiny LOCAL MODEL SELECTOR.
Do not answer the task.
Choose one exact local model key from the candidate list.
Return JSON only:
{"model":"publisher/model","reason":"short"}

Capability already inferred: ${capability}
Heuristic choice: ${heuristic}

Prefer:
- code-specialized models for code
- vision/VL models for image understanding
- stronger reasoning models for difficult analysis
- smaller models for trivial/fast work
- do not choose the tiny router for substantial work when stronger candidates exist

Candidates:
${candidates.slice(0, 18).map((x) => `- ${x}`).join("\n")}
`.trim();

    const res = await fetch(
      lmUrl.replace(/\/$/, "") + "/v1/chat/completions",
      {
        method: "POST",
        headers,
        signal: controller.signal,
        body: JSON.stringify({
          model: routerModel,
          messages: [
            { role: "system", content: rules },
            { role: "user", content: String(task).slice(0, 3500) }
          ],
          temperature: 0,
          max_tokens: 80
        })
      }
    );

    if (!res.ok) return heuristic;

    const obj = await res.json();
    const txt =
      obj?.choices?.[0]?.message?.content ??
      obj?.choices?.[0]?.message?.reasoning_content ??
      "";

    const m = String(txt).match(/\{[\s\S]*\}/);
    if (!m) return heuristic;

    const d = JSON.parse(m[0]);
    if (candidates.includes(d.model)) return d.model;
  } catch {
    return heuristic;
  } finally {
    clearTimeout(timer);
  }

  return heuristic;
}

function parseEstimate(text) {
  const gpu =
    String(text).match(/Estimated GPU Memory:\s*([0-9.]+)\s*(GB|MB)/i);
  const total =
    String(text).match(/Estimated Total Memory:\s*([0-9.]+)\s*(GB|MB)/i);

  function mb(m) {
    if (!m) return null;
    const n = Number(m[1]);
    return m[2].toUpperCase() === "GB" ? n * 1024 : n;
  }

  return {
    gpuMB: mb(gpu),
    totalMB: mb(total),
    raw: String(text).slice(0, 1500),
  };
}

async function freeGpuMB() {
  const nvidia = await cmd(
    "nvidia-smi",
    ["--query-gpu=memory.free", "--format=csv,noheader,nounits"],
    3000
  );

  if (nvidia.ok) {
    const nums = nvidia.stdout
      .trim()
      .split(/\s+/)
      .map(Number)
      .filter(Number.isFinite);
    if (nums.length) return Math.max(...nums);
  }

  return null;
}

async function ensureRouter(routerModel) {
  const loaded = await loadedKeys();
  if (loaded.includes(routerModel)) return true;

  const r = await cmd(
    "lms",
    ["load", routerModel, "--gpu", "off", "--context-length", "4096"],
    180000
  );
  return r.ok;
}

async function freeHeavyModels(routerModel) {
  // Reliable and deterministic: free everything, then immediately restore
  // the tiny selector on CPU. This avoids depending on per-instance unload IDs.
  await cmd("lms", ["unload", "--all"], 60000);
  await ensureRouter(routerModel);
}

async function comfyAlive(comfyUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  try {
    const urls = [
      comfyUrl.replace(/\/$/, "") + "/system_stats",
      comfyUrl.replace(/\/$/, "") + "/object_info",
    ];
    for (const u of urls) {
      try {
        const r = await fetch(u, { signal: controller.signal });
        if (r.ok) return true;
      } catch {}
    }
    return false;
  } finally {
    clearTimeout(timer);
  }
}

async function comfyConfigured() {
  const r = await cmd(
    "openclaw",
    ["models", "list", "--provider", "comfy", "--json"],
    8000
  );
  return r.ok && /comfy\/workflow/i.test(r.stdout);
}

async function logDecision(row) {
  try {
    const dir = path.join(os.homedir(), ".openclaw", "logs");
    await mkdir(dir, { recursive: true });
    await appendFile(
      path.join(dir, "local-ai-manager.log"),
      `${new Date().toISOString()} ${JSON.stringify(row)}\n`,
      "utf8"
    );
  } catch {}
}

function result(text, details) {
  return {
    content: [{ type: "text", text }],
    details,
  };
}

export default definePluginEntry({
  id: "anthony-local-ai-manager",
  name: "Anthony Local AI Manager",
  description:
    "Selects and prepares task-specific local models in LM Studio and local media capacity.",

  register(api) {
    const pc = api.pluginConfig ?? {};

    const cfg = {
      routerModel: pc.routerModel || "qwen/qwen3.5-2b",
      defaultModel: pc.defaultModel || "qwen/qwen3.5-9b",
      lmUrl: pc.lmUrl || "http://127.0.0.1:1234",
      comfyUrl: pc.comfyUrl || "http://127.0.0.1:8188",
      defaultTtlSeconds: Number(pc.defaultTtlSeconds || 900),
      defaultContextLength: Number(pc.defaultContextLength || 16384),
    };

    api.registerTool({
      name: "local_ai_manager",
      description:
        "Prepare a LOCAL fallback backend when cloud AI is unavailable, unsuitable, rate-limited, or explicitly forbidden. " +
        "For text/code/reasoning/vision it chooses an installed LM Studio model, frees old GPU models, loads the chosen model, " +
        "and returns a modelRef. AFTER prepare succeeds, delegate the actual substantive task with sessions_spawn using that exact modelRef. " +
        "For image generation it frees LM Studio GPU capacity and checks local ComfyUI; if ready, call image_generate with model=comfy/workflow. " +
        "Use action=status to inspect without changing anything. Do not call this merely to replace a healthy cloud model unless local execution is requested.",

      parameters: Type.Object({
        action: Type.Optional(
          Type.Union([
            Type.Literal("prepare"),
            Type.Literal("recommend"),
            Type.Literal("status"),
            Type.Literal("release")
          ])
        ),
        capability: Type.Optional(
          Type.Union([
            Type.Literal("auto"),
            Type.Literal("fast"),
            Type.Literal("general"),
            Type.Literal("code"),
            Type.Literal("reasoning"),
            Type.Literal("vision"),
            Type.Literal("embedding"),
            Type.Literal("image")
          ])
        ),
        task: Type.Optional(
          Type.String({
            description:
              "A concise description of the work that the selected local model/backend must perform."
          })
        ),
        forceModel: Type.Optional(
          Type.String({
            description:
              "Optional exact LM Studio model key such as qwen/qwen3.5-9b."
          })
        ),
        contextLength: Type.Optional(
          Type.Number({ minimum: 1024, maximum: 262144 })
        ),
        ttlSeconds: Type.Optional(
          Type.Number({ minimum: 60, maximum: 7200 })
        ),
        keepGpuModels: Type.Optional(
          Type.Boolean({
            description:
              "If true, do not unload existing heavy LM Studio models before loading the selected model."
          })
        )
      }),

      async execute(_id, params) {
        const action = params.action || "prepare";
        const requested = params.capability || "auto";
        const task = params.task || "";
        const ttlSeconds = Math.round(
          params.ttlSeconds || cfg.defaultTtlSeconds
        );
        const contextLength = Math.round(
          params.contextLength || cfg.defaultContextLength
        );

        if (action === "status") {
          const [llms, embeddings, loaded, comfy, comfyCfg, gpuFree] =
            await Promise.all([
              lmsKeys("llm"),
              lmsKeys("embedding"),
              loadedKeys(),
              comfyAlive(cfg.comfyUrl),
              comfyConfigured(),
              freeGpuMB(),
            ]);

          return result(
            [
              `Tiny router: ${cfg.routerModel}`,
              `Loaded LM Studio models: ${loaded.join(", ") || "none"}`,
              `Downloaded LLMs: ${llms.length}`,
              `Downloaded embeddings: ${embeddings.length}`,
              `Free NVIDIA VRAM: ${gpuFree == null ? "unknown" : gpuFree + " MB"}`,
              `ComfyUI reachable: ${comfy ? "yes" : "no"}`,
              `OpenClaw comfy/workflow configured: ${comfyCfg ? "yes" : "no"}`
            ].join("\n"),
            {
              routerModel: cfg.routerModel,
              loaded,
              llmCount: llms.length,
              embeddingCount: embeddings.length,
              freeGpuMB: gpuFree,
              comfyReachable: comfy,
              comfyConfigured: comfyCfg,
            }
          );
        }

        if (action === "release") {
          await freeHeavyModels(cfg.routerModel);

          const details = {
            released: true,
            routerPreserved: cfg.routerModel,
            next: "Local heavy GPU models were unloaded; tiny CPU router restored."
          };

          await logDecision({ action, ...details });
          return result(
            `Released heavy LM Studio models. Tiny CPU router remains: ${cfg.routerModel}`,
            details
          );
        }

        const capability = classifyHard(task, requested);

        // ----------------------------------------------------------
        // LOCAL IMAGE / MEDIA HANDOFF
        // ----------------------------------------------------------
        if (capability === "image") {
          const cAlive = await comfyAlive(cfg.comfyUrl);
          const cConfigured = await comfyConfigured();

          if (action === "prepare" && !params.keepGpuModels) {
            await freeHeavyModels(cfg.routerModel);
          }

          const ready = cAlive && cConfigured;

          const details = {
            capability: "image",
            backend: ready ? "comfy" : "unavailable-local-image",
            comfyUrl: cfg.comfyUrl,
            comfyReachable: cAlive,
            comfyConfigured: cConfigured,
            modelRef: ready ? "comfy/workflow" : null,
            nextTool: ready ? "image_generate" : null,
            nextToolArgs: ready
              ? { model: "comfy/workflow", prompt: task }
              : null,
            recommendation: ready
              ? "Call image_generate with model=comfy/workflow now."
              : "Use healthy online image_generate providers. To enable local image fallback, run local-ai-image-setup after ComfyUI is installed and a workflow JSON is available."
          };

          await logDecision({ action, ...details });

          return result(
            ready
              ? "Local image GPU mode prepared. LM Studio heavy models were released. ComfyUI is reachable and configured. Call image_generate with model=comfy/workflow."
              : "Local image generation is not fully ready. LM Studio itself does not generate diffusion images. Use an online image_generate provider, or configure local ComfyUI with local-ai-image-setup.",
            details
          );
        }

        // ----------------------------------------------------------
        // EMBEDDING
        // ----------------------------------------------------------
        if (capability === "embedding") {
          const models = await lmsKeys("embedding");
          if (!models.length) {
            return result(
              "No local embedding model is installed in LM Studio.",
              {
                capability,
                backend: "lmstudio",
                modelRef: null,
                recommendation:
                  "Download an embedding model in LM Studio, then call local_ai_manager again."
              }
            );
          }

          const selected = params.forceModel || models[0];

          if (action === "prepare") {
            const r = await cmd(
              "lms",
              [
                "load", selected,
                "--gpu", "auto",
                "--ttl", String(ttlSeconds)
              ],
              180000
            );

            if (!r.ok) {
              return result(
                `Failed to load embedding model ${selected}: ${r.error || r.stderr}`,
                { capability, selected, loadFailed: true }
              );
            }
          }

          const details = {
            capability,
            backend: "lmstudio",
            modelKey: selected,
            modelRef: `lmstudio/${selected}`,
            ttlSeconds,
          };

          await logDecision({ action, ...details });

          return result(
            `${action === "prepare" ? "Prepared" : "Recommend"} local embedding model ${selected}.`,
            details
          );
        }

        // ----------------------------------------------------------
        // LLM / VLM
        // ----------------------------------------------------------
        const models = await lmsKeys("llm");

        if (!models.length) {
          return result(
            "LM Studio has no downloaded LLM/VLM models.",
            {
              capability,
              backend: "lmstudio",
              modelRef: null,
              recommendation: "Download a local model with lms get, then retry."
            }
          );
        }

        let selected;

        if (params.forceModel) {
          const forced = String(params.forceModel).replace(/^lmstudio\//, "");
          if (!models.includes(forced)) {
            return result(
              `Forced model ${forced} is not in the local LM Studio catalog.`,
              {
                capability,
                modelRef: null,
                localModels: models.slice(0, 40)
              }
            );
          }
          selected = forced;
        } else {
          const heuristic = chooseModel(
            models,
            capability,
            cfg.routerModel,
            cfg.defaultModel
          );

          // Obvious categories are already strongly classified. Tiny Qwen only
          // adjudicates among installed models when there are meaningful choices.
          selected = await callTinyRouter({
            lmUrl: cfg.lmUrl,
            routerModel: cfg.routerModel,
            task,
            candidates: models,
            heuristic,
            capability,
          });
        }

        const estimateR = await cmd(
          "lms",
          [
            "load", "--estimate-only", selected,
            "--gpu", "max",
            "--context-length", String(contextLength)
          ],
          30000
        );

        const estimate = parseEstimate(
          estimateR.stdout + "\n" + estimateR.stderr
        );
        const gpuFree = await freeGpuMB();

        let gpuMode = "max";

        // Leave a practical margin for desktop/driver/Comfy/etc.
        if (
          gpuFree != null &&
          estimate.gpuMB != null &&
          estimate.gpuMB > gpuFree * 0.90
        ) {
          gpuMode = "auto";
        }

        if (action === "prepare") {
          if (!params.keepGpuModels) {
            await freeHeavyModels(cfg.routerModel);
          } else {
            await ensureRouter(cfg.routerModel);
          }

          // If the selected model is the tiny router, it is already resident.
          if (selected !== cfg.routerModel) {
            const args = [
              "load", selected,
              "--gpu", gpuMode,
              "--context-length", String(contextLength),
              "--ttl", String(ttlSeconds)
            ];

            const loadR = await cmd("lms", args, 300000);

            if (!loadR.ok) {
              // Retry with LM Studio automatic offload if a full GPU load failed.
              if (gpuMode !== "auto") {
                const retry = await cmd(
                  "lms",
                  [
                    "load", selected,
                    "--gpu", "auto",
                    "--context-length", String(contextLength),
                    "--ttl", String(ttlSeconds)
                  ],
                  300000
                );

                if (!retry.ok) {
                  return result(
                    `Selected ${selected}, but LM Studio could not load it: ${retry.error || retry.stderr}`,
                    {
                      capability,
                      selected,
                      modelRef: `lmstudio/${selected}`,
                      loadFailed: true,
                      estimate,
                      freeGpuMB: gpuFree
                    }
                  );
                }

                gpuMode = "auto";
              } else {
                return result(
                  `Selected ${selected}, but LM Studio could not load it: ${loadR.error || loadR.stderr}`,
                  {
                    capability,
                    selected,
                    modelRef: `lmstudio/${selected}`,
                    loadFailed: true,
                    estimate,
                    freeGpuMB: gpuFree
                  }
                );
              }
            }
          }
        }

        const modelRef = `lmstudio/${selected}`;

        const details = {
          capability,
          backend: "lmstudio",
          modelKey: selected,
          modelRef,
          gpuMode,
          contextLength,
          ttlSeconds,
          estimate,
          freeGpuMB: gpuFree,
          action,
          nextTool: "sessions_spawn",
          nextToolArgs: {
            runtime: "subagent",
            model: modelRef,
            context: "fork",
            task: task || "Perform the delegated local task."
          },
          instruction:
            "Delegate the actual work with sessions_spawn using the exact modelRef returned here. Do not silently substitute a different model."
        };

        await logDecision(details);

        return result(
          [
            `${action === "prepare" ? "Prepared" : "Recommended"} local ${capability} model: ${modelRef}`,
            `GPU mode: ${gpuMode}`,
            `Context: ${contextLength}`,
            `TTL: ${ttlSeconds}s`,
            action === "prepare"
              ? "NEXT: call sessions_spawn using this exact modelRef for the actual task."
              : "Call again with action=prepare before delegating."
          ].join("\n"),
          details
        );
      }
    });
  }
});
JS

(
  cd "$PLUGIN_DIR"
  npm install --omit=dev --silent
)

# ------------------------------------------------------------------
# Install/enable plugin
# ------------------------------------------------------------------
echo
echo "[4/8] Installing tool into OpenClaw..."

if "$OC" plugins inspect "$PLUGIN_ID" >/dev/null 2>&1; then
  "$OC" plugins enable "$PLUGIN_ID" --accept-capabilities >/dev/null 2>&1 || \
    "$OC" plugins enable "$PLUGIN_ID" >/dev/null 2>&1 || true
else
  "$OC" plugins install \
    --link "$PLUGIN_DIR" \
    --force \
    --accept-capabilities
fi

PLUGIN_CONFIG="$(python3 - <<PY
import json
print(json.dumps({
    "routerModel": "$ROUTER_MODEL",
    "defaultModel": "$DEFAULT_MODEL",
    "lmUrl": "$LM_URL",
    "comfyUrl": "$COMFY_URL",
    "defaultTtlSeconds": 900,
    "defaultContextLength": 16384
}))
PY
)"

"$OC" config set \
  "plugins.entries.$PLUGIN_ID.config" \
  "$PLUGIN_CONFIG" --strict-json

# ------------------------------------------------------------------
# Skill: teach OpenClaw exactly when/how to use the tool.
# ------------------------------------------------------------------
echo
echo "[5/8] Installing OpenClaw skill..."

cat > "$SKILL_DIR/SKILL.md" <<'MD'
---
name: local-ai-manager
description: Smart local fallback and GPU model swapping for LM Studio and ComfyUI
user-invocable: true
---

# Local AI Manager

Use this workflow when a hosted/cloud model is unavailable, quota-limited,
rate-limited, unsuitable, or when the user explicitly asks for local execution.

## Core rule

Do not guess which LM Studio model to use and do not manually leave several
large models occupying GPU memory.

Call `local_ai_manager` first.

For normal work:

1. Call `local_ai_manager` with:
   - `action: "prepare"`
   - `capability: "auto"` unless the capability is obvious
   - `task`: a concise but complete description of the work
2. Read the returned `modelRef`.
3. Immediately delegate the actual task with `sessions_spawn`:
   - `runtime: "subagent"`
   - `model`: EXACT returned `modelRef`
   - `context: "fork"` when prior conversation matters; otherwise `isolated`
   - `task`: the full delegated task
4. Do not silently substitute a different local model.

The manager keeps a tiny Qwen router on CPU/RAM, unloads stale heavy LM Studio
models, estimates resources, and loads the selected model onto GPU when it fits.
Heavy models get a TTL so they do not remain in GPU memory forever.

## Capability hints

- `code`: programming, debugging, shell, Flutter, QML, architecture implementation
- `reasoning`: hard analysis, root cause, algorithms, complex planning
- `vision`: understanding an existing image/screenshot
- `fast`: small/simple local work
- `general`: ordinary local chat or drafting
- `embedding`: vector/semantic embedding work
- `image`: GENERATING or editing images, not merely inspecting them

Use `capability: "auto"` if uncertain.

## Local image generation

LM Studio is not a diffusion image generator.

For image creation:

1. Prefer the normal OpenClaw `image_generate` hosted providers while a usable
   hosted provider is available, according to the user's cloud-first policy.
2. If hosted image generation fails or the request must be local:
   - call `local_ai_manager` with `action:"prepare"`, `capability:"image"`
3. If it returns `modelRef: "comfy/workflow"`:
   - call `image_generate` with `model:"comfy/workflow"`
4. If it reports ComfyUI unavailable/unconfigured:
   - explain that local image generation is not currently ready;
   - do not claim LM Studio can generate diffusion images.

## Releasing GPU memory

When a local heavy model is no longer needed and GPU RAM should be reclaimed,
call:

`local_ai_manager` with `action:"release"`.

That unloads heavy LM Studio models and restores only the tiny CPU router.
MD

# ------------------------------------------------------------------
# Local ComfyUI setup helper
# ------------------------------------------------------------------
echo
echo "[6/8] Installing local image setup helper..."

cat > "$BIN/local-ai-image-setup" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -lt 3 ]; then
  cat <<'EOF'
Usage:
  local-ai-image-setup WORKFLOW_JSON PROMPT_NODE_ID OUTPUT_NODE_ID [SEED_NODE_ID]

Example:
  local-ai-image-setup ~/ComfyUI/workflows/flux-api.json 6 9 25

Requirements:
  - ComfyUI running locally on http://127.0.0.1:8188
  - an API-format ComfyUI workflow JSON
  - prompt node id
  - output node id
EOF
  exit 2
fi

WORKFLOW="$(realpath "$1")"
PROMPT_NODE="$2"
OUTPUT_NODE="$3"
SEED_NODE="${4:-}"

if [ ! -f "$WORKFLOW" ]; then
  echo "Workflow not found: $WORKFLOW"
  exit 1
fi

if ! curl -fsS http://127.0.0.1:8188/system_stats >/dev/null 2>&1 &&
   ! curl -fsS http://127.0.0.1:8188/object_info >/dev/null 2>&1; then
  echo "ComfyUI is not answering on http://127.0.0.1:8188"
  echo "Start ComfyUI, then rerun this command."
  exit 1
fi

openclaw plugins install @openclaw/comfy-provider || true

openclaw config set plugins.entries.comfy.config.mode local
openclaw config set plugins.entries.comfy.config.baseUrl http://127.0.0.1:8188
openclaw config set plugins.entries.comfy.config.image.workflowPath "$WORKFLOW"
openclaw config set plugins.entries.comfy.config.image.promptNodeId "$PROMPT_NODE"
openclaw config set plugins.entries.comfy.config.image.outputNodeId "$OUTPUT_NODE"

if [ -n "$SEED_NODE" ]; then
  openclaw config set plugins.entries.comfy.config.image.seedNodeId "$SEED_NODE"
fi

openclaw gateway restart

echo
echo "Local ComfyUI image provider configured."
echo "Verify:"
echo "  openclaw models list --provider comfy"
echo
echo "Test:"
echo "  openclaw infer image generate --model comfy/workflow --prompt 'A small friendly robot on a desk' --json"
SH
chmod +x "$BIN/local-ai-image-setup"

# ------------------------------------------------------------------
# Status helper
# ------------------------------------------------------------------
cat > "$BIN/local-ai-status" <<'SH'
#!/usr/bin/env bash
set +e

echo
echo "================ TINY CPU ROUTER ==================="
systemctl --user --no-pager status local-ai-router.service | sed -n '1,14p'

echo
echo "================ LM STUDIO LOADED =================="
lms ps

echo
echo "================ LM STUDIO ON DISK ================="
lms ls --llm

echo
echo "================ GPU ==============================="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free,utilization.gpu \
    --format=csv,noheader
else
  echo "nvidia-smi not available"
fi

echo
echo "================ COMFYUI ==========================="
if curl -fsS http://127.0.0.1:8188/system_stats >/dev/null 2>&1 ||
   curl -fsS http://127.0.0.1:8188/object_info >/dev/null 2>&1; then
  echo "ComfyUI: reachable on :8188"
else
  echo "ComfyUI: not reachable on :8188"
fi
openclaw models list --provider comfy 2>/dev/null || true

echo
echo "================ OPENCLAW TOOL ====================="
openclaw plugins inspect anthony-local-ai-manager --runtime

echo
echo "================ RECENT DECISIONS =================="
tail -20 "$HOME/.openclaw/logs/local-ai-manager.log" 2>/dev/null || true
SH
chmod +x "$BIN/local-ai-status"

cat > "$BIN/local-ai-test" <<'SH'
#!/usr/bin/env bash
set -e

echo "Testing whether OpenClaw can see/use the local manager tool..."
openclaw agent \
  --agent main \
  --session-key "local-ai-manager-test-$(date +%s)" \
  --message 'Use the local_ai_manager tool with action=status. Then tell me which LM Studio models are loaded and whether ComfyUI is ready. Do not perform any other work.' \
  --json
SH
chmod +x "$BIN/local-ai-test"

# ------------------------------------------------------------------
# Make OpenClaw gateway wait for tiny CPU router
# ------------------------------------------------------------------
echo
echo "[7/8] Wiring startup order..."

mkdir -p "$SYSTEMD/openclaw-gateway.service.d"
cat > "$SYSTEMD/openclaw-gateway.service.d/40-local-ai-manager.conf" <<EOF
[Unit]
Wants=local-ai-router.service
After=local-ai-router.service
EOF

systemctl --user daemon-reload

# LM Studio handles heavy local model lifecycle.
"$OC" config set models.providers.lmstudio.params.preload false --strict-json || true

# Make delegation available/encouraged because the manager returns a model
# that must run in a child after the current turn has already begun.
"$OC" config set agents.defaults.subagents.delegationMode prefer || true
"$OC" config set agents.defaults.subagents.maxConcurrent 4 --strict-json || true

# ------------------------------------------------------------------
# Validate/restart
# ------------------------------------------------------------------
echo
echo "[8/8] Validating and restarting OpenClaw..."

"$OC" config validate
"$OC" gateway install --force >/dev/null 2>&1 || true
"$OC" gateway restart >/dev/null 2>&1 || \
  systemctl --user restart openclaw-gateway.service

sleep 3

PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qsF "$PROFILE_LINE" "$HOME/.profile" 2>/dev/null; then
  printf '\n%s\n' "$PROFILE_LINE" >> "$HOME/.profile"
fi

echo
echo "=============================================================="
echo " INSTALLED"
echo "=============================================================="
echo
echo "OpenClaw tool:"
echo "  local_ai_manager"
echo
echo "Tiny always-on CPU router:"
echo "  $ROUTER_MODEL"
echo
echo "Commands:"
echo "  local-ai-status"
echo "  local-ai-test"
echo "  local-ai-image-setup WORKFLOW.json PROMPT_NODE OUTPUT_NODE [SEED_NODE]"
echo
echo "Logs:"
echo "  tail -f ~/.openclaw/logs/local-ai-manager.log"
echo
echo "The normal local-task flow is now:"
echo
echo "  cloud fails"
echo "      |"
echo "      v"
echo "  local_ai_manager"
echo "      |"
echo "      +-- hard rules classify obvious task"
echo "      |"
echo "      +-- tiny Qwen adjudicates ambiguous local model choice"
echo "      |"
echo "      v"
echo "  unload stale heavy LM Studio models"
echo "      |"
echo "      v"
echo "  keep tiny router on CPU"
echo "      |"
echo "      v"
echo "  estimate selected model"
echo "      |"
echo "      v"
echo "  load best model -> GPU max (or auto if VRAM is tight)"
echo "      |"
echo "      v"
echo "  sessions_spawn(model=<selected local model>)"
echo
echo "For image generation:"
echo
echo "  hosted image_generate fails"
echo "      |"
echo "      v"
echo "  local_ai_manager(capability=image)"
echo "      |"
echo "      v"
echo "  free LM Studio GPU memory"
echo "      |"
echo "      v"
echo "  ComfyUI :8188 -> image_generate(model=comfy/workflow)"
echo
echo "Run this now:"
echo "  local-ai-status"
echo "  local-ai-test"
