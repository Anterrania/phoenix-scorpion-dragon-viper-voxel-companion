class_name OpenSimArchive
extends RefCounted
## Read-only importer for OpenSimulator / Aurora-Sim / WhiteCore archives (clean-room, from the
## public archive layout; OpenSim and Aurora/WhiteCore are BSD-3-Clause, see docs/modules/INTEROP.md).
## - OAR (region archive): archive.xml, terrains/<region>.r32, objects/*.xml, assets/<uuid>_<type>,
##   landdata/<uuid>.xml, settings/<region>.xml. We read terrain + summaries. Prims are NOT converted
##   (prim -> voxel conversion is lossy; it's on the roadmap).
## - IAR (inventory archive): inventory/<folders>/<item>__<uuid>.xml + assets/. We read item names,
##   types and next-owner permissions, and extract notecard TEXT. Textures are listed (JPEG 2000 is
##   not decodable by Godot, so they are marked "needs conversion").
## Terrain formats: RAW32 (.r32: little-endian float32, row-major y then x, square, no header; what
## OpenSim writes into OARs) and LLRAW (.raw: 13 bytes/pixel, height = b0 * b1 / 128, rows bottom-up).
## Nothing here touches the network or runs scripts from the archive.

const ASSET_TYPES := {   # OpenSim ArchiveConstants ASSET_TYPE_TO_EXTENSION (suffix after "_")
	"texture.jp2": "texture", "texture.tga": "texture", "image.jpg": "texture", "image.tga": "texture",
	"sound.ogg": "sound", "sound.wav": "sound", "animation.bvh": "animation", "bodypart.txt": "bodypart",
	"clothing.txt": "clothing", "notecard.txt": "notecard", "script.lsl": "script", "object.xml": "object",
	"mesh.llmesh": "mesh", "landmark.txt": "landmark", "gesture.txt": "gesture", "material.xml": "material",
	"settings.bin": "environment", "callingcard.txt": "callingcard", "bytecode.lso": "bytecode",
}
## OpenSim/SL permission bits (PermissionMask): Transfer 1<<13, Modify 1<<14, Copy 1<<15.
const PERM_TRANSFER := 8192
const PERM_MODIFY := 16384
const PERM_COPY := 32768
const MAX_NOTECARD := 65536

# ---------- terrain ----------
## RAW32 -> {ok, size, heights: PackedFloat32Array, min, max, mean}. size = sqrt(floats) (square).
static func parse_r32(b: PackedByteArray) -> Dictionary:
	var n := b.size() / 4
	var side := int(sqrt(float(n)))
	if n == 0 or side * side != n or b.size() % 4 != 0: return {"ok": false, "error": "RAW32 terrain must be a square float32 grid."}
	var h := b.to_float32_array()   # little-endian, same as OpenSim's BinaryWriter
	return _stats({"ok": true, "size": side, "heights": h})

## LLRAW (.raw, 13 channels) -> same dict. Rows are stored top-down in the file (SL convention).
static func parse_llraw(b: PackedByteArray) -> Dictionary:
	var n := b.size() / 13
	var side := int(sqrt(float(n)))
	if n == 0 or side * side != n or b.size() % 13 != 0: return {"ok": false, "error": "LLRAW terrain must be a square 13-channel grid."}
	var h := PackedFloat32Array(); h.resize(n)
	for y in side:
		for x in side:
			var i := (y * side + x) * 13
			h[(side - 1 - y) * side + x] = float(b[i]) * (float(b[i + 1]) / 128.0)
	return _stats({"ok": true, "size": side, "heights": h})

static func _stats(d: Dictionary) -> Dictionary:
	var h: PackedFloat32Array = d["heights"]
	var lo := INF; var hi := -INF; var sum := 0.0
	for v in h:
		if is_nan(v) or is_inf(v): return {"ok": false, "error": "Terrain has invalid heights."}
		lo = minf(lo, v); hi = maxf(hi, v); sum += v
	d["min"] = lo; d["max"] = hi; d["mean"] = sum / maxf(1.0, float(h.size()))
	return d

