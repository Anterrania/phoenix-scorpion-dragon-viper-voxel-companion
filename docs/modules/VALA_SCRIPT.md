# Vala Script (`.vscript`)

Status: built and headless-tested (VALA-1..9). The editor, debug console and screen rendering belong to Foxy (docs/specs/foxy/VALA_SCRIPT_CLIENT.md).
Code: `scripts/vala_script/` (`vs_lexer.gd`, `vs_parser.gd`, `vs_vm.gd`, `vs_engine.gd`, `vs_lsl_shim.gd`, `vs_script_store.gd`). Tests: `tests/vala_script_tests.gd`.

> **Name note.** Vala Script is our own in-world scripting language. It is **not** the GNOME Vala
> programming language and has no connection to it, its compiler or GLib. The syntax borrows a few
> ideas from Vala and C#, which is all the two share. This repo also has real GNOME Vala code in
> `core/vala` (EveCore). That is a separate thing.

## 1. Shape of a script

States, events and typed variables in the LSL style, plus Dual Universe-style element slots and
tick/update/flush events. Every script must have a `default` state.

```vscript
integer count;
slot hatch : door;

default {
    state_entry() { set_text("Tap to open", <1, 1, 1>, 1.0); }
    touch_start(integer n) {
        count++;
        hatch.toggle();
        say(0, @"Opened $count times by $(detected_name(0))");
        if (count >= 3) state tired;
    }
}

state tired {
    state_entry() { timer(30.0); }
    timer() { count = 0; state default; }
}
```

## 2. Language reference

- **Types:** `integer` (`int`), `float` (`double`), `string`, `key`, `vector`, `rotation` (`quaternion`), `list`, `bool`. `var` infers from the initializer.
- **Literals:** `12`, `0x1F`, `1.5`, `1.5f`, `"text\n"`, vectors `<x, y, z>`, rotations `<x, y, z, s>`, lists `[1, "two"]`, and templates `@"x is $x, sum $(a + b)"`.
- **Statements:** `if`/`else`, `while`, `do`/`while`, `for`, `foreach (var x in list)`, `break`, `continue`, `return`, `state name;`. Casts look like `(string) n`. Operators: `+ - * / %`, comparisons, `&& || !`, bit ops, `+= -= *= /=`, `++ --`, and `.x .y .z .s` on vectors and rotations.
- **Functions:** `float half(float x) { return x / 2; }` at the top level. Recursion is allowed up to the call-depth limit.
- **Slots:** `slot name : type;` binds an element that the owner links to the object. Each type has a fixed set of methods. Anything else is a compile error.
- **Not supported, by design:** `jump`/labels, `goto`, pointers, file/OS/process access, reflection, `eval`.

The compiler checks names, arity, event signatures, slot methods and state targets before anything runs, and reports the line.

### Events

`state_entry()`, `state_exit()`, `on_rez(integer)`, `changed(integer)`, `touch_start/touch/touch_end(integer)`,
`collision_start/collision/collision_end(integer)`, `timer()`, `listen(integer channel, string name, key id, string msg)`,
`sensor(integer)`, `no_sensor()`, `http_response(key, integer, string)`. Unit-style events: `start()`, `stop()`,
`tick(string id)` (named timers), `update(float dt)` (10 Hz), `flush(float dt)` (after update), and `element(string slot, string what)`.

### Element slots

| type | methods (✱ = changes the world, goes through the gates) |
|---|---|
| door | open✱ close✱ toggle✱ is_open |
| light | on✱ off✱ toggle✱ is_on set_color✱ set_intensity✱ |
| screen | clear✱ text(x,y,s)✱ rect✱ line✱ circle✱ set_color✱ set_background✱ flush✱ width height |
| engine | set_thrust✱ get_thrust max_thrust |
| container | count items capacity |
| sensor | detected range set_range✱ |
| button | is_pressed |

The screen is **data only**. It's 320×180 with up to 256 draw ops per frame, and `flush()` hands the op list to the client. Scripts never touch pixels, shaders or UI nodes.

## 3. Built-in library

**Chat:** `say(channel?, msg)` 20 m, `whisper(` 10 m, `shout(` 100 m, `region_say(channel, msg)`, `owner_say(msg)`, `listen(channel, name?, id?, msg?)` returns a handle (max 16), and `listen_remove(handle)`.

**Object:** `set_text(text, color?, alpha?)`, `set_color(vector)`, `set_alpha(float)`, `get_pos()`, `set_pos(vector)`, `get_rot()`, `set_rot(rotation)`, `get_owner()`, `get_key()`, `get_name()`, `rez(item, offset)`, `give_item(avatar, item)`, `teleport(avatar, pos)` and `die()`.

**Timers & sensing:** `timer(seconds)` (0 stops it), `start_timer(id, seconds)` which fires `tick(id)`, `stop_timer(id)`, `sensor(name, range)`, `sensor_remove()`, `detected_key(i)`, `detected_name(i)` and `detected_pos(i)`.

