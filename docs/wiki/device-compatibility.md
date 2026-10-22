---
title: Device Compatibility
slug: device-compatibility
tags: [device, phone, tablet, tv, gamepad, settings, compatibility]
audience: all
status: built
updated: 2026-10-22
sources: [scripts/system/device_profile.gd, scripts/system/auto_config.gd, scripts/admin/device_compat_screen.gd]
ticket: COMPAT-1
---

# Device Compatibility

> **Built** and headless-tested. Not tried on a phone yet.

Viper OS checks your device when it starts and sets itself up to match.

- **Graphics** match your phone's power: low, medium, high or ultra.
- **Text and icons** stay compact on phones and get bigger on tablets, computers and TVs.
- **Controls** use touch, a gamepad (switched on the moment you connect one), keyboard and mouse, or VR later.
- **Features** your device can't run are switched off, and the screen tells you why.

Your own choices always win. To go back, tap **Reset to auto**.

## Where to see it
Viper Admin › Home › **▣ Device & compatibility**. It shows what was found, what was set up, and the features
that are off with the reason. **Re-detect** checks again.

## Privacy
Device details stay on your phone and are never uploaded.

See also [Battery & Data](battery-and-data.md) and [Graphics Settings](graphics-settings.md).
