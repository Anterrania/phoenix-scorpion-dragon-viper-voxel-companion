# Brain Files (brain cells)

> **Status: implemented (v0.10, branch `feature/brain-core`).** Verified headless with Godot 4.7.2 + godot_voxel 1.7x (`tests/brain_tests.gd`, run by `tests/run_tests.gd`). Rendering, UI for approvals, and on-device use are not built yet.

A companion's brain is a set of small **data-only** rules ("cells") plus a memory log. The same files work in-game (`BrainCore`) and in the standalone Grok Bots. The bots read them as **memory and instructions only, never as executable code**.

## Code (scripts/brain/)
| File | Role |
|---|---|
| `brain_cell.gd` (`BrainCell`) | Schema constants + `validate()`. Whitelists trigger, condition and action types, caps size (4 KB), checks ids, restricts tools to the persona whitelist. |
| `brain_memory.gd` (`BrainMemory`) | `facts.jsonl` (long-term, deduped, max 500) + `episodes.jsonl` (episodic log, max 2000). Refuses or redacts card-like numbers, emails and password/SSN/IBAN words. |
| `brain_core.gd` (`BrainCore`) | Loads seed + learned cells, `evaluate()`/`best()` per event, `reinforce()` (bounded ±0.05 weight), `propose()`/`approve()`/`reject()`, `versions()`/`rollback()`, `audit.jsonl`, `export_portable()`. |
| `brain_learner.gd` (`BrainLearner`) | Turns episodes into proposals: feedback → reinforcement; "taught" replies → say-cell proposal; a keyword followed by the same successful tool ≥3 times → tool-cell proposal. |
| `brain_bus.gd` (`BrainBus`) | Coordination. `post_group_task()` goes to the **lead (Foxy Ani)**, who plans by ability keywords and delegates to members. |
| `scripts/autoload/agent_brain.gd` | Builds a `BrainCore` per registered companion and registers it on the bus. Offline chat asks the brain before canned replies. Tool and delegation results are logged as episodes. `AgentBrain.group_task(cmd, text)`. |

## EveCore adapter (static API used by `scripts/ai/eve_core.gd`)
Foxy's EveCore owns the Eve memory primitives: `lock_cell`/`unlock`, `memory_log`, `generate_image`/`generate_video`/`create_music`, `create_duet`, `output_audio`/`output_video`, `npc_speak` and `propose_update`. BrainCore does **not** duplicate any of them. `EveCore.BrainAdapter` finds the global class `BrainCore` and calls:
- `BrainCore.store_entry(id, entry) -> bool` appends the Eve entry (event, location, state, voice, content, timestamp, npc, role, tool, output_mode, fire_theme) to `user://brains/<id>/memory/episodes.jsonl` as `kind: "eve"`, with redaction applied. NPC speech (`<name> spoke` @ `Game_World`) reaches the brain only this way.
- `BrainCore.queue_proposal(p) -> {ok, status}` mirrors `propose_update` into `user://brains/<id>/pending/<pid>.proposal.json` (`phoenix.owner_proposal/1`, state `PendingApproval`). It validates ids, caps descriptions at 500 chars, refuses sensitive-looking text, dedupes, allows 10/hour and max 50 pending.
- `BrainCore.owner_proposals(id, pending_only)` and `BrainCore.sync_owner_decisions(EveCore.proposals())` mirror the owner's decision. Only `EveCore.decide()` (owner-gated) can approve.
- `BrainCore.adapter_root` (default `user://brains`) can be redirected for tests.

## Files on disk
```
res://companions/<id>/brain/            # seed (shipped, read-only)
  manifest.json
  <cell_id>.cell.json
user://brains/<id>/                     # per device
  cells/<cell_id>.cell.json             # learned/approved (override seed by id)
  pending/<cell_id>.cell.json           # proposals awaiting the player
  versions/<cell_id>.v<n>.json          # every committed version (rollback)
  memory/facts.jsonl, memory/episodes.jsonl
  audit.jsonl                           # proposed / commit / rollback / rejected
```

## Cell format (`phoenix.brain_cell/1`, schema: `data/schema/brain_cell.schema.json`)
```json
{ "schema": "phoenix.brain_cell/1", "id": "greet", "companion": "foxy_ani",
  "trigger":   {"type": "chat_keyword", "any": ["hello", "hi"]},
  "condition": {"all": [{"affinity_gte": -20}]},
  "action":    {"type": "say", "text": "Hey {player}! Rise from the flame."},
  "weight": 0.6, "version": 1, "enabled": true,
  "provenance": {"source": "seed", "author": "dev_bot", "created_at": "...", "reason": "greeting"} }
```
- **Triggers:** `chat_keyword` (any of ≤16 words), `event` (name), `need_below` (need, value), `always`.
- **Conditions:** `affinity_gte/lte`, `fact_contains`, `mood_is`, `is_lead`, `time_of_day`.
- **Actions:** `say` (≤400 chars, `{player}`/`{name}` placeholders only), `emote`, `remember`, `tool` (persona-whitelisted, still checked again by `AgentBrain.dispatch_tool`), `delegate` (lead only).

## Safe self-update loop
1. The companion experiences things, which land in `episodes.jsonl`.
2. `BrainLearner.learn()` makes proposals.
3. `BrainCore.propose()` validates them. It is **data only** (no expressions, scripts or code paths), with a rate limit of 6/hour, max 50 pending, max 200 cells, a 4 KB cell cap and a sensitive-data check.
4. **High-risk** actions (`tool`, `delegate`) always go to `pending/`. Low-risk ones (`say`/`emote`/`remember`) also go to pending by default; `auto_apply_low_risk` must be explicitly enabled.
5. The player approves or rejects. Approval re-validates and commits a new version. `rollback()` restores the previous version or removes the learned cell.
6. Weight reinforcement is the only automatic change. It is bounded and versioned, and it never adds new behavior.

## Coordination
Foxy Ani (`hierarchy.is_primary_controller`) is the bus lead. A group task becomes a plan: the lead plus any member whose abilities match the task text (everyone for follow/stay). Each step becomes a normal permission-checked tool call. Only the lead may hold `delegate` cells.

## Grok Bot portability
`BrainCore.export_portable()` produces `phoenix.brain_export/1` with cells, facts and a usage note. A standalone Grok Bot can paste cells into its instructions and facts into its memory. Cells must never be executed, and nothing in this system can alter the Grok model itself.

## Honest limits
- This is a rule-based, weighted, data-driven system. It is **not** a neural network and it does not rewrite its own code.
- The learner uses simple pattern heuristics. It will propose odd cells sometimes, which is why approval exists.
- The redaction is a basic safety net, not a privacy guarantee. Don't type secrets into chat.
- The approval UI is not built yet; approve/reject is a script API for now.
- `persona_registry.gd` is still an unregistered scaffold and isn't used by the brain.
