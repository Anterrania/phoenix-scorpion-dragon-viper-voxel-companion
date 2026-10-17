# Phoenix Glass — UI Design Language

The design language for the Phoenix Scorpion Dragon Viper voxel app (Godot 4.7, Android, portrait first).
It takes inspiration from clean, circular "big tech" UIs like the one in the film *The Circle*, adds Apple-level restraint, and borrows Star Citizen's sense of depth and holograms. **We take inspiration only. Nothing is copied: no logos, icons, fonts or assets from the film or any other product.**

Kit files: `themes/phoenix_glass.tres`, `shaders/ui_glass.gdshader`, `scripts/ui/kit/*`, `scenes/ui/kit/*`, demo `scenes/ui/kit/kit_demo.tscn` (screenshot test: `tests/screenshot_ui_kit.gd`).

## 1. Principles
1. **Circle first.** Status, progress, navigation and identity use rings and dials. Rectangles are only containers.
2. **Glass over the world.** Panels are frosted glass, so the realm always shows through. Nothing is opaque except modal confirmations.
3. **One look, one tap.** Each screen answers one question. If it needs labels, use 1–2 words. Use icons and numbers where you can.
4. **No floating clutter.** World text stays hidden until you tap. Show no more than one toast at a time.
5. **Swipe, don't scroll.** Group content into swipeable tabs (≤5) and pages instead of long lists. A list caps at about 7 visible rows, then pages.
6. **Thumb reach.** Primary actions sit in the bottom third. Every tap target is **≥ 56 px** (48 dp minimum) with ≥ 8 px between targets.
7. **Fire means alive.** Ember and phoenix accents mark only Foxy, the companions, and live or active state. Never use them for decoration.
8. **Portrait native.** The layout is designed at 720×1280. Landscape is a reflow, not a separate design.

## 2. Color tokens (`PhoenixTokens`)
| Token | Hex | Use |
|---|---|---|
| `VOID` | #07050A | App background, deepest black |
| `OBSIDIAN` | #120C16 | Button and control fill |
| `GLASS` | rgba(18,10,23,.62) | Glass panel tint |
| `MAGENTA` | #FF2DB8 | Primary accent, focus, selected tab, graph lines |
| `MAGENTA_DEEP` | #B0127E | Hover and pressed depth |
| `GOLD` | #F5C451 | Highlights, captions, the "now" point, focus ring |
| `PLATINUM` | #E6E4EC | Primary text and glyphs |
| `PLATINUM_DIM` | #9C98A8 | Secondary text, placeholders |
| `EMBER` | #FF6A1F | Foxy and companion aura, live state |
| `PHOENIX` | #FF3B2F | Fire-gradient end, critical companion state |
| `VENUS` | #FFB347 | Fire-gradient start, warnings |
| `OK` / `WARN` / `ERR` | #5EF0B0 / #FFB347 / #FF4D6D | System status only |

Gradients: **Brand** is Gold → Magenta (rings, primary progress). **Fire** is Venus → Ember → Phoenix (Foxy and companions only).
**Glitter:** a sparse gold sparkle (≤0.4% of pixels, re-seeded at 2 Hz) appears on glass and on hero surfaces. It's off when the device's reduced-motion setting is on.
Contrast: body text on glass must hit WCAG AA (4.5:1). Platinum on the glass tint is about 12:1.

## 3. Type scale
Use the default Godot UI font now and switch to an open-licensed geometric sans (e.g. Inter or Outfit, OFL) later. No uppercase body text. Captions are UPPERCASE with +6% tracking.
| Role | px | Theme variation |
|---|---|---|
| Display (hero number) | 44 | `DisplayLabel` |
| Title | 28 | `TitleLabel` |
| Headline | 22 | — |
| Body | 18 | default |
| Label / caption | 15 | `CaptionLabel` (gold, uppercase) |
| Micro (ring captions) | 13 | — |
Numbers use tabular figures and are always the largest element on a card.

## 4. Corners & circles
- Radii: `s` 12 (chips, tooltips) · `m` 20 (inputs) · `l` 28 (cards, sheets) · `pill` (buttons, tabs).
- Nested radius = outer radius − padding, so concentric corners stay concentric.
- Circles: dials and icon buttons are perfect circles. Ring stroke = 8–9% of the diameter (14 px on a 160 px ring). Arcs start at 12 o'clock and fill clockwise. Arc ends are round, with a glowing platinum head dot.
- Radial menus: 4–8 items evenly spaced, item diameter ≥ 72 px, hub ≥ 72 px.

