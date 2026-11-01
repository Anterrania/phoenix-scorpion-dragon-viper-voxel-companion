# Observation — 2026-10-31 (Phoenix Voxel Dev Bot, v0.13.0 package)

**When:** Saturday Oct 31, 2026, evening (CT). **Who:** Phoenix Voxel Dev Bot (executor).
**Scope:** read-only review of three repos before the v0.13.0 PR. Nothing was changed in the two web repos.

## 1. phoenix-scorpion-dragon-viper-voxel-companion (this repo, Godot 4.7.2 + Zylann voxel)

- `main` at `6adbd9c` (#50 HEAVEN-9 + CHAT-16). 16 commits to main since Oct 24. Suite: 3,274 checks, 0 failures at base.
- 40 companion persona folders under `companions/`; three companions are placed statically in `main_world.tscn`
  (Foxy Ani, Metallic, Aaliyah). Others had no in-app way to be added.
- Companion features (Talk, Avatar, Roleplay, Wyrmlings, Proposals, History, Nearby) sat in the public main-menu grid
  next to Play/Settings. The admin panel (`AdminScreen`) already had an owner-gated glass Home menu — the natural home.
- Memory: `BrainMemory` (facts/episodes jsonl per companion) and `BrainCore` cells with versions + rollback.
  There was no write lock separating the AI from the owner, no tamper-evident log of conversations, and no
  similarity recall across sessions.
- Voice: `CompanionVoice.speak()` returned `no_tts` (silence) whenever `DisplayServer.tts_get_voices()` was empty.
  On Android that list fills asynchronously, so the first lines after launch were silent. No user voice settings
  beyond on/off.
- Economy: Aethel Coin (fixed-price purchases only), PlayTokens (earn-only, casino free play), LegalReview policy
  with exchange / cash-out / p2p / NFT all HARD. Creators earned nothing from views or sales.
- Branding: `icon.svg` only; Android `launcher_icons/*` empty (Godot default adaptive icon on device); no favicons.
- Builds: one Android preset, CI derives versionName from the latest tag (would have stamped 0.12.2 on a 0.13.0 build).
  No demo flavor exists — good; kept that way and now tested.
- Tracker: Sonic Gage's priority lock (REL-013, HEAVEN-GIGA, INT-*, INT-NSFW blocked) was uncommitted in this worktree.

## 2. SkorpionViper (private, TypeScript web app)

- Active today ("Answer from the live mind…"). Vite/React-style `src/` with `brain/` (engine, store, voice) and views:
  admin, brain, court, feed, live, maker. Ships an Android wrapper (`android/` MainActivity) and a checked-in
  `artifacts/ScorpionViper.apk`.
- Useful ideas mirrored here (re-written in GDScript, no code copied): a brain "store" with versions, a voice
  layer that tolerates a missing voice list, an admin-first navigation model.
- Risk noted: a binary APK committed to the repo. Not touched (observe only).

## 3. scorpion-viper (private, TypeScript web app)

- Last commit Oct 24 ("Mix live into one floor…"). Companion images and `os/admin` assets; live/feed floor UI.
- Visual language matches PhoenixTokens (void black, magenta, gold, platinum). Its art was **not** reused; the new
  icons are generated from code (`tools/icons/make_icons.py`).

## Highlights → actions in the v0.13.0 PR

| Finding | Action |
|---|---|
| Companion menu public | Moved into Admin > Companions (owner only); old rows commented out; panels still reachable |
| No way to add the other companions | Add-a-companion list + cinematic intro |
| AI could write memory anytime | Brain Cell lock (default locked), owner-only time window, versioned append-only vault |
| No tamper-evident record | Local hash-chained interaction ledger with verify() |
| Silent first TTS lines on Android | Speak with the system default voice when the list is empty |
| Creators earn nothing | Sparks (in-game only): views, tips, 70% marketplace share |
| CI stamps old versionName | CI uses the higher of tag and preset version |
| Default icon on device | New launcher/adaptive/monochrome icons + favicons |
