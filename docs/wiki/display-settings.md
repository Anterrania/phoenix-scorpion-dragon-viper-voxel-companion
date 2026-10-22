---
title: Display Settings
slug: display-settings
tags: [display, accessibility, text size, large, max view, orientation, rotate]
audience: all
status: partial
updated: 2026-10-17
sources: [scripts/ui/display_settings.gd, scripts/ui/kit/phoenix_tokens.gd, scripts/admin/settings_screen.gd, patches/ui_root_display_settings.patch]
ticket: PHONE-1
---

# Display Settings

> **Partial.** Built and headless-tested. Not yet checked on a phone. The main game menus follow
> these settings once Foxy applies `patches/ui_root_display_settings.patch`.

## Open it
- Round menu › **Admin** (12 o'clock) › **⚙** (top right) › **Display** tab.
- Round menu › **Security** (2 o'clock) › **Display & text size**.
- After Foxy's patch: MENU › **Aa Display & device**, or MENU › **⚙ Settings** › **Aa Display, device & voice…**

## Large in one tap
- **Large text & buttons** switch (Display tab).
- After Foxy's patch it is also on the first screens: **Create Your Avatar** and **🏝 Welcome Island**
  (**Aa  Large text & buttons**), and at the top of MENU › **⚙ Settings**.

## Sizes
| Setting | Compact (default) | Large |
|---|---|---|
| Buttons (tap size) | 56 px | 80 px |
| Small text (micro) | 13 px | 18 px |
| Labels | 15 px | 21 px |
| Body text | 18 px | 25 px |

- **Text size** slider: 100% (compact, the smallest usable) to 200%.
- **Icon & button size** slider: 100% to 200%.
- **Reset to compact** puts everything back.

## Max view
- **Max view (show the most)** halves margins and gaps, so more fits on screen.

## Orientation
- **Auto-rotate** (default): turns with the phone, portrait and landscape.
- **Portrait**: locked upright.
- Screens re-flow when you turn the phone. Wide screens keep text in a readable column.
  The round menu stays on the right edge.

## How it works
- All sizes come from `PhoenixTokens` scale values. Settings are saved on this phone in
  `settings.cfg` [display].
