# Heraldry — Anterrania (National Flag, Great Seals, Title & Mottos)

> **Scaffold / lore catalog only.** Flags, seals, and the Phoenix God coin are **game-only virtual** cosmetics. Never sold for real money. Palette v2 (black / magenta / gold / platinum + glitter). Data: `data/lore/heraldry.json`, `data/items/currency.json`. Concept art: `assets/concept_art/batch_23/` (national) + `assets/concept_art/batch_25/` (house emblem hybrid). Economy: `docs/modules/ECONOMY_BANKING.md`.

## Royal title

**Printed:** `PHOENIX GOD, ANTERRANIAN MONARCH`  
**Short:** Phoenix God  
**Formal:** Phoenix God, Anterranian Monarch

Art typos kept for fidelity (official spelling always **MONARCH**):

| Printed | Source |
|---------|--------|
| ANTERRANIAN **MONORCH** | batch_22/03 capitol |
| ANTERRANIAN **MONAACH** | batch_23/01 capitol floating pads |
| ANTERRANIAN **MONACH** | batch_23/03 coin rim |

**Pending user:** Is **Phoenix God** the official royal style, a ceremonial epithet, or art-only? (See `docs/PENDING_USER_QUESTIONS.md`.)

## Mottos

| Motto | Role | Source |
|-------|------|--------|
| **Flamma. Ordo. Aeterna.** | Primary trilogy (regalia / signets) | batch_02 / batch_06 |
| **Divine Right** | Coin / heraldry | batch_23/03 |
| **Universal Wealth** | Coin / heraldry | batch_23/03 |

## National flag

| Id | Motif | Orientation | Art |
|----|-------|-------------|-----|
| `national_flag_phoenix_radiating` | Gold phoenix + twin 8s; eight magenta radiating lines with small 8s | horizontal | batch_23/04 |
| `national_flag_phoenix_vertical` | Gold phoenix (pair to phoenix seal) | vertical | batch_23/05 |
| `national_flag_dragon_vertical` | Gold winged dragon; magenta X-lines; corner 8s | vertical | batch_23/06 |

Black field, gold border (braid or knotwork), palette v2.

## Great seals

| Id | Motif | Rim text | Art |
|----|-------|----------|-----|
| `great_seal_phoenix` | Gold phoenix, twin gold 8s, magenta ring | PHOENIX GOD, ANTERRANIAN MONARCH | batch_23/04 + 05 |
| `great_seal_dragon` | Gold winged dragon, magenta 8 in tail loop | PHOENIX GOD, ANTERRANIAN MONARCH | batch_23/06 |

Phoenix is currently marked `primary_candidate` in data until the user chooses.

## Recurring symbol: **8**

Appears on rings/signets, household uniforms, Phoenix God floor seal, capitol banners/plaques/archway, national flag (radiating + edge 8s), both great seals, and the coin reverse (magenta 8 over galaxy). **Meaning still pending.**

## Coin (virtual currency face)

| Id | Data | Art |
|----|------|-----|
| `phoenix_god_coin` | `data/items/currency.json` | batch_23/03 |

Obverse: gold phoenix. Reverse: magenta **8** over galaxy. Rim: title + **DIVINE RIGHT** / **UNIVERSAL WEALTH**. Ledger unit remains working name **Phoenix Embers** (integer soft currency). **Not real money, not crypto.**

## Capitol link

`anterranian_capitol` in `data/items/structures.json` (batch_22 base + batch_23 variants: floating pads / phoenix plaques; gold-dome dragon crest with **8** archway).

## House emblem: **Crowned Dragon-Phoenix** (batch_25)

**Id:** `crowned_dragon_phoenix`  
**Also called:** Scorpion Dragon Viper Phoenix / Dragon-Phoenix hybrid (project namesake)  
**Motif:** Dragon head + serpentine body with phoenix feathered wings and flame-like tail, under a crown. Palette v2 magenta creature, gold crown/filigree.

| Id | Type | Art | Notes |
|----|------|-----|-------|
| `house_emblem_crowned_dragon_phoenix_holo_flag` | holo flag | batch_25/01 | Translucent holographic flag, gold filigree |
| `house_emblem_crowned_dragon_phoenix_tapestry` | tapestry | batch_25/02 | Black field, gold filigree, starburst |
| `house_emblem_crowned_dragon_phoenix_neon_card` | UI emblem card | batch_25/03 | Neon outline, circuit frame — card back / loading |
| `house_emblem_crowned_dragon_phoenix_neon_circuit_body` | UI emblem card | batch_25/04 | Circuit-body fill, cross crown — card back / loading |
| `house_emblem_crowned_dragon_phoenix_magenta_banner` | banner | batch_25/05 | Magenta field, constellation-pattern hybrid |
| `house_emblem_crowned_dragon_phoenix_galaxy_flag` | galaxy flag (landscape) | batch_25/06 | Gold frame over spiral galaxy |

This hybrid **may** answer the phoenix-vs-dragon primary question as a combined house/national motif. **Question stays open** until the user confirms (phoenix / dragon / hybrid).

## Open confirmations (user)

1. **Phoenix vs dragon vs Crowned Dragon-Phoenix hybrid** as the **primary** national seal / flag / house emblem? (Hybrid catalogued in batch_25; does not auto-close.)
2. Meaning of the recurring **8**?
3. Confirm **Phoenix God** title use (see PENDING).

When answered, update `data/lore/heraldry.json` `primary_candidate` / `hybrid_candidate` flags and clear the matching PENDING items.

## Batch 26 — Fleet war banner, orb banner, Great Sigil candidate

| Id | Type | Art | Notes |
|----|------|-----|-------|
| `fleet_war_banner` | war banner (spear + fleet) | batch_26/01 | Holographic-edge black flag; crowned dragon-phoenix |
| `orb_banner_seven_glyphs` | vertical banner | batch_26/02 | Magenta; dragon-phoenix around glowing orb + **7 glyph medallions** (meaning pending) |
| `great_sigil_crowned_dragon_phoenix_flames` | great_sigil_candidate | batch_26/05 | Crowned hybrid rising from gold flames in magenta rune circle — **primary Great Sigil candidate** |

Also batch_26: `aethel_coin` (currency), `aethel_citadel` orbital fortress (structures; name pending approve).
