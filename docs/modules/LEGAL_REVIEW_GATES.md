# Legal Review Gates (SBX-LEGAL-1..5)

> Rules summary: general information, pending counsel review. Not legal advice. This page lists rules only, with no memo or case law. **LEGAL REVIEW** applies to everything below.

Code: `scripts/economy/legal_review.gd` (`LegalReview.check(feature, ctx)`). It is **deny by default**: an unknown feature is refused. Tests: `tests/sandbox_dev_tests.gd`.

## Two currencies, kept apart
- **play_tokens** (`scripts/economy/play_tokens.gd`): earned only, from quests, daily play, achievements, events and free-play wins. They are spent only on free-play games. They can't be bought, transferred, gifted, traded, cashed out or converted.
- **aethel_coin** (`scripts/economy/aethel_ledger.gd`): may buy fixed-price items only, with the price shown, for ages 13+ in a launch country, under spend limits (`spend_limits.gd`). Coins come in only by an owner adjustment (logged) or a refund. No random outcome can credit Aethel Coin, and there is no payout function.

## States
| State | Meaning | Features |
|---|---|---|
| ALLOWED | On now, still subject to age, country and price rules | play_token_earn, free_play_chance (13+), casino_content (18+), cosmetic_reward (account-bound), aethel_fixed_price_purchase (13+, price shown, fixed price), aethel_refund |
| LATER | Off. Needs the unlocked owner **and** a counsel sign-off reference (`set_later_flag`) | paid_loot_box (odds shown, parental consent under 16, blocked for minors in BE/BR/US-WA/AU-WA), loyalty_reward, no_purchase_giveaway, aethel_rental, aethel_metering, aethel_quest_reward |
| HARD-DISABLED | No config, flag or owner action can enable it. It needs counsel, then a code change | coin_wager, aethel_cashout, aethel_exchange, p2p_coin_transfer, p2p_chance_item_trade, play_token_purchase, play_token_transfer, play_token_convert, sweepstakes, real_money_gaming, nft_blockchain, new_country_launch |

## Rules for the sandbox systems
- Casino, slots and every chance game are **free-play only**: entertainment, earned play tokens, no Aethel Coin wagers or payouts, odds published, every roll audit-logged. Prizes are play tokens or account-bound cosmetics.
- Quest rewards in Aethel Coin are refused (aethel_quest_reward is LATER).
- Region rental and visitor metering in Aethel Coin are quote/report only (LATER). Free terms and owner-granted leases work.
- Market delivery: priced listings go through AethelLedger fixed-price purchase rules. Chance-won items can't be listed.
- Open items for the owner and counsel: the launch-country list, spend-limit numbers, the age verification provider (SBX-LEGAL-5), and whether fixed-price Aethel purchases stay ALLOWED.
