# Spec for Foxy: DeviceProfile caps() schema (agreed 2026-10-17, schema 1)

`DeviceProfile.caps() -> Dictionary` always has **every** key. Unknown values are -1 or "".
Re-read on `caps_changed`, and never poll. `redetect()` runs a full detection and emits `caps_changed`.
The live keys (battery_pct, charging, power_save, thermal, network, orientation) refresh every 30 s and on
app focus. Pass anything you store or receive through `DeviceCaps.normalize()` so older caps still work,
and check `DeviceCaps.is_newer(c)` (use known keys only).

| key | type | values |
|---|---|---|
| schema | int | 1 |
| source | String | engine · engine+plugin · fake |
| os, os_version, model, locale, arch, cpu_name | String | "" if unknown |
| android_api, cpu_cores, ram_mb, vram_mb (estimate), storage_free_mb | int | -1 if unknown |
| gpu, gpu_vendor, gpu_api | String | |
| renderer | String | mobile · forward_plus · gl_compatibility · dummy |
| compute | String | vulkan · gles3 · none |
| astc, etc2 | bool | |
| screen_w, screen_h, dpi | int | |
| screen_scale, refresh_hz, diag_in | float | -1.0 if unknown |
| safe_area | Rect2i | Rect2i() if unknown |
| orientation | String | portrait · landscape · "" |
| form_factor | String | phone · tablet · desktop · tv |
| foldable, touch, mouse, keyboard, xr, haptics | bool | |
| gamepads | int | count |
| accelerometer, gyro, camera, mic, power_save, charging | int | -1 unknown · 0 no · 1 yes |
| camera_perm, mic_perm | String | granted · ask · n/a · "" |
| battery_pct | int | 0..100 or -1 |
| thermal | int | Android thermal status 0..6, or -1 |
| network | String | wifi · cell · none · "" |
| capability_score | int | 0..100 |
| capability_class | String | low · mid · high · ultra |
| headless | bool | |
| detected_at | int | unix seconds |

`charging` is an additive schema-1 key, added for PowerData (charger + Wi-Fi means full quality).
Tests: `DeviceProfile.set_fake(dict)` swaps in a fake profile; `set_fake(null)` switches back.
