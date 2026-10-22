# Foxy spec: dialogue UI (SBX-F9)


> 2026-10-22: written before the dev/Foxy split. Ids like SBX-SIM-n point at the inactive reference model in `scripts/sim/` (Foxy owns those features now). Dev-side APIs: QuestEngine (SBX-2), WorldHost (SBX-3), MarketDelivery (SBX-5), FreePlay (SBX-7).
Owner: **Foxy**. A dialogue engine is not built yet (no tracker row yet; it would be dev-side): nodes with text, speaker, options, conditions and effects.

## Abilities
- Talk to an NPC or companion: show the line, speaker name, up to 4 options.
- Options can be locked with a reason ("needs speech 20", "needs Friendly with Frost Wardens") from the
  engine; show them greyed with the reason, never hide them silently.
- Effects reported back to the engine: reputation change (`Factions.change`), quest accept (sandbox-dev
  quest engine), item give, mood moodlet (`NeedsMood.add_moodlet`).
- Voice: lines can play through the companion's TTS voice (EveCore voice profile) with lip sync.
- History: scroll back the conversation; "skip" and "auto-advance" options.
- Companion chat stays the free-text chat panel; dialogue trees are for scripted NPC talks.

## Engine contract (proposed)
`Dialogue.start(npc_id, actor) -> {node}`; `Dialogue.choose(option_id) -> {node | end}`; each node:
`{id, speaker, text, options: [{id, text, locked_reason}]}`.
