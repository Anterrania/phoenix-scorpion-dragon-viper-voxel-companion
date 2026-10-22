# Spec for Foxy: Power & data on the client

The client governor is yours: AutoQuality thermal throttling, FPS caps, render scale, client streaming and
LOD, and the idle or screen-off frame rate. AutoConfig gives you inputs; it never drives the renderer.

## Signals (connect once, never poll)
- `AutoConfig.power_changed(mode, reasons)`, where mode is full · balanced-saver · saver · background
- `AutoConfig.budgets_changed(budgets)`
- `AutoConfig.applied(plan)`: the whole plan (tier, perf_profile, power_mode, data_mode, budgets)
- `DeviceProfile.caps_changed(caps)`: thermal 0..6, battery_pct, charging, power_save, network

## Calls into AutoQuality (has_method-guarded)
- `set_power_profile("battery_saver" | "balanced" | "performance")`
- `set_fps_cap_hint(fps)`: 30 on battery saver, 60 on balanced (30 on low devices), refresh rate (≤ 120) on performance, and 1 in background

## Please honour
| input | client action |
|---|---|
| power_mode saver | 30 fps cap, render scale ≤ 0.8, no glow or SSAO, lower LOD distance |
| thermal ≥ 3 | step down one tier immediately; ≥ 5 go to the lowest tier and 30 fps |
| power_mode background | stop rendering (`OS.low_processor_usage_mode = true`); audio may keep playing if music is on |
| idle 60 s with no input | drop to 30 fps, and 10 fps on a static menu |
| budgets.view_distance_hint / particle_budget / streaming_threads | ceilings for your knobs |
| budgets.thumbnails_only, autoplay=false | feed and clip UI: thumbnails, tap to play |
| budgets.defer_large_downloads | show "Waiting for Wi-Fi" on big downloads, with a "Download now" override |
| budgets.prefetch | prefetch the next region's meshes and textures only when true |

Settings > Device & compatibility > Battery & data (ours) shows the mode, the reason, data used this
session, and Data saver Auto/On/Off.
