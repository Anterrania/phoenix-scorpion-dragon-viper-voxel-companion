---
title: Interop (OpenSim, Aurora, WhiteCore, OSgrid)
slug: interop
tags: [interop, opensim, aurora, whitecore, osgrid, oar, iar, import]
audience: all
status: partial
updated: 2026-10-17
sources: [scripts/interop/opensim_archive.gd, scripts/interop/interop_import.gd, scripts/admin/interop_screen.gd, docs/modules/INTEROP.md]
ticket: VWGAP-3
---

# Interop

> **Partial.** Importing terrain and notecards works (headless-tested). Applying terrain to a region, objects, textures, scripts and Hypergrid travel are **Planned**.

## Open it
MENU › **⇄ Interop**.

## What you can bring in
- **OAR** (region archive) from OpenSim, Aurora-Sim, WhiteCore or OSgrid: the terrain heightmap, plus a summary of parcels, region settings, objects and assets.
- **IAR** (inventory archive): your notecards' text, and a list of your items with their next-owner permissions.

OSgrid closes on 31 December 2026. Export your OARs and IARs from there now.

## Steps
1. Put the `.oar` or `.iar` file on your phone, for example in Download.
2. MENU › **⇄ Interop**.
3. Type the file path in the box.
4. Tap **Preview** to see what's inside. Anyone can do this.
5. Tap **Import** to keep it. This needs Premium / Creator, Builder / Staff, or the owner unlock.

## Who can do what
| Action | Who |
|---|---|
| Preview | everyone |
| Import | Premium / Creator, Builder / Staff, Estate Manager, unlocked Owner |
| Clear log (owner) | unlocked Owner only |

## Planned
- Apply an imported heightmap to a region (needs land rights there).
- Textures (JPEG 2000 needs converting first), sounds, animations, mesh.
- Objects to voxel stamps. Prims don't convert exactly.
- A small LSL-like script subset, and Hypergrid-style travel.

See [Tiers](tiers.md) and [Landmarks & Teleport](landmarks-teleport.md).
