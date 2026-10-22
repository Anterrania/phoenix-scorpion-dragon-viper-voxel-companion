# Device compatibility (COMPAT)

Status: built and headless-tested (COMPAT-1..8). Not yet tried on real phones, tablets or TVs.
Standing directive (Phoenix, 2026-10-17): the app detects the device, OS, hardware and capabilities and
applies matching settings by itself. It stays light, uses our own code and never overrides a manual choice.

**Privacy.** Device data stays on the device. It is never uploaded, never sent to an AI and never written
to the repo. It lives in memory, plus the user's choices in `user://settings.cfg`.

## 1. Pieces

| piece | file | owner | job |
|---|---|---|---|
| `DeviceCaps` | scripts/system/device_caps.gd | us | the caps() schema, normalize(), pure scoring and classification |
| `DeviceProfile` (autoload) | scripts/system/device_profile.gd | us now; Foxy may take it over (the schema is the contract) | detects once at start, caches, re-detects on change |
| `AutoConfig` (autoload) | scripts/system/auto_config.gd | us | maps caps to defaults and applies them without overriding manual choices; PowerData |
| `FeatureRegistry` | scripts/system/feature_registry.gd | us | features declare requirements and get disabled with a reason |
| `AutoQuality` (autoload) | scripts/render/auto_quality.gd | **Foxy** | render tiers, thermal handling, render scale, FPS governor. We only *recommend*. |
| Device & compatibility screen | scripts/admin/device_compat_screen.gd | us | read-only report with Re-detect, Reset to auto and Data saver |

## 2. Detection (DeviceProfile)

Engine APIs only, with no plugins and no dependencies. caps() always returns the full schema
(docs/specs/foxy/device_profile_caps.md). Unknown values are `-1` or `""`, and no key is ever omitted.

| area | keys | source |
|---|---|---|
| System | os, os_version, android_api, model, locale, arch, cpu_cores, cpu_name | `OS.*`, `Engine.get_architecture_name()`. The API level is mapped from the Android release because Godot doesn't expose SDK_INT. |
| Memory / storage | ram_mb, vram_mb, storage_free_mb | `OS.get_memory_info()`, `DirAccess.get_space_left()`. On phones vram_mb is an **estimate** (RAM/4, since memory is shared); on desktop it's -1. |
| Graphics | gpu, gpu_vendor, gpu_api, renderer, compute, astc, etc2 | `RenderingServer.get_video_adapter_*`, `get_current_rendering_method()`, `get_rendering_device()`, `has_os_feature()` |
| Screen | screen_w/h, dpi, screen_scale, refresh_hz, safe_area, orientation, diag_in | `DisplayServer.screen_*`, `get_display_safe_area()` |
| Form | form_factor (phone/tablet/desktop/tv), foldable | heuristics, see §2.4 |
| Input | touch, mouse, keyboard, gamepads, xr | `DisplayServer.is_touchscreen_available()`, `has_hardware_keyboard()`, `Input.get_connected_joypads()`, `XRServer` |
| Sensors / media | accelerometer, gyro, haptics, camera, mic, camera_perm, mic_perm | `Input.get_accelerometer/gyroscope` (ZERO on a phone means unknown, not no), `CameraServer`, `AudioServer.get_input_device_list()`, `OS.get_granted_permissions()` |
| Live | battery_pct, charging, power_save, thermal, network, orientation | orientation comes from the engine. The rest need the Android plugin (§6) and are -1 or "" until then. |

**2.1 When it re-detects:** at startup, on window resize, rotation or fold (`size_changed`), when a
gamepad connects (`joy_connection_changed`), when the app regains focus, and every 30 s for the live
keys only. A refresh emits `caps_changed` only if something actually changed. Consumers never poll.

**2.4 Form factor heuristic:** Godot has no form-factor API.
- Windows, macOS or Linux → desktop.
- Android or iOS without a touchscreen → tv (Android TV and Google TV have no touchscreen).
- Android with a keyboard, a mouse and a screen 11" or larger → desktop (ChromeOS, DeX).
- A 7" or larger screen → tablet. Anything else → phone.
- Foldable: a nearly square (≤ 1.35:1) Android screen of 6.8–9" (the inner display unfolded).

## 3. Capability score (pure, `DeviceCaps.score`)

The score runs from 0 to 100 and is hardware only. Battery and heat choose the performance profile
instead (see POWER_AND_DATA.md).

| part | points |
|---|---|
| RAM | <2 GB 0 · <3 5 · <4 10 · <6 18 · <8 24 · <12 30 · ≥12 35 (unknown 10) |
| CPU cores | ≤4 2 · ≤6 6 · ≤8 10 · >8 12 (unknown 4) |
| Graphics API | Vulkan Forward+ 20 · Vulkan Mobile 15 · GLES3 5 · none 0 |
| GPU family | Adreno 7xx/8xx 15 · Adreno 6xx 8 · Immortalis 15 · Mali-G7x 12 · G6x 8 · G5x 4 · Xclipse 12 · PowerVR 2 · Apple 20 · NVIDIA/AMD 25 · Intel 8 · software 0 · unknown 5 |
| Display | refresh ≥ 119 Hz +5 · ASTC +3 |

