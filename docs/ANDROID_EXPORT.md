# Android Export Pipeline (plan, untested)

## Pinned versions (verified 2026-10-13 against GitHub releases)
- **Godot 4.7.2-stable** (official, `Godot_v4.7.2-stable_linux.x86_64.zip`; editor reports `v4.7.2.stable.official.ed1daf0bf`). Export templates must be **4.7.2-stable** too.
- **godot_voxel GDExtension v1.7x** (`GodotVoxelExtension.zip`, released 2026-08-20, "Voxel Tools GDExtension 1.7 for Godot 4.5+"; its `voxel.gdextension` declares `compatibility_minimum = "4.4.1"`). Unzip at the project root → `addons/zylann.voxel/`.
- Ships Android libs: `libvoxel.android.editor.arm64.so` (debug) and `libvoxel.android.template_release.arm64.so` (release), plus x86_64 variants for emulators. Binaries are gitignored (`addons/zylann.voxel/bin/`). Re-download them from the release; don't commit them.
- Alternative: the custom module build "Godot 4.7.2 + Voxel Tools 1.7" (tag v1.7) is also available. We use the GDExtension so that stock Godot and stock export templates work. Upstream warns that the extension has had less testing than module builds.

1. Install Godot 4.x (pinned: 4.7.2-stable) and the **exactly matching** export templates.
2. Install OpenJDK 17 and the Android SDK (platform-tools, build-tools, platform 34). Set the paths in Editor Settings → Export → Android.
3. Install godot_voxel GDExtension for that Godot version. Confirm the `.gdextension` file lists `android.arm64` libraries. If it doesn't, build the custom engine + templates with the module.
4. Project → Install Android Build Template (Gradle build).
5. Export preset: arm64-v8a only (smaller APK), Mobile renderer, ETC2/ASTC, debug keystore first.
6. Device test: chunk view distance, FPS, memory. Then release keystore and AAB for Play.
7. CI later: headless `godot --export-release` in a GitHub Action with cached templates.
