# On-device companion AI (LocalLLM)

> **Status: phase 1 (LAI-1..9).** Implemented, with headless tests and a debug APK build. **Not yet run on a real phone.** The checklist at the bottom lists what still needs a device.

Companions (Foxy Ani, Aaliyah, Circuit Nova, …) reply through a small language model that runs **on the phone's CPU**. It needs no API key and no server, and after the one-time model download it works offline. The key-based live path (any OpenAI-compatible endpoint) stays optional. Canned persona replies are only the last fallback.

## Reply order (AgentBrain.chat)

1. **Live** (`Settings.live_ai()`): only when the player chose live mode or a build key exists, and a key and a valid endpoint are set. If a live call fails, the on-device model answers. Only if that is unavailable does a canned reply come next.
2. **On-device** (`Settings.local_ai()`): this is the **default mode** (`llm.mode = "local"`). It runs when the model is downloaded and the phone is not hot or in the background.
3. **Canned persona replies**: used when the player explicitly picked "Offline replies", or while the model is downloading or paused, or on any engine error.

Every `chat()` still ends in exactly **one** `reply_ready` (CHAT-1 contract). `reply_partial(id, text)` streams the on-device reply to the chat status line, with tool-call markup hidden.

**Migration:** older installs saved `mode = "canned"` as the default without `mode_set`. That now counts as `local`. An explicit Offline choice (`mode_set`) is respected.

## Pieces

| File | Role |
|---|---|
| `android/plugins/viper_llm/` | Self-written Godot 4 Android plugin (v2) **ViperLLM**: Kotlin plus JNI plus a C++ engine (`viper_llm_engine.cpp`) over **llama.cpp**. Covers: model load, streamed generation, KV-cache prefix reuse, cancel, thread changes, and a resumable HTTPS download with SHA-256 check. arm64-v8a only. |
| `android/plugins/viper_llm/fetch_llama.sh` | Fetches llama.cpp at the pinned tag **b12017** (commit `5047748f114564fcf271e6a648f60e2d2eae6264`) into gitignored `third_party/`. The tag and commit are verified. **No llama.cpp source is committed.** |
| `addons/viper_llm/` | Editor export plugin: adds `bin/viper-llm-release.aar` (built by `build.sh`, gitignored) to Android exports. |
| `scripts/ai/local_llm.gd` | **LocalLLM** autoload. Handles the backend (plugin or mock), model catalog, download state machine, lazy load and idle unload, request queue, and the thermal/power policy. |
| `scripts/ai/llm_mock_backend.gd` | Same API and signals as the plugin. Used on desktop, CI and in tests, so headless runs never need native code or a model. |
| `scripts/ai/llm_prompt.gd` | ChatML prompt builder (Qwen2.5 format). Covers: persona, style, memory facts, tools in Qwen's own `<tools>` / `<tool_call>` format, history trimmed to a token budget, tool-call parser, and streaming filter. |
| `data/ai/local_models.json` | Model catalog: URL, SHA-256, size, license, minimum RAM. |
| `tools/llm/desktop_smoke/` | Desktop build of the same C++ engine. Runs a prompt twice to check output, speed and KV reuse. |

## Model

| | Default | Optional |
|---|---|---|
| Model | **Qwen2.5-0.5B-Instruct**, GGUF Q4_0 | Qwen2.5-1.5B-Instruct, GGUF Q4_0 |
| License | **Apache-2.0** (Qwen/Alibaba) | Apache-2.0 |
| Download | 428,730,208 B (409 MB) | 1,066,227,232 B (1017 MB) |
| SHA-256 | `7671c0c3…daf6ed` | `dcd819ff…bfdb` |
| Min RAM | 2 GB | 5.5 GB |
| Source | huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF | huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF |

**Why Q4_0:** llama.cpp repacks Q4_0 for ARM dotprod and i8mm on load, which makes it the fastest 4-bit format on phones.

**Download:** the file is **not in the APK**. On first run, LocalLLM downloads it in the background **on Wi-Fi only**. It goes to `user://models/`. Interrupted downloads resume through a `.part` file and an HTTP Range request. The download pauses when the network becomes metered. The size and SHA-256 are checked before the rename, and then a `<file>.ok` marker is written. For mobile data, the player taps Settings › Companion AI › Download now twice. The model can be deleted from the same screen.

