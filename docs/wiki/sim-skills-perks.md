---
title: Skills & Perks
slug: sim-skills-perks
tags: [skills, xp, perks, progression, permissions]
audience: all
status: built
updated: 2026-10-17
sources: [scripts/sim/perk_tree.gd, scripts/sim/sim_gate.gd, scripts/progression/skill_by_use.gd, data/sim/perks.json]
ticket: SBX-22
---

# Skills & Perks

> **Built** (headless-tested). The HUD is Foxy's ([spec](../specs/foxy/sbx_hud_needs_skills.md)).

- **Skills grow by doing.** Build to raise building, gather to raise gathering, craft to raise crafting.
- **Perk points.** Every 3 skill levels you gain (across all skills) give one perk point. Quests can give
  bonus points.
- **Perks** need a skill level, sometimes another perk first, and some have several ranks.
  Examples: *Steady Hands* (faster building), *Keen Eye* (more from gathering), *Tinkerer* (chance of a
  bonus item when crafting), *Infuser* (stronger infusions).
- **Respec.** You can reset your own perks any time. Only the owner can reset a companion's.

## Who can do what (all sim systems)

Every sim action asks the same tier check as the rest of Viper OS ([Tiers](tiers.md)):

| Action | Needs |
|---|---|
| Track needs, earn XP, spend perk points | anyone (guests too) |
| Craft | Resident, and build rights on that land |
| Join a faction | Resident |
| Found a faction | Premium / Creator |
| Mark faction territory | Estate Manager for that region |
| Reset needs, respec others, set reputation | Owner, unlocked |

When the e-stop is on, companions can only look around.
