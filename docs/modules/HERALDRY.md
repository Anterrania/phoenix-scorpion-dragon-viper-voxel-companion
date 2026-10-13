# Heraldry — Anterrania (National Flag, Great Seals, Title & Mottos)

> **Scaffold / lore catalog only.** Flags, seals, and the Phoenix God coin are **game-only virtual** cosmetics. Never sold for real money. Palette v2 (black / magenta / gold / platinum + glitter). Data: `data/lore/heraldry.json`, `data/items/currency.json`. Concept art: `assets/concept_art/batch_23/`. Economy: `docs/modules/ECONOMY_BANKING.md`.

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

## Open confirmations (user)

1. **Phoenix vs dragon** as the **primary** national seal / flag?
2. Meaning of the recurring **8**?
3. Confirm **Phoenix God** title use (see PENDING).

When answered, update `data/lore/heraldry.json` `primary_candidate` flags and clear the matching PENDING items.
