class_name SectorPager
extends RefCounted
## LIFE-7: server-side sector paging. Viewers report their sector; sectors within `radius` of any
## viewer are kept active, the rest drop to an LRU cache of `cache_cap` sectors and then unload.
## The server can feed active sectors to Survival.set_region_active() so only active regions tick.

var radius := 1
var cache_cap := 64
var viewers := {}      # viewer id -> Vector3i sector
var active := {}       # Vector3i -> true
var cache: Array = []  # LRU of recently active sectors (oldest first)
var loads := 0
var unloads := 0

func _init(p_radius := 1, p_cache := 64) -> void:
	radius = p_radius; cache_cap = p_cache

func set_viewer(id: String, sector: Vector3i) -> void:
	viewers[id] = sector; _refresh()

func remove_viewer(id: String) -> void:
	viewers.erase(id); _refresh()

func is_active(s: Vector3i) -> bool: return active.has(s)
func is_loaded(s: Vector3i) -> bool: return active.has(s) or s in cache

func _refresh() -> void:
	var want := {}
	for v in viewers.values():
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					want[v + Vector3i(x, y, z)] = true
	for s in active.keys():
		if not want.has(s):
			active.erase(s); cache.append(s)
	for s in want:
		if not active.has(s):
			if s in cache: cache.erase(s)
			else: loads += 1
			active[s] = true
	while cache.size() > cache_cap:
		cache.pop_front(); unloads += 1
