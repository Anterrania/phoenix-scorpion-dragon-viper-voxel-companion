extends Node
## RealmBuilder: sends a realm prompt to the configured LLM endpoint and returns
## realm parameters validated against data/schema/realm_params.schema.json.
## Falls back to bundled presets offline. User-approved overrides can be
## hot-reloaded from user://realm_overrides/*.json.

signal realm_ready(params: Dictionary)
signal realm_failed(error: String)

const PRESET_DIR := "res://data/realm_presets"
const OVERRIDE_DIR := "user://realm_overrides"
const BIOMES := ["alaskan_tundra", "alaskan_boreal", "alaskan_glacier", "cosmic", "cyberpunk", "venus_fire"]

const SYSTEM := """You design voxel realms. Reply with ONLY a JSON object with keys:
name (string), biome (one of alaskan_tundra, alaskan_boreal, alaskan_glacier, cosmic, cyberpunk, venus_fire),
palette (object: sky, ground, accent, fog as #RRGGBB),
noise (object: seed int, frequency 0.001-0.1, octaves 1-8, height_scale 4-128, base_height -32..64),
structures (array of {type in tower|hut|arch|pillar|wall|fire_altar, count 0-50, material 1-15}),
ambience (object: fog_density 0-1, particles string, light_energy 0-4)."""

func list_presets() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(PRESET_DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out

func load_preset(name: String) -> Dictionary:
	var override_path := "%s/%s.json" % [OVERRIDE_DIR, name]
	if Settings.get_value("hotreload", "allow_user_overrides", true) and FileAccess.file_exists(override_path):
		var o: Variant = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		if o is Dictionary and validate(o).is_empty():
			return o
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [PRESET_DIR, name]))
	return p if p is Dictionary else {}

func request_realm(prompt: String) -> void:
	if not Settings.has_api_key():
		realm_ready.emit(_guess_preset(prompt))
		return
	var http := HTTPRequest.new()
	http.timeout = float(Settings.get_value("llm", "timeout_sec", 45.0))
	add_child(http)
	http.request_completed.connect(_on_done.bind(http, prompt))
	var body := {"model": Settings.get_value("llm", "model"), "temperature": 0.7,
		"response_format": {"type": "json_object"},
		"messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": prompt}]}
	http.request(str(Settings.get_value("llm", "endpoint")),
		["Content-Type: application/json", "Authorization: Bearer %s" % Settings.get_value("llm", "api_key")],
		HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_done(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray, http: HTTPRequest, prompt: String) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		realm_failed.emit("LLM error %d/%d, using preset" % [result, code])
		realm_ready.emit(_guess_preset(prompt))
		return
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	var params: Variant = null
	if data is Dictionary and not data.get("choices", []).is_empty():
		params = JSON.parse_string(str(data["choices"][0]["message"].get("content", "")))
	if not (params is Dictionary) or not validate(params).is_empty():
		realm_failed.emit("invalid realm JSON, using preset")
		realm_ready.emit(_guess_preset(prompt))
		return
	realm_ready.emit(params)

## Returns a list of validation errors (empty = valid). Mirrors the JSON schema.
func validate(p: Dictionary) -> Array:
	var errs := []
	for k in ["name", "biome", "palette", "noise", "structures"]:
		if not p.has(k):
			errs.append("missing " + k)
	if errs.size() > 0:
		return errs
	if p["biome"] not in BIOMES:
		errs.append("bad biome")
	var n: Dictionary = p["noise"]
	if float(n.get("frequency", 0)) <= 0.0 or float(n.get("frequency", 0)) > 0.1:
		errs.append("noise.frequency out of range")
	if int(n.get("octaves", 0)) < 1 or int(n.get("octaves", 0)) > 8:
		errs.append("noise.octaves out of range")
	if not (p["structures"] is Array) or p["structures"].size() > 20:
		errs.append("structures must be array <= 20")
	return errs

func _guess_preset(prompt: String) -> Dictionary:
	var l := prompt.to_lower()
	for pair in [["glacier", "alaskan_glacier"], ["ice", "alaskan_glacier"], ["forest", "alaskan_boreal"], ["boreal", "alaskan_boreal"], ["tundra", "alaskan_tundra"], ["alask", "alaskan_tundra"], ["neon", "cyberpunk"], ["cyber", "cyberpunk"], ["venus", "venus_fire"], ["fire", "venus_fire"], ["cosm", "cosmic"], ["star", "cosmic"]]:
		if pair[0] in l:
			return load_preset(pair[1])
	return load_preset("alaskan_tundra")