## Downsample (box filter) to target x target and shift so OpenSim's water level lands on ours.
## OpenSim default water is 20 m; Viper's default region water_height is -3 m (Estate). Heights are
## clamped to the voxel generator's sane band (-20..48). Returns {size, heights: Array[float], src_size}.
static func to_viper_heightmap(t: Dictionary, target := 64, water_src := 20.0, water_dst := -3.0) -> Dictionary:
	var side: int = t["size"]
	var h: PackedFloat32Array = t["heights"]
	target = clampi(target, 2, side)
	var out: Array = []
	var cell := float(side) / float(target)
	for ty in target:
		for tx in target:
			var x0 := int(tx * cell); var x1 := maxi(x0 + 1, int((tx + 1) * cell))
			var y0 := int(ty * cell); var y1 := maxi(y0 + 1, int((ty + 1) * cell))
			var s := 0.0; var c := 0
			for y in range(y0, mini(y1, side)):
				for x in range(x0, mini(x1, side)):
					s += h[y * side + x]; c += 1
			out.append(snappedf(clampf(s / maxf(1, c) - water_src + water_dst, -20.0, 48.0), 0.01))
	return {"size": target, "heights": out, "src_size": side, "water_src": water_src, "water_dst": water_dst}

# ---------- XML helpers ----------
## Flat {element_name: text} of the FIRST occurrence of each leaf element (enough for landdata,
## inventory items and region settings, which are shallow).
static func xml_leaves(text: String) -> Dictionary:
	var out := {}
	var p := XMLParser.new()
	if p.open_buffer(text.to_utf8_buffer()) != OK: return out
	var cur := ""
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				cur = p.get_node_name()
				if p.is_empty() and not out.has(cur): out[cur] = ""
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if cur != "" and not out.has(cur):
					var t := p.get_node_data().strip_edges()
					if t != "": out[cur] = t
			XMLParser.NODE_ELEMENT_END:
				cur = ""
	return out

static func _attr(text: String, element: String, attr: String) -> String:
	var p := XMLParser.new()
	if p.open_buffer(text.to_utf8_buffer()) != OK: return ""
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == element:
			return p.get_named_attribute_value_safe(attr)
	return ""

static func asset_kind(path: String) -> String:
	var f := path.get_file()
	var us := f.find("_")
	return ASSET_TYPES.get(f.substr(us + 1) if us >= 0 else "", "other")

# ---------- notecards ----------
## SL/OpenSim notecard asset ("Linden text version 2 { LLEmbeddedItems ... } Text length N\n<text>}")
## -> plain text. Plain text files are returned as-is. Capped at MAX_NOTECARD bytes.
static func notecard_text(b: PackedByteArray) -> String:
	var s := b.slice(0, MAX_NOTECARD * 2).get_string_from_utf8()
	if not s.begins_with("Linden text version"): return s.left(MAX_NOTECARD)
	var re := RegEx.new(); re.compile("Text length (\\d+)\\n")
	var m := re.search(s)
	if m == null: return ""
	var start := m.get_end()
	var body := s.to_utf8_buffer().slice(s.left(start).to_utf8_buffer().size())   # length is in BYTES
	var n := mini(int(m.get_string(1)), MAX_NOTECARD)
	return body.slice(0, n).get_string_from_utf8()

