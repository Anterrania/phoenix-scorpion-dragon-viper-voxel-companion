class_name WorldHost
extends RefCounted
## SBX-3: on-demand worlds (the "regions sleep until someone visits" idea from cloud-hosted
## OpenSim grids) + Viper region bundles (export / import). Our own code and format.
##
## Region lifecycle: stored -> starting -> running -> stopping -> stored.
##   request_entry() wakes a stored region (SPINUP_S later it's running); tick() puts idle regions to
##   sleep after idle_timeout_s with nobody inside and outside any keep-awake schedule window.
##   On a phone only MAX_RUNNING regions run at once; the least-recently-visited idle one sleeps first.
## Region bundle ("viper-region-bundle" v1, JSON): estate settings + parcels + placed objects.
##   This is the Viper-native counterpart of the OAR plan in docs/modules/OPENSIM_OAR_AUROS.md:
##   an OAR converter (heightmap -> realm params, prims -> placeholders) will read/write the same
##   manifest fields later. Export rules (content protection): an object leaves only if
##   (a) the exporter made it, or (b) it came from the market with export=true, or
##   (c) it is not a market item and has copy AND transfer. Everything else is listed in the report.
## Gates: schedule / export / object placement = SandboxGate "manage_region" (estate manager+, Tiers
## "land" with the region target). Import (writes a whole region) = owner only.

const STATES := ["stored", "starting", "running", "stopping"]
const SPINUP_S := 20
const SPINDOWN_S := 5
const DEFAULT_IDLE_S := 600
const MAX_RUNNING := 4
const FORMAT := "viper-region-bundle"
const VERSION := 1

static var _w = null

static func _all() -> Dictionary:
	if _w == null:
		var d: Variant = SandboxGate.load_json("worlds", {})
		_w = d if d is Dictionary else {}
		if not _w.has("regions"): _w["regions"] = {}
		if not _w.has("objects"): _w["objects"] = {}
	return _w
static func _save() -> bool: return SandboxGate.save_json("worlds", _all())

static func world(region: String) -> Dictionary:
	var r: Dictionary = _all()["regions"]
	if not r.has(region):
		r[region] = {"state": "stored", "since": 0, "last_visit": 0, "visitors": [], "schedule": [], "idle_timeout_s": DEFAULT_IDLE_S}
	return r[region]

static func state(region: String) -> String: return str(world(region)["state"])

static func running() -> Array:
	var out: Array = []
	for k in _all()["regions"]:
		if str(_all()["regions"][k]["state"]) in ["starting", "running"]: out.append(k)
	return out

## Keep-awake schedule: [{"days": [0..6] (0 = Sunday), "start_h": 18, "end_h": 23}] in region-local hours.
static func set_schedule(actor: Variant, region: String, schedule: Array, idle_timeout_s := DEFAULT_IDLE_S) -> String:
	if not SandboxGate.can(actor, "manage_region", region): return "Estate manager or owner only."
	for w in schedule:
		if not (w is Dictionary) or int(w.get("start_h", -1)) < 0 or int(w.get("end_h", 25)) > 24 or int(w["start_h"]) >= int(w["end_h"]):
			return "Each window needs start_h < end_h within 0-24."
	var wd := world(region)
	wd["schedule"] = schedule.duplicate(true)
	wd["idle_timeout_s"] = clampi(idle_timeout_s, 60, 86400)
	return "" if _save() else "Saves are sealed. Unlock first."

static func in_schedule(region: String, now: int) -> bool:
	var t := Time.get_datetime_dict_from_unix_time(now)
	for w in world(region)["schedule"]:
		var days: Array = w.get("days", [0, 1, 2, 3, 4, 5, 6])
		if int(t["weekday"]) in days and int(t["hour"]) >= int(w["start_h"]) and int(t["hour"]) < int(w["end_h"]): return true
	return false

## A visitor asks to enter. Returns {"state": ..., "eta_s": n} or {"error": "..."}.
static func request_entry(actor: Variant, region: String, now: int) -> Dictionary:
	if not Tiers.can(actor, "enter", region): return {"error": "You can't enter that region."}
	var wd := world(region)
	var who := SandboxGate.id_of(actor)
	if not who in wd["visitors"]: wd["visitors"].append(who)
	wd["last_visit"] = now
	match str(wd["state"]):
		"stored", "stopping":
			_make_room(now, region)
			wd["state"] = "starting"; wd["since"] = now
	_save()
	var eta := maxi(0, SPINUP_S - (now - int(wd["since"]))) if wd["state"] == "starting" else 0
	return {"state": wd["state"], "eta_s": eta}

static func leave(actor: Variant, region: String, now: int) -> void:
	var wd := world(region)
	wd["visitors"].erase(SandboxGate.id_of(actor))
	wd["last_visit"] = now
	_save()

## Phone budget: sleep the least-recently-visited empty region when MAX_RUNNING are up.
static func _make_room(now: int, keep: String) -> void:
	var up := running().filter(func(k): return k != keep)
	if up.size() < MAX_RUNNING: return
	up.sort_custom(func(a, b): return int(world(a)["last_visit"]) < int(world(b)["last_visit"]))
	for k in up:
		if world(k)["visitors"].is_empty():
			world(k)["state"] = "stopping"; world(k)["since"] = now
			return

