class_name SceneSnapshots
extends RefCounted
## v0.13 BRAIN-SCENE: automatic snapshots on in-world scene changes, written to the InteractionLedger.
## In-world events ONLY: realm / district changes, weather and time-of-day shifts, companions joining or
## leaving, Heaven edits, teleports. Never the phone camera, microphone, screen, location or any real person.
## Identical back-to-back snapshots are skipped so a busy scene doesn't flood the ledger.

const KINDS := ["realm_change", "district_change", "weather_change", "time_of_day", "companion_join",
	"companion_leave", "heaven_edit", "player_teleport", "light_change"]
## Explicitly refused: anything that would capture the real world.
const REFUSED := ["camera", "microphone", "mic", "screen", "location", "gps", "contacts", "photo"]

static var enabled := true
static var _last_sig := ""
static var _recent: Array = []   # ids (ledger hashes) of the latest snapshots

static func capture(kind: String, data := {}, companion := "") -> Dictionary:
	if not enabled: return {"error": "snapshots off"}
	if kind in REFUSED or not kind in KINDS: return {"error": "only in-world scene events are recorded"}
	var clean: Dictionary = InteractionLedger.clean(data)
	var sig := kind + JSON.stringify(clean, "", true)
	if sig == _last_sig: return {"skipped": true}
	var b := InteractionLedger.append("scene", companion, {"scene": kind, "state": clean})
	if b.has("error"): return b
	_last_sig = sig
	_recent.append(str(b["hash"]).left(16))
	if _recent.size() > 32: _recent = _recent.slice(-32)
	return b

static func recent_ids(n := 3) -> Array: return _recent.slice(-n)

static func reset_for_tests() -> void:
	_last_sig = ""; _recent = []; enabled = true