The class is **low** below 30, **mid** below 55, **high** below 80, and **ultra** otherwise. Two RAM caps
apply: under 3 GB is always low, and under 6 GB is at most high.

## 4. Mapping tables (`AutoConfig.derive`, pure)

| class | AutoQuality tier | legacy Settings quality | companion AI Hz | sim Hz | script ms/frame | streaming threads | sync Hz | view hint m | particles |
|---|---|---|---|---|---|---|---|---|---|
| low | low | 0 | 6 | 1 | 1 | 1 | 5 | 256 | 200 |
| mid | med | 1 | 10 | 2 | 2 | 2 | 10 | 512 | 600 |
| high | high | 2 | 15 | 4 | 3 | 3 | 15 | 768 | 1500 |
| ultra | ultra | 2 | 20 | 4 | 4 | 4 | 20 | 1024 | 3000 |

The budgets above are for **balanced**. Battery saver multiplies them by 0.5 and performance by 1.5, with a
minimum of 1. Streaming threads are capped at cores − 1. The fps hint is 30 on battery saver, 60 on
balanced (30 on low devices), and the display refresh rate (60–120) on performance.

| form factor | UI scale (text = icons) | input scheme | default profile |
|---|---|---|---|
| phone | 1.0 (compact, the smallest usable) | touch, or gamepad when one is connected | balanced |
| tablet / foldable | 1.15 | touch / gamepad | balanced |
| desktop (dev, ChromeOS) | 1.25 | keyboard + mouse | performance if high+ |
| tv | 1.6 (10-foot) | gamepad / D-pad | performance if high+ |
| any with an XR runtime | — | xr | — |

Input remaps are **data only** (`AutoConfig.input_profile(scheme)`), and Foxy's HUD consumes them. The one
engine change is additive: on gamepad, stick and A-button events are added to the existing `move_*` and
`jump` actions. Keyboard bindings are kept.

**Feature registry** (`FeatureRegistry`). Built in: voice chat, voice morph, camera capture, tilt to
look, haptics, compute effects (Vulkan, 3 GB+), hi-res textures (6 GB+), clip capture, live AI, music
streams, broadcast and XR mode. Other systems call `FeatureRegistry.register(id, label, reqs)`.
**Unknown never disables.** Only a definite "no" does, and it always comes with a reason, for example
"Needs Vulkan compute (this device runs OpenGL ES 3)".

## 5. Override rules

1. User choices live in `[compat]`: tier, ui_scale, input_scheme, perf_profile and data_saver. The value
   `"auto"` means "follow the device". Any other value always wins.
2. Settings owned by other systems (legacy `graphics/quality`, and the phone branch's
   `display/text_scale` and `icon_scale`) are written only while they still hold the value we wrote last
   time (`compat/auto_<section>_<key>`), or the untouched default. Any other value is a manual choice, and
   it is kept until **Reset to auto**.
3. AutoQuality: when Foxy's governor reports `get_mode() != "auto"`, we leave it alone. In auto mode we
   call `recommend_tier()`, so we never switch it to manual.
4. Background pause always applies, because it is not a quality choice.
5. Headless (CI and tests) works out the plan but applies nothing.
6. **Reset to auto** clears every choice, calls `AutoQuality.set_tier("auto")`, re-detects and re-applies.

## 6. Gaps: things Godot can't read on Android without a plugin

These are -1 or "" today. The optional `ViperDevice` Android plugin hook is ready in DeviceProfile (§2).
- battery %, charging, power-save mode (BatteryManager, PowerManager)
- thermal status 0..6 (PowerManager.getCurrentThermalStatus, API 29+)
- network type wifi/cell/none (ConnectivityManager)
- the real SDK_INT (we map the release name), true VRAM, and whether a vibrator exists
- camera presence before the permission is granted (CameraServer lists nothing until then)
- foldable posture and hinge (Jetpack WindowManager): the aspect-ratio heuristic stands in
- Android TV "leanback" and ChromeOS flags: heuristics stand in

## 7. Platform matrix

| platform | detected as | status |
|---|---|---|
| Android phone | phone | primary target, compact UI, touch |
| Android tablet | tablet | supported, 1.15× UI |
| Android foldable | tablet + foldable | supported; re-detects on fold/unfold (size change) |
| ChromeOS / DeX | desktop | supported via keyboard + mouse heuristic |
| Android TV / Google TV | tv | gamepad / D-pad, 1.6× UI. Needs a leanback manifest entry before store release. |
| Quest-style XR | xr scheme | **future**: OpenXR is not in the export yet; the feature shows as off with a reason |
| Desktop (Linux/Windows/macOS) | desktop | dev builds |

Tests use fake caps for low, mid, high and ultra phones, a tablet, a foldable, a TV, a Chromebook and a
desktop (tests/compat_tests.gd).
