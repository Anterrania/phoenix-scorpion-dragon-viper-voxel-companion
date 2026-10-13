# Economy — Aethel (PLAN / SCAFFOLD)

> ⚠️ **Strictly fictional game-only virtual currency.** No cash value. Cannot be bought, sold, or redeemed for real money or crypto. No fiat exchange, no crypto minting, no real-world payments. Real-money features stay blocked until Anterrania Law Bot legal review **and** explicit Anterranian approval. See also `ECONOMY_BANKING.md` (ledger / Phoenix Embers).

## Purpose

Diegetic **Aethel** economy art from concept batch_24. Catalogued in `data/items/currency.json` under `economies.aethel`. Complements (does not replace) the soft ledger unit **Phoenix Embers** and the batch_23 **Phoenix God Coin** face.

**Pending user confirmation:** relationship of Aethel family ↔ Phoenix God Coin / Phoenix Embers; meaning of the crowned lion coin.

## Roles (in-game only)

| Role | Item id | Art label (as printed) | Game meaning |
|------|---------|------------------------|--------------|
| Notes | `aethel_banknotes` | UNIVERSAL CURRENCY (100 / 1000) | Soft-currency banknote cosmetics |
| Coins | `aethel_lion_coin` | (runic rim; crowned lion) | Coin face; lion meaning TBD |
| Sigil | `aethel_sigil` | AETHEL SIGIL / UNIVERSAL VALIDATION | Ledger/quest validation stamp |
| Stasis | `aethel_stasis` | AETHEL-STASIS / STABLE UNIVERSAL CURRENCY | **Stable** soft currency face |
| Ascendant | `aethel_ascendant` | AETHEL-ASCENDAND [sic ASCENDANT] / DYNAMIC UNIVERSAL ASSET | **Variable** in-game asset (balance rules only) |
| Key | `aethel_key` | THE AETHEL KEY / UNIVERSAL ACCESS | Wallet / access / ID card item |
| **Main coin** | `aethel_coin` | AETHEL COIN / UNIVERSAL CURRENCY | Primary Aethel coin face (zodiac rim; batch_26) |

## Rules (hard)

- Integer ledger amounts only (`scripts/economy/ledger.gd`).
- Ascendant “dynamic” = quest/trade/prestige float **inside the game**, never linked to real markets.
- Aethel Key biometrics are **cosmetic fiction** — no real biometric capture or identity binding.
- Sigil validates in-game actions only — not a payment rail or KYC product.
- Palette v2: black / magenta / gold / platinum + glitter on all faces.

## Concept art

`assets/concept_art/batch_24/`

1. `01_aethel_banknotes_100_1000_universal_currency.png`
2. `02_aethel_lion_coins_crowned.png`
3. `03_aethel_sigil_universal_validation.jpg`
4. `04_aethel_stasis_stable_universal_currency.png`
5. `05_aethel_ascendant_dynamic_universal_asset.png`
6. `06_aethel_key_universal_access.png`


7. *(batch_26)* `assets/concept_art/batch_26/03_aethel_coin_universal_currency_zodiac.jpg` — **Aethel Coin** (main face; zodiac rim dragon-phoenix)

## Landmark link

`aethel_citadel` in `data/items/structures.json` (batch_26/04 orbital fortress) — name pending user approve. Diegetic Aethel branding on a defense/landmark structure.

## Related

- `data/items/currency.json`
- `docs/modules/ECONOMY_BANKING.md`
- `docs/modules/GAME_BALANCE.md`
- `docs/modules/HERALDRY.md`
- `docs/PENDING_USER_QUESTIONS.md`

