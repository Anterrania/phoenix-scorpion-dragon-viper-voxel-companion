class_name PhoenixTokens
## Design tokens for the Phoenix Glass design language (see docs/UI_DESIGN_LANGUAGE.md).
## Sizes are BASE (compact) values. Screens read the scaled sizes through fs()/tap()/icon()/space(),
## which follow the scale variables below. DisplaySettings (scripts/ui/display_settings.gd) sets them
## from Settings > Display, so the text/icon sliders, Large and Max view reach every screen.
const VOID := Color("#07050a")
const OBSIDIAN := Color("#120c16")
const MAGENTA := Color("#ff2db8")
const MAGENTA_DEEP := Color("#b0127e")
const GOLD := Color("#f5c451")
const PLATINUM := Color("#e6e4ec")
const PLATINUM_DIM := Color("#9c98a8")
const EMBER := Color("#ff6a1f")
const PHOENIX := Color("#ff3b2f")
const VENUS := Color("#ffb347")
const GLASS := Color(0.07, 0.04, 0.09, 0.62)
const OK := Color("#5ef0b0")
const WARN := Color("#ffb347")
const ERR := Color("#ff4d6d")
## Compact (default) tap target. Large = TAP_LARGE. Read tap() for the live value.
const TAP_MIN := 56
const TAP_LARGE := 80
const RADIUS := {"s": 12, "m": 20, "l": 28, "pill": 999}
const SPACE := [0, 4, 8, 12, 16, 24, 32, 48]
## Compact type sizes (label 15, micro 13). Large multiplies them so micro reaches 18 px.
const TYPE := {"display": 44, "title": 28, "headline": 22, "body": 18, "label": 15, "micro": 13}
## Motion: 180-240 ms ease-out, no bounce (base 0.24, fast 0.18).
const MOTION := {"tap": 0.09, "fast": 0.18, "base": 0.24, "slow": 0.42, "ambient": 2.4}

# ---------- scale variables (written by DisplaySettings.apply) ----------
const TEXT_MIN := 1.0          # compact = smallest usable (micro 13 px, label 15 px)
const TEXT_MAX := 2.0
const ICON_MIN := 1.0          # compact taps 56 px
const ICON_MAX := 2.0
const LARGE_TEXT := 18.0 / 13.0          # micro 13 -> 18 px, label 15 -> 21 px, body 18 -> 25 px
const LARGE_ICON := float(TAP_LARGE) / TAP_MIN   # taps 56 -> 80 px
const MAX_VIEW_SPACE := 0.5    # Max view halves margins/gaps so the most content fits
static var text_scale := 1.0
static var icon_scale := 1.0
static var space_scale := 1.0

static func clamp_text(s: float) -> float: return clampf(s, TEXT_MIN, TEXT_MAX)
static func clamp_icon(s: float) -> float: return clampf(s, ICON_MIN, ICON_MAX)

## Scaled font size for a TYPE role ("body", "label", ...) or any base px number.
static func fs(role: Variant = "body") -> int:
	var base := float(TYPE.get(role, 18)) if role is String else float(role)
	return int(round(base * text_scale))

## Scaled tap target (px). Compact 56, Large 80.
static func tap() -> int: return int(round(TAP_MIN * icon_scale))

## Scale an icon/glyph/hit-radius base size.
static func icon(base: float) -> float: return base * icon_scale

## Scaled spacing step SPACE[i] (Max view tightens it).
static func space(i: int) -> int: return int(round(SPACE[clampi(i, 0, SPACE.size() - 1)] * space_scale))

static func is_large() -> bool: return text_scale >= LARGE_TEXT - 0.001 and icon_scale >= LARGE_ICON - 0.001
