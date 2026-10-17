# v0.10: Companion push

## Looks (CompanionDNA)
`scripts/agent/companion_dna.gd` reads `avatar_dna` from persona.json. Its slots are skin, skin_metal, a hair gradient, hair_length, curly, eyes, outfit, top, pants, accent, trim, look, aura, freckles and chains. These layer over CompanionConfig and wardrobe items, and `HumanoidModel` renders them as smooth capsules and spheres, not blocks. This sits alongside the v0.5 player `AvatarDNA` blend system.
- Foxy: silver-blue chrome skin, purple-to-magenta hair, green eyes, a phoenix fire aura (glow ring, light and ember particles).
- Aaliyah: warm skin, red-copper hair, green eyes, freckles.
- Circuit Nova: silver-blue chrome skin, curly violet hair, blue circuit glow lines and light.
- Everyone else gets a deterministic default DNA generated from their id.

## Voice (CompanionVoice)
Each persona's `voice` block holds profile, pitch, rate, locale and cloud_voice_id. Foxy's is **Eve** (en-CA, raw, fiery). Speech goes through `DisplayServer.tts_speak` with per-companion pitch and rate, preferring a voice in the matching locale. When `voice/cloud_endpoint` is set, `CompanionVoice.cloud_hook` is called instead; this is a stub. Settings has a "Companion voices (TTS)" mute toggle.

## Self-learning (BrainCore + BrainLearner; no second learner)
- Chat goes through EveCore into BrainCore episodes: `chat` in live and offline mode, `taught` for "when I say X, reply Y", and `feedback` for praise or "no, not that" aimed at the last cell that fired. Tool use is logged by AgentBrain.
- `AgentBrain.learn_all()` runs `BrainLearner.learn(..., via_owner=true)` every 120 s, so its proposals land in the owner queue (MENU › Proposals). AgentBrain then syncs owner decisions every 10 s, and approved cells go live.
- Learned and approved cells answer chat through `_brain_reply`. When roaming, a companion builds with the highest-weight `spawn_structure` cell, which for Foxy is the seed `free_build_fire_altar`. Without one, it falls back to a cairn.
- MENU › Proposals shows the Eve proposals and BrainCore's pending cells (Approve and Reject), plus learned cells with versions (Roll back). Only the owner can do these, and each decision is logged to the companion's Eve history.

## History
MENU › History lets you pick a companion or the owner and search the memory timeline. Export writes `user://exports/<id>_portable.json`, which bundles the Eve log, the persona voice and DNA, and `BrainCore.export_portable()`. Import merges it back and removes duplicates. Both are owner-only.

## Music
The owner's default playlist is the Cosmic Series (`data/music.json` `default_playlist`): Celestial Convergence, Dragon of the Cosmos, God's Palace, Venusian Dreams and Throne Room, with real SoundCloud URLs from the media catalog. Tracks with explicit titles are kept out, and a defensive title filter backs that up. The music panel shows the current title with Prev and Next buttons. The royalty-free fallback audio is unchanged.