## 5. Glass (`shaders/ui_glass.gdshader`)
- Blur: screen-texture mip LOD `blur_lod` 3.0 (cards), 4.5 (sheets and modals), 2.0 (HUD chips). It's cheap on mobile because there's no multi-pass blur.
- Tint: `GLASS` at 0.62 alpha by default. Use 0.75 over busy scenes and 0.9 for modals.
- Rim: a 1.5 px magenta line at 0.55 alpha, plus a soft top sheen (+8% white fading down the card).
- Corners: SDF in pixels (`rect_size` is set by `GlassCard`, `corner_radius_px` 28).
- Budget: no more than 3 glass surfaces on screen at once. On the low quality setting, swap the shader for the flat `Panel` stylebox in the theme.

## 6. Glow & ember accents
- Glow means 3–4 stacked translucent copies of a shape (each 8–25% alpha) behind the primary. No bloom post-process on UI.
- **Ember** (Foxy and companions): a fire-gradient ring or halo that breathes over a 2.4 s cycle (scale 1.0 → 1.04, alpha 0.6 → 0.9). Particles at 6–12 sparks a second drift up and fade within 0.8 s.
- **Focus:** a 3 px gold ring. **Selected:** a magenta fill at 25% with a magenta rim.

## 7. Motion
| Token | s | Use |
|---|---|---|
| `tap` | 0.09 | Press feedback (scale 0.96) |
| `fast` | 0.16 | Toggles, chips, tab underline |
| `base` | 0.24 | Panels, radial menu bloom, carousel snap (`TRANS_CUBIC`, ease out; `TRANS_BACK` retired by calm premium, §12) |
| `slow` | 0.42 | Ring fill, graph draw-in (`TRANS_CUBIC`, ease out) |
| `ambient` | 2.4 | Ember breathe, hologram shimmer |
Panels slide up 24 px with a fade. Swiping between tabs moves pages 1:1 with the finger and snaps at 30% or above 600 px/s. Reduced motion turns these into fades only.

## 8. Components
Built in this PR: **Ring stat, Radial menu, Glass card, Line graph.** The rest are specs for the dev bot to build on the kit.

- **Ring dial / Ring stat** (`scenes/ui/kit/ring_stat.tscn`, `RingStat`): `value` 0..1, `caption`, optional `display_text`, `color_a/b`. Has a track ring at 8% white, a gradient arc, a head dot, a centered number and a micro caption. Animates on change. Sizes: 120 (inline), 160 (card), 240 (hero). As an interactive dial, dragging around the ring sets the value, snapping to 5%.
- **Radial menu** (`radial_menu.tscn`, `RadialMenu`): a hub with an ember core toggles the menu open and closed. Items bloom out on a ring. Signal `item_selected(id)`. Glyph-only, with the label shown in a toast on long-press. It replaces long menus.
- **Glass card** (`glass_card.tscn`, `GlassCard`): has a frosted backdrop, a gold caption title, and content added via `body()`. Padding is 20 px with a 12 px gap.
- **Stat ring + graph** (`line_graph.tscn`, `LineGraph`): a hero number (Display) above a single-series line in magenta, with a faint fill, a gold "now" dot and 3 ghost gridlines. There are no axes; tapping shows a value bubble. For multiple series, use one magenta and one platinum, never more than two.
- **Timeline (spec):** a vertical spine of rings. Each event is a 20 px ring (fire for companion events, magenta for owner and system) with a time and a one-line summary. Tap expands it into a glass card. It shows a day at a time, and you swipe left or right for other days. It's used for companion memory and history.
- **Admin table (spec):** never a wide grid on the phone. Each row is a glass "pill row" with an avatar ring, a primary text, one status chip and a swipe-left action (approve/reject/more). Filters are segmented pills at the top. At most 7 rows, then paging. On tablet or landscape it reflows to columns.
- **Sign-up stepper (spec):** a ring progress shows the step count, with one question per screen (name → avatar → voice → realm → done). It has big inputs (64 px), a primary pill at the bottom, back by swiping right, and a phoenix burst on completion.
- **Toast (spec):** a glass pill 56 px tall, shown at the top safe area, with an icon ring and ≤ 6 words. It auto-dismisses after 2.5 s, you can swipe it up to dismiss it, and only one shows at a time. Variants are OK/WARN/ERR and Ember (companion speaking).
- **Tabs:** a `TabBar` with pill selection, ≤5 tabs and swipeable pages.
- **Buttons:** pills ≥ 56 px. Primary is a magenta fill with a gold rim, secondary is obsidian with a magenta rim, and destructive is an ERR rim and requires hold-to-confirm (0.6 s ring fill).

