# Platforms & Testing — PLAN
Test device: **one Motorola 5G Android phone** (no PC dev loop is assumed). No APK has been built yet.

## 1. Sideload a debug APK
1. CI builds `phoenix-debug.apk` (signed with a debug keystore) → download the artifact on the phone from the GitHub Actions run page.
2. Settings → Apps → Special app access → Install unknown apps → allow the browser/Files app.
3. Open the APK and install. Updating requires the same signing key; uninstall first if the keys change.
4. Logs: no adb without a PC. Use an in-app log console (planned debug overlay) or Wireless debugging + adb from Termux (below).

## 2. CI builds (GitHub Actions)
`.github/workflows/export.yml` (DRAFT, manual trigger only). It uses a Godot headless container plus export templates for each preset: Android (debug APK), Linux, Windows, macOS (unsigned zip), Web (HTML5), iOS (Xcode project only; signing needs a Mac + Apple account). The Zylann voxel module needs a **custom Godot build** or the GDExtension version. CI must use a matching editor and templates. Open item.

## 3. Web build on the phone
Godot 4 web export needs SharedArrayBuffer → COOP/COEP headers (or Godot 4.3+ single-threaded export). GitHub Pages doesn't set the headers, so use the single-threaded build or the `coi-serviceworker` shim. Open it in Chrome on the Motorola. Expect lower performance than native, and the voxel extension may not support web; verify.

## 4. Termux notes
- `pkg install android-tools` → `adb pair`/`adb connect` to the phone's own Wireless debugging to get `adb logcat` on-device.
- Can host the web build locally: `python -m http.server` (no COOP/COEP). Running the Godot editor itself in Termux isn't practical. The Godot Android editor app is an option for small edits.

## 5. Cloud emulators / device farms
Firebase Test Lab (Robo test, free tier), BrowserStack/LambdaTest App Live, AWS Device Farm. Use them for crash checks across other Android versions and GPUs.
