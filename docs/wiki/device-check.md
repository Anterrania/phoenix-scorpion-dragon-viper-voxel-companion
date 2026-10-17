---
title: Device Check
slug: device-check
tags: [device, permissions, camera, microphone, notifications, android]
audience: all
status: partial
updated: 2026-10-17
sources: [scripts/app/device_check.gd, scripts/admin/settings_screen.gd, export_presets.cfg, project.godot]
ticket: PHONE-3
---

# Device Check

> **Partial.** Built and headless-tested. Permission prompts only appear on a real Android phone.

## Open it
- Round menu › **Admin** › **⚙** › **Device** tab.
- Round menu › **Security** › **Device check**.

## What it shows
- **Camera, Microphone, Notifications, Photos, Videos, Music files**: Allowed or Not allowed yet.
- **Internet, Vibration**: always allowed (no prompt).
- **Audio input (mic driver)**: On.
- **Mic devices** and **Camera feeds** found.
- **Text-to-speech voices** found.
- **Screen**: Auto-rotate or Portrait.

## Buttons
- **Ask for permissions**: the phone asks for each one. Answer on the phone's prompt.
- **Check again**: refresh the list.
- The camera and mic are also asked for the first time you use them (for example **Start mic**).

## Declared in the app (Android)
Camera, Record audio, Modify audio settings, Post notifications, Read media images / video / audio,
Read external storage (Android 12 and older), Internet, Network state, Vibrate.
