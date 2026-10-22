class_name DeviceCaps
extends RefCounted
## DeviceCaps: the caps() schema shared by DeviceProfile (detects), AutoConfig (maps) and Foxy's client
## (AutoQuality, HUD). Pure static functions only, so every rule is testable with fake profiles.
## Spec: docs/specs/foxy/device_profile_caps.md · Doc: docs/modules/DEVICE_COMPAT.md
##
## Rules (agreed with Foxy, 2026-10-17):
##  - Every key is always present. Unknown = -1 (numbers / tri-state) or "" (strings). Never omitted.
##  - Tri-state ints (camera, mic, accelerometer, gyro, power_save, charging): -1 unknown, 0 no, 1 yes.
##  - thermal: Android PowerManager thermal status 0..6 (NONE..SHUTDOWN), or -1.
##  - compute: "vulkan" | "gles3" | "none". form_factor: "phone" | "tablet" | "desktop" | "tv".
##  - network: "wifi" | "cell" | "none" | "" (unknown).
##  - schema starts at 1. Readers call normalize() so older/partial caps still work.
## PRIVACY: caps stay on the device. Nothing here is uploaded, logged remotely or written to the repo.

const SCHEMA := 1
## Keys refreshed every 30 s and on app focus (DeviceProfile.refresh_live()).
const LIVE_KEYS := ["battery_pct", "power_save", "charging", "thermal", "network", "orientation"]
const FORM_FACTORS := ["phone", "tablet", "desktop", "tv"]
const CLASSES := ["low", "mid", "high", "ultra"]
const TIERS := {"low": "low", "mid": "med", "high": "high", "ultra": "ultra"}   # class -> AutoQuality tier

## The full schema with its "unknown" values. normalize() fills missing keys from here.
static func defaults() -> Dictionary:
	return {
		"schema": SCHEMA, "source": "",                 # "engine" | "engine+plugin" | "fake"
		# system
		"os": "", "os_version": "", "android_api": -1, "model": "", "locale": "",
		"arch": "", "cpu_cores": -1, "cpu_name": "", "ram_mb": -1, "vram_mb": -1, "storage_free_mb": -1,
		# graphics
		"gpu": "", "gpu_vendor": "", "gpu_api": "", "renderer": "", "compute": "none",
		"astc": false, "etc2": false,
		# screen
		"screen_w": -1, "screen_h": -1, "dpi": -1, "screen_scale": -1.0, "refresh_hz": -1.0,
		"safe_area": Rect2i(), "orientation": "", "diag_in": -1.0, "form_factor": "phone", "foldable": false,
		# input + sensors + media
		"touch": false, "mouse": false, "keyboard": false, "gamepads": 0, "xr": false,
		"accelerometer": -1, "gyro": -1, "haptics": false,
		"camera": -1, "mic": -1, "camera_perm": "", "mic_perm": "",
		# live
		"battery_pct": -1, "charging": -1, "power_save": -1, "thermal": -1, "network": "",
		# derived
		"capability_score": -1, "capability_class": "", "headless": false, "detected_at": -1,
	}

## Fill missing keys, coerce types, and upgrade older schemas. Unknown future keys are kept untouched.
static func normalize(c: Dictionary) -> Dictionary:
	var d := defaults()
	var out := c.duplicate(true)
	for k in d:
		if not out.has(k) or out[k] == null: out[k] = d[k]
		elif typeof(d[k]) == TYPE_INT and typeof(out[k]) == TYPE_FLOAT: out[k] = int(out[k])
		elif typeof(d[k]) == TYPE_FLOAT and typeof(out[k]) == TYPE_INT: out[k] = float(out[k])
	if out["safe_area"] is Dictionary:   # JSON round-trip
		var s: Dictionary = out["safe_area"]
		out["safe_area"] = Rect2i(int(s.get("x", 0)), int(s.get("y", 0)), int(s.get("w", 0)), int(s.get("h", 0)))
	if not out["safe_area"] is Rect2i: out["safe_area"] = Rect2i()
	var ver := int(c.get("schema", 0))
	# schema 0 = caps from before the schema existed (no version key): treat like 1 with defaults filled.
	if ver < SCHEMA: out["schema"] = SCHEMA
	if not str(out["form_factor"]) in FORM_FACTORS: out["form_factor"] = "phone"
	if not str(out["compute"]) in ["vulkan", "gles3", "none"]: out["compute"] = "none"
	if not str(out["network"]) in ["wifi", "cell", "none", ""]: out["network"] = ""
	out["thermal"] = clampi(int(out["thermal"]), -1, 6)
	if int(out["capability_score"]) < 0 or str(out["capability_class"]) == "":
		out["capability_score"] = score(out)
		out["capability_class"] = capability_class(out)
	return out

## True when caps come from a newer schema than this build knows (still usable: known keys only).
static func is_newer(c: Dictionary) -> bool: return int(c.get("schema", 0)) > SCHEMA

# ---------- pure classification ----------
static func compute_of(renderer: String, has_rd: bool) -> String:
	if has_rd and renderer in ["forward_plus", "mobile"]: return "vulkan"
	if renderer == "gl_compatibility": return "gles3"
	return "none"

