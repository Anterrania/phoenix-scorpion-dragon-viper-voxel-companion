class_name Governance
extends RefCounted
## LIFE-5: Earth-like governance as a GAME system. Fictional nations only: no real countries,
## parties or politicians (names on the REAL_WORLD list are refused). Data: data/living/governance.json.
##
## - Nations: name, government type (monarchy, republic, council, ...), leader, citizens, territories.
## - Territory = Estate regions or parcels ("region" or "region/parcel"). Claiming needs the nation
##   leader AND Tiers.can(actor, "land", region) (owner or estate manager), so the Estate system stays
##   the single land authority. The Frontier Territory claims (feature/spacesim-parity, Territory +
##   OrgRights) are org claims on parcels; a nation can hold regions that contain org claims.
## - Laws: rule toggles per nation (mining, build_permit, pvp, trade, open_borders, quarantine,
##   vaccination_required, hunting, curfew_quiet). law_allows() answers for an actor in a region.
##   pvp still needs Estate allow_damage: a law can only restrict, never unlock what the estate forbids.
## - Taxes: in-game hook. Currency "civic_credit" (earned only, never bought, never cashed out) works.
##   "aethel_coin" taxes are INACTIVE: LEGAL REVIEW REQUIRED (docs/modules/GOVERNANCE.md).
## - Elections + votes: one vote per citizen; results are counted on close; republics elect leaders.
## - Embassies (mutual) and borders (open / visa / citizens_only / closed).
## - Phoenix as god: LivingGate.exempt (unlocked owner) ignores laws and borders. Locked owner = guest.
## - Every write goes through Tiers.can, so the e-stop blocks bots/companions.
## State: user://living/governance.json through SecureFile.

const DATA := "res://data/living/governance.json"
const AETHEL_TAX_ACTIVE := false   # LEGAL REVIEW REQUIRED (2026-10-17 memo): no Aethel Coin taxes.
const REAL_WORLD := ["united states", "usa", "america", "china", "russia", "united kingdom", "britain", "france",
	"germany", "india", "japan", "israel", "palestine", "ukraine", "iran", "north korea", "south korea", "canada",
	"mexico", "democrat", "republican party", "labour", "tory", "communist party", "nazi", "taliban", "isis"]
static var root := "user://living"
static var _db = null
static var _cfg = null

static func cfg() -> Dictionary:
	if _cfg == null:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_cfg = d if d is Dictionary else {}
	return _cfg

static func _d() -> Dictionary:
	if _db == null:
		var d: Variant = SecureFile.read_json(root.path_join("governance.json"), {})
		_db = d if d is Dictionary else {}
		for k in ["nations", "territory"]:
			if not _db.has(k): _db[k] = {}
		if not _db.has("seq"): _db["seq"] = 0
	return _db

static func _commit(snap: Dictionary, ok_result: Dictionary) -> Dictionary:
	if SecureFile.write_json(root.path_join("governance.json"), _db): return ok_result
	_db = snap
	return _err("Saves are sealed. Unlock first.")

static func _ok(x := {}) -> Dictionary:
	var r := {"ok": true, "error": ""}; r.merge(x); return r
static func _err(e: String) -> Dictionary: return {"ok": false, "error": e}

static func nation(id: String) -> Dictionary: return _d()["nations"].get(id, {}).duplicate(true)
static func nations() -> Array: return _d()["nations"].keys()

static func is_real_world(name: String) -> bool:
	var n := name.to_lower()
	for w in REAL_WORLD:
		if n.contains(w): return true
	return false

static func _leader(actor: Variant, n: Dictionary) -> bool:
	return LivingGate.exempt(actor) or str(n.get("leader", "")) == Tiers.actor_id(actor)

static func found(actor: Variant, name: String, gov_type: String) -> Dictionary:
	if not Tiers.can(actor, "group_create"): return _err("Creator tier or higher can found a nation.")
	var clean := str(name).strip_edges().left(48).replace("[", "(").replace("]", ")")
	if clean.length() < 3: return _err("Pick a name (3+ letters).")
	if is_real_world(clean): return _err("Nations are fictional. Real countries and parties are not allowed.")
	if not cfg().get("government_types", {}).has(gov_type): return _err("Unknown government type.")
	var snap := _d().duplicate(true)
	_d()["seq"] = int(_d()["seq"]) + 1
	var id := "nation%d" % _d()["seq"]
	var laws := {}
	for l in cfg()["laws"]: laws[l] = bool(cfg()["laws"][l]["default"])
	var me := Tiers.actor_id(actor)
	_d()["nations"][id] = {"id": id, "name": clean, "gov_type": gov_type, "founder": me, "leader": me,
		"citizens": [me], "visas": [], "territories": [], "laws": laws, "taxes": {}, "tax_currency": "civic_credit",
		"border": "open", "embassies": [], "embassy_requests": [], "elections": {}, "treasury": 0}
	return _commit(snap, _ok({"id": id}))

