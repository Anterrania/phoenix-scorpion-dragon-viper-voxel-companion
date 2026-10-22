---
title: Vala Script
slug: vala-script
tags: [scripting, vscript, objects, lsl]
audience: all
status: built
updated: 2026-10-22
sources: [scripts/vala_script/vs_engine.gd, docs/modules/VALA_SCRIPT.md]
ticket: VALA-1
---

# Vala Script

> **Built** and tested. The editor screen is coming.

Make objects do things: doors that open on touch, signs that talk, screens that show numbers.

- Files end in **.vscript** and live in your inventory with copy / modify / transfer perms.
- This is our own language. It is **not** the GNOME Vala language, it only looks a bit like Vala and C#.
- Scripts can't touch your files or phone. Internet calls are off unless you turn them on for sites you pick.
- Big red e-stop? Every script stops.
- Nobody nearby? Scripts there take a nap to save battery.
- Have an LSL script? Import it, and we'll point out any lines that need changes.

```vscript
default {
    touch_start(integer n) { say(0, "Hello!"); }
}
```

Full reference: docs/modules/VALA_SCRIPT.md.
