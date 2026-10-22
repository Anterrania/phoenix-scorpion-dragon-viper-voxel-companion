class_name TarGz
extends RefCounted
## Minimal ustar/GNU tar reader + writer with gzip, on Godot built-ins (no plugins).
## Used for OpenSim/Aurora/WhiteCore OAR (region) and IAR (inventory) archives, which are
## gzip-compressed tar files. Reader limits protect a phone from hostile archives:
## MAX_UNPACKED total bytes, MAX_ENTRIES files, names with ".." or absolute paths are dropped.

const MAX_UNPACKED := 128 * 1024 * 1024
const MAX_ENTRIES := 50000
const BLOCK := 512

static func is_gzip(b: PackedByteArray) -> bool: return b.size() > 2 and b[0] == 0x1f and b[1] == 0x8b

static func gunzip(b: PackedByteArray) -> PackedByteArray:
	if not is_gzip(b): return b   # plain .tar is accepted too
	return b.decompress_dynamic(MAX_UNPACKED, FileAccess.COMPRESSION_GZIP)

static func _str(b: PackedByteArray, off: int, n: int) -> String:
	var s := b.slice(off, off + n)
	var z := s.find(0)
	if z >= 0: s = s.slice(0, z)
	return s.get_string_from_utf8()

static func _octal(b: PackedByteArray, off: int, n: int) -> int:
	var t := _str(b, off, n).strip_edges()
	var v := 0
	for c in t:
		if c < "0" or c > "7": break
		v = v * 8 + (c.unicode_at(0) - 48)
	return v

static func safe_name(n: String) -> bool:
	return n != "" and not n.begins_with("/") and not ".." in n.split("/") and not ":" in n

## {ok, error, entries: {path: PackedByteArray}, skipped: int}. Directories are omitted.
static func read(archive: PackedByteArray) -> Dictionary:
	var tar := gunzip(archive)
	if tar.is_empty(): return {"ok": false, "error": "Not a readable gzip/tar archive (or larger than %d MB unpacked)." % (MAX_UNPACKED >> 20), "entries": {}, "skipped": 0}
	var entries := {}
	var skipped := 0
	var off := 0
	var long_name := ""
	while off + BLOCK <= tar.size():
		var h := tar.slice(off, off + BLOCK)
		if h.count(0) == BLOCK: break   # end-of-archive marker
		var name := _str(h, 0, 100)
		var prefix := _str(h, 345, 155) if _str(h, 257, 5) == "ustar" else ""
		if prefix != "": name = prefix + "/" + name
		var size := _octal(h, 124, 12)
		var kind := char(h[156]) if h[156] != 0 else "0"
		off += BLOCK
		if off + size > tar.size(): return {"ok": false, "error": "Archive is truncated.", "entries": entries, "skipped": skipped}
		var data := tar.slice(off, off + size)
		off += ((size + BLOCK - 1) / BLOCK) * BLOCK
		match kind:
			"L": long_name = _str(data, 0, data.size()); continue      # GNU long name for the next entry
			"x", "g": continue                                          # pax headers: ignored
			"0", "7":
				if long_name != "": name = long_name
				long_name = ""
				name = name.trim_prefix("./")
				if not safe_name(name): skipped += 1; continue
				if entries.size() >= MAX_ENTRIES: return {"ok": false, "error": "Too many files in archive.", "entries": entries, "skipped": skipped}
				entries[name] = data
			_:
				long_name = ""   # directories, links: not extracted
	return {"ok": true, "error": "", "entries": entries, "skipped": skipped}

## Write a gzip'd ustar archive from {path: PackedByteArray|String}. Names must be < 100 bytes.
static func write(files: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	for path in files:
		var data: PackedByteArray = files[path] if files[path] is PackedByteArray else str(files[path]).to_utf8_buffer()
		var h := PackedByteArray(); h.resize(BLOCK); h.fill(0)
		var nb := str(path).to_utf8_buffer().slice(0, 99)
		for i in nb.size(): h[i] = nb[i]
		_put(h, 100, "%07o" % 420); _put(h, 108, "%07o" % 0); _put(h, 116, "%07o" % 0)
		_put(h, 124, "%011o" % data.size()); _put(h, 136, "%011o" % 0)
		h[156] = 48   # '0' regular file
		_put(h, 257, "ustar"); _put(h, 263, "00")
		for i in 8: h[148 + i] = 32
		var sum := 0
		for x in h: sum += x
		_put(h, 148, "%06o" % sum); h[154] = 0; h[155] = 32
		out.append_array(h)
		out.append_array(data)
		var pad := (BLOCK - data.size() % BLOCK) % BLOCK
		if pad > 0:
			var z := PackedByteArray(); z.resize(pad); z.fill(0); out.append_array(z)
	var end := PackedByteArray(); end.resize(BLOCK * 2); end.fill(0); out.append_array(end)
	return out.compress(FileAccess.COMPRESSION_GZIP)

static func _put(h: PackedByteArray, off: int, s: String) -> void:
	var b := s.to_ascii_buffer()
	for i in b.size(): h[off + i] = b[i]
