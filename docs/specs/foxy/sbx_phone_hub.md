# Foxy spec: in-world phone hub (SBX-F4)

Owner: **Foxy**. Open-world "phone in your pocket" concept, our own UI.

## Abilities
- Contacts (friends, companions, quest givers) and messages (Social messaging).
- Jobs app: lists `QuestEngine.available(actor, now)`, accepts with `accept()`, tracks with `track()`.
- Map pins for the tracked quest's objectives; region wake ETA from `WorldHost.request_entry()` ("waking up, ~20 s").
- Market app: `MarketDelivery` listings, Received folder, redelivery.
- Camera/photo (quest objective type `photo`).
- Non-violent by default. No crime or heat apps except where estate `allow_damage` is on.
- Nothing in the phone spends Aethel Coin unless `LegalReview` allows it (fixed price, price shown).