**Net:** `http_request(url, method, body)` returns a key, and the answer arrives in `http_response`. It's off unless the owner enables it (§5).

**Script:** `reset_script()`, `get_state()`, `time()` (seconds since start), `now()` (unix time), `free_memory()` and `debug(msg)` (to the HUD console).

**Strings:** `length(` (string or list), `substr(s, start, len?)`, `index_of(s, part)`, `to_upper(`, `to_lower(`, `trim(`, `replace(s, a, b)`, `split(s, sep)`, `join(list, sep)` and `contains(s, part)`.

**Lists:** `list_slice(l, a, b)`, `list_find(l, v)`, `list_insert(l, i, v)`, `list_remove(l, i)` and `list_sort(l)`.

**Math:** `abs(`, `floor(`, `ceil(`, `round(`, `sqrt(`, `pow(a, b)`, `min(a, b)`, `max(a, b)`, `sin(`, `cos(`, `tan(`, `atan2(y, x)`, `rand(max)`, `vec_mag(`, `vec_norm(`, `vec_dist(a, b)`, `euler_to_rot(vector)` and `rot_to_euler(rotation)`.

**Constants:** `PI`, `TWO_PI`, `PI_BY_TWO`, `DEG_TO_RAD`, `RAD_TO_DEG`, `ZERO_VECTOR`, `ZERO_ROTATION`, `NULL_KEY`, `PUBLIC_CHANNEL`, `DEBUG_CHANNEL`, `TRUE`, `FALSE` and the `CHANGED_*` flags. They're read-only.

## 4. Limits

| limit | value |
|---|---|
| source size / tokens | 64 KB / 20,000 |
| nesting depth (compiler) | 48 |
| steps per event | 20,000 at the reference power budget, scaled by PowerData (§6) |
| memory per script | 64 KB (strings, lists, globals) |
| string length | 16 KB |
| call depth | 64 |
| queued events | 64 (extra events are dropped and logged) |
| listens | 16 |
| rates (per object) | chat 20/10 s · world calls 40/10 s · rez 5/10 s · give 10/10 s · teleport 2/10 s · http 5/20 s · screen 30/1 s |

A script that runs out of steps or memory, or hits a runtime error such as divide-by-zero, **stops** with a line number in the debug log, like a crash. The owner fixes it and resets it. A rate-limited call is skipped and logged, and the script carries on.

## 5. Sandbox and security model

- **No file, OS, process or network sockets.** The VM is a tree-walking interpreter over checked data. There's no `eval`, and the only things a script can reach are the built-ins above.
- **World calls are gated.** Every call that changes the world goes through `Tiers.can(owner, "build", parcel)` (teleport uses `"enter"` on the destination) **and** the estate's `allow_scripts` flag (`allow_group_scripts` for land-group members). The owner session overrides the estate flag. Slot calls only reach elements linked to the script's own object.
- **E-stop.** While `AutonomyGuard.paused()`, every script halts at once. Only the owner can resume, after the guard is released.
- **Companion scripts** never start directly. Loading one files `EveCore.propose_update` and waits for owner approval.
- **HTTP is off by default.** The owner turns it on with an allowlist of hosts. Only `https://` is allowed, the host must match exactly, and URLs with userinfo (`user@host`) are refused. The rate is 5 requests per 20 s.
- **Inventory perms.** Scripts are `.vscript` inventory items with copy, modify and transfer perms. Next-owner perms apply on transfer, and a no-modify script's source can't be read or edited by the next owner.

## 6. Power and dormancy

- **Dormant regions pause.** If `Dormancy.is_dormant("region:<name>")` is true for the object's region, or the app is in the background, the script doesn't run. Timers and update don't fire and touch/chat events are dropped. On wake it carries on from where it was, and missed ticks are **not** replayed.
- **Budget scales with PowerData.** The step budget per event is `20,000 × script_budget_ms / 2` (clamped to 0–2×, never below 1,000). It's halved in saver mode and doubled in full mode. A budget of `0` (background) pauses all scripts.

## 7. LSL import

`VsLslShim.translate(lsl)` maps common `ll*` calls to their built-ins (for example `llSay` → `say`, `llSetTimerEvent` → `timer`, `llGetSubString` → `substr`). It returns the new source plus a list of `{line, what}` for everything it can't carry over: unknown functions (left in place, so the compile fails visibly), unsupported events (handler dropped), and labels/jump. Nothing is silently dropped.

## 8. Engine API (for the host and Foxy)

`VsEngine`: `add_object`, `load_script(oid, src, author, name)`, `activate_approved`, `touch`, `collide`, `hear`, `changed`, `rezzed`, `add_element`/`link`/`element_event`, `tick(dt)`, `set_http(on, hosts)` (owner), `http_reply`, `halt_all`, `resume_all` (owner), `status()` and `log`, plus the `effect` signal (`chat`, `set_text`, `screen`, `element`, `rez`, …), which the client renders.
