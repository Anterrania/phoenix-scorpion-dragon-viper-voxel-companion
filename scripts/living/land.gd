class_name Land
extends RefCounted
## LIFE-7: unlimited land addressing + rules.
## - No artificial object caps on land: object_cap() is unlimited (-1) wherever Tiers allows "build",
##   0 where it doesn't. WHO builds WHERE stays Tiers.can(actor, "build", parcel) (estate rules).
## - Phone safety is NOT a land rule: it comes from streaming, LOD/HLOD and per-viewer budgets
##   (render_budget(), used by Foxy's client renderer with her AutoQuality tiers low/med/high/ultra).
## - Addressing: planet > region > chunk. A region is a 1024 m sector; chunks are 64 m (= parcels).
##   Positions are stored as sector (Vector3i) + local (Vector3, 0..SECTOR_M) so float precision never
##   degrades far from the origin (floating origin). rebase() gives coordinates relative to a viewer's
##   sector for rendering; the server keeps sector+local.
## - Server-side paging: SectorPager keeps only the sectors near active viewers loaded.

const SECTOR_M := 1024.0
const CHUNK_M := 64.0
const UNLIMITED := -1
## Per-viewer render budgets (client renderer reads these; numbers are targets, not land limits).
const BUDGETS := {
	"low": {"view_m": 192.0, "lod_m": [48.0, 96.0, 192.0], "draw_calls": 300, "tris": 250000, "objects": 1500, "hlod_from_m": 96.0},
	"med": {"view_m": 384.0, "lod_m": [64.0, 160.0, 384.0], "draw_calls": 700, "tris": 800000, "objects": 4000, "hlod_from_m": 160.0},
	"high": {"view_m": 768.0, "lod_m": [96.0, 256.0, 768.0], "draw_calls": 1500, "tris": 2500000, "objects": 10000, "hlod_from_m": 256.0},
	"ultra": {"view_m": 1536.0, "lod_m": [128.0, 384.0, 1536.0], "draw_calls": 3000, "tris": 6000000, "objects": 25000, "hlod_from_m": 384.0},
}

static func render_budget(tier: String) -> Dictionary:
	return BUDGETS.get(tier, BUDGETS["low"]).duplicate(true)

static func object_cap(actor: Variant, parcel: Variant) -> int:
	return UNLIMITED if Tiers.can(actor, "build", parcel) else 0

static func can_place(actor: Variant, parcel: Variant, _count := 1) -> bool:
	return Tiers.can(actor, "build", parcel)   # count is never capped

## ---- sector + local (floating origin) ----
static func normalize(sector: Vector3i, local: Vector3) -> Dictionary:
	var s := sector; var l := local
	for a in 3:
		var shift := floori(l[a] / SECTOR_M)
		if shift != 0:
			s[a] += shift
			l[a] -= shift * SECTOR_M
	return {"sector": s, "local": l}

static func add(pos: Dictionary, delta: Vector3) -> Dictionary:
	return normalize(pos["sector"], pos["local"] + delta)

## Position relative to the viewer's sector origin (what the renderer uses).
static func rebase(pos: Dictionary, origin_sector: Vector3i) -> Vector3:
	var ds: Vector3i = pos["sector"] - origin_sector
	return Vector3(ds) * SECTOR_M + pos["local"]

## Distance in metres, computed in sector space (exact for huge coordinates).
static func distance(a: Dictionary, b: Dictionary) -> float:
	return rebase(b, a["sector"]).distance_to(a["local"])

static func from_world(p: Vector3) -> Dictionary: return normalize(Vector3i.ZERO, p)

## Address string: planet/region/chunk, e.g. "earth/r12_-3_0/c5_0_7".
static func address(planet: String, pos: Dictionary) -> String:
	var s: Vector3i = pos["sector"]; var l: Vector3 = pos["local"]
	var c := Vector3i(floori(l.x / CHUNK_M), floori(l.y / CHUNK_M), floori(l.z / CHUNK_M))
	return "%s/r%d_%d_%d/c%d_%d_%d" % [planet, s.x, s.y, s.z, c.x, c.y, c.z]

static func parse_address(addr: String) -> Dictionary:
	var p := addr.split("/")
	if p.size() != 3 or not p[1].begins_with("r") or not p[2].begins_with("c"): return {}
	var r := p[1].substr(1).split("_"); var c := p[2].substr(1).split("_")
	if r.size() != 3 or c.size() != 3: return {}
	return {"planet": p[0], "sector": Vector3i(int(r[0]), int(r[1]), int(r[2])),
		"chunk": Vector3i(int(c[0]), int(c[1]), int(c[2]))}
