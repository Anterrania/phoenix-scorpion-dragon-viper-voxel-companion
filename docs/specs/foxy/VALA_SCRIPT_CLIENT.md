# Foxy spec: Vala Script client (editor, debug console, screens)

The backend is done (docs/modules/VALA_SCRIPT.md). This page lists what the client needs. Nothing here changes Foxy's files from our side.

## 1. Script editor
- Open/save a `.vscript` inventory item through `VsScriptStore` (`source` needs modify perms, `edit`, `create`). Show perms (copy/mod/transfer) and the next-owner perms.
- Syntax colours from `VsLexer.tokenize` token kinds (`kw`, `type`, `str`, `tpl`, `int`, `float`, `op`, `id`).
- **Compile** button: `VsParser.compile(src)` → show `error` at `line`. Gutter marker, tap to jump.
- **Import LSL**: `VsLslShim.translate` → load `source` into the editor and list `unsupported` (`line`, `what`) as warnings.
- Companion-authored scripts show "Waiting for owner approval" until `activate_approved`.

## 2. HUD debug console
- Poll `engine.status()` (1 Hz is enough): per script name, object, state, running/stopped, error + line, steps used/budget, memory, and paused (dormant / e-stop / background).
- Tail `engine.log` (`{t, sid, level, msg}`) with a filter, and show `debug()` and `DEBUG_CHANNEL` output.
- Owner buttons: reset, stop, **Resume all** (e-stop), HTTP on/off with the allowlist editor (`set_http`).

## 3. Rendering effects (`engine.effect` signal)
| kind | render |
|---|---|
| `chat` | chat bubble / chat log with range (whisper/say/shout/region/owner) |
| `set_text` | floating text above the object (text, colour, alpha) |
| `set_color` / `set_alpha` / `set_pos` / `set_rot` | apply to the object node |
| `screen` | draw the op list (`clear`, `text`, `rect`, `line`, `circle`, colours) on a 320×180 texture; scale to the surface. Data only, so cap at 256 ops |
| `element` | animate the door/light/engine (open, on, thrust…) |
| `rez` / `die` / `give_item` / `teleport` | spawn/remove/inventory toast/teleport |

## 4. Power
Show "Paused: nobody nearby" or "Paused: background" in the console when the script is paused by dormancy. There's nothing to render while it's dormant.
