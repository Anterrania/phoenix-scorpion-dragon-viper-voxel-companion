# Defense Projects (SCDI & Royal Programs)

> **Scaffold / lore catalog only.** All weapons, armor, and mechs are **game-only virtual items** — cosmetic/gameplay stubs with placeholder stats. Never sold for real money. Combat hooks: `docs/modules/PHYSICS_RPG.md`. Concept art: `assets/concept_art/batch_19/`. Data: `data/items/{weapons,armor,mechs}.json`. Palette v2 (black / magenta / gold / platinum + glitter).

## SCDI program

Printed prefix on several assets: **SCDI** (also on batch_01 Omni-Worker android: "SCDI – Omni-Worker").

| Item | Id | Data | Art |
|------|-----|------|-----|
| Dominion Shotgun (+ crowned heavy trooper) | `scdi_dominion_shotgun` + `scdi_dominion_heavy_trooper_armor` | weapons.json + armor.json | batch_19/04 |
| Royal Aegis mech | `scdi_royal_aegis_mech` | mechs.json | batch_19/05 |
| Omni-Worker android (earlier) | companion `omni_worker` | companions/omni_worker/ | batch_01/06 |

**Pending user:** What does **SCDI** stand for? (See `docs/PENDING_USER_QUESTIONS.md`.)

**Art note:** Dominion Shotgun banner prints **SHOTGUAN** — catalogued as **Dominion Shotgun** with that spelling note retained for art fidelity.

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

## Cross-links

- Ethereal Sentinels heavy trooper + phoenix plasma cannon (batch_18) remain a separate guild line; Dominion heavy trooper is SCDI-tagged and distinct.
- Royal Aegis lives in `data/items/mechs.json` (not vehicles.json) as a bipedal combat frame.
- All entries: `palette_version: 2`, `cosmetic_gameplay_only: true`, `real_money: false`.
