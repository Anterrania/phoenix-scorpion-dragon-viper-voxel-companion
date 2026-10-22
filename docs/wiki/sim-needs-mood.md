---
title: Needs & Mood
slug: sim-needs-mood
tags: [needs, mood, companions, npc, life-sim, autonomy]
audience: all
status: built
updated: 2026-10-17
sources: [scripts/sim/needs_mood.gd, docs/modules/NEEDS.md, docs/modules/SANDBOX_PARITY.md]
ticket: SBX-SIM-1
---

# Needs & Mood

> **Built** (headless-tested). The HUD for it is Foxy's next step ([spec](../specs/foxy/sbx_hud_needs_skills.md)).

Companions (and NPCs) have needs from 0 to 100 that slowly go down:
hunger, energy, social, fun, hygiene, comfort and purpose. **Warmth** only drains in hostile realms
(Venus heat, the cosmic void) and comes back by itself elsewhere.

- **What you do changes it.** Building tires them out faster but fills *purpose*. Chatting fills *social*.
  Resting fills *energy*.
- **Mood** is a word (elated, happy, fine, uneasy, miserable) from all needs together, plus short
  feelings ("moodlets") such as "had a great party" that wear off after a while.
- **Personality** makes some needs matter more (an outgoing companion cares more about social).
- **Autonomy.** The companion picks the most urgent need and goes to fix it (eat, rest, chat, play, build).
- **Relaxed mode** turns decay off for creative play.
- **Memory.** When mood changes, it's written to the companion's memory log. Locked cells refuse, so
  this only happens while you're unlocked.
- **Owner only:** resetting a companion's needs.

Saves are encrypted once you have an owner lock. See also [Skills & Perks](sim-skills-perks.md).
