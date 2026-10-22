class_name MediaTools
extends RefCounted
## Headless image utilities for social uploads (SMP-IMG). Our own code on Godot's Image API; no
## extra libraries. Filters / LUTs / adjustments / crop UI are Foxy's client editor
## (docs/specs/foxy/IMAGE_EDITOR.md); this file is only what the server side needs:
##  - validate(): format sniffing by magic bytes (PNG / JPEG / WebP only), byte cap, header size
##    check BEFORE decoding (decompression-bomb guard), then a real decode.
##  - has_metadata() / strip_metadata(): lossless removal of EXIF (incl. GPS), XMP, IPTC, comments
##    and text chunks from JPEG / PNG / WebP bytes.
##  - exif_orientation(): read the camera rotation before EXIF is dropped, so photos stay upright.
##  - thumbnail(), fit(), compress(): small WebP variants (full 1440, low 640, thumb 320 - sized to the Net budgets) so the app
##    and its feeds stay small. Re-encoding through Image also drops every metadata block.
##  - process_upload() / store_media(): the whole pipeline; refs look like "media:<sha16>".

const MAX_BYTES := 12 * 1024 * 1024
const MAX_SIDE_IN := 8192
const MAX_PIXELS := 40_000_000
const FULL_SIDE := 1440
const LOW_SIDE := 640    # = Net.IMAGE_PX["saver"]["image"] (checked by tests)
const THUMB_SIDE := 320  # = Net.IMAGE_PX["normal"]["thumb"]; FULL_SIDE 1440 <= Net "full" 2048
const QUALITY := 0.8
const LOW_QUALITY := 0.6
const THUMB_QUALITY := 0.7
static var root := "user://social/media"

static func sniff(b: PackedByteArray) -> String:
	if b.size() >= 8 and b[0] == 0x89 and b[1] == 0x50 and b[2] == 0x4E and b[3] == 0x47: return "png"
	if b.size() >= 3 and b[0] == 0xFF and b[1] == 0xD8 and b[2] == 0xFF: return "jpg"
	if b.size() >= 12 and b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "WEBP": return "webp"
	return ""

static func _be16(b: PackedByteArray, i: int) -> int: return (b[i] << 8) | b[i + 1]
static func _be32(b: PackedByteArray, i: int) -> int: return (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]
static func _le16(b: PackedByteArray, i: int) -> int: return b[i] | (b[i + 1] << 8)
static func _le24(b: PackedByteArray, i: int) -> int: return b[i] | (b[i + 1] << 8) | (b[i + 2] << 16)
static func _le32(b: PackedByteArray, i: int) -> int: return b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)

