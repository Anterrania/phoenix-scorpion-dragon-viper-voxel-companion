# Second Life / LSL Scripting Notes — PLAN ONLY
Complements SMARTBOT_AND_SCRIPTING.md. Nothing here is implemented.

| LSL concept | Godot/Phoenix equivalent (planned) |
|---|---|
| `state default {}` / events (`touch_start`, `timer`, `listen`) | GDScript signals on usable objects (USABLE_OBJECTS.md) |
| `llSay`/`llListen` channels | in-world chat bus; companions subscribe by channel |
| `llSetTimerEvent` | `Timer` node |
| Prim permissions (copy/mod/transfer) | asset library license flags |
| Notecards | JSON config files under `data/` |
| Sensors (`llSensor`) | `Area3D` + companion perception |

- Possible future work: a small sandboxed "Phoenix Script" that uses LSL-like event names so builders feel at home. Do not interpret real LSL.
- Bots like SmartBots/Corrade are reference ideas only. Nothing connects to Second Life servers.