## Prompt and tools

- The **system block** holds the persona prompt and style, an "in-game companion, 1–3 short sentences" instruction, the player's name, up to 12 memory facts, and the tool list. It stays identical between turns, so the engine **reuses its KV cache** and only processes the new turn. On the desktop smoke run, a 520-token prompt went from 2486 ms to 17 ms on the second run.
- **Volatile context** goes on the latest user message as `[You are at …. Player is at …. You just did: …. Idea for your reply: …]`. This covers positions and what the brain cell already did or suggested.
- **History** goes newest first until the budget is used: n_ctx 2048, minus max tokens, minus a margin. If the engine still reports `context_full`, the turn is retried with 55% of the budget, up to 2 times.
- **Tools** are the companion's persona tools that it actually implements (`tool_*` methods), plus `remember`. Coordinates are optional for the model. AgentBrain fills them with a point 3 m in front of the companion; `move_to` goes to the player. Bad enum values or radius values are clamped to safe defaults.
- **Tool calls run through `AgentBrain.dispatch_tool`**, so the e-stop, persona permissions and **Tiers.can / LandGate** checks all apply. The limit is 3 per turn. A **tool-intent guard** (`LlmPrompt.plausible`) drops a call when the player's message has none of that tool's trigger words. For example, on the desktop, 0.5B answered "build me a fire altar" by calling `follow`.
- **Brain cells run first**, as before: exact commands stay instant and deterministic. The model is told what the cell did, so it doesn't repeat the action.

## Power and thermal (PowerData)

| Condition | Effect |
|---|---|
| thermal ≥ 4 (CRITICAL) | **Paused**: the running reply is cancelled and chat uses persona replies until the phone cools. |
| App in background / power mode `background` | Paused (same as above). |
| thermal ≥ 3 (SEVERE), power mode `saver`, or battery ≤ 15% and not charging | **Throttled**: 2 threads and 60% of the reply length. |
| Normal | 4 threads on phones with 6+ cores (big cores), otherwise 2. |
| 5 minutes idle | Model unloaded (RAM returned). It loads again on the next chat, or when the chat panel opens (`warm_up`). |
| RAM below the model's minimum | `unsupported_ram`: persona replies. |

LocalLLM listens to `DeviceProfile.caps_changed` and `AutoConfig.power_changed`, so it never polls. Generation runs on one worker thread at background priority. A 120 s watchdog cancels a stuck generation.

## Native build

- llama.cpp is built with `GGML_BACKEND_DL=ON` and `GGML_CPU_ALL_VARIANTS=ON`. The engine loads the best CPU variant by soname, in this order: `armv8.6_1` (i8mm), `armv8.2_2` (dotprod and fp16), `armv8.0_1` (any arm64). It falls back to scanning the native library directory.
- Only these 3 of the 7 variants are packaged (see `build.gradle.kts`), to keep the APK small. OpenMP, KleidiAI and llamafile are off. Libraries are stripped and use 16 KB page alignment.
- Build steps: `android/plugins/viper_llm/build.sh` needs JDK 17, Android SDK, **NDK 27.2.12479018** and **CMake 3.22.1**. It produces `addons/viper_llm/bin/viper-llm-release.aar`. CI does the same and checks that the APK has `libviper_llm.so`, the plugin metadata and the plugin class.
- Desktop smoke test: `tools/llm/desktop_smoke/run.sh <model.gguf>`.

## Size and speed

- **AAR:** 3.19 MB. **Native libraries** (arm64): about 7.9 MB uncompressed: llama 3.4 MB, c++_shared 1.3 MB, ggml-base 0.8 MB, 3 CPU variants at 0.78 MB each, glue 56 KB. **Debug APK, measured on the box:** 47,397,172 B without ViperLLM, 50,364,367 B with it, so **+2.97 MB (+6.3%)**. The APK keeps `extractNativeLibs=true`, so the libraries are compressed in the APK and take about 7.9 MB once installed. The model download is separate (409 MB).
- **Desktop (8-core Xeon, 4 threads, measured):**
  - 0.5B: prompt about 1650 tok/s, generation about 63 tok/s.
  - 1.5B: prompt about 470 tok/s, generation about 32 tok/s.
