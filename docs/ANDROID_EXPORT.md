# Android Export Pipeline (plan, untested)
1. Install Godot 4.x (pin one version, e.g. 4.3) and the **exactly matching** export templates.
2. Install OpenJDK 17 and the Android SDK (platform-tools, build-tools, platform 34). Set the paths in Editor Settings → Export → Android.
3. Install godot_voxel GDExtension for that Godot version. Confirm the `.gdextension` file lists `android.arm64` libraries. If it doesn't, build the custom engine + templates with the module.
4. Project → Install Android Build Template (Gradle build).
5. Export preset: arm64-v8a only (smaller APK), Mobile renderer, ETC2/ASTC, debug keystore first.
6. Device test: chunk view distance, FPS, memory. Then release keystore and AAB for Play.
7. CI later: headless `godot --export-release` in a GitHub Action with cached templates.
