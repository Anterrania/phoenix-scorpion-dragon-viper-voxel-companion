# Bot Integration — one identity, two surfaces

Each companion exists in the 3D voxel world AND as a standalone chat bot, sharing `companions/<id>/persona.json`.

## Persona → standalone bot
| persona.json field | Standalone bot field |
|---|---|
| `name` | Bot name |
| `role` | Short description / tagline |
| `system_prompt` + `voice_style` | Instructions / system prompt |
| `starter_message` | Greeting |
| `abilities` | Description bullets (drop world-only ones) |
| `chat_tools` | Tools exposed in chat (`remember` only) |
| `memory_schema` | What the bot should persist |

`world_only_tools` (`place_voxel, carve_area, spawn_structure, follow, move_to, build_realm, emote`) **only work in-game**. In the standalone bot, append: "You cannot act in the voxel world from here; describe builds as plans the player can bring into the game."

## Memory sync
Format: `companions/<id>/memory_export.json` (`schema_version, companion_id, source, facts[], history[], relationship, built_structures[], updated_at`).
1. **Manual (now):** in-game `AgentBrain.export_memory(id, path)` writes the file; paste/upload it into the bot's memory or knowledge. To bring bot memory back, save it in the same format and call `AgentBrain.import_memory(id, path)`. Import merges facts (dedup), appends history (capped at 30), never deletes.
2. **Sync endpoint (later):** optional `sync.endpoint` in settings; `PUT/GET /companions/<id>/memory` with the same JSON, last-writer-wins per fact plus `updated_at`. Opt-in, user's own server, auth token from settings.

`built_structures` is in-world data; bots keep it but ignore it.
