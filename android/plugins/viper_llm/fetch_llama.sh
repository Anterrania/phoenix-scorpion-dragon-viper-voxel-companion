#!/usr/bin/env bash
# Fetch the pinned llama.cpp (MIT, https://github.com/ggml-org/llama.cpp) into third_party/ (gitignored).
# Only the source is fetched at build time; nothing from it is committed to this repo.
set -euo pipefail
cd "$(dirname "$0")"
TAG="b12017"
SHA="5047748f114564fcf271e6a648f60e2d2eae6264"
dst=third_party/llama.cpp
if [ -f "$dst/.viper_pin" ] && [ "$(cat "$dst/.viper_pin")" = "$SHA" ]; then exit 0; fi
rm -rf "$dst"; mkdir -p third_party
git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp "$dst"
got="$(git -C "$dst" rev-parse HEAD)"
if [ "$got" != "$SHA" ]; then echo "llama.cpp pin mismatch: $got != $SHA" >&2; exit 1; fi
echo "$SHA" > "$dst/.viper_pin"
