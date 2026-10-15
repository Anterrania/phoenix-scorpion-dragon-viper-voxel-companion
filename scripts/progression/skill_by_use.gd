# SCAFFOLD: Skyrim-style skill-by-use progression. Using a skill grants XP to that skill.
class_name SkillByUse
extends RefCounted

signal leveled_up(skill: String, level: int)

const MAX_LEVEL := 200
var skills: Dictionary = {}  # name -> {level, xp}
var learn_rate := 1.0        # modified by DNA traits

func xp_to_next(level: int) -> int:
	return int(10.0 * pow(level, 1.5)) + 10

func use(skill: String, base_xp := 1.0) -> void:
	var s: Dictionary = skills.get(skill, {"level": 1, "xp": 0.0})
	if s.level >= MAX_LEVEL:
		return
	s.xp += base_xp * learn_rate
	while s.level < MAX_LEVEL and s.xp >= xp_to_next(s.level):
		s.xp -= xp_to_next(s.level)
		s.level += 1
		leveled_up.emit(skill, s.level)
	skills[skill] = s

func character_level() -> int:
	var total := 0
	for s in skills.values():
		total += s.level - 1
	return 1 + total / 10
