#!/usr/bin/env bash
# Build the ViperLLM AAR (Kotlin + arm64 native llama.cpp) and copy it into the Godot editor plugin.
# Needs JDK 17 and an Android SDK with platforms;android-34, ndk;27.2.12479018, cmake;3.22.1.
set -euo pipefail
cd "$(dirname "$0")"
./fetch_llama.sh
# MIT notice for llama.cpp/ggml ships inside the APK (assets/licenses/), generated each build (gitignored).
mkdir -p src/main/assets/licenses
cp third_party/llama.cpp/LICENSE src/main/assets/licenses/llama.cpp-MIT-LICENSE.txt
./gradlew --no-daemon -q assembleRelease
mkdir -p ../../../addons/viper_llm/bin
cp build/outputs/aar/viper-llm-release.aar ../../../addons/viper_llm/bin/viper-llm-release.aar
ls -l ../../../addons/viper_llm/bin/viper-llm-release.aar
unzip -l ../../../addons/viper_llm/bin/viper-llm-release.aar | grep '\.so$' || true
