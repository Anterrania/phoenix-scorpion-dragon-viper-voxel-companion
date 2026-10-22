extends RefCounted
## Audit-gate tests (2026-10-17, fix/audit-gates): each gate is checked on the refused AND allowed path.
## AUDIT-2 admin writes, estate allow_fly / allow_damage, companion tools via Tiers.can, Tiers.set_role.

const POS_A := Vector3(1300, 0, 1300)    # a quiet region far from spawn and the arena
const POS_B := Vector3(-1300, 0, -1300)

static func _wipe_estate(pos: Vector3) -> void:
	var t := LandGate.target_at(pos)
	var c := Estate.cfg()
	for sec in ["region:" + t["region"], "parcel:%s/%s" % [t["region"], t["parcel"]]]:
		if c.has_section(sec): c.erase_section(sec)
	SecureFile.write_text(Estate.PATH, c.encode_to_text())

static func run(t: Node) -> void:
	var root := "user://test_gates_%d" % Time.get_ticks_usec()
	var old_tiers := Tiers.root
	Tiers.reset_for_tests(root.path_join("social"))
	ViperAdminData.root = root.path_join("viper"); ViperAdminData.reset()

	# --- AUDIT-2: admin writes need the owner session; reads stay open ---
	Tiers.owner_override = true
	var ts := ViperAdminData.tickets(); var ws := ViperAdminData.wiki(); var rs := ViperAdminData.revisions()
	var id := ts.create({"summary": "Gate fixture"}, "phoenix")
	var wrev := ws.save_page("GateNotes", "v1", "phoenix")
	t.check(id > 0 and wrev > 0 and AdminGate.ok(), "gate: unlocked owner creates ticket + wiki page")
	var head := rs.head()
	Tiers.owner_override = false
	t.check(not AdminGate.ok(), "gate: locked owner is not admin")
	t.check(ts.create({"summary": "Intruder"}, "x") == 0, "gate: ticket create refused while locked")
	t.check(ts.transition(id, "accepted", "x") == 0 and ts.get_ticket(id)["status"] == "new", "gate: ticket transition refused while locked")
	t.check(ts.update(id, {"priority": "P0"}, "x") == 0 and ts.get_ticket(id)["priority"] == "P2", "gate: ticket update refused while locked")
	t.check(ts.comment(id, "hi", "x") == 0 and ts.get_ticket(id)["comments"].is_empty(), "gate: ticket comment refused while locked")
	t.check(ws.save_page("GateNotes", "defaced", "x") == 0 and ws.get_text("GateNotes") == "v1", "gate: wiki save refused while locked")
	t.check(rs.revert(wrev, "x") == 0 and ws.get_text("GateNotes") == "v1", "gate: revision revert refused while locked")
	t.check(rs.head() == head, "gate: refused writes add no revisions")
	t.check(ts.query().size() > 0 and ws.names().has("GateNotes") and not rs.history("wiki/GateNotes").is_empty() and rs.diff(wrev) != "", "gate: tickets, wiki, history and diff stay readable while locked")
	t.check(AdminGate.estate_set(LandGate.target_at(POS_A)["region"], "", "allow_fly", false) == AdminGate.DENIED and bool(Estate.region_get(LandGate.target_at(POS_A)["region"], "allow_fly")), "gate: estate setting save refused while locked")
	Tiers.owner_override = true
	t.check(ts.transition(id, "accepted", "phoenix") > 0 and ts.comment(id, "ok", "phoenix") > 0 and ts.update(id, {"priority": "P1"}, "phoenix") > 0, "gate: unlocked owner transitions, comments, updates")
	var w2 := ws.save_page("GateNotes", "v2", "phoenix")
	t.check(w2 > 0 and rs.revert(w2, "phoenix") > 0 and ws.get_text("GateNotes") == "v1", "gate: unlocked owner saves + reverts wiki")
	var ra: String = LandGate.target_at(POS_A)["region"]
	t.check(AdminGate.estate_set(ra, "", "allow_fly", false) == "" and not bool(Estate.region_get(ra, "allow_fly")), "gate: unlocked owner saves estate setting")
	Tiers.set_tier("gate_mgr", "estate_manager")
	Tiers.owner_override = false
	t.check(AdminGate.land_ok(ra, "", "gate_mgr") and not AdminGate.land_ok(ra, "", "gate_res"), "gate: estate manager may edit land settings, a guest may not")
	_wipe_estate(POS_A)

	# --- Tiers.set_role: owner-gated, audited ---
	Tiers.owner_override = false
	var rh := rs.head()
	t.check(Tiers.set_role("circuit_nova", "staff") == "Owner unlock needed." and Tiers.assigned_tier("circuit_nova") == "resident", "set_role: refused while the owner session is locked")
	t.check(rs.head() == rh, "set_role: refused change is not logged")
	Tiers.owner_override = true
	t.check(Tiers.set_role("circuit_nova", "staff") == "" and Tiers.tier_of("circuit_nova") == "staff", "set_role: owner assigns Builder/Staff")
	var role_log := rs.history("role/circuit_nova", "role")
	t.check(role_log.size() == 1 and role_log[0]["before"] == "resident" and role_log[0]["after"] == "staff" and role_log[0]["author"] == Tiers.OWNER_ID, "set_role: audit revision role/<id> resident -> staff")
	t.check(Tiers.set_role("aaliyah", "Builder") == "" and Tiers.tier_of("aaliyah") == "staff", "set_role: 'builder' alias -> staff")
	t.check(Tiers.set_role("circuit_nova", "staff") == "" and rs.history("role/circuit_nova", "role").size() == 1, "set_role: no-op change adds no audit entry")
	t.check(Tiers.set_role("foxy_ani", "owner") != "" and Tiers.set_role(Tiers.OWNER_ID, "guest") != "" and Tiers.set_role("foxy_ani", "wizard") != "", "set_role: never owner, owner unchangeable, unknown role refused")
	t.check(rs.verify_chain()["ok"], "set_role: revision chain still verifies")
	Tiers.reset_for_tests(root.path_join("social2"))   # clean roles for the land checks

	# --- estate allow_fly ---
	Tiers.owner_override = false
	var tb := LandGate.target_at(POS_B)
	t.check(LandGate.can_fly("gate_visitor", POS_B), "fly: allowed by default (allow_fly true)")
	Estate.region_set(tb["region"], "allow_fly", false)
	t.check(not LandGate.can_fly("gate_visitor", POS_B), "fly: refused on a no-fly region")
	Estate.parcel_set(tb["region"], tb["parcel"], "allow_fly", true)
	t.check(LandGate.can_fly("gate_visitor", POS_B), "fly: parcel allow_fly overrides the region")
	Estate.parcel_set(tb["region"], tb["parcel"], "allow_fly", false)
	Tiers.owner_override = true
	t.check(LandGate.can_fly(Tiers.SELF, POS_B), "fly: unlocked owner flies anywhere")
	Tiers.owner_override = false
	t.check(not LandGate.can_fly(Tiers.SELF, POS_B), "fly: locked owner follows the land rule")
	_wipe_estate(POS_B)

	# --- estate allow_damage (+ arena default) ---
	var saved_zones := CombatZone.zones.duplicate()
	CombatZone.zones.clear()
	CombatZone.zones.append({"center": POS_B, "radius": 10.0})
	t.check(CombatZone.is_damage_enabled(POS_B) and not CombatZone.is_damage_enabled(POS_A), "damage: arena on, elsewhere off when the Estate is unset")
	Estate.region_set(tb["region"], "allow_damage", false)
	t.check(not CombatZone.is_damage_enabled(POS_B), "damage: owner switches the arena region off (allow_damage false)")
	var ta := LandGate.target_at(POS_A)
	Estate.parcel_set(ta["region"], ta["parcel"], "allow_damage", true)
	t.check(CombatZone.is_damage_enabled(POS_A), "damage: allow_damage true turns damage on outside arenas")
	_wipe_estate(POS_A); _wipe_estate(POS_B)
	CombatZone.zones = saved_zones

	# --- companion tools through Tiers.can(companion, build|land, parcel) ---
	var bot := "bot:gate_builder"
	var args := {"name": "pillar", "x": POS_A.x, "y": 0.0, "z": POS_A.z}
	t.check(LandGate.companion_tool_error(bot, "emote", {}, POS_A) == "", "companion: non-world tools always pass")
	t.check(LandGate.companion_tool_error(bot, "spawn_structure", args, POS_A).begins_with("land:"), "companion: Resident refused on owner_only land")
	Estate.region_set(ta["region"], "terraform", "everyone")
	t.check(LandGate.companion_tool_error(bot, "spawn_structure", args, POS_A) == "", "companion: Resident builds where terraform = everyone")
	Estate.region_set(ta["region"], "allow_build", false)
	t.check(LandGate.companion_tool_error(bot, "carve_area", args, POS_A) != "", "companion: allow_build false refuses even 'everyone' land")
	_wipe_estate(POS_A)
	Tiers.owner_override = true
	Tiers.set_role(bot, "staff")
	Tiers.owner_override = false
	t.check(LandGate.companion_tool_error(bot, "place_voxel", args, POS_A) == "", "companion: Builder/Staff builds on owner_only land")
	t.check(LandGate.companion_tool_error(bot, "build_realm", {}, POS_A) != "", "companion: Staff can't reshape the region (land)")
	Tiers.owner_override = true
	Tiers.set_role(bot, "estate_manager")
	Tiers.owner_override = false
	t.check(LandGate.companion_tool_error(bot, "build_realm", {}, POS_A) == "", "companion: Estate Manager may reshape the region")
	Estate.region_set(ta["region"], "banned", [bot])
	t.check(LandGate.companion_tool_error(bot, "place_voxel", args, POS_A) != "", "companion: banned companion refused")
	_wipe_estate(POS_A)

	Tiers.owner_override = null
	ViperAdminData.reset()
	Tiers.reset_for_tests(old_tiers)

