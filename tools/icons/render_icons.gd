extends SceneTree
## v0.13 BRAND-1: rasterize assets/brand/*.svg (from make_icons.py) into the PNGs the exports use.
## godot --headless --path . --script res://tools/icons/render_icons.gd

const JOBS := [
	["icon.svg", "icon_192.png", 192], ["icon.svg", "icon_512.png", 512],
	["adaptive_foreground.svg", "adaptive_foreground_432.png", 432],
	["adaptive_background.svg", "adaptive_background_432.png", 432],
	["adaptive_monochrome.svg", "adaptive_monochrome_432.png", 432],
	["favicon.svg", "favicon_16.png", 16], ["favicon.svg", "favicon_32.png", 32],
	["favicon.svg", "favicon_144.png", 144], ["favicon.svg", "apple_touch_180.png", 180],
	["favicon.svg", "favicon_512.png", 512],
]

func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/brand")
	var bad := 0
	for j in JOBS:
		var src := FileAccess.get_file_as_string("res://assets/brand/" + j[0])
		var img := Image.new()
		if img.load_svg_from_string(src, float(j[2]) / 512.0) != OK:
			bad += 1
			continue
		img.save_png(dir.path_join(j[1]))
		print("  ", j[1], " ", img.get_size())
	print("render_icons: ", JOBS.size() - bad, " ok, ", bad, " failed")
	quit(1 if bad else 0)
