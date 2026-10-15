# Setup Guide

## 1. Godot with voxel tools
`godot_voxel` (Zylann) is a C++ module, so stock Godot does NOT include `VoxelTerrain`. Options:
- **Recommended:** download a prebuilt Godot 4.x editor that bundles the voxel module from the godot_voxel GitHub releases / CI artifacts (https://github.com/Zylann/godot_voxel). You also need the matching **Android export templates** built with the module.
- **GDExtension:** install the godot_voxel GDExtension build into `addons/zylann.voxel/` and use stock Godot 4.3+. Android libraries must be included for arm64.
- **Build from source:** clone godot + godot_voxel into `modules/voxel`, `scons platform=linuxbsd target=editor`, then `scons platform=android target=template_release arch=arm64` for export templates.

Open the project: `godot -e --path .`. If you see "godot_voxel not found", the build lacks the module.

## 2. Android toolchain
- JDK 17 (`sudo apt install openjdk-17-jdk`)
- Android SDK command-line tools; then:
  `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest" "ndk;23.2.8568313"`
- Godot: Editor Settings > Export > Android: set Java SDK path and Android SDK path.
- Debug keystore: `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999` (keep outside the repo).
- Release keystore: set via Editor Settings or env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`. Never commit it.

## 3. Build
- Debug APK: `godot --headless --export-debug "Android" build/phoenix-voxel.apk`
- Install: `adb install -r build/phoenix-voxel.apk`
- Release AAB: enable `gradle_build/use_gradle_build`, export format AAB, `--export-release`.
- On-device builds: GABE (Godot Android Build Environment) can be used instead of a PC.

## 4. LLM endpoint
In-game Settings (or edit `user://settings.cfg`): `endpoint`, `model`, `api_key`. Any OpenAI-compatible chat-completions API with tool calling works. A Grok/xAI endpoint is configurable: `https://api.x.ai/v1/chat/completions`. Without a key, realms come from presets and companions reply with a setup hint.
