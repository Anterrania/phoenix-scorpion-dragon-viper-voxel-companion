---
title: Crafting & Infusion
slug: sim-crafting
tags: [crafting, recipes, voxel, materials, enchanting, infusion]
audience: all
status: built
updated: 2026-10-17
sources: [scripts/sim/crafting.gd, data/sim/recipes.json]
ticket: SBX-24
---

# Crafting & Infusion

> **Built** (headless-tested). The station sheet is Foxy's ([spec](../specs/foxy/sbx_build_mode_tools.md)).

- **Recipes use voxel materials** you gather in the world: snow, ice, granite, basalt, lava, gold,
  platinum, glitter crystal, aurora crystal. Crafted items can feed other recipes (stone bricks → gilded
  frame).
- **Stations:** some recipes work by hand, others need a workbench, a forge or an infuser.
- **Skill gate + XP.** Higher recipes need a crafting level; every craft raises it.
- **Batches.** Craft several at once if you have the materials.
- **Nothing is lost on failure.** Materials are only used when the craft works.
- **Land rules.** Crafting counts as building, so on someone's parcel you need build rights there.
- **Infusion** adds one effect to a crafted item (for example *Frostbite* on an obsidian blade). The
  *Infuser* perk makes it stronger. One infusion per item.

Example recipes: Beacon (4 snow + 1 aurora crystal), Stone Brick, Glitter Lamp, Gilded Frame, Obsidian Blade.
