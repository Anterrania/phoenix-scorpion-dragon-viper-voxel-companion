# Platforms & Testing — PLAN
Test device: **one Motorola 5G Android phone** (no PC dev loop is assumed). No APK has been built yet.

## 1. Sideload a debug APK
1. CI builds `phoenix-debug.apk` (signed with a debug keystore) → download the artifact on the phone from the GitHub Actions run page.
2. Settings → Apps → Special app access → Install unknown apps → allow the browser/Files app.
3. Open the APK and install. Updating requires the same signing key; uninstall first if the keys change.
4. Logs: no adb without a PC. Use an in-app log console (planned debug overlay) or Wireless debugging + adb from Termux (below).

## 2. CI builds (GitHub Actions)
`.github/workflows/export.yml` (DRAFT, manual trigger only). It uses a Godot headless container plus export templates for each preset: Android (debug APK), Linux, Windows, macOS (unsigned zip), Web (HTML5), iOS (Xcode project only; signing needs a Mac + Apple account). The Zylann voxel module needs a **custom Godot build** or the GDExtension version. CI must use a matching editor and templates. Open item.

## 3. Web build on the phone: threading and browser isolation
**Problem.** Godot's threaded web export uses WebAssembly threads, which need `SharedArrayBuffer`. Browsers only enable that when the page is **cross-origin isolated**, which means the server must send:
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```
GitHub Pages and most simple hosts can't set these headers, so a threaded build fails to start there ("SharedArrayBuffer is not defined" / a cross-origin isolation error).

**Workarounds (in order of preference):**
1. **Single-threaded export** (the Web preset already sets `variant/thread_support=false`; Godot 4.3+). No special headers are needed, so it runs on GitHub Pages and in Chrome on the Motorola. The cost is that audio and any worker-thread work run on the main thread.
2. **Host that sets the headers** (Netlify/Cloudflare Pages `_headers` file, itch.io's "SharedArrayBuffer support" checkbox) for the threaded variant.
3. **`coi-serviceworker` shim**: a service worker that injects the headers. It works on Pages but reloads the page once and isn't supported everywhere.
4. Godot's web export option "Ensure Cross Origin Isolation Headers" (PWA service worker) is similar to #3.

**Voxel plugin on web: may not work.** godot_voxel relies on threads for meshing and generation. The GDExtension release (v1.7x) may not ship a web binary at all, and GDExtension on web also needs `variant/extensions_support=true` (set) plus a matching dlink build. Expect any of these: (a) no web build of the extension, so VoxelTerrain is missing; (b) it runs single-threaded and is very slow; (c) it only works with threads + COOP/COEP. **Fallback plan:** `scripts/world.gd` already checks `ClassDB.class_exists("VoxelTerrain")`. On web we'd show a static/pre-baked mesh demo realm (menus, chat with companions, MobiGlass UI) instead of live voxel editing. Native Android stays the main target.
- Check: after CI, open the `*.gdextension` file printed in the log and confirm whether it lists `web.*` entries.

## 4. Termux notes
- `pkg install android-tools` → `adb pair`/`adb connect` to the phone's own Wireless debugging to get `adb logcat` on-device.
- Can host the web build locally: `python -m http.server` (no COOP/COEP). Running the Godot editor itself in Termux isn't practical. The Godot Android editor app is an option for small edits.

## 5. Cloud emulators / device farms
Firebase Test Lab (Robo test, free tier), BrowserStack/LambdaTest App Live, AWS Device Farm. Use them for crash checks across other Android versions and GPUs.
