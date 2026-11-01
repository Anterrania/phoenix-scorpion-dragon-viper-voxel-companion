#!/usr/bin/env python3
"""v0.13 BRAND-1: original Viper OS icon set, drawn from code (no stock or third-party art).

Emblem: a gold phoenix (spread wings + crest) rising over a platinum viper/dragon coil that ends in a
magenta scorpion stinger, on void black with a magenta glow and platinum/gold sparkles.
Palette: PhoenixTokens VOID #07050a, MAGENTA #ff2db8, GOLD #f5c451, PLATINUM #e6e4ec.

Writes SVG sources only; tools/icons/render_icons.gd rasterizes them with Godot:
  python3 tools/icons/make_icons.py && godot --headless --path . --script res://tools/icons/render_icons.gd
"""
import math, os

VOID, MAGENTA, MAGENTA_DEEP, GOLD, GOLD_HI, PLATINUM = "#07050a", "#ff2db8", "#b0127d", "#f5c451", "#ffe7a3", "#e6e4ec"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "assets", "brand")


def star(cx, cy, r, color, opacity=1.0):
    """4-point sparkle."""
    k = r * 0.22
    pts = [(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)]
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    return f'<path d="{d}" fill="{color}" opacity="{opacity}"/>'


def wing(side):
    """One phoenix wing as layered feather blades, mirrored by side (+1 right, -1 left). 512 canvas."""
    out = []
    for i in range(6):
        a = math.radians(-70 + i * 17)
        length = 175 - i * 14
        x0, y0 = 256 + side * 18, 214 + i * 6
        x1 = x0 + side * math.cos(a) * length
        y1 = y0 + math.sin(a) * length
        mx, my = (x0 + x1) / 2 - side * 10, (y0 + y1) / 2 - 26
        w = 16 - i
        fill = GOLD if i % 2 == 0 else GOLD_HI
        out.append(
            f'<path d="M{x0:.1f},{y0:.1f} Q{mx:.1f},{my - w:.1f} {x1:.1f},{y1:.1f} Q{mx + side * w:.1f},{my + w:.1f} {x0:.1f},{y0 + 10:.1f} Z" '
            f'fill="{fill}" opacity="{1.0 - i * 0.07:.2f}"/>')
    return "\n".join(out)


def emblem(mono=False):
    """Emblem group on a 512x512 canvas, centered in the adaptive-icon safe zone (r ~ 170)."""
    g = GOLD if not mono else "#ffffff"
    p = PLATINUM if not mono else "#ffffff"
    m = MAGENTA if not mono else "#ffffff"
    parts = []
    # viper / dragon coil: an S-curve body with scales, platinum
    parts.append(f'<path d="M180,380 C120,330 170,280 250,300 C330,320 380,280 340,240 C320,220 290,230 292,250" '
                 f'fill="none" stroke="{p}" stroke-width="26" stroke-linecap="round"/>')
    parts.append(f'<path d="M180,380 C120,330 170,280 250,300 C330,320 380,280 340,240" fill="none" stroke="{VOID if not mono else "#000"}" '
                 f'stroke-width="4" stroke-dasharray="3 11" stroke-linecap="round" opacity="0.55"/>')
    # dragon head at the coil start: wedge with horn + eye
    parts.append(f'<path d="M180,380 L138,398 L150,376 L128,372 L170,356 Z" fill="{p}"/>')
    parts.append(f'<path d="M160,362 L146,338 L170,356 Z" fill="{g}"/>')
    parts.append(f'<circle cx="160" cy="376" r="4" fill="{m}"/>')
    # scorpion tail: segmented arc rising from the coil end, magenta stinger
    for i, (x, y) in enumerate([(300, 262), (316, 236), (338, 220), (362, 214), (384, 222)]):
        parts.append(f'<ellipse cx="{x}" cy="{y}" rx="{13 - i}" ry="{10 - i}" fill="{m if not mono else "#fff"}" opacity="{0.75 + i * 0.05:.2f}"/>')
    parts.append(f'<path d="M384,222 Q412,232 404,262 Q398,246 382,240 Z" fill="{g}"/>')
    # phoenix: wings, body, crest, tail flame
    if not mono:
        parts.append(wing(1))
        parts.append(wing(-1))
    else:
        parts.append(wing(1).replace(GOLD_HI, "#fff").replace(GOLD, "#fff"))
        parts.append(wing(-1).replace(GOLD_HI, "#fff").replace(GOLD, "#fff"))
    parts.append(f'<path d="M256,150 C278,180 280,240 256,300 C232,240 234,180 256,150 Z" fill="{g}"/>')
    parts.append(f'<path d="M256,300 C266,320 270,346 256,372 C242,346 246,320 256,300 Z" fill="{m}"/>')
    parts.append(f'<path d="M256,150 L246,118 L256,132 L262,104 L266,136 L276,122 L266,156 Z" fill="{m}"/>')
    parts.append(f'<circle cx="256" cy="168" r="5" fill="{VOID if not mono else "#000"}"/>')
    # sparkles
    sp = [(150, 150, 16, p), (370, 130, 12, g), (396, 330, 10, p), (118, 260, 8, g), (330, 400, 9, m), (210, 110, 7, p)]
    parts += [star(x, y, r, c if not mono else "#fff", 0.95) for x, y, r, c in sp]
    return "\n".join(parts)


def background(rounded=True, size=512):
    r = 112 if rounded else 0
    return f'''<defs>
<radialGradient id="glow" cx="50%" cy="48%" r="60%">
<stop offset="0%" stop-color="{MAGENTA_DEEP}" stop-opacity="0.85"/>
<stop offset="55%" stop-color="#2a0420" stop-opacity="0.9"/>
<stop offset="100%" stop-color="{VOID}"/>
</radialGradient>
<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
<stop offset="0%" stop-color="{GOLD}"/><stop offset="50%" stop-color="{PLATINUM}"/><stop offset="100%" stop-color="{MAGENTA}"/>
</linearGradient>
</defs>
<rect width="{size}" height="{size}" rx="{r}" fill="{VOID}"/>
<rect width="{size}" height="{size}" rx="{r}" fill="url(#glow)"/>
''' + (f'<rect x="10" y="10" width="{size - 20}" height="{size - 20}" rx="{r - 8}" fill="none" stroke="url(#rim)" stroke-width="8"/>' if rounded else "")


def svg(inner, size=512, view=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {view} {view}">\n{inner}\n</svg>\n'


def scaled(inner, s):
    """Scale the emblem around the center (adaptive icons keep art inside the 66% safe zone)."""
    t = 256 * (1 - s)
    return f'<g transform="translate({t:.1f},{t:.1f}) scale({s})">{inner}</g>'


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        "icon.svg": svg(background() + scaled(emblem(), 0.92)),                       # launcher + project icon
        "adaptive_foreground.svg": svg(scaled(emblem(), 0.62)),                        # transparent, safe zone
        "adaptive_background.svg": svg(background(rounded=False)),
        "adaptive_monochrome.svg": svg(scaled(emblem(mono=True), 0.62)),
        "favicon.svg": svg(background() + scaled(emblem(), 0.92)),
    }
    for name, data in files.items():
        with open(os.path.join(OUT, name), "w") as f:
            f.write(data)
    with open(os.path.join(ROOT, "icon.svg"), "w") as f:
        f.write(files["icon.svg"])
    print("wrote", ", ".join(files), "+ icon.svg")


if __name__ == "__main__":
    main()
