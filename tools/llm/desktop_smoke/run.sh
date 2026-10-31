#!/usr/bin/env bash
# Desktop smoke test: builds the ViperLLM engine against the pinned llama.cpp and runs one prompt.
# Usage: tools/llm/desktop_smoke/run.sh <model.gguf> [prompt.txt]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../.."
"$root/android/plugins/viper_llm/fetch_llama.sh"
llama="$root/android/plugins/viper_llm/third_party/llama.cpp"
cmake -S "$here" -B "$here/build" -DLLAMA_DIR="$llama" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$here/build" -j"$(nproc)" --target viper_llm_smoke >/dev/null
prompt="${2:-$here/prompt_foxy.txt}"
"$here/build/viper_llm_smoke" "$1" "$prompt" 120 "$(nproc)"
