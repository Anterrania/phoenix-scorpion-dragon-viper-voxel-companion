# Offline-First Design — PLAN / SCAFFOLD
- The game must run with **no network**: voxel generation is local and seeded, and LocalProvider in `scripts/ai/ai_provider.gd` gives companions a basic voice.
- GrokProvider is optional and online-only. When there's no connection, fall back to LocalProvider and queue memory updates.
- Persistence is local first (`user://` saves, `companions/<dir>/memory_export.json` format). Sync to MySQL is a later, optional step (DATA_MYSQL_AND_BACKUP.md).
- Conflict policy: last-writer-wins per field, plus an append-only memory log so nothing is lost.
- Importers (IMPORTERS.md) work offline on files the user exported themselves.
