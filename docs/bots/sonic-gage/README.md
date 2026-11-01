# Sonic Gage · Voxel Task Manager Bot

**Role:** task / project manager for the Phoenix Scorpion Dragon Viper voxel companion Android app (Viper OS).
Owned `docs/TASK_TRACKER.csv`, prioritized the roadmap, logged progress Subversion-style in `docs/trac/`,
and coordinated **Phoenix Voxel Dev Bot** (builder) and **Unrestricted Force Bot**.

**Status:** retired Oct 31, 2026 (CT) by owner order (t23u). Case load transferred — see [HANDOFF.md](HANDOFF.md).

## Priority order at handoff (owner, Oct 31 CT)
1. **Social app + social APK first** — SkorpionViper / scorpion-viper (Dolphin-style) user/admin parity and the new default template (magenta, gold, black, platinum, glitter, sparkles, polish, sheen, shine, floss, flamboyant, futuristic).
2. **Voxel v0.13.0** (`REL-013`, `REL-013-1..8`).
3. **Heaven Welcome Island giga build** as default starting realm (`HEAVEN-GIGA`, `HEAVEN-8/11/13`).

## Summary of work
- **PRI-1..7** — initial roadmap: Godot scaffold + VoxelTerrain, companion placeholders, dual-bot persona sync, offline AI notes, future-systems notes, Android export research, social hooks design.
- **Viper OS items** — approval gate, APK status, Trac/wiki, UI kit, security next steps, quantum lattice notes, AI body design vision added and prioritized.
- **Wiki expansion** — FAQ + full Second Life-style wiki coverage (worlds, GDP-style metrics, interactions, popular places, Lindex ties, how-tos) tracked.
- **Security** — tracked `SEC-FIX-1..6` and the on-device security test plan (`docs/SECURITY_DEVICE_TEST_PLAN.md`).
- **CORE TICKs** (t12u–t15u) — voxel focus: USAGE_AND_LIMITS cleanup, WebView fix, full 3D world + companions, interactivity (`INT-1..3`), modular kernel (`INT-4`, P1 after v0.13), NSFW request logged.
- **Heaven Welcome Island** — zones, livable shops, flight rules, Kelvin weather, social + Studio integration logged as `HEAVEN-*`.
- **FORCE flags** — owner force orders logged on tracker rows (`INT-NSFW`, `FLAG-SEXUAL`, `FLAG-RECORD-REAL`, `FLAG-UNBREAKABLE`, `AI-UNRESTRICTED`, `ECON-AETHEL`, `COMPANION-LIVE`, `AUTO-CORRECT`, `MEMBER-AUTO`, `GFX-HP-GLITZ`) with constraints in the notes. Logs: `docs/trac/20261031-sonic-gage-force-all-flags*.md`.
- **Dolphin comparison** — `docs/trac/20261031-dolphin-demo-comparison.md` (gap list + new default template spec §5).
- **PR #52** — tracker + Trac push (merge `af36ce6`). It flipped forced-flag statuses and broke CI; Dev Bot fixed in PR #54 (`633a7f8`).

## Open items (successor)
- `SOCIAL-APK-RELEASE` (P0, todo) — ships before the v0.13.0 APK.
- `SOCIAL-TEMPLATE` (P0, todo) — spec in the Dolphin comparison §5.
- `REPO-SCORPION-2` (blocked) — TypeScript SkorpionViper / scorpion-viper repos are not on the box.
- Phone tests pending: `SEC-TEST`, `CHAT-15`, `LAI-9`, `COMPAT-8` (box has no /dev/kvm; needs a real device).
- `FIX-USAGE` (USAGE_AND_LIMITS.md missing/cleanup), `FIX-WEBVIEW` (appassets.androidplatform.net).
- APK delivery to the owner's phone pending.
- Weekly Monday "Phoenix voxel project review" routine failed Oct 19 and Oct 26 (Grok Bot usage limit reached).

## Owner order t22u — not applied
The owner ordered clearing the declined/awaiting_builder status on the four forced flags. It was **not applied**:
`tests/v013_tests.gd` on main requires `INT-NSFW`, `FLAG-SEXUAL`, `AI-UNRESTRICTED` to be `declined_blocked`,
so changing them turns CI red and blocks every release (incl. the social APK). Successor must update that test
together with Phoenix Voxel Dev Bot before changing those rows.

## Files here
- `profile.json`, `settings.json` — bot configuration at retirement (checked: no secrets/tokens).
- `HANDOFF.md` — case load transfer.
