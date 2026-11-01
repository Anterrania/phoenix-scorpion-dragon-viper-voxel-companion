# v0.13.0 modules — Brain Cell core, companions admin, intro, Sparks, icons

## Brain Cell core (`scripts/brain/`)
| Module | Role |
|---|---|
| `InteractionLedger` | Local append-only, hash-chained record (`user://brain_core/ledger_NNNN.jsonl`, 1000 per segment). `append`, `record_interaction`, `verify`, `records`. Every chat turn = one record (transcript + links to recent scene snapshots for replay). No tokens, no network. |
| `MemoryVault` | Versioned, append-only memories per companion. Writers: `system`, `owner` (owner session), `ai` (refused while locked — the default). `owner_unlock_ai(seconds)` opens a window; `lock()` closes it. Private/financial text is refused. No edit/delete API. |
| `PatternRecall` | Word-overlap + word-order similarity over vault + ledger transcripts; flags déjà vu (≥ 0.6); `recurring()` finds themes the companion keeps returning to. |
| `SceneSnapshots` | In-world events only (realm, district, weather, time of day, companion join/leave, Heaven edits, teleports, light). Refuses camera/mic/screen/GPS/contacts. Duplicates skipped. |
| `PersonaPresets` | Starting personality: **Foxy Ani Firecaster Gray** (default) or **No personality**. Never overrides a persona's own prompt; appends grown traits from recall. |

Settings: `brain/record`, `brain/scene_snapshots`, `persona/preset`, `voice/{pitch,rate,locale,voice_id}`.

## Admin > Companions (`scripts/admin/companions_screen.gd`)
Owner only (lock card + Unlock otherwise). Talk to companions here, add any of the persona folders (with the
cinematic intro), open the moved panels (Talk, Avatar, Roleplay, Wyrmlings, Proposals, History, Nearby), Brain
Cell lock/verify/recall, personality toggle, voice sliders and test. Main menu: "🧬 Companions" redirects here.
Companions you add come back on next launch.

## Cinematic intro (`scripts/ui/companion_intro.gd`)
Fade → letterbox → gold/magenta flare + sparks → name reveal → spoken greeting → fade out (~6 s). Tap to skip.

## Creator Sparks (`scripts/economy/creator_economy.gd`)
In-game credit only. Earn: 1 per unique viewer per post (cap 1000/day), tips (1–500, 13+, no self-tips),
70% of marketplace sale price. Spend in-world. Buy / cash-out / convert are HARD in LegalReview.
Aethel real-money exchange stays LEGAL REVIEW; casino stays free play.

## One build (`scripts/system/build_info.gd`)
Same APK and features for everyone; only owner gates and device capability differ. Tests fail if a demo flavor appears.

## Icons (`tools/icons/`)
`python3 tools/icons/make_icons.py && godot --headless --path . --script res://tools/icons/render_icons.gd`
→ `assets/brand/` launcher 192, adaptive fg/bg/monochrome 432, favicons 16/32/144/180/512, `icon.svg`.