## AgentBrain.dispatch_tool end to end: refused tools never reach the agent; allowed ones do.
static func run_scene(t: Node) -> void:
	var ab: Node = t.get_node_or_null("/root/AgentBrain")
	if ab == null:
		t.check(false, "gate: AgentBrain autoload present"); return
	var root := "user://test_gates_scene_%d" % Time.get_ticks_usec()
	var old_tiers := Tiers.root
	Tiers.reset_for_tests(root.path_join("social"))
	ViperAdminData.root = root.path_join("viper"); ViperAdminData.reset()
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar companion_id := \"\"\nvar persona := {}\nvar built := 0\nfunc tool_spawn_structure(a): built += 1; return {\"ok\": true}\n"
	gs.reload()
	var fake := Node3D.new(); fake.set_script(gs)
	fake.companion_id = "bot:gate_agent"
	fake.persona = {"tools": ["spawn_structure"]}
	t.add_child(fake)
	fake.global_position = POS_A
	ab._agents[fake.companion_id] = fake
	ab._memory[fake.companion_id] = ab.load_memory(fake.companion_id)
	var args := {"name": "pillar", "x": POS_A.x, "y": 0.0, "z": POS_A.z}
	var r: Dictionary = ab.dispatch_tool(fake.companion_id, "spawn_structure", args)
	t.check(not r.get("ok", false) and str(r.get("error", "")).begins_with("land:") and fake.built == 0, "gate: AgentBrain refuses a Resident companion's build on owner_only land")
	Tiers.owner_override = true
	Tiers.set_role(fake.companion_id, "builder")
	Tiers.owner_override = null
	r = ab.dispatch_tool(fake.companion_id, "spawn_structure", args)
	t.check(r.get("ok", false) and fake.built == 1, "gate: AgentBrain runs the build for a Builder/Staff companion")
	ab._agents.erase(fake.companion_id); ab._memory.erase(fake.companion_id)
	fake.queue_free()
	await t.get_tree().process_frame
	ViperAdminData.reset()
	Tiers.reset_for_tests(old_tiers)