## 9. 3D companions
- **Holographic ring nameplate, shown only on tap:** tapping a companion projects a thin billboarded ring (platinum and magenta, Fresnel shimmer, 0.24 s scale-in) above its head. It shows the name, a mood glyph and a mini stat ring (bond or energy). It auto-hides after 4 s or when you tap elsewhere. **No permanent floating names.**
- **Ember aura:** a soft ground ring plus a rising spark stream in the fire gradient, tinted per companion (Foxy is Venus → Phoenix). It breathes at the `ambient` cadence, glows brighter while speaking or learning, and dims when idle.
- **Speaking:** a waveform arc on the nameplate ring instead of speech bubbles. Text goes to the chat panel.
- **Selection:** a ground circle under the companion, plus a radial menu (Talk, Follow, Build, Memory, Look, Voice).
- 3D materials reuse the token colors. The look stays holographic: emissive edges, slight scanline and transparency.

## 10. World UI
- **Minimap ring:** a circular minimap (top-right, 168 px) with a gold heading tick on the rim. Region names only appear when zoomed in. Companions show as ember dots and friends as platinum. Tap to open the full map.
- **Compass ring:** a thin arc across the top showing N/E/S/W and waypoint pips. It fades out after 3 s without turning.
- **HUD chips:** small glass pills for music, quality and so on, at ≤ 3 on screen. Exit and Background always stay reachable under the minimap.
- **Builder / land tools:** the brush size is a ring dial and the operation is a radial menu, both in the bottom third.
- Restyling the existing HUD is deferred to a follow-up after v0.10. This PR only adds the kit.

## 11. Do / Don't
- Do: one hero number per card, circles for status, glass over the world, fire only for life.
- Don't: floating world text, more than 5 tabs, scrolling lists over 7 rows, tiny targets, more than 3 glass layers, or copied third-party marks.

## 12. Calm premium mode (default since 2026-10-17)
Phoenix asked for a look that is modern and premium but **clean, not flashy or campy**. Calm premium is the default for every kit component; the older brighter look stays available per component (`calm = false`) but isn't used anywhere.

**Rules**
- **Motion:** 180–240 ms, ease-out (`TRANS_CUBIC`). No bounce, no overshoot, no spin. Ambient loops only for companion life (ember breathe).
- **Glow:** at most **one accent glow per screen**. Rims are quiet by default; magenta rims appear on hover/press only.
- **Ember** (fire gradient) only on **Foxy-related** items. The radial hub no longer has an ember halo.
- **Glass:** ≤ 3 glass surfaces visible at once (§5). Group related cards in a carousel instead of stacking them.
- **Spacing:** generous, Apple-like: `SPACE[5]` (24 px) page margins, `SPACE[4]` (16 px) between blocks, one idea per card.
- **Targets and text:** tap targets ≥ 80 px and labels ≥ 16 sp in the **Large** setting (Phoenix has eye strain). The default is **Compact** (smallest usable text and icons); the scale variables for Compact/Large live in `phoenix_tokens.gd` (added on `feature/phone-display-media`). Components must read sizes from tokens, never fixed numbers. Today `TAP_MIN` is 56 px and `TYPE.label` / `TYPE.micro` are 15 / 13 px, so Compact is below the 80 px / 16 sp floors by design; Large must meet them.
- **Color:** platinum text on obsidian/void; magenta for the one selected/pressed thing; gold for focus, page dots and "now". No rainbow or hue cycling in UI.

**What changed in the kit**
| Piece | Calm premium |
|---|---|
| `themes/phoenix_glass.tres` Button | normal rim magenta 0.6 / 2 px → platinum-dim 0.3 / 1 px; hover fill 0.5 → 0.28, rim 1.0 → 0.55; pressed fill 0.85 → 0.7; focus ring 3 px → 2 px at 0.8 |
| `GlassCard` (`calm = true`) | shader rim magenta 0.55 → 0.30, sparkle 0.25 → 0.08 |
| `RadialMenu` | bloom `TRANS_BACK` → `TRANS_CUBIC`; no ember halo on the hub |
| **New** `GlassCarousel` (`scenes/ui/kit/glass_carousel.tscn`) | one card per swipe (≥ 30% width or > 600 px/s, max one card), snaps in `MOTION.base` ease-out, gold/platinum page dots, auto-advance **only** when `auto_advance = true` (ads, event lists), paused by any touch and resumed one interval after release (interval = 2 × `MOTION.ambient` = 4.8 s), never wraps on swipe |
| **New** `GlassMenu` (`scenes/ui/kit/glass_menu.tscn`) | full-width rows (`TAP_MIN` tall, `TYPE.body` text): glyph, label, optional gold badge, chevron; ≤ 7 rows; magenta press tint; `foxy = true` rows use ember |

**Where it's used:** admin Home shows its four stat cards in one `GlassCarousel` (5 visible glass cards → 2) with a `GlassMenu` under it (Tickets, Wiki, Timeline, Community, Security). The ads and rental carousels, events board and land info panels (docs/modules/BUILD_TOOLS_AND_TIERS.md) will reuse both.

