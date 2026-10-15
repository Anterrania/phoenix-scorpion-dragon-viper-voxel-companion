# Brain Files

> **Future module, not implemented.** Phase: Phase 5. Design notes only.

A companion's "brain" is a folder of human-readable text files, so the same brain can run in-game, in the standalone Grok Bot, or be edited by hand. Each file is a **brain cell**: small, single-purpose and versioned.
```
companions/<id>/brain/
  manifest.json        # list of cells, schema version, owner-approved flags
  identity.md          # who I am (mirrors persona.json personality)
  values.md            # rules / boundaries
  memory/
    facts.jsonl        # one fact per line {t, text, source, weight}
    episodes.jsonl     # summarized events {t, summary, realm, people}
  skills/
    build_fire_altar.md  # step list + VoxelTool tool-call template
    follow_player.md
  mood.json            # current mood + needs snapshot
  relationships.json   # affinity per entity
  drift.json           # personality deltas
```
- **Cell format:** markdown/JSONL with a header line `cell: <name> v<version> updated: <iso>`.
- **Loading:** the AI adapter builds its prompt from identity + values + top-k relevant facts and episodes + skills that match the request.
- **Sync:** the folder zips into `memory_export` for the standalone bot. Merges by timestamp, with conflicts kept as duplicates for review.
- **Privacy:** brains stay on the device by default. Nothing private goes into the repo; the example brains here are templates only.
