# Issue Tracking Workflow (Jira/Trac-style)

> **Planned module, not implemented. No live servers or services exist.** Phase: 0 onward (process).

Use **GitHub Issues + Projects** as the tracker (no self-hosted Jira/Trac server), with a Jira/Trac-style workflow layered on through labels.
- **Types:** `type:bug`, `type:feature`, `type:task`, `type:epic`, `type:doc`.
- **Workflow:** Backlog → Ready → In Progress → In Review (PR open) → Done; plus Blocked.
- **Priority:** `P0`–`P3` (matches TASK_TRACKER.csv). Components: `comp:voxel`, `comp:companion-ai`, `comp:android`, `comp:ui`, `comp:docs`.
- **IDs:** a `PRI-n` / milestone in the title for traceability. Commits and PRs reference `#issue`. Trac-style milestones = roadmap phases.
- **Templates:** a bug report (device, Godot + voxel version, steps, logs) and a feature request (goal, acceptance criteria).
- Until `gh` is authed, `docs/TASK_TRACKER.csv/.md` are the source of truth. Later they get migrated into issues.
- The Task Manager Bot keeps the trackers in sync (see COORDINATION.md).
