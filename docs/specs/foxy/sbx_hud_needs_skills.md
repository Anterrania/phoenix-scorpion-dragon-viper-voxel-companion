# Foxy spec: needs, skills, perks and standing on the HUD (SBX-31)

Owner: **Foxy** (client HUD). Dev side is shipped: `NeedsMood`, `PerkTree`, `Factions` (scripts/sim/).
Features only here; look and layout follow the Phoenix Glass kit and PhoenixTokens (compact default,
one-tap Large, portrait + auto-rotate, no bounce, at most one glow).

## What the player must be able to do
- See the companion's (and later the player's) mood word and the 2 lowest needs at a glance.
- Open a detail sheet: all needs 0-100, active moodlets with minutes left, relaxed-mode toggle (owner only
  for companions).
- See skills and levels, perk points available, and unlock a perk (shows the reason when it can't).
- See faction standing: rank word per faction, member badge, territory owner for the current region.

## API (read-only unless noted)
- `NeedsMood.load_for(companion_id)` → `.mood()`, `.mood_score()`, `.values`, `.moodlets`, `.critical()`,
  `.suggest()`; `.relaxed = bool` then `.save()`; owner reset: `.reset_needs()` (returns false if locked).
- `PerkTree`: `.points_available()`, `.skill_level(skill)`, `.defs()`, `.why_not(id)`, `.unlock(id)` → ""
  or reason; `.respec()`.
- `Factions.load_saved()`: `.rank(actor, faction)`, `.is_member(actor, f)`, `.territory[region]`.
- Poll at most once per second and only while visible (same rule as the minimap throttle patch).

## Hook point
`patches/companion_life_needs_mood.patch` ties `CompanionLife` energy to `NeedsMood`. Apply it before the
HUD reads needs from live companions.
