class_name EnvPresets
extends RefCounted
## v0.7 windlight-style environment presets (original values) + day/night cycle.
## Fields: sky top, horizon, ground, fog, sun color, sun energy, sun pitch (deg),
## stars, ambient energy.
const PRESETS := {
	"Sunrise":     ["#2a3a7a", "#ffb38a", "#c9b8b0", "#e8b8a0", "#ffcf9a", 0.9, -8.0, 0.25, 0.7],
	"Midday":      ["#1a4fa8", "#a8d0ff", "#d0dce8", "#bcd2ea", "#fff6e8", 1.5, -60.0, 0.0, 1.0],
	"Sunset":      ["#3a1a5a", "#ff6a3a", "#5a2a2a", "#c86a5a", "#ff8a4a", 0.9, -6.0, 0.3, 0.65],
	"Midnight":    ["#020210", "#141a3a", "#05050a", "#10142a", "#9ab0ff", 0.15, -40.0, 1.4, 0.3],
	"Venus Storm": ["#1a0404", "#c03a10", "#200404", "#7a2010", "#ff8a4a", 1.1, -25.0, 0.1, 0.8],
	"Cosmic":      ["#03010d", "#5a1fa0", "#0c0620", "#2b1257", "#e4d0ff", 0.9, -35.0, 1.5, 0.75],
}
const CYCLE := ["Midnight", "Sunrise", "Midday", "Sunset"]  # at 0h, 6h, 12h, 18h
const DAY_SECONDS := 24.0 * 60.0  # one in-game day = 24 real minutes

## Blend the 4 cycle presets for an hour 0..24.
static func cycle_values(hour: float) -> Array:
	var h := fposmod(hour, 24.0)
	var i := int(h / 6.0) % 4
	var t := (h - i * 6.0) / 6.0
	return lerp_preset(PRESETS[CYCLE[i]], PRESETS[CYCLE[(i + 1) % 4]], t)

static func lerp_preset(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for k in a.size():
		if a[k] is String: out.append(Color(a[k]).lerp(Color(b[k]), t).to_html(false))
		else: out.append(lerpf(float(a[k]), float(b[k]), t))
	return out

static func clock_text(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
