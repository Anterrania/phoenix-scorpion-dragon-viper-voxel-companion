---
title: Graphics Settings
slug: graphics-settings
tags: [graphics, settings, quality, performance, battery]
audience: all
status: built
updated: 2026-10-22
sources: [scripts/autoload/settings.gd, scripts/render/render_tiers.gd, docs/modules/RENDERING.md]
---

# Graphics Settings

## Quality levels
- **LOW:** shortest view, no glow, no shadows. Best for battery.
- **MED:** the default. Glow on.
- **HIGH:** longest view, shadows, reflections, more particles.
- Tap **GFX** to cycle, or use **⚙ Settings**.

## What each level changes
- **Low:** 256 m view, 70% resolution, no shadows or glow, fewer particles and grass.
- **Medium:** 384 m view, 80% resolution with sharp upscaling, light anti-aliasing.
- **High:** 640 m view, sun shadows, water depth and shore foam, smooth land blending.
- **Ultra** (when your phone offers it): 1 km view, full resolution, sharper shadows.
- **Auto:** the phone picks a level and lowers resolution a little when it gets hot or slow.

## Skies
- Alaskan realm: northern lights at night.
- Cosmic realm: a deep starfield with a galaxy band.

## Sky and time
- **☀ ENV:** Sunrise, Midday, Sunset, Midnight, Venus Storm, Cosmic.
- Or a 24-minute day/night cycle.

## Less clutter
- Floating names and labels are **off** by default.
- Turn them on in Settings.

## If it's slow
- Drop to **LOW**.
- Close other apps.
