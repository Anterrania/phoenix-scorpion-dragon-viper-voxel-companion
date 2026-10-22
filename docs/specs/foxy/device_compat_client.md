# Spec for Foxy: device compatibility on the client

## 1. AutoQuality hookup (your autoload; we never duplicate it)
AutoConfig calls these only if `has_method` says they exist:
- `recommend_tier(name)` (**please add**): sets the starting tier for the auto governor **without** leaving
  auto mode. We call it only while `get_mode() == "auto"`. If you've chosen a tier by hand, we leave it alone.
- `set_tier(name)`: we call it only when the user picked a tier in Device & compatibility, or with "auto"
  on **Reset to auto**.
- `set_power_profile(p)` (**please add**): battery_saver · balanced · performance.
- `set_fps_cap_hint(fps)` (**please add**): see power_data.md.
- Until AutoQuality is on main, AutoConfig writes the legacy `Settings.graphics/quality` (0..2) using the
  same override rules. That branch is marked INACTIVE once your autoload exists.
- World knobs: register them with your `register_knob(id, setter, levels)`. The hints in
  `AutoConfig.budget("view_distance_hint" | "particle_budget" | "streaming_threads")` are ceilings for them.

## 2. Input scheme UI
- Listen to `AutoConfig.input_scheme_changed(scheme)`: touch · gamepad · kbm · xr.
- `AutoConfig.last_plan["input_profile"]` is data: move, look, jump, interact, menu, radial, fly, and hud
  (touch · gamepad · desktop · xr). Draw the matching glyphs and hide the touch pads on gamepad, kbm and xr.
- Settings picker: "Controls: Auto / Touch / Gamepad / Keyboard + mouse" calls `AutoConfig.choose("input_scheme", v)`.
- Gamepad events are already added to move_* and jump. Please add actions for interact, menu and radial, and
  we'll add the pad binds to `AutoConfig.PAD_EVENTS`.

## 3. Gamepad HUD
- D-pad / left stick focus navigation for the MENU and the radial (`focus_neighbor_*`). The A button presses
  and B goes back. Start opens MENU, and Y opens the radial.
- TV (form_factor "tv"): 1.6× UI from AutoConfig, keep 5% overscan margins, and never require touch.
- A gamepad connecting mid-session swaps the HUD within one frame of `input_scheme_changed`.

## 4. UI scale
On main AutoConfig calls `ui_scale_provider` if you or the phone worker set it. With the phone branch's
DisplaySettings it writes `display/text_scale` and `display/icon_scale`, so phones stay compact (1.0).

## 5. Disabled features
`AutoConfig.feature_on(id)` / `feature_reason(id)`: hide the button, or show it greyed out with the reason.
Don't let it fail later.