## Screen diagonal in inches from pixels + DPI (-1 when DPI is unknown).
static func diagonal_in(w: int, h: int, dpi: int) -> float:
	if w <= 0 or h <= 0 or dpi <= 0: return -1.0
	return snappedf(sqrt(float(w * w + h * h)) / float(dpi), 0.1)

## Form factor heuristic (Godot has no form-factor API; see DEVICE_COMPAT.md §2.4).
static func form_factor_of(os: String, touch: bool, diag: float, keyboard: bool, mouse: bool) -> String:
	if os in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Web"] and not touch: return "desktop"
	if os in ["Windows", "macOS", "Linux"]: return "desktop"   # touch laptops are still desktops
	if os in ["Android", "iOS"]:
		if not touch: return "tv"                                 # Android TV / Google TV: no touchscreen
		if keyboard and mouse and diag >= 11.0: return "desktop"  # ChromeOS, DeX, desktop mode
		if diag >= 7.0: return "tablet"
		return "phone"
	return "desktop" if not touch else "phone"

## Foldable guess: an Android touch screen that is nearly square at 7-9" (inner display unfolded).
static func foldable_of(os: String, touch: bool, w: int, h: int, diag: float) -> bool:
	if os != "Android" or not touch or w <= 0 or h <= 0: return false
	var ar := float(maxi(w, h)) / float(mini(w, h))
	return ar <= 1.35 and diag >= 6.8 and diag <= 9.0

static func orientation_of(w: int, h: int) -> String:
	if w <= 0 or h <= 0: return ""
	return "portrait" if h >= w else "landscape"

## Android release ("14", "13", "12L") -> API level. Godot exposes the release, not SDK_INT.
const ANDROID_API := {"16": 36, "15": 35, "14": 34, "13": 33, "12L": 32, "12": 31, "11": 30, "10": 29, "9": 28, "8.1": 27, "8.0": 26, "8": 26, "7.1": 25, "7.0": 24, "7": 24}
static func android_api_of(release: String) -> int:
	var r := release.strip_edges()
	if ANDROID_API.has(r): return ANDROID_API[r]
	var major := r.split(".")[0]
	return int(ANDROID_API.get(major, -1))

# ---------- capability score (documented in DEVICE_COMPAT.md §3) ----------
## GPU family points. Matching is on lower-case "vendor gpu" text. First match wins.
const GPU_POINTS := [
	["adreno (tm) 8", 15], ["adreno 8", 15], ["adreno (tm) 7", 15], ["adreno 7", 15],
	["adreno (tm) 6", 8], ["adreno 6", 8], ["adreno", 3],
	["immortalis", 15], ["mali-g7", 12], ["mali-g6", 8], ["mali-g5", 4], ["mali", 1],
	["xclipse", 12], ["powervr", 2], ["apple", 20],
	["nvidia", 25], ["geforce", 25], ["radeon", 25], ["amd", 25], ["intel", 8], ["llvmpipe", 0], ["swiftshader", 0],
]
static func gpu_points(vendor: String, gpu: String) -> int:
	var s := (vendor + " " + gpu).to_lower()
	if s.strip_edges() == "": return 5   # unknown GPU: neutral
	for p in GPU_POINTS:
		if s.contains(p[0]): return p[1]
	return 5

static func ram_points(mb: int) -> int:
	if mb < 0: return 10           # unknown: assume a modest phone
	if mb < 2048: return 0
	if mb < 3072: return 5
	if mb < 4096: return 10
	if mb < 6144: return 18
	if mb < 8192: return 24
	if mb < 12288: return 30
	return 35

static func core_points(n: int) -> int:
	if n < 0: return 4
	if n <= 4: return 2
	if n <= 6: return 6
	if n <= 8: return 10
	return 12

static func api_points(compute: String, renderer: String) -> int:
	if compute == "vulkan": return 20 if renderer == "forward_plus" else 15
	if compute == "gles3": return 5
	return 0

## 0..100 hardware score. Live state (battery, heat) is NOT scored: it picks the performance profile.
static func score(c: Dictionary) -> int:
	var s := ram_points(int(c.get("ram_mb", -1))) + core_points(int(c.get("cpu_cores", -1)))
	s += api_points(str(c.get("compute", "none")), str(c.get("renderer", "")))
	s += gpu_points(str(c.get("gpu_vendor", "")), str(c.get("gpu", "")))
	if float(c.get("refresh_hz", -1.0)) >= 119.0: s += 5
	if bool(c.get("astc", false)): s += 3
	return clampi(s, 0, 100)

## Class from score, then RAM caps: < 3 GB is always low, < 6 GB is at most high.
static func capability_class(c: Dictionary) -> String:
	var s := int(c.get("capability_score", -1))
	if s < 0: s = score(c)
	var cls := 0 if s < 30 else (1 if s < 55 else (2 if s < 78 else 3))
	var ram := int(c.get("ram_mb", -1))
	if ram > 0 and ram < 3072: cls = mini(cls, 0)
	elif ram > 0 and ram < 6144: cls = mini(cls, 2)
	return CLASSES[cls]

## JSON-safe copy (Rect2i -> dict) for the admin "copy report" and debug dumps. Local only.
static func to_json_safe(c: Dictionary) -> Dictionary:
	var o := c.duplicate(true)
	var r: Rect2i = o.get("safe_area", Rect2i())
	o["safe_area"] = {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}
	return o