# ---------- whole archives ----------
## OAR summary. {ok, error, kind:"oar", version, region_size, terrains:[{name,size,min,max,mean}],
##  objects, assets:{kind: n}, parcels:[{name, area, sale_price, flags, viper_flags}], settings:{...}, skipped}
static func inspect_oar(archive: PackedByteArray) -> Dictionary:
	var r := TarGz.read(archive)
	if not r["ok"]: return {"ok": false, "error": r["error"]}
	var e: Dictionary = r["entries"]
	if not e.has("archive.xml"): return {"ok": false, "error": "No archive.xml: not an OAR."}
	if e.keys().any(func(k): return str(k).begins_with("inventory/")): return {"ok": false, "error": "This is an IAR (inventory archive), not an OAR."}
	var ax := (e["archive.xml"] as PackedByteArray).get_string_from_utf8()
	var rep := {"ok": true, "error": "", "kind": "oar", "skipped": r["skipped"],
		"version": "%s.%s" % [_attr(ax, "archive", "major_version"), _attr(ax, "archive", "minor_version")],
		"region_size": xml_leaves(ax).get("size_in_meters", "256,256"),
		"terrains": [], "objects": 0, "assets": {}, "parcels": [], "settings": {}}
	for path in e:
		var b: PackedByteArray = e[path]
		if path.begins_with("terrains/"):
			var t := parse_r32(b) if path.ends_with(".r32") else parse_llraw(b) if path.ends_with(".raw") else {"ok": false, "error": "unsupported terrain format"}
			var row := {"name": path.get_file().get_basename(), "path": path, "ok": t["ok"]}
			if t["ok"]: row.merge({"size": t["size"], "min": snappedf(t["min"], 0.01), "max": snappedf(t["max"], 0.01), "mean": snappedf(t["mean"], 0.01)})
			else: row["error"] = t["error"]
			rep["terrains"].append(row)
		elif path.begins_with("objects/") and path.ends_with(".xml"): rep["objects"] += 1
		elif path.begins_with("assets/"):
			var k := asset_kind(path)
			rep["assets"][k] = int(rep["assets"].get(k, 0)) + 1
		elif path.begins_with("landdata/") and path.ends_with(".xml"):
			var l := xml_leaves(b.get_string_from_utf8())
			var fl := int(l.get("Flags", "0"))
			rep["parcels"].append({"name": str(l.get("Name", "")).left(64), "area": int(l.get("Area", "0")),
				"sale_price": int(l.get("SalePrice", "0")), "flags": fl, "viper_flags": Estate.flags_from_sl(fl)})
		elif path.begins_with("settings/") and path.ends_with(".xml"):
			var s := xml_leaves(b.get_string_from_utf8())
			for k in ["AllowDamage", "BlockFly", "BlockTerraform", "RestrictPushing", "AllowLandResell", "AllowLandJoinDivide",
					"BlockShowInSearch", "AgentLimit", "MaturityRating", "DisableScripts", "DisablePhysics", "WaterHeight", "FixedSun"]:
				if s.has(k): rep["settings"][k] = s[k]
	return rep

## The first valid terrain of an OAR as {ok, name, terrain} (terrain = parse_r32/parse_llraw dict).
static func oar_terrain(archive: PackedByteArray) -> Dictionary:
	var r := TarGz.read(archive)
	if not r["ok"]: return {"ok": false, "error": r["error"]}
	for path in r["entries"]:
		if path.begins_with("terrains/") and (path.ends_with(".r32") or path.ends_with(".raw")):
			var b: PackedByteArray = r["entries"][path]
			var t := parse_r32(b) if path.ends_with(".r32") else parse_llraw(b)
			if t["ok"]: return {"ok": true, "name": path.get_file().get_basename(), "terrain": t}
	return {"ok": false, "error": "No readable terrain in this OAR."}

## IAR summary + notecard texts. {ok, error, kind:"iar", items:[{name, type, asset_id, next_copy,
##  next_modify, next_transfer, folder}], notecards:{name: text}, textures:[{name, format, convertible}]}
static func inspect_iar(archive: PackedByteArray) -> Dictionary:
	var r := TarGz.read(archive)
	if not r["ok"]: return {"ok": false, "error": r["error"]}
	var e: Dictionary = r["entries"]
	var by_asset := {}   # uuid -> asset path
	for path in e:
		if path.begins_with("assets/"): by_asset[path.get_file().get_slice("_", 0)] = path
	var rep := {"ok": true, "error": "", "kind": "iar", "skipped": r["skipped"], "items": [], "notecards": {}, "textures": []}
	var any_inv := false
	for path in e:
		if not (path.begins_with("inventory/") and path.ends_with(".xml")): continue
		any_inv = true
		var l := xml_leaves((e[path] as PackedByteArray).get_string_from_utf8())
		if not l.has("AssetID"): continue
		var np := int(l.get("NextPermissions", "0"))
		var aid := str(l["AssetID"])
		var ap: String = by_asset.get(aid, "")
		var kind := asset_kind(ap) if ap != "" else "missing"
		var item := {"name": str(l.get("Name", "")).left(64), "type": kind, "asset_id": aid,
			"next_copy": (np & PERM_COPY) != 0, "next_modify": (np & PERM_MODIFY) != 0, "next_transfer": (np & PERM_TRANSFER) != 0,
			"folder": path.get_base_dir().trim_prefix("inventory/").get_slice("__", 0)}
		rep["items"].append(item)
		if kind == "notecard": rep["notecards"][item["name"]] = notecard_text(e[ap])
		elif kind == "texture":
			var fmt := ap.get_extension()
			rep["textures"].append({"name": item["name"], "format": fmt, "convertible": fmt in ["tga", "jpg"]})
	if not any_inv: return {"ok": false, "error": "No inventory/ folder: not an IAR."}
	return rep
