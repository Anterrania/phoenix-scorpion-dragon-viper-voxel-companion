# Defense Projects (SCDI & Royal Programs)

> **Scaffold / lore catalog only.** All weapons, armor, and mechs are **game-only virtual items** — cosmetic/gameplay stubs with placeholder stats. Never sold for real money. Combat hooks: `docs/modules/PHYSICS_RPG.md`. Concept art: `assets/concept_art/batch_19/`, `assets/concept_art/batch_20/`, `assets/concept_art/batch_21/`. Data: `data/items/{weapons,armor,mechs,vehicles}.json`, `data/npcs.json`. Palette v2 (black / magenta / gold / platinum + glitter).

## SCDI program

Printed prefix on several assets: **SCDI** (also on batch_01 Omni-Worker android: "SCDI – Omni-Worker").

| Item | Id | Data | Art |
|------|-----|------|-----|
| Dominion Shotgun (+ crowned heavy trooper) | `scdi_dominion_shotgun` + `scdi_dominion_heavy_trooper_armor` | weapons.json + armor.json | batch_19/04 |
| Royal Aegis mech | `scdi_royal_aegis_mech` | mechs.json | batch_19/05 |
| Aura Cannon (rockets / grenade launcher) | `scdi_aura_cannon` | weapons.json | batch_20/01 |
| Omni-Worker android (worker unit) | NPC `scdi_omni_worker_unit` + template companion `omni_worker` | data/npcs.json + companions/omni_worker/ | batch_01/06 + batch_21/06 (card 14) |

**Pending user:** What does **SCDI** stand for? (See `docs/PENDING_USER_QUESTIONS.md`.)

**Art notes (printed → catalogued):**
- Dominion Shotgun banner prints **SHOTGUAN** → **Dominion Shotgun**
- Universal Sentinel prints **EXOSKELTON** → **Exoskeleton**
- Void Weaver prints **SPACRACT** → **Spacecraft**
- Abyssal Sovereign prints **SOVEREGIN** → **Sovereign**
- Firestorme Warden prints **FIRESTORME** / **PYRO-RESILENT** → **Firestorm** / **Pyro-Resilient**
- Skyfall Harness prints **PARCHUTE** / **BUNNGE** → **Parachute** / **Bungee**
Printed strings kept for art fidelity.

## Project Crusader

Printed: **PROJECT CRUSADER - Apex-Class Modular Kinetic Rifle**  
Subsystems (as printed): Magnelcration • Ares Interface AI • Phamx Configuration  
*(Likely art typos: Magnelcration → Magnetization?; Phamx → Phoenix? — keep printed strings.)*

| Item | Id | Data | Art |
|------|-----|------|-----|
| Apex-Class Modular Kinetic Rifle | `project_crusader_apex_modular_kinetic_rifle` | weapons.json | batch_19/02 |
| Crusader soldier armor (same plate) | `project_crusader_soldier_armor` | armor.json | batch_19/02 |

Role: fictional modular kinetic rifle + tactical soldier kit for royal/guard use. Tagged `scdi_program` pending confirmation whether Crusader sits under SCDI.

## Project Aegis-Guard

Printed: **PROJECT AEGIS-GUARD - Triton-Class Unisex Coast Guard Attire**  
Subsystems: Smart-Fabric Composites • Guardian Weave • Automated Buoyancy

| Item | Id | Data | Art |
|------|-----|------|-----|
| Triton-Class Coast Guard Attire | `project_aegis_guard_triton_coast_guard` | armor.json | batch_19/03 |

**Linked order:** **Order of the Trident** (`order_of_the_trident` / `uniform_order_of_the_trident`) — navy/sea role in `docs/modules/ROYAL_ORDERS.md` and `data/guilds.json`. Aegis-Guard is the coast-guard / harbor smart-fabric line for that order.


## SCDI Suit Series (cards 0–14 partial)

Numbered cards on batch_20 / batch_21 concept art describe an SCDI suit series (palette v2). All game-only virtual items.

**Received cards:** 0, 1, 2, 3, 4, 5, 6, 8, 14 (+ unnumbered Skyfall Harness).  
**Missing card numbers (not yet uploaded):** **7, 9, 10, 11, 12, 13**.

