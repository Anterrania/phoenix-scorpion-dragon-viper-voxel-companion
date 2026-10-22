---
title: Factions & Reputation
slug: sim-factions
tags: [factions, reputation, territory, groups, rpg]
audience: all
status: built
updated: 2026-10-17
sources: [scripts/sim/factions.gd, data/sim/factions.json]
ticket: SBX-SIM-3
---

# Factions & Reputation

> **Built** (headless-tested).

- **Starter factions:** Frost Wardens (tundra), Ember Court (Venus), Star Cartographers (cosmic),
  Free Builders (anywhere). Names and lore are our own.
- **Reputation** runs from -1000 to 1000: hostile, unfriendly, neutral, friendly, honored, exalted.
- **Allies and rivals.** Helping one faction also helps its allies a little and annoys its rivals.
- **Joining** needs Resident tier and at least neutral standing. Some factions won't take members of
  their rival.
- **Your own faction.** Premium / Creator members can found one. It can link to a Social group so roles
  and land reuse the group tools.
- **Territory.** An estate manager can mark which faction holds a region. Members earn 25% more
  reputation there. It's a label only: who can build is still the estate's land rules.
- **Owner only:** set anyone's reputation directly.

See also [Skills & Perks](sim-skills-perks.md) for the permission table.