- **Mid-range phone (Cortex-A78 class, 4 threads), estimated, not measured:**
  - 0.5B: prompt 150–300 tok/s, generation 15–30 tok/s. A typical 30-token reply takes about 1–2 s. The first turn adds 2–4 s to process the roughly 600-token system block; later turns reuse it.
  - 1.5B: generation 8–12 tok/s, with about 3x the first-turn delay.
- **RAM:** the model is memory-mapped. Working set is about 450 MB (0.5B) or 1.1 GB (1.5B), plus KV cache: 24 MB (0.5B) or 57 MB (1.5B) at n_ctx 2048.

## Quality notes (desktop smoke, same prompt format)

- **0.5B:** good short in-character small talk, but **weak at choosing tools** (missed "build a fire altar" and "remember …"). Brain cells and the intent guard cover common commands.
- **1.5B:** correct tool calls (`spawn_structure fire_altar`, `remember`, `follow`) but terse text. It is the better pick on phones with 6 GB+ RAM if the speed is acceptable.

## Tests

`tests/local_ai_tests.gd` (around 60 checks, all headless with the mock) covers:
- prompt layout, cache stability, budget and parsing (including unclosed tags, bare JSON and broken JSON);
- the tool-intent guard and argument filling;
- mode migration and statuses;
- the download state machine (Wi-Fi only, bad checksum, `.ok` marker);
- lazy load and streaming;
- thermal throttle and pause, background cancel, RAM gate, idle unload;
- the AgentBrain local path: one reply, streaming, memory, tools through dispatch_tool/LandGate, `context_full` retry, engine error → canned, live failure → on-device;
- the docs and tracker.

## Licenses

- **llama.cpp / ggml:** MIT (Georgi Gerganov and contributors). It is compiled into the AAR and its license notice ships with it (`third_party/llama.cpp/LICENSE`, fetched at build time).
- **Qwen2.5-0.5B/1.5B-Instruct weights:** Apache-2.0. They are downloaded at runtime and not bundled.
- **ViperLLM glue** (Kotlin, JNI, engine, GDScript): self-written for this project. No LGPL code is used.

## Needs a real phone (phase 2)

1. Plugin loads, and `init_backend()` picks the right CPU variant (check `LocalLLM.summary()["cpu"]`).
2. Wi-Fi download, resume after killing the app, mobile-data confirmation, and free-space check.
3. Measured speed (prompt and generation tok/s), first-reply latency, and RAM with the 0.5B and 1.5B models.
4. Thermal: a long chat session on a warm phone. Check that the pause at CRITICAL and the throttle at SEVERE behave.
5. Background and resume, plus idle unload and reload.
6. Signals arriving from worker threads (they connect with CONNECT_DEFERRED).

## Tool-result follow-up (CHAT-16)
After tools run, the companion answers about what actually happened (built, refused, waiting for approval):
1. **On-device first:** one extra short generation (max 96 tokens) with the results as Qwen `<tool_response>` blocks
   (`LlmPrompt.followup`). To save battery it only runs when the results need explaining: the model said nothing,
   a tool failed, or a tool has news (e.g. `heaven_edit` "waiting for approval"). The prompt prefix is unchanged,
   so the KV cache is reused. Tool calls in the follow-up are ignored (tools run once per turn).
2. **Live (with a key):** a second request with the assistant `tool_calls` and one `tool` message per result,
   `tool_choice: "none"`. A failed follow-up never raises `request_failed`; the turn already worked.
3. **Canned:** if neither answers, the model's own line plus the tool's result line (`say`), or the old
   `*tool*` / `(couldn't …)` summary.
Switch: Settings `llm/tool_followup` (default on). What the model sees per result: `AgentBrain.result_for_model`
(tool, ok, error, state, say, note; no internals).

**Phase 2 ideas:** GPU (Vulkan/OpenCL) backends, grammar-constrained tool JSON for the 0.5B model, and an automatic 1.5B pick on 8 GB+ phones.
