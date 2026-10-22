# Foxy spec: free-play games UI (SBX-F12)

Owner: **Foxy**. Dev logic: `scripts/sandbox/free_play.gd` (SBX-7) + `LegalReview`.

## Abilities
- Prize wheel and reels screens that call `FreePlay.spin(actor, game, ctx, now)` and only animate the result the server returns.
- Odds panel on every game from `FreePlay.odds(game)`, one tap from the spin button.
- Play-token balance (`PlayTokens.balance`), where tokens are earned. There is no buy button, no refill and no Aethel Coin anywhere on these screens.
- Age gate: casino-themed games 18+, other chance games 13+. Show the `LegalReview` reason when refused.
- Prizes: play tokens or account-bound cosmetics marked "can't be traded".
- Session timer and a "take a break" reminder.
- Entertainment only. Any currency tie-in stays disabled (LEGAL REVIEW).
