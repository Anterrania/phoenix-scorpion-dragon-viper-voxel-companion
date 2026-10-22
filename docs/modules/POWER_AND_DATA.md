# Power & data (COMPAT-PWR)

Status: built and headless-tested. The battery, thermal and network inputs need the Android plugin (DEVICE_COMPAT.md §6).
Standing directive (Phoenix): use as little battery and data as possible, automatically, while keeping the app smooth.

## 1. PowerData policy (`AutoConfig.power_of`, pure)

| mode | when | effect |
|---|---|---|
| **balanced-saver** (default) | nothing below applies | balanced budgets, standard media |
| **saver** | battery < 30% and not charging, phone power saver on, thermal ≥ 3 (Android SEVERE), or on mobile data | battery-saver budgets (×0.5): companion AI, survival/disease/sim tick, script VM time, streaming threads, sync/send rate; small images and thumbnails; low media bitrate; 30 fps hint |
| **full** | charging **and** on Wi-Fi | full quality, prefetch allowed |
| **background** | app paused (NOTIFICATION_APPLICATION_PAUSED) | sims, scripts, streaming and sync at 0; 60 s keepalive only; Dormancy puts everything to sleep |

Every mode comes with plain-language reasons, which the Settings screen shows. A manual performance profile
wins, except in background, which always pauses.

## 2. Budgets (`AutoConfig.budget(key)`, re-read on `budgets_changed`)

companion_ai_hz · sim_tick_hz · script_budget_ms · streaming_threads · sync_send_hz · view_distance_hint ·
particle_budget · fps_cap_hint · media_audio_kbps · media_video_kbps · image_px · thumb_px · autoplay ·
thumbnails_only · prefetch · defer_large_downloads · keepalive_s. See DEVICE_COMPAT.md §4 for the tables.

## 3. Data saver

The preference is **Auto / On / Off** (Settings > Device & compatibility > Battery & data), and the user's
choice wins. Auto turns it on when on mobile data or in saver mode.

| Net mode | audio kbps | video kbps | image px | thumb px | autoplay | big downloads |
|---|---|---|---|---|---|---|
| full | 256 | 4000 | 2048 | 512 | yes | yes, plus prefetch |
| normal | 128 | 1500 | 1280 | 320 | yes | yes |
| saver | 64 | 400 | 640 | 160 | **no**, thumbnails only | > 5 MB waits for Wi-Fi |

## 4. Net (scripts/system/net.gd)

- `Net.set_data_mode(m)`, which AutoConfig sets. Readers: `media_kbps`, `image_px`, `thumbnails_only`,
  `autoplay_ok`, `prefetch_ok`, `large_download_ok(bytes)`.
- `pack(messages)` / `unpack(frame)` batch messages into one frame, deflate-compressed with
  `PackedByteArray.compress` when it helps. Frames under 128 B stay raw.
- `delta(prev, cur)` / `apply_delta(base, d)` send only the state keys that changed.
- HTTP cache: `request_headers(url)` adds If-None-Match and If-Modified-Since, and `on_response(...)` returns
  the cached body on a 304 and respects `no-store`. It's wired into our GET helpers: MusicRadio station
  fetch and SoundCloudSource. The LLM POSTs aren't cached, but they are counted.
- A session counter (`count`, `session_mb`) feeds the "Data this session" line. It stays on the device.

## 5. Dormancy (scripts/system/dormancy.gd): shared API for the living-world, Vala Script and social workers

```gdscript
Dormancy.register("region:Spawn", center, func(elapsed_s): _catch_up(elapsed_s), 96.0, "region")
Dormancy.update(viewer_positions, now_s)      # ~1 Hz from the world loop, not per frame
if Dormancy.is_dormant(id): return            # skip ticking
func _catch_up(e):                            # ONE call: fast-forward math, never a tick replay
	hunger = Dormancy.ff_linear(hunger, HUNGER_PER_S, e, 0, 100)
	mood   = Dormancy.ff_toward(mood, 50.0, 600.0, e)
	spawns = Dormancy.ff_ticks(e, SPAWN_HZ, 20)
```

- Hysteresis: it wakes inside `wake_radius`, and sleeps only beyond 1.25 × radius after 10 s.
- Catch-up is capped at 7 days.
- `set_background(true)` puts everything to sleep, and nothing wakes until the app is in front again and
  `update()` sees a viewer.

## 6. Client side (Foxy): docs/specs/foxy/power_data.md

AutoQuality thermal throttling, FPS caps, render scale, client streaming and LOD, and the idle or screen-off
frame rate are Foxy's. AutoConfig hands them over through `set_power_profile`, `set_fps_cap_hint` and the
signals `power_changed` and `budgets_changed`.