## Advance every region's state machine. Returns [{region, from, to}].
static func tick(now: int) -> Array:
	var moves: Array = []
	for k in _all()["regions"]:
		var wd: Dictionary = _all()["regions"][k]
		var from := str(wd["state"])
		match from:
			"starting":
				if now - int(wd["since"]) >= SPINUP_S: wd["state"] = "running"; wd["since"] = now
			"running":
				if wd["visitors"].is_empty() and not in_schedule(k, now) and now - int(wd["last_visit"]) >= int(wd["idle_timeout_s"]):
					wd["state"] = "stopping"; wd["since"] = now
			"stopping":
				if now - int(wd["since"]) >= SPINDOWN_S: wd["state"] = "stored"; wd["since"] = now
			"stored":
				if in_schedule(k, now): wd["state"] = "starting"; wd["since"] = now
		if str(wd["state"]) != from: moves.append({"region": k, "from": from, "to": wd["state"]})
	if not moves.is_empty(): _save()
	return moves

# ---------- placed objects (region manifest) ----------
## obj: {id, name, creator, perms: {copy, modify, transfer}, market: bool, export: bool, pos: [x,y,z]}
static func objects(region: String) -> Array:
	if not _all()["objects"].has(region): _all()["objects"][region] = []
	return _all()["objects"][region]

static func place_object(actor: Variant, region: String, obj: Dictionary) -> String:
	if not SandboxGate.can(actor, "manage_region", region): return "Estate manager or owner only."
	if str(obj.get("id", "")) == "": return "Object needs an id."
	objects(region).append(obj.duplicate(true))
	return "" if _save() else "Saves are sealed. Unlock first."

static func exportable(obj: Dictionary, exporter: String) -> String:
	var p: Dictionary = obj.get("perms", {})
	if str(obj.get("creator", "")) == exporter: return ""
	if bool(obj.get("market", false)): return "" if bool(obj.get("export", false)) else "market item without export permission"
	if bool(p.get("copy", false)) and bool(p.get("transfer", false)): return ""
	return "needs copy and transfer (or your own creation)"

## Build a bundle + export report. Writes user://sandbox/exports/<region>.vrb.json and returns the bundle.
static func export_bundle(actor: Variant, region: String) -> Dictionary:
	if not SandboxGate.can(actor, "manage_region", region): return {"error": "Estate manager or owner only."}
	var who := SandboxGate.id_of(actor)
	var estate := {}
	for key in Estate.REGION_DEFAULTS:
		if key in ["allowed", "banned"]: continue   # people lists stay on this device (privacy)
		estate[key] = Estate.region_get(region, key)
	var parcels := {}
	var c := Estate.cfg()
	for sec in c.get_sections():
		if sec.begins_with("parcel:%s/" % region):
			var pid := sec.trim_prefix("parcel:%s/" % region)
			parcels[pid] = {}
			for key in c.get_section_keys(sec):
				if key in Estate.REGION_DEFAULTS and not key in ["allowed", "banned"]: parcels[pid][key] = c.get_value(sec, key)
	var inc: Array = []
	var skipped: Array = []
	for o in objects(region):
		var why := exportable(o, who)
		if why == "": inc.append(o.duplicate(true))
		else: skipped.append({"id": o["id"], "name": o.get("name", ""), "reason": why})
	var b := {"format": FORMAT, "version": VERSION, "region": region, "estate": estate, "parcels": parcels,
		"objects": inc, "report": {"included": inc.size(), "skipped": skipped}}
	DirAccess.make_dir_recursive_absolute(SandboxGate.root.path_join("exports"))
	SecureFile.write_json(SandboxGate.root.path_join("exports/%s.vrb.json" % region.validate_filename()), b, "\t")
	return b

## Owner only. Restores estate keys we know about, parcels and objects into `as_region`.
static func import_bundle(actor: Variant, bundle: Dictionary, as_region: String, overwrite := false) -> String:
	if not SandboxGate.can(actor, "import_bundle"): return "Owner unlock needed."
	if str(bundle.get("format", "")) != FORMAT: return "Not a Viper region bundle."
	if int(bundle.get("version", 0)) > VERSION: return "Bundle is from a newer Viper. Update first."
	if as_region == "" or as_region != as_region.validate_filename(): return "Pick a plain region name."
	if not objects(as_region).is_empty() and not overwrite: return "That region has objects. Turn on overwrite."
	for key in bundle.get("estate", {}):
		if key in Estate.REGION_DEFAULTS and not key in ["allowed", "banned"]: Estate.region_set(as_region, key, bundle["estate"][key])
	for pid in bundle.get("parcels", {}):
		for key in bundle["parcels"][pid]:
			if key in Estate.REGION_DEFAULTS and not key in ["allowed", "banned"]: Estate.parcel_set(as_region, str(pid), key, bundle["parcels"][pid][key])
	var objs: Array = []
	for o in bundle.get("objects", []):
		if o is Dictionary and str(o.get("id", "")) != "": objs.append(o.duplicate(true))
	_all()["objects"][as_region] = objs
	world(as_region)
	return "" if _save() else "Saves are sealed. Unlock first."

static func reset_for_tests() -> void: _w = null
