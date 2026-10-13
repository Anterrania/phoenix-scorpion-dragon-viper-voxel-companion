# Economy & Banking — PLAN (VIRTUAL CURRENCY ONLY)
> ⚠️ **The currency is virtual only.** It has no cash value and can't be bought, sold, or redeemed for real money. **Any real-money feature (purchases, cash-out, exchange to fiat, trading between players for money) is blocked until Anterrania Law Bot does a legal review and Anterranian explicitly approves.** Money-transmission, gambling, consumer-protection, and app-store rules may apply.

- **Currency:** "Phoenix Embers" (working name), Linden-dollar-style soft currency earned through quests, trade skills, and building. A second premium-style currency is NOT planned.
- **Exchange (Lindex-like):** an in-game order book between Embers and in-game commodities or a second in-game token. Limit/market orders, a spread, and fees that are destroyed (a sink). `scripts/economy/currency_exchange.gd` is a stub.
- **Ledger/banking:** double-entry, append-only ledger (`scripts/economy/ledger.gd`). Every transfer is a debit plus a credit with matching amounts. Balances are derived from entries. Amounts are integers (no floats). Optional bank accounts for realms/guilds, plus interest as a game mechanic.
- **Sinks/faucets:** track both. Ledger Vale (economy-advisor persona) explains them in-game.
- Persistence: local first. Later MySQL tables `ledger_entries`, `accounts`, `orders` (DATA_MYSQL_AND_BACKUP.md).

## Coin face (batch 23)

- **Physical diegetic coin:** `phoenix_god_coin` in `data/items/currency.json` (concept art `assets/concept_art/batch_23/03_phoenix_god_coin_divine_right_universal_wealth.jpg`).
- Obverse gold phoenix; reverse magenta **8** over galaxy; rim mottos **Divine Right** / **Universal Wealth**; rim title **Phoenix God, Anterranian Monarch** (art may print MONACH).
- Still **virtual only** — no cash value, no crypto, no real-money purchase/redemption. Heraldry: `docs/modules/HERALDRY.md`.


## Aethel family (batch 24)

- Full diegetic economy section: **`docs/modules/ECONOMY.md`** + `economies.aethel` in `data/items/currency.json`.
- **Stasis** = stable soft-currency face; **Ascendant** = variable in-game asset (game balance only); **Key** = wallet/access card; notes / lion coins / sigil as listed there.
- Still **virtual only** — no cash value, no crypto, no real-money purchase/redemption. Pending: Aethel ↔ Phoenix God Coin / Embers relationship; lion coin meaning.
