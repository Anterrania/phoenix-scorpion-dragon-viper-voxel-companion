# v0.13.1 follow-ups (voxel app)

Owner scope added Oct 31, 2026 (after v0.13.0 shipped). All of it stays in-game, local-first, and owner-gated.

## Companions Live (`scripts/social/companion_live.gd`, `live_feed_screen.gd`)
- Shows each companion's creative space: what they are building, shaping or exploring, taken from the
  in-world scene events already in the Brain Cell ledger (`SceneSnapshots`).
- A **LIVE** badge appears when the companion was active in the last 10 minutes. Live cards are listed first.
- Cards show a chat **count** only. Chat text never appears in the feed.
- Viewing is on your own device only (owner / local). Other members get "Companion live feeds show on your own device."
- To share a card publicly, use "Share to feed". It posts as the companion, so it lands in **pending approval**
  and you approve it first.
- Open it from the main menu (📡 Companions Live), Admin › Companions › 📡 Live, or `Social.feed_page(viewer, "live")`.

## Auto-correct and repair suggestions (`scripts/input/text_assist.gd`)
- Every text field gets auto-correct when you finish a word: common typos, missing apostrophes (dont → don't),
  and a lone i → I. `TextAssist.undo_last(field)` puts the last fix back.
- It never touches PIN, password or other secret fields, or fields marked `no_autocorrect`. It also leaves URLs,
  emails, @handles, numbers and code-like words alone.
- Words with two possible meanings (id, ill, lets) are only offered as suggestions and never changed by themselves.
- Repair chips under the companion chat box offer a cleaned-up sentence. Tap one to use it. Nothing is sent by itself.
- AI repair: `TextAssist.ai_hook` (a Callable) can point at a configured model. Its result is only offered as a
  chip. With no model set up, it stays off.
- Settings: `input/autocorrect`, `input/capitalize`, `input/ai_suggest`. There is an Auto-correct on/off button in Settings.

## Group join policy (`Social.group_create` opts, `Social.group_set_join_policy`)
- `auto_approve: true` means join requests are accepted at once. The member gets a welcome note and officers get
  a notice. The group is still not open-join.
- An optional `min_tier` (a Tiers.ORDER name) refuses lower tiers.
- Block lists and the mature/age gate still apply.
- When an officer turns auto-approve on, pending requests that qualify are admitted.
- The default is unchanged: officers approve each request.

## Glam pass (`scripts/fx/glam_fx.gd`)
- Original procedural art only: a 4-point star and soft dot drawn in code, coloured with the magenta → gold → platinum ramp.
- Effects:
  - additive glitter/sparkle layer on the main menu and Companions Live
  - sheen shader for buttons and cards (`GlamFx.shine`)
  - bloom on the world environment
  - magic motes swirling around the player
- Levels: off / subtle (default) / full, set with the "Glam:" button in Settings. Power Saver tones full down to subtle.

## Currency
The voxel app's in-game currency is already **Aethel** (`aethel_ledger.gd`). There is no "Marks" currency in this
repo, so nothing was renamed. Real-money exchange stays LEGAL REVIEW (HARD).
