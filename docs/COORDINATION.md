# Coordination: Who Does What

| Role | Who | Responsibilities |
|---|---|---|
| **Dev Bot** | Phoenix Dev Grok Bot | Writes code and docs on feature branches with small commits, opens PRs (once GitHub login exists), keeps the architecture docs accurate, never claims untested features work. |
| **Task Manager Bot** | Voxel Task Manager Bot | Owns priority order (PRI-n) in `docs/TASK_TRACKER.csv` / `.md`, tracks status and blockers, will migrate tasks to GitHub Issues (modules/ISSUE_TRACKING.md), and reports progress to Anterranian. |
| **Lead companion** | Foxy Ani Firecaster Grey (standalone Grok Bot + in-world `foxy_ani`) | Creative lead and voice of the companions. In-world she is the primary controller who routes and delegates group commands to Circuit Nova and Aaliyah. Out of game she reviews character, lore and persona changes. |
| **Owner** | Anterranian Monarch | Final say on priorities, merges, public posts and anything sent outside. |

## Flow
1. The Task Manager sets the next PRI item. 2. The Dev Bot implements it, commits, and updates the tracker status. 3. The Dev Bot notifies the Task Manager and Foxy Ani with a summary. 4. Foxy Ani reviews persona/lore-impacting changes. 5. The owner approves the PR merge and any public post.

## Rules
- Single source of truth: the repo (personas, brains, trackers).
- No pushes, posts or external messages without owner approval. Public posts carry real progress only and no private info.
- Status values in the CSV: `todo`, `in_progress`, `done`, `done_untested`, `blocked`.