| Card | Printed name | Corrected | Id | Data | Art | Links |
|------|--------------|-----------|----|------|-----|-------|
| 0 | UNIVERSAL SENTINEL - EXOSKELTON/UNIFORM | Exoskeleton | `scdi_universal_sentinel_exoskeleton` | armor.json | batch_20/02 | Ethereal Sentinels heavy trooper (batch_18/05) |
| 1 | AEGIS PRIME - UNIVERSAL COMBAT & EXPLORATION SUIT | — | `scdi_aegis_prime_suit` | armor.json | batch_20/03 | Distinct from Project Aegis-Guard Triton + Royal Aegis mech |
| 2 | VOID WEAVER - SPACRACT PILOTING & EVA SUIT | Spacecraft | `scdi_void_weaver_eva_suit` | armor.json | batch_20/04 | Pilot / EVA; related `royal_flagship_starfighter` |
| 3 | ABYSSAL SOVEREGIN - UNDERWATER EXPLORATION & COMBAT SUIT | Sovereign | `scdi_abyssal_sovereign_suit` | armor.json | batch_20/05 | **Order of the Trident**; paired `scdi_abyssal_submarine` (vehicles.json stub) |
| 4 | FIRESTORME WARDEN - PYRO-RESILENT HAZARD SUIT | Firestorm / Pyro-Resilient | `scdi_firestorme_warden_suit` | armor.json | batch_21/01 | Venus fire biome / volcanic hazard |
| 5 | TERRA EXPLORER - ALL-TERRAIN CIVILIAN & EXPLORER SUIT | — | `scdi_terra_explorer_suit` | armor.json | batch_21/02 | Civilian / explorer light kit |
| 6 | VERDANT GUARDIAN - FOREST & JUNGLE COMBAT SUIT | — | `scdi_verdant_guardian_suit` | armor.json | batch_21/03 | **Order of the Verdant Tree**; paired energy machete + jungle rifle (weapons.json) |
| 7 | *(missing)* | — | — | — | — | Awaiting upload |
| 8 | COSMIC HABITATION - SPACE STATION OPERATIONS SUIT | — | `scdi_cosmic_habitation_suit` | armor.json | batch_21/05 | Station ops / low-g habitation |
| 9–13 | *(missing)* | — | — | — | — | Awaiting upload |
| 14 | OMNI-WORKER - UNIVERSAL ANDROID ASSISTANT | — | `scdi_omni_worker_unit` | data/npcs.json | batch_21/06 (+ batch_01/06) | Android **worker unit** (NPC type); template companion `omni_worker` — not a new named companion |

**Also (not numbered in suit series):**
- batch_20 Aura Cannon — `scdi_aura_cannon` (weapons.json)
- batch_21 Skyfall Harness (unnumbered) — `scdi_skyfall_harness` (armor.json, mobility_harness / wing glider; prints PARCHUTE & BUNNGE)
- batch_21 Verdant Guardian weapons — `scdi_verdant_guardian_energy_machete`, `scdi_verdant_guardian_jungle_rifle` (weapons.json)

## Cross-links

- Ethereal Sentinels heavy trooper + phoenix plasma cannon (batch_18) remain a guild line; Dominion heavy trooper is SCDI-tagged and distinct; **Universal Sentinel** (suit card 0) is the SCDI exoskeleton link back to that Sentinel trooper look.
- Royal Aegis lives in `data/items/mechs.json` (not vehicles.json) as a bipedal combat frame.
- Abyssal submarine stub lives in `data/items/vehicles.json` (`type: underwater`), paired with Abyssal Sovereign suit.
- Aegis Prime (suit) ≠ Project Aegis-Guard Triton (coast attire) ≠ Royal Aegis (mech).
- **Verdant Guardian** (suit card 6) links **Order of the Verdant Tree** (`order_of_the_verdant_tree`); energy machete + jungle rifle in weapons.json.
- **Omni-Worker** (card 14) is an android **worker unit** in `data/npcs.json` (`scdi_omni_worker_unit`), not a second named companion; `companions/omni_worker/` remains the spawnable template.
- Skyfall Harness is SCDI gear but **unnumbered** (wing glider / parachute-bungee).
- Missing suit series cards **7, 9–13** — leave gaps until user uploads.
- All entries: `palette_version: 2`, `cosmetic_gameplay_only: true`, `real_money: false`.
