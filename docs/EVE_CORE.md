# Eve Core (port of the owner's Vala "Anterranian Eve Core")

Source: `docs/vala_reference/AnterranianEveCore.vala`. Port: `scripts/ai/eve_core.gd` (`EveCore` + inner `EveBrainCell`).

## Model
- One `EveCore` per companion, keyed by persona id (`companions/<id>/persona.json`), via `EveCore.for_companion(id, persona)`. The owner has a core too (`phoenix`) for player music and land actions.
- Memory entries are dictionaries: `event, location, state, voice, content, timestamp` (+ `companion`, optional `fire_theme`, `role`, `tool`, `output_mode`). Saved to `user://eve/<id>.json` (last 500).
- `memory_hash` is a plain id string (`ANTERRANIAN-BRAIN-<id>`). No NFT or blockchain.
- **Lock:** cells start locked and unlock only when `Profile.is_owner()` is true, i.e. after the owner code. A locked cell drops writes, and the lock is re-checked on every access.
- **Voices:** Foxy (`foxy_ani`) = **Eve** (Canadian, raw, fiery). Other companions use `persona.voice.profile`, falling back to `Phoenix_Default_Voice`. A voice of `""` or `"Default"` means the companion's own voice.
- **Fire theme:** Foxy's entries carry `fire_theme: ["phoenix","ember","Venus"]`.
- Media methods (`generate_image/video`, `create_music`, `create_duet`, `output_audio/video`) only log requests. They don't generate anything.

## Owner approval queue
`propose_update(desc)` logs a `PendingApproval` entry and adds it to `user://eve/proposals.json`. It stays pending until Phoenix taps Approve or Reject in **MENU › 📜 Proposals**. `EveCore.decide()` refuses anyone who isn't the owner.

## Wired hooks
- Chat: player lines (`AgentBrain.chat`) and companion replies (`reply_ready`, live or offline).
- Building: successful `spawn_structure`, `carve_area` and `place_voxel` tool calls (companion core), plus player Land Tools terraform (owner core).
- Music: every `MusicRadio.tune()` (owner core).

## BrainCore adapter
`EveCore.BrainAdapter` forwards every entry and proposal to a global `BrainCore` class when one exists, through `store_entry(id, entry)` and `queue_proposal(p)`. `feature/brain-core` was not on origin at port time, so local `user://eve` storage is the fallback and is always written. Rename these two calls to match BrainCore's API once that branch lands.

## Tests
`_eve_tests()` in `tests/run_tests.gd`: lock, owner unlock, plain hash, voice fallback, fire tag, duet, proposal gate, persistence.