## Claim an estate region (or region/parcel) for a nation.
static func claim(actor: Variant, nid: String, place: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not _leader(actor, n): return _err("Only the leader can claim territory.")
	var region := place.split("/")[0]
	if not Tiers.can(actor, "land", region): return _err("Only the owner or an estate manager can put land under a nation.")
	if _d()["territory"].has(place): return _err("Already held by a nation.")
	var snap := _d().duplicate(true)
	_d()["territory"][place] = nid
	n["territories"].append(place)
	return _commit(snap, _ok())

## Nation that governs a region/parcel ("" if none). Parcel claims win over region claims.
static func nation_at(region: String, parcel := "") -> String:
	if parcel != "" and _d()["territory"].has(region + "/" + parcel): return str(_d()["territory"][region + "/" + parcel])
	return str(_d()["territory"].get(region, ""))

static func is_citizen(nid: String, id: String) -> bool:
	return id in _d()["nations"].get(nid, {}).get("citizens", [])

static func grant_citizenship(actor: Variant, nid: String, member: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not _leader(actor, n) or not Tiers.can(actor, "group_join"): return _err("Only the leader grants citizenship.")
	if member in n["citizens"]: return _ok()
	var snap := _d().duplicate(true)
	n["citizens"].append(member)
	return _commit(snap, _ok())

static func renounce(actor: Variant, nid: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	var me := Tiers.actor_id(actor)
	if n.is_empty() or not me in n["citizens"]: return _err("Not a citizen.")
	if n["leader"] == me: return _err("Hand over leadership first.")
	var snap := _d().duplicate(true)
	n["citizens"].erase(me)
	return _commit(snap, _ok())

static func set_law(actor: Variant, nid: String, law: String, on: bool) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not cfg()["laws"].has(law): return _err("Unknown law.")
	if not _leader(actor, n) or not Tiers.can(actor, "poll_create"): return _err("Only the leader changes laws.")
	var snap := _d().duplicate(true)
	n["laws"][law] = on
	return _commit(snap, _ok())

## Does the law in force at region/parcel allow this actor to do `law`'s activity?
static func law_allows(actor: Variant, region: String, law: String, parcel := "") -> bool:
	if LivingGate.exempt(actor): return true
	if law == "pvp" and not bool(Estate.region_get(region, "allow_damage")): return false
	var nid := nation_at(region, parcel)
	if nid == "": return true
	var n: Dictionary = _d()["nations"][nid]
	var on := bool(n["laws"].get(law, cfg()["laws"].get(law, {}).get("default", true)))
	if law == "build_permit": return not on or is_citizen(nid, Tiers.actor_id(actor))
	return on

## Taxes. currency: civic_credit (works) or aethel_coin (LEGAL REVIEW, refused).
static func set_tax(actor: Variant, nid: String, kind: String, pct: float, currency := "civic_credit") -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not _leader(actor, n): return _err("Only the leader sets taxes.")
	if currency == "aethel_coin" and not AETHEL_TAX_ACTIVE: return _err("Aethel Coin taxes are off: LEGAL REVIEW REQUIRED.")
	if currency != "civic_credit": return _err("Unknown currency.")
	if not kind in cfg()["tax_kinds"]: return _err("Unknown tax.")
	if pct < 0 or pct > float(cfg()["max_tax_pct"]): return _err("Tax must be 0..%d%%." % int(cfg()["max_tax_pct"]))
	var snap := _d().duplicate(true)
	n["taxes"][kind] = pct; n["tax_currency"] = currency
	return _commit(snap, _ok())

## Tax due on an amount (civic credits, rounded down). Exempt actor pays nothing.
static func tax_due(actor: Variant, region: String, kind: String, amount: int) -> int:
	if LivingGate.exempt(actor): return 0
	var nid := nation_at(region)
	if nid == "": return 0
	return int(floor(amount * float(_d()["nations"][nid]["taxes"].get(kind, 0.0)) / 100.0))

# ---------- elections ----------
static func start_election(actor: Variant, nid: String, office: String, candidates: Array, hours := 48) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not _leader(actor, n) or not Tiers.can(actor, "poll_create"): return _err("Only the leader calls elections.")
	if not bool(cfg()["government_types"][n["gov_type"]]["elections"]) and office == "leader": return _err("This government type has no leader elections.")
	var c := candidates.filter(func(x): return str(x) in n["citizens"])
	if c.size() < 1: return _err("Candidates must be citizens.")
	var snap := _d().duplicate(true)
	_d()["seq"] = int(_d()["seq"]) + 1
	var eid := "e%d" % _d()["seq"]
	n["elections"][eid] = {"office": office, "candidates": c, "votes": {}, "open": true, "hours": hours}
	return _commit(snap, _ok({"id": eid}))

static func vote(actor: Variant, nid: String, eid: String, candidate: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	var e: Dictionary = n.get("elections", {}).get(eid, {})
	if e.is_empty() or not bool(e["open"]): return _err("No open election.")
	var me := Tiers.actor_id(actor)
	if not Tiers.can(actor, "poll_vote"): return _err("You can't vote right now.")
	if not me in n["citizens"]: return _err("Only citizens vote.")
	if e["votes"].has(me): return _err("You already voted.")
	if not candidate in e["candidates"]: return _err("Not a candidate.")
	var snap := _d().duplicate(true)
	e["votes"][me] = candidate
	return _commit(snap, _ok())

static func close_election(actor: Variant, nid: String, eid: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	var e: Dictionary = n.get("elections", {}).get(eid, {})
	if e.is_empty() or not bool(e["open"]): return _err("No open election.")
	if not _leader(actor, n): return _err("Only the leader closes the vote.")
	var tally := {}
	for v in e["votes"].values(): tally[v] = int(tally.get(v, 0)) + 1
	var winner := ""; var best := -1
	for c in e["candidates"]:   # ties: earlier candidate in the list wins (deterministic)
		if int(tally.get(c, 0)) > best: best = int(tally.get(c, 0)); winner = c
	var snap := _d().duplicate(true)
	e["open"] = false; e["winner"] = winner; e["tally"] = tally
	if e["office"] == "leader": n["leader"] = winner
	return _commit(snap, _ok({"winner": winner, "tally": tally}))

# ---------- embassies + borders ----------
static func request_embassy(actor: Variant, nid: String, host: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {}); var h: Dictionary = _d()["nations"].get(host, {})
	if n.is_empty() or h.is_empty() or nid == host: return _err("Pick two nations.")
	if not _leader(actor, n): return _err("Only the leader opens embassies.")
	var snap := _d().duplicate(true)
	if not nid in h["embassy_requests"]: h["embassy_requests"].append(nid)
	return _commit(snap, _ok())

static func accept_embassy(actor: Variant, host: String, from_nid: String) -> Dictionary:
	var h: Dictionary = _d()["nations"].get(host, {}); var n: Dictionary = _d()["nations"].get(from_nid, {})
	if h.is_empty() or n.is_empty() or not from_nid in h["embassy_requests"]: return _err("No such request.")
	if not _leader(actor, h): return _err("Only the host leader accepts.")
	var snap := _d().duplicate(true)
	h["embassy_requests"].erase(from_nid)
	if not from_nid in h["embassies"]: h["embassies"].append(from_nid)
	if not host in n["embassies"]: n["embassies"].append(host)
	return _commit(snap, _ok())

static func set_border(actor: Variant, nid: String, policy: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty(): return _err("No such nation.")
	if not _leader(actor, n): return _err("Only the leader sets the border.")
	if not policy in cfg()["border_policies"]: return _err("Unknown border policy.")
	var snap := _d().duplicate(true)
	n["border"] = policy
	return _commit(snap, _ok())

static func grant_visa(actor: Variant, nid: String, member: String) -> Dictionary:
	var n: Dictionary = _d()["nations"].get(nid, {})
	if n.is_empty() or not _leader(actor, n): return _err("Only the leader grants visas.")
	var snap := _d().duplicate(true)
	if not member in n["visas"]: n["visas"].append(member)
	return _commit(snap, _ok())

## Border + quarantine check for entering a region. "" = allowed, else the reason.
## Estate access (Tiers.can enter) is checked separately and always wins.
static func can_cross(actor: Variant, region: String) -> String:
	if LivingGate.exempt(actor): return ""
	var nid := nation_at(region)
	if nid == "": return ""
	var n: Dictionary = _d()["nations"][nid]
	var me := Tiers.actor_id(actor)
	var citizen: bool = me in n["citizens"]
	if bool(n["laws"].get("quarantine", false)) and Disease.is_contagious(me): return "Quarantine: rest up and come back when you're well."
	if bool(n["laws"].get("vaccination_required", false)) and not citizen and not Disease.is_immune(me, "shiver_fever"): return "A shiver fever vaccine is required to enter."
	match str(n["border"]):
		"open": return ""
		"visa": return "" if citizen or me in n["visas"] else "You need a visa."
		"citizens_only", "closed": return "" if citizen else "The border is closed to visitors."
	return ""

static func reset_for_tests(p_root: String) -> void:
	root = p_root; _db = null