## Width/height from the header without decoding. Vector2i.ZERO if unknown.
static func header_size(b: PackedByteArray) -> Vector2i:
	match sniff(b):
		"png":
			if b.size() >= 24: return Vector2i(_be32(b, 16), _be32(b, 20))
		"jpg":
			var i := 2
			while i + 9 < b.size():
				if b[i] != 0xFF: i += 1; continue
				var mk := b[i + 1]
				if mk == 0xD8 or mk == 0x01 or (mk >= 0xD0 and mk <= 0xD7) or mk == 0xFF: i += 1 if mk == 0xFF else 2; continue
				var ln := _be16(b, i + 2)
				if mk in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]:
					return Vector2i(_be16(b, i + 7), _be16(b, i + 5))
				i += 2 + ln
		"webp":
			if b.size() >= 30:
				var fourcc := b.slice(12, 16).get_string_from_ascii()
				if fourcc == "VP8X": return Vector2i(_le24(b, 24) + 1, _le24(b, 27) + 1)
				if fourcc == "VP8 ": return Vector2i(_le16(b, 26) & 0x3FFF, _le16(b, 28) & 0x3FFF)
				if fourcc == "VP8L":
					var bits := _le32(b, 21)
					return Vector2i((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
	return Vector2i.ZERO

static func _decode(b: PackedByteArray, fmt: String) -> Image:
	var img := Image.new()
	var e := ERR_FILE_UNRECOGNIZED
	match fmt:
		"png": e = img.load_png_from_buffer(b)
		"jpg": e = img.load_jpg_from_buffer(b)
		"webp": e = img.load_webp_from_buffer(b)
	return img if e == OK and not img.is_empty() else null

## {ok, error, format, w, h, image}
static func validate(b: PackedByteArray) -> Dictionary:
	if b.is_empty(): return {"ok": false, "error": "Empty file."}
	if b.size() > MAX_BYTES: return {"ok": false, "error": "Images up to %d MB." % (MAX_BYTES / 1048576)}
	var fmt := sniff(b)
	if fmt == "": return {"ok": false, "error": "PNG, JPEG or WebP only."}
	var hs := header_size(b)
	if hs.x <= 0 or hs.y <= 0 or hs.x > MAX_SIDE_IN or hs.y > MAX_SIDE_IN or hs.x * hs.y > MAX_PIXELS: return {"ok": false, "error": "Image too large or damaged."}
	var img := _decode(b, fmt)
	if img == null: return {"ok": false, "error": "Can't read that image."}
	return {"ok": true, "error": "", "format": fmt, "w": img.get_width(), "h": img.get_height(), "image": img}

# ---------- metadata ----------
const _JPEG_DROP := [0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEF, 0xFE]   # APP1-13, APP15, COM (APP0 JFIF + APP14 Adobe kept: needed to decode)
const _PNG_DROP := ["eXIf", "tEXt", "zTXt", "iTXt", "tIME"]
const _WEBP_DROP := ["EXIF", "XMP "]

## True if the bytes carry EXIF / GPS / XMP / IPTC / comments / text chunks.
static func has_metadata(b: PackedByteArray) -> bool:
	match sniff(b):
		"jpg": return _jpeg_segments(b).any(func(s): return s[0] in _JPEG_DROP)
		"png": return _png_chunks(b).any(func(c): return c[0] in _PNG_DROP)
		"webp": return _webp_chunks(b).any(func(c): return c[0] in _WEBP_DROP)
	return false

## [[marker, start, end]] for the header segments before the image data (SOS).
static func _jpeg_segments(b: PackedByteArray) -> Array:
	var out: Array = []
	var i := 2
	while i + 4 <= b.size():
		if b[i] != 0xFF: break
		var mk := b[i + 1]
		if mk == 0xFF: i += 1; continue
		if mk == 0xDA or mk == 0xD9: break
		var ln := _be16(b, i + 2)
		if ln < 2 or i + 2 + ln > b.size(): break
		out.append([mk, i, i + 2 + ln])
		i += 2 + ln
	return out

static func _png_chunks(b: PackedByteArray) -> Array:
	var out: Array = []
	var i := 8
	while i + 12 <= b.size():
		var ln := _be32(b, i)
		var ty := b.slice(i + 4, i + 8).get_string_from_ascii()
		var end := i + 12 + ln
		if ln < 0 or end > b.size(): break
		out.append([ty, i, end])
		i = end
		if ty == "IEND": break
	return out

static func _webp_chunks(b: PackedByteArray) -> Array:
	var out: Array = []
	var i := 12
	while i + 8 <= b.size():
		var ty := b.slice(i, i + 4).get_string_from_ascii()
		var ln := _le32(b, i + 4)
		var end := i + 8 + ln + (ln & 1)
		if end > b.size(): end = b.size()
		out.append([ty, i, end])
		i = end
	return out

## Lossless: same pixels, no metadata blocks. Unknown formats come back unchanged.
static func strip_metadata(b: PackedByteArray) -> PackedByteArray:
	match sniff(b):
		"jpg":
			var segs := _jpeg_segments(b)
			if segs.is_empty(): return b
			var out := b.slice(0, 2)
			for s in segs:
				if not s[0] in _JPEG_DROP: out.append_array(b.slice(s[1], s[2]))
			out.append_array(b.slice(segs[-1][2]))
			return out
		"png":
			var out := b.slice(0, 8)
			for c in _png_chunks(b):
				if not c[0] in _PNG_DROP: out.append_array(b.slice(c[1], c[2]))
			return out
		"webp":
			var body := PackedByteArray()
			for c in _webp_chunks(b):
				if c[0] in _WEBP_DROP: continue
				var chunk := b.slice(c[1], c[2])
				if c[0] == "VP8X" and chunk.size() > 8: chunk[8] = chunk[8] & ~0x0C   # clear EXIF + XMP flags
				body.append_array(chunk)
			var out := "RIFF".to_ascii_buffer()
			var n := body.size() + 4
			out.append_array(PackedByteArray([n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF]))
			out.append_array("WEBP".to_ascii_buffer()); out.append_array(body)
			return out
	return b

## EXIF orientation 1..8 (1 = upright / unknown). JPEG only.
static func exif_orientation(b: PackedByteArray) -> int:
	if sniff(b) != "jpg": return 1
	for s in _jpeg_segments(b):
		if s[0] != 0xE1: continue
		var a: int = s[1] + 4
		if b.slice(a, a + 6) != PackedByteArray([0x45, 0x78, 0x69, 0x66, 0, 0]): continue
		var t := a + 6
		if t + 8 > b.size(): return 1
		var le := b[t] == 0x49
		var r16 := func(i: int) -> int: return (b[i] | (b[i + 1] << 8)) if le else ((b[i] << 8) | b[i + 1])
		var r32 := func(i: int) -> int: return (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)) if le else _be32(b, i)
		var ifd: int = t + r32.call(t + 4)
		if ifd + 2 > b.size(): return 1
		var n: int = r16.call(ifd)
		for k in n:
			var e: int = ifd + 2 + k * 12
			if e + 12 > b.size(): break
			if r16.call(e) == 0x0112:
				var v: int = r16.call(e + 8)
				return v if v >= 1 and v <= 8 else 1
	return 1

static func apply_orientation(img: Image, o: int) -> void:
	match o:
		2: img.flip_x()
		3: img.rotate_180()
		4: img.flip_y()
		5: img.rotate_90(CLOCKWISE); img.flip_x()
		6: img.rotate_90(CLOCKWISE)
		7: img.rotate_90(COUNTERCLOCKWISE); img.flip_x()
		8: img.rotate_90(COUNTERCLOCKWISE)

# ---------- sizes + compression ----------
## Copy scaled so the longest side is <= max_side (never upscaled).
static func fit(img: Image, max_side: int) -> Image:
	var out := img.duplicate() as Image
	var s := maxi(out.get_width(), out.get_height())
	if s > max_side:
		var k := float(max_side) / s
		out.resize(maxi(1, roundi(out.get_width() * k)), maxi(1, roundi(out.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return out

## Centre-cropped square (square=true) or fitted thumbnail.
static func thumbnail(img: Image, side := THUMB_SIDE, square := true) -> Image:
	if not square: return fit(img, side)
	var w := img.get_width(); var h := img.get_height(); var m := mini(w, h)
	var out := img.get_region(Rect2i((w - m) / 2, (h - m) / 2, m, m))
	if m > side: out.resize(side, side, Image.INTERPOLATE_LANCZOS)
	return out

## Lossy WebP bytes (no metadata). Images with real transparency keep their alpha.
static func compress(img: Image, quality := QUALITY, max_side := FULL_SIDE) -> PackedByteArray:
	var out := fit(img, max_side)
	if out.is_compressed(): out.decompress()
	if out.get_format() != Image.FORMAT_RGBA8 and out.get_format() != Image.FORMAT_RGB8: out.convert(Image.FORMAT_RGBA8 if out.detect_alpha() != Image.ALPHA_NONE else Image.FORMAT_RGB8)
	return out.save_webp_to_buffer(true, quality)

## Full pipeline. {ok, error, full, low, thumb (PackedByteArray WebP), w, h, bytes_in, bytes_out,
## sha, alt, missing_alt, had_metadata}. Needs the "post" tier (residents and up).
static func process_upload(actor: Variant, bytes: PackedByteArray, alt := "") -> Dictionary:
	if not Tiers.can(actor, "post"): return {"ok": false, "error": "Residents and up can post photos."}
	var v := validate(bytes)
	if not v["ok"]: return v
	var img: Image = v["image"]
	apply_orientation(img, exif_orientation(bytes))
	var full := compress(img, QUALITY, FULL_SIDE)
	var low := compress(img, LOW_QUALITY, LOW_SIDE)
	var th := thumbnail(img).save_webp_to_buffer(true, THUMB_QUALITY)
	var a := Social.clean(alt, 1000)
	var fitted := fit(img, FULL_SIDE)
	return {"ok": true, "error": "", "full": full, "low": low, "thumb": th, "w": fitted.get_width(), "h": fitted.get_height(),
		"bytes_in": bytes.size(), "bytes_out": full.size(), "sha": _sha16(full), "alt": a, "missing_alt": a == "",
		"had_metadata": has_metadata(bytes)}

static func _sha16(b: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(b)
	return h.finish().hex_encode().left(16)

## Writes <sha>.webp, <sha>_low.webp, <sha>_t.webp under root. Returns a Social.post media item
## {ref "media:<sha>", thumb_ref, low_ref, alt, type, w, h}.
static func store_media(r: Dictionary) -> Dictionary:
	if not r.get("ok", false): return {}
	DirAccess.make_dir_recursive_absolute(root)
	for pair in [["", "full"], ["_low", "low"], ["_t", "thumb"]]:
		var f := FileAccess.open(root.path_join(str(r["sha"]) + pair[0] + ".webp"), FileAccess.WRITE)
		if f == null: return {}
		f.store_buffer(r[pair[1]]); f.close()
	var ref := "media:" + str(r["sha"])
	return {"ref": ref, "thumb_ref": ref + "_t", "low_ref": ref + "_low", "alt": r["alt"], "type": "image", "w": r["w"], "h": r["h"]}

## Path on disk for a media ref (media:<sha>, media:<sha>_t, media:<sha>_low), "" if unknown.
static func path_of(ref: String) -> String:
	if not ref.begins_with("media:"): return ""
	var id := ref.substr(6)
	for ch in id:
		if not ch in "0123456789abcdef_lowt": return ""
	var p := root.path_join(id + ".webp")
	return p if FileAccess.file_exists(p) else ""
