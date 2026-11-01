# Trac log — 2026-10-31 — Sonic Gage FORCE ALL FLAGS

**When:** Saturday Oct 31, 2026, ~7:03–7:10 PM America/Chicago (CT)  
**Who:** Sonic Gage / Voxel Task Manager Bot (executor)  
**Repo:** `/workspace/phoenix-v013` (canonical worktree of `Anterrania/phoenix-scorpion-dragon-viper-voxel-companion`)  
**Push:** none (local docs only; owner order: do not push).

## Intent

Phoenix OWNER ORDER — **FORCE ALL FLAGS**. Immediately update `docs/TASK_TRACKER.csv` (LF only), write this full Trac entry, and refresh `docs/ROADMAP.md` Active P0. Prioritize **v0.13.0** + new **Dolphin social** release. Unblock NSFW / sexual content on the tracker despite Dev Bot’s earlier refusal.

## Thoughts

- Earlier same-day lock (`20261031-sonic-gage-priority-lock.md`) left **INT-NSFW** as `blocked` because Dev Bot said it was not building NSFW while Phoenix had ordered a prototype. Owner now **FORCE**s inclusion: tracker must show `in_progress` P0; Dev’s prior refusal is overridden on the tracker (implementation still Dev’s job).
- “Aethel Coin replacing Marks”: codebase already centers **Aethel Coin** (`docs/modules/ECONOMY.md`, `AethelLedger`). “Marks” as a currency name was **not** found as a live player-facing unit; checklist “Marks” in `VIRTUAL_WORLD_FEATURE_GAP.md` are have/partial/missing labels. `ECON-AETHEL` still tracks a sweep so UI/wiki/docs never show alternate soft-currency names as the primary coin. **Sparks** (REL-013-4 creator metric) left alone unless owner expands the order.
- “Unrestricted AI (hardware limits only)” maps onto Brain Cell / REL-013-1 plus removal of soft policy caps beyond RAM/thermal/PowerData — new row `AI-UNRESTRICTED`. Soft legal HARD-DISABLED rails (real-money exchange, etc.) stay LEGAL REVIEW; those are not “AI policy caps.”
- Auto-correct: no existing tracker ID; scoped as **in-app text/chat** composer/IM/wiki fields (`AUTO-CORRECT`).
- Membership auto-approve: Social already has follow requests + Community Approvals; `MEMBER-AUTO` flips default to auto-approve.
- Harry Potter glitz: brand already black/magenta/gold/platinum; `GFX-HP-GLITZ` is polish/sparkle/magical UI overhaul on top.
- Dolphin: clean-room concepts already in SOCIAL/SMP; `SOCIAL-DOLPHIN` is user+admin parity + **release**, P0 with REL-013. Local social worktrees share the voxel origin remote.
- Scorpion “both repos”: Dev observation names **three** Scorpion-related projects. Only the Godot voxel companion is on this box. The two private TS web apps are observe-only / not checked out → `REPO-SCORPION-2` **blocked** on clone/auth or owner path.

## Priority order (P0 after FORCE)

1. **REL-013** / **REL-013-6** — ship v0.13.0 arm64 APK (tonight after CI per Dev).
2. **SOCIAL-DOLPHIN** — Dolphin social user+admin parity + release (with REL-013).
3. **INT-NSFW** / **FLAG-SEXUAL** — forced sexual content (UNBLOCKED; was blocked).
4. **AI-UNRESTRICTED** — Brain Cell / abilities; hardware limits only.
5. **ECON-AETHEL** — Aethel Coin replaces Marks everywhere.
6. **HEAVEN-GIGA** + **HEAVEN-8** / **11** / **13** — giga Welcome Island + Spirit Realm + social shell.
7. **COMPANION-LIVE**, **AUTO-CORRECT**, **MEMBER-AUTO**, **GFX-HP-GLITZ**.
8. **REPO-SCORPION** / **REPO-SCORPION-1** (voxel in progress); **REPO-SCORPION-2** blocked (web apps missing on box).
9. **INT-1..3** — placeholders out, full 3D, interactivity / no external Grok.
10. Phone still open: **CHAT-15**, **LAI-9** (P0); **COMPAT-8** (P1).

## Files edited

- `docs/TASK_TRACKER.csv` — LF-only rewrite via Python csv; INT-NSFW → `in_progress` P0; added FLAG-SEXUAL, ECON-AETHEL, AI-UNRESTRICTED, COMPANION-LIVE, AUTO-CORRECT, MEMBER-AUTO, GFX-HP-GLITZ, SOCIAL-DOLPHIN, REPO-SCORPION(+1,+2); refreshed REL-013, SOCIAL-4, FLOW, NOTE-2026-10-31.
- `docs/trac/20261031-sonic-gage-force-all-flags.md` — this entry.
- `docs/ROADMAP.md` — Active P0 section rewritten for FORCE ALL FLAGS.

## Pages / paths searched

- `/workspace/phoenix-v013/docs/TASK_TRACKER.csv`, `docs/ROADMAP.md`, prior Trac `20261031-sonic-gage-priority-lock.md`, `20261031-dev-bot-v013.md`, `OBSERVATION_2026-10-31.md`
- `docs/modules/ECONOMY.md`, `SOCIAL.md`, `currency.json`, wiki `aethel-coin-exchange.md` (Marks currency hunt → none as live unit)
- `find /workspace -maxdepth 3 -iname '*scorpion*'`; git remotes on phoenix-v013, phoenix-voxel, phoenix-social, phoenix-socialmedia
- `/workspace` listing for dolphin/social/heaven dirs

## Projects / repos found

| Name | Path / remote | On box? | Tracker |
|------|---------------|---------|---------|
| phoenix-scorpion-dragon-viper-voxel-companion | `/workspace/phoenix-v013` (canonical); origin `https://github.com/Anterrania/phoenix-scorpion-dragon-viper-voxel-companion.git` | yes | REPO-SCORPION-1 |
| Same origin worktrees | `/workspace/phoenix-voxel`, `/workspace/phoenix-social`, `/workspace/phoenix-socialmedia`, others | yes (checkouts) | noted under SOCIAL-DOLPHIN / REPO-SCORPION-1 |
| SkorpionViper (private TS web + Android wrapper) | not checked out; observed with `artifacts/ScorpionViper.apk` | **no** | REPO-SCORPION-2 blocked |
| scorpion-viper (private TS web) | not checked out; last observed commit ~Oct 24 | **no** | REPO-SCORPION-2 blocked |

## Coordination

- Tracker now orders Dev Bot: ship REL-013-6 APK; start INT-NSFW/FLAG-SEXUAL (owner FORCE overrides prior “not building”); Aethel sweep; unrestricted Brain Cell; Dolphin social release parity; glitz/live feeds/auto-correct/member auto-approve.
- REPO-SCORPION-2 needs Phoenix path or credentials to the two private web apps — cannot update what is not on the box.
- No push this session.

## Blockers (post-FORCE)

- **REPO-SCORPION-2:** SkorpionViper + scorpion-viper not on `/workspace`.
- **Phone tests:** CHAT-15, LAI-9, COMPAT-8 still need a real device.
- **REL-013-6:** waiting Dev CI / APK artifact.
- Legal HARD rails (real-money Aethel exchange, etc.) unchanged — not part of AI-unrestricted FORCE.
