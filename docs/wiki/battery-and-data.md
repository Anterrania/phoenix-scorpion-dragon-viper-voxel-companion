---
title: Battery & Data
slug: battery-and-data
tags: [battery, data, saver, mobile data, wifi, power]
audience: all
status: built
updated: 2026-10-22
sources: [scripts/system/auto_config.gd, scripts/system/net.gd, scripts/system/dormancy.gd]
ticket: COMPAT-PWR-1
---

# Battery & Data

> **Built** and headless-tested. A small built-in Android add-on reads battery, heat and network; not yet tried on a real phone.

Viper OS saves battery and data by itself and stays smooth.

- **Balanced saver** is the normal mode.
- **Saver** turns on when the battery drops below 30%, power saver is on, the phone gets hot, or you're on
  mobile data. Companions think a little slower, music and video use less data, and pictures load smaller.
- **Full quality** turns on when you're charging on Wi-Fi.
- **In the background**, the world pauses. When you come back, it catches up in one step.

## Data saver: Auto / On / Off
On mobile data, videos don't autoplay, you see thumbnails, and big downloads wait for Wi-Fi.
Your choice wins.

Find it at Viper Admin › Home › ▣ Device & compatibility › **Battery & data**, along with the data used
this session.

See also [Device Compatibility](device-compatibility.md).
