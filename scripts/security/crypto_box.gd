class_name CryptoBox
extends RefCounted
## Small crypto toolbox on Godot built-ins (no plugins):
## - PBKDF2-HMAC-SHA256 (RFC 8018) via Crypto.hmac_digest; Argon2 is not built into Godot.
## - Sealed boxes: AES-256-CBC (AESContext, random 16-byte IV, PKCS#7) + HMAC-SHA256 over
##   magic|iv|ciphertext (encrypt-then-MAC). Layout: "PXE1" | iv(16) | ct | mac(32).
## - SHA-256 helpers for the audit hash chain.

const MAGIC := "PXE1"
const DEFAULT_ITERATIONS := 310000   # ~0.15 s/100k on desktop; tune per device (stored per key slot)

## No static Crypto instance: a static RefCounted outlives the engine's crypto module at exit.
static func random_bytes(n: int) -> PackedByteArray: return Crypto.new().generate_random_bytes(n)

static func hmac(key: PackedByteArray, msg: PackedByteArray, c: Crypto = null) -> PackedByteArray:
	return (c if c else Crypto.new()).hmac_digest(HashingContext.HASH_SHA256, key, msg)

static func sha256(data: PackedByteArray) -> PackedByteArray:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return h.finish()

static func sha256_hex(text: String) -> String: return sha256(text.to_utf8_buffer()).hex_encode()

## PBKDF2-HMAC-SHA256. dklen <= 32*k; one 32-byte block per call to F.
static func pbkdf2_sha256(password: PackedByteArray, salt: PackedByteArray, iterations: int, dklen := 32) -> PackedByteArray:
	var c := Crypto.new()
	var out := PackedByteArray()
	var block := 1
	while out.size() < dklen:
		var ib := PackedByteArray([(block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255])
		var u := hmac(password, salt + ib, c)
		var a0 := u.decode_u64(0); var a1 := u.decode_u64(8); var a2 := u.decode_u64(16); var a3 := u.decode_u64(24)
		for i in iterations - 1:
			u = c.hmac_digest(HashingContext.HASH_SHA256, password, u)
			a0 ^= u.decode_u64(0); a1 ^= u.decode_u64(8); a2 ^= u.decode_u64(16); a3 ^= u.decode_u64(24)
		var t := PackedByteArray(); t.resize(32)
		t.encode_u64(0, a0); t.encode_u64(8, a1); t.encode_u64(16, a2); t.encode_u64(24, a3)
		out.append_array(t)
		block += 1
	return out.slice(0, dklen)

## Derive {enc, mac} 32-byte subkeys from a master secret (HMAC-based expansion).
static func subkeys(master: PackedByteArray) -> Dictionary:
	return {"enc": hmac(master, "phoenix/enc".to_utf8_buffer()), "mac": hmac(master, "phoenix/mac".to_utf8_buffer())}

static func is_sealed(data: PackedByteArray) -> bool:
	return data.size() >= 4 + 16 + 16 + 32 and data.slice(0, 4).get_string_from_ascii() == MAGIC

static func seal(enc_key: PackedByteArray, mac_key: PackedByteArray, plain: PackedByteArray) -> PackedByteArray:
	var iv := random_bytes(16)
	var pad := 16 - plain.size() % 16
	var p := plain.duplicate()
	for i in pad: p.append(pad)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, enc_key, iv)
	var ct := aes.update(p)
	aes.finish()
	var head := MAGIC.to_ascii_buffer() + iv + ct
	return head + hmac(mac_key, head)

## Returns the plaintext, or an empty array with ok=false in `status` on a bad MAC / format.
static func open(enc_key: PackedByteArray, mac_key: PackedByteArray, box: PackedByteArray, status := {}) -> PackedByteArray:
	status["ok"] = false
	if not is_sealed(box) or (box.size() - 4 - 16 - 32) % 16 != 0: return PackedByteArray()
	var head := box.slice(0, box.size() - 32)
	if not equal(hmac(mac_key, head), box.slice(box.size() - 32)): return PackedByteArray()
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, enc_key, box.slice(4, 20))
	var p := aes.update(box.slice(20, box.size() - 32))
	aes.finish()
	var pad := p[p.size() - 1] if p.size() > 0 else 0
	if pad < 1 or pad > 16: return PackedByteArray()
	status["ok"] = true
	return p.slice(0, p.size() - pad)

## Constant-time compare.
static func equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size(): return false
	var d := 0
	for i in a.size(): d |= a[i] ^ b[i]
	return d == 0
