# Data Storage, MySQL Sync & Backup

> **Planned module, not implemented. No live servers or services exist.** Phase: 4 (local) / 9 (server sync).

## On device (default)
- World chunks are stored in `VoxelStreamSQLite` (`user://worlds/<realm>.sqlite`).
- Game data (inventory, needs, relationships, settings) goes in a separate SQLite DB `user://phoenix.db`, through a godot-sqlite GDExtension that has to be vetted for Android arm64.
- Brains are plain files under `user://brains/<id>/` (see BRAIN_FILES.md).
- Schema migrations use a `schema_version` table and ordered migration scripts.

## Optional MySQL server sync (future, opt-in)
- The game **never talks to MySQL directly**. A small HTTPS API (e.g. a REST service in front of MySQL/MariaDB) gives auth, rate limits, and keeps DB credentials off the phone.
- Sync model: each record carries `uuid`, `updated_at` and `device_id`, using last-write-wins plus a conflict log. World chunks sync as compressed blobs, edited chunks only.
- Off by default, enabled in Settings with an account. Privacy policy required.

## Backup / restore
- **Local export:** zip `phoenix.db` + world DBs + brains → `Phoenix_backup_<date>.zip` via the Android share sheet or Storage Access Framework.
- **Restore:** pick the zip, validate the manifest + schema version, then swap atomically (keep the previous copy until it succeeds).
- Android Auto Backup rules exclude large world files by default (a setting can include them).
- Optional encrypted backups (passphrase → key) for brains.
