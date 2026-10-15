# Legacy Persona Import Log (scaffold)
Source: `/workspace/phoenix-voxel-scaffold.zip` (format v1). Target: schema v3 personas. No new folders were created; the legacy ids are kept as `legacy_id`.

| Legacy folder | Merged into | Fields added | Already present / kept v3 |
|---|---|---|---|
| foxy_ani_firecaster_grey | companions/foxy_ani | none | name, role, system_prompt, voice_style, voice, abilities, temperature, memory_schema, tools (normalized into tools{}), world_only_tools (normalized into tools{}), chat_tools (normalized into tools{}), starter_message |
| metallic_companion | companions/circuit_nova | none | name, role (v3 value kept), system_prompt, voice_style, voice, abilities, temperature, memory_schema, tools (normalized into tools{}), world_only_tools (normalized into tools{}), chat_tools (normalized into tools{}), starter_message |
| aaliyah_refined | companions/aaliyah | none | name, role (v3 value kept), system_prompt, voice_style, voice, abilities, temperature, memory_schema, tools (normalized into tools{}), world_only_tools (normalized into tools{}), chat_tools (normalized into tools{}), starter_message |

Each persona.json also has a `provenance` block. The legacy memory_export.json files were empty templates, so they were not merged.
