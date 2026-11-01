class_name Marketplace
extends RefCounted
## v0.5 local UGC marketplace model: import a .glb as an item with creator id,
## SL-style permissions (copy/modify/transfer), Aethel Coin price, mature flag and a
## moderation queue. Purchases use a local Aethel wallet. Server-backed later.

const DIR := "user://ugc"
const QUEUE := "user://ugc/catalog.json"
const WALLET := "user://ugc/wallet.json"
const MAX_BYTES := 8 * 1024 * 1024

static func _load(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path): return fallback
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d != null else fallback

static func _save(path: String, d: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d, "  "))

static func catalog() -> Array:
	return _load(QUEUE, [])

static func validate(item: Dictionary) -> String:
	var p: Dictionary = item.get("permissions", {})
	if not (bool(p.get("copy", false)) or bool(p.get("transfer", false))): return "need copy or transfer permission"
	if int(item.get("price_aethel", 0)) < 0: return "price must be >= 0"
	if not AvatarDNA.POINTS.has(str(item.get("attach_point", ""))) and str(item.get("kind", "")) in ["attachment", "clothing", "hair", "body_part"]: return "bad attach point"
	return ""

## Copy a .glb into user://ugc and queue it for moderation.
static func import_glb(src: String, name: String, creator_id: String, point: String, perms: Dictionary, price: int, mature: bool) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(src)
	if bytes.is_empty(): return {"error": "file not found"}
	if bytes.size() > MAX_BYTES: return {"error": "file too big (max 8 MB)"}
	if bytes.slice(0, 4).get_string_from_ascii() != "glTF": return {"error": "not a .glb file"}
	var id := "ugc_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	DirAccess.make_dir_recursive_absolute(DIR)
	var dst := "%s/%s.glb" % [DIR, id]
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var item := {"id": id, "name": name, "creator_id": creator_id, "kind": "attachment",
		"asset": {"format": "glb", "path": dst, "sha256": FileAccess.get_sha256(dst), "bytes": bytes.size()},
		"attach_point": point, "alpha_masks": [], "permissions": perms, "price_aethel": price,
		"mature": mature, "moderation": "pending", "created": Time.get_datetime_string_from_system()}
	var err := validate(item)
	if err != "": return {"error": err}
	var c := catalog()
	c.append(item)
	_save(QUEUE, c)
	return item

static func listed(mature_ok: bool) -> Array:
	return catalog().filter(func(i): return i["moderation"] == "approved" and (mature_ok or not bool(i.get("mature", false))))

static func set_moderation(id: String, status: String) -> void:
	var c := catalog()
	for i in c:
		if i["id"] == id: i["moderation"] = status
	_save(QUEUE, c)

## SBX-LEGAL-4: Aethel Coin now lives in AethelLedger (separate from play tokens). The old local
## wallet below is INACTIVE (kept for reference; it handed every device 100 free coins):
##   return int(_load(WALLET, {"aethel": 100}).get("aethel", 100))
static func balance(member := "local") -> int:
	return AethelLedger.balance(member)

## Fixed-price purchase only, through LegalReview (13+, launch country, price shown, spend limits).
## ctx: {age, country, price_shown: true}. Free items (price 0) need no ctx.
static func buy(item: Dictionary, buyer_id: String, ctx: Dictionary = {}, now := 0) -> String:
	if item.get("moderation", "") != "approved": return "not approved"
	if item.get("creator_id", "") == buyer_id: return "you made this"
	var price := int(item.get("price_aethel", 0))
	if price <= 0: return ""
	# INACTIVE (old local wallet debit): _save(WALLET, {"aethel": balance() - price})
	var tx := AethelLedger.purchase_fixed(buyer_id, str(item.get("id", "")), price, ctx, now if now > 0 else int(Time.get_unix_time_from_system()))
	# v0.13 ECON-1: the creator's share is paid in Sparks by the creator fund (no coin moves member to member).
	if not tx.has("error"): CreatorEconomy.on_sale(str(item.get("creator_id", "")), str(item.get("id", "")), price, now)
	return str(tx.get("error", ""))

## v0.6 stub: list a Satchel item locally ("List on Marketplace"). Server delivery later.
const LISTINGS := "user://ugc/listings.json"
static func list_inventory_item(item: Dictionary, merchant: String, price: int) -> Dictionary:
	var l := {"id": "lst_%d" % Time.get_ticks_usec(), "item_ref": item.get("id", ""), "title": item.get("name", ""),
		"merchant_id": merchant, "category": "Other", "price_aethel": maxi(price, 0), "status": "draft (server needed)",
		"permissions": {"copy": true, "modify": false, "transfer": false}}
	var all: Array = _load(LISTINGS, [])
	all.append(l)
	_save(LISTINGS, all)
	return l

static func listings() -> Array:
	return _load(LISTINGS, [])
