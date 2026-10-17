# Viper OS Admin & In-app Tracker

> **Status:** implemented in GDScript and headless-tested with Godot 4.7.2 (`tests/admin_tests.gd`: 92 checks). Everything is **local only**: no accounts, no servers, no network. Built on Foxy's Phoenix Glass kit (PR #17); see [UI_DESIGN_LANGUAGE.md](UI_DESIGN_LANGUAGE.md) §8.

Open it from the radial launcher (**12 o'clock ◎ Admin**) or MENU › 🛡 Viper Admin (`UIRoot.open_admin()`). Security (lock, PIN, e-stop, audit, backup) is at **2 o'clock 🛡** on the radial. All routes are in [SECURITY.md](SECURITY.md#access-paths-where-to-find-each-screen).

## Screens (portrait 720×1280, five swipeable tabs)
| Tab | What it shows | Kit pieces used (§8) |
|---|---|---|
| Home | Ticket rings (open / accepted / closed), pending brain proposals, companion energy (fire rings), revisions per day (LineGraph + hero `rN`), text report | GlassCard, RingStat, LineGraph |
| Tickets | Segmented filters (Open/New/Mine/Closed/All). Admin-table pill rows (avatar ring, `#id summary`, one status chip). **Swipe left** on a row for workflow actions. Tap a row to open a detail card with comments and links. 7 rows, then pages. | SegmentedPills, PillRow, PagedList, Toast |
| Wiki | Pages / Recent filter, pill rows, rendered page with Trac-style links, Edit → Save (new revision), History | same + RichTextLabel links |
| Timeline | Ring timeline, one day at a time (‹ › or swipe). Git commits + in-app revisions. Tap to expand into a glass card with the diff. **Hold 0.6 s to revert.** | RingTimeline, HoldButton |
| Profile | Sign-up stepper: name → avatar → voice → realm → done. Ring progress, 64 px inputs, primary pill at the bottom, swipe right to go back, phoenix burst at the end. After that, a profile card. | SignupStepper, RingStat |

New kit components (in `scripts/ui/kit/`, built to the §8 specs): `SwipePages`, `SegmentedPills`, `PillRow`, `PagedList`, `RingTimeline`, `Toast`, `HoldButton`, `SignupStepper`. `scripts/admin/ui/viper_kit.gd` is a thin helper over `themes/phoenix_glass.tres`, `PhoenixTokens` and `scenes/ui/kit/*`. It defines no colors of its own.

Not in this PR: §9 (3D companion nameplates and auras) and §10 (minimap/compass/HUD restyle). The design doc defers those until after v0.10.

## Data model (`scripts/admin/tracker/`)
Root: `ViperAdminData.root` = `user://viper` (tests use a throwaway `user://test_viper_*`).

- **RevisionStore**: SVN-style global counter `r1, r2, …` in `revisions.jsonl` + `head.json`. Each record holds `{rev, t (local ISO with offset), kind, path, author, message, before, after}`. Kinds are `ticket`, `wiki`, `brain_cell`, `world`, `profile`. Snapshots are capped at 32 KB. `history(prefix, kind)`, `get_rev`, `content_at(path, rev)`, `diff(rev)` (LCS line diff), and `revert(rev)`. A revert re-applies the old `before` through the kind's applier and **commits a new revision**, so history is never rewritten.
- **TicketStore**: `tickets.json`, seeded once from `res://data/admin/tickets_seed.json` (built from `docs/TASK_TRACKER.csv`). Fields: id, type (defect/enhancement/task), summary, description, status, resolution, priority P0–P3, component, milestone, owner, reporter, comments, revisions. The workflow is Trac's default: `new → assigned/accepted/closed`, `assigned → accepted/new/closed`, `accepted → assigned/closed`, `closed → reopened`, `reopened → assigned/accepted/closed`. Closing needs a resolution (fixed/invalid/wontfix/duplicate/worksforme). Comments that mention `rN` link that revision to the ticket.
- **WikiStore**: `wiki.json`, seeded once from `res://data/admin/wiki_seed.json` (`docs/*.md`, `docs/modules/*.md`, with WikiName taken from the filename, e.g. `VOXEL_ARCHITECTURE.md` → `VoxelArchitecture`). Page names must be CamelCase. Links: CamelCase names of existing pages, `[wiki:Name label]`, `#12` (ticket), `r42` (revision), `[changeset:abc1234]` (git commit). Rendering escapes BBCode first.
- **Brain cells share the r-number sequence.** `BrainCore.on_commit` is a static hook. `ViperAdminData` wires it so every `_commit_cell` and `rollback` becomes a `brain_cell` revision (`brain/<companion>/<cell>`). BrainCore's own `versions/<cell>.vN.json` stays the source of truth for rollback. A revert from the admin writes the old cell back, but only after it passes `BrainCell.validate` again.
- **World edits**: `ViperAdminData.record_world_edit(summary, region)` stores summaries only (no voxel data).
- **RepoTimeline**: read-only. `tools/export_admin_seed.py` exports `git log --first-parent` (sha, author, date, subject) to `res://data/admin/repo_log.json` at build time. Run `python3 tools/export_admin_seed.py` before an export.

## Privacy
- Sign-up stores name, handle, avatar preset, voice and realm in `user://viper/signup.json`, and mirrors the name and avatar into the `Profile` autoload. It never asks for email or phone. Text that looks sensitive (email, card number, "password") is rejected by the same `BrainMemory` filter used for companion memory.
- The owner role is the `Profile` role plus an unlocked `OwnerVault` session (PIN, PR #23). The admin screen does not grant it. Brain-cell reverts from the Timeline need that unlocked owner session (audit 2026-10-17).

## Visual references (inspiration only, nothing copied, no images in the repo)
- Karen Sori interview on the graphic design of *The Circle* (red/white corporate system, interface elements leaving the rectangle): https://www.pushing-pixels.org/2017/09/20/graphic-design-of-the-circle-interview-with-karen-sori.html
- Filmograph's title sequence ("bubbly, colorful shapes that animate in concentric patterns… stylized operating system"): https://www.filmograph.tv/project/the-circle
- Production design context (glass, openness, avoiding any real company's signature color): https://www.vanityfair.com/hollywood/2017/04/the-circle-tom-hanks-emma-watson-production-design-tech

The takeaway for Phoenix Glass: concentric rings and soft round shapes for status, glass and openness, and our own palette (black, magenta, gold, platinum) instead of the film's red.

## Screenshots
`godot --resolution 720x1280 -s res://tests/screenshot_admin.gd -- <out_dir>` renders all five tabs plus a wiki page into a throwaway data root. Local renders go in `/workspace/refs/admin_shots/` and are not committed.

## Limits
- There is no multi-user sync or merge. Revisions are per device. A grid-side tracker belongs to the Aurora-model grid services (ARCHITECTURE_AURORA_MODEL.md).
- The diff is line-based LCS, capped at about 500×500 lines.
- Switching tabs rebuilds only the tab being shown (audit 2026-10-17; it used to rebuild all five).
- `SwipePages` follows the finger 1:1 and snaps. Reduced-motion handling is not wired to a setting yet.
- Glass budget: the Home tab shows 4 GlassCards, over the §5 limit of 3 visible glass surfaces. On a phone only about 3 fit on screen at once, but it still needs a perf check on device.
