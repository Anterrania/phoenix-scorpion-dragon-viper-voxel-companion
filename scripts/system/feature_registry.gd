class_name FeatureRegistry
extends RefCounted
## Feature toggles by capability. A feature declares what it needs; evaluate(caps) turns off what the
## device can't do, with a plain reason string, instead of letting it fail later.
## Requirement keys (all optional):
##   camera, mic, gyro, haptics, xr: true   -> needs it (tri-state caps: only a definite 0/false disables)
##   compute: "vulkan"                       -> needs compute shaders (RenderingDevice)
##   min_ram_mb: int                         -> needs at least this much RAM (unknown RAM passes)
##   network: true                           -> needs a connection (only "none" disables; unknown passes)
##   form_factors: ["phone", ...]            -> only on these form factors
## Unknown never disables: Godot can't read some values on Android without a plugin (DEVICE_COMPAT.md §6).

static var _features: Dictionary = {}   # id -> {label, reqs, builtin}

## Built-in features. Systems may register more at startup with register().
const BUILTIN := {
	"voice_chat": {"label": "Voice chat", "reqs": {"mic": true, "network": true}},
	"voice_morph": {"label": "Voice morph + mic lip sync", "reqs": {"mic": true}},
	"camera_capture": {"label": "Camera (AR photo, face capture)", "reqs": {"camera": true}},
	"gyro_look": {"label": "Tilt to look", "reqs": {"gyro": true}},
	"haptics": {"label": "Vibration feedback", "reqs": {"haptics": true}},
	"compute_effects": {"label": "Compute effects (GPU particles, terrain shading)", "reqs": {"compute": "vulkan", "min_ram_mb": 3072}},
	"hi_res_textures": {"label": "High-resolution textures", "reqs": {"min_ram_mb": 6144}},
	"clip_capture": {"label": "In-world clip capture", "reqs": {"min_ram_mb": 3072}},
	"live_ai": {"label": "Live AI chat", "reqs": {"network": true}},
	"music_stream": {"label": "Music streams (radio, SoundCloud)", "reqs": {"network": true}},
	"broadcast": {"label": "Live broadcast", "reqs": {"network": true, "min_ram_mb": 3072}},
	"xr_mode": {"label": "VR / XR mode (future)", "reqs": {"xr": true}},
}

static func _ensure() -> void:
	if not _features.is_empty(): return
	for id in BUILTIN: _features[id] = {"label": BUILTIN[id]["label"], "reqs": BUILTIN[id]["reqs"], "builtin": true}

static func register(id: String, label: String, reqs: Dictionary) -> void:
	_ensure()
	_features[id] = {"label": label, "reqs": reqs.duplicate(true), "builtin": false}

static func ids() -> Array:
	_ensure()
	return _features.keys()

static func label(id: String) -> String:
	_ensure()
	return str(_features.get(id, {}).get("label", id))

static func reset_for_tests() -> void: _features.clear()

## "" when the device meets every requirement, else the first reason.
static func check(reqs: Dictionary, c: Dictionary) -> String:
	if reqs.get("camera", false) and int(c.get("camera", -1)) == 0: return "No camera found"
	if reqs.get("mic", false) and int(c.get("mic", -1)) == 0: return "No microphone found"
	if reqs.get("gyro", false) and int(c.get("gyro", -1)) == 0: return "No gyroscope"
	if reqs.get("haptics", false) and not bool(c.get("haptics", false)): return "No vibration motor"
	if reqs.get("xr", false) and not bool(c.get("xr", false)): return "No XR headset"
	if str(reqs.get("compute", "")) == "vulkan" and str(c.get("compute", "none")) != "vulkan":
		return "Needs Vulkan compute (this device runs %s)" % ("OpenGL ES 3" if str(c.get("compute")) == "gles3" else "no GPU compute")
	var need := int(reqs.get("min_ram_mb", 0))
	var ram := int(c.get("ram_mb", -1))
	if need > 0 and ram > 0 and ram < need: return "Needs %.0f GB RAM (this device has %.1f GB)" % [need / 1024.0, ram / 1024.0]
	if reqs.get("network", false) and str(c.get("network", "")) == "none": return "Offline (no network)"
	var ff: Array = reqs.get("form_factors", [])
	if not ff.is_empty() and not str(c.get("form_factor", "")) in ff: return "Not available on %s" % str(c.get("form_factor", ""))
	return ""

## {id: {on: bool, reason: String, label: String}} for these caps.
static func evaluate(c: Dictionary) -> Dictionary:
	_ensure()
	var out := {}
	for id in _features:
		var r := check(_features[id]["reqs"], c)
		out[id] = {"on": r == "", "reason": r, "label": _features[id]["label"]}
	return out
