# v0.15.0 — the social app is the menu (SOCIAL-SHELL, MENU, SCROLL, KB)

Two seamless concepts, one owner session:
- **Voxel app with the social app built in** (this repo): ☰ opens Scorpion Viper (embedded panel) as the main menu.
  Its "World" dock runs world actions (Play, Teleport, Worlds, Companions, Avatar, Settings, …) in this app.
- **Social app with the voxel world built in** (SkorpionViper v0.39): when embedded it shows "▶ World" / "☰ World menu"
  and reads the owner session from the host. Standalone APK keeps working as a plain social app (plan below).

## Done
| ID | Change |
|----|--------|
| SOCIAL-SHELL-1 | `show_panel("menu")` opens the embedded social app when available; `SOCIAL_MENU` const + setting `ui/classic_menu` fall back to the Godot menu ("☰ Classic menu" action too). |
| SOCIAL-SHELL-2 | Menu dispatch extracted to `menu_action(id)`; `menu_actions()` sends `[{id,label}]` to the plugin (`set_world_actions`). |
| SOCIAL-SHELL-3 | ViperDevice plugin v4: JS `ViperHost.worldActions()` / `ViperHost.worldAction(id)` (whitelisted ids) → `social_world_action` signal; panel is hidden, not destroyed, so it reopens instantly. |
| MENU-2 | Panel lists get a right gutter; scrollbar is slimmer and only shows when needed. |
| MENU-3 | Radial launcher hidden while any panel is open. |
| SCROLL-1 | KineticScroll: sub-pixel accumulator, time-based velocity, no fling after a pause, clamped at ends. |
| KB-1 | Godot: `virtual_keyboard_get_height()` lifts open panels and `ensure_control_visible` on the focused field. Plugin: IME insets pad the social panel + `SOFT_INPUT_ADJUST_RESIZE` (immersive mode ignores adjustResize alone). |
| VER | 0.15.0 / versionCode 19 (CI: 100 + run number). |

## Planned
- Godot Web export of the world so the standalone social APK can show it inside (or retire that APK and ship only this one).
- Server-backed shared account so the same owner session works across devices, not just inside this app.
