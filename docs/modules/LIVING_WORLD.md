# Living world (LIFE)

Status: built and headless-tested on the server/system side (branch feature/living-world). The client UI is Foxy's: see
[docs/specs/foxy/LIVING_WORLD_CLIENT.md](../specs/foxy/LIVING_WORLD_CLIENT.md).
Related: [SURVIVAL.md](SURVIVAL.md) · [GOVERNANCE.md](GOVERNANCE.md) · [MINING_AND_MATERIALS.md](MINING_AND_MATERIALS.md) · [POWER_AND_DATA.md](POWER_AND_DATA.md) · [DNA_GENETICS.md](DNA_GENETICS.md)

## 1. World seeds per realm (`data/living/realms.json`, `WorldEnv`)

Each realm has gravity, total pressure, O2 and CO2 partial pressures, a temperature range, radiation dose, water,
day length, soil pH and hazards. `WorldEnv.outdoor(realm, y, t01)` returns the conditions at a height and time of day,
and `WorldEnv.personal(env, {shelter, powered, suit})` applies habitats and suits.

| realm | g | kPa | O2 kPa | temp C | radiation mSv/day | notes |
|---|---|---|---|---|---|---|
| alaskan_tundra / boreal / glacier | 1.0 | 101 | 21 | −40…15 | ~0.008 | permafrost, ice, taiga |
| venus_fire (cloud deck, ~50–55 km) | 0.9 | ~100 | trace | 20…70 | low | sulfuric-acid aerosol |
| venus_deep (below y −30) | 0.9 | 9200 | 0 | 455…470 | low | CO2 96.5%, crushing |
| cosmic | 0 | 0 | 0 | −100…120 | 1.8 | vacuum, interplanetary dose |
| cyberpunk / ai_forge / celestial_ruin_sanctum | 1.0 | 101 | 21 / low | mild | low | pollution / low O2 (softcore) |
| social / club / home | 1.0 | 101 | 21 | mild | 0 | survival off |

Sources (real data, simplified for play):
- Venus surface ~92 bar, ~464 °C, 96.5% CO2. The cloud layer at ~50–55 km is ~1 bar and 0–70 °C, with sulfuric acid clouds (NASA Venus Fact Sheet, nssdc.gsfc.nasa.gov/planetary/factsheet/venusfact.html).
- Interplanetary space gives about 1.8 mSv/day, as measured by MSL RAD during cruise (Zeitlin et al., *Science* 340, 2013).
- Earth background is ~2.4 mSv/year (UNSCEAR 2008).
- The Armstrong limit is ~6.3 kPa, where body-temperature water boils.

## 2. Species viability via DNA (`data/living/species.json`, `Genome`)

- Creatures and plants carry **tolerance genes** (diploid: two alleles, expressed as the mean): temp_min/max, pressure_min/max,
  o2_min, radiation_tol, water_min, ph_min/max and gravity_max.
- `Genome.viability(genome, env)` returns {ok, score, reasons}. `spawnable(realm)` lists the species that can live there in some season.
- Extremophile analogues:
  - frostcoil_worm is modelled on the Alaskan ice worm (*Mesenchytraeus solifugus*, active near 0 °C).
  - emberstrand is a thermoacidophile analogue (cf. *Picrophilus*, which grows at pH ~0.7; Schleper et al. 1995).
  - voidbear is a tardigrade analogue (tardigrades survived open space on FOTON-M3; Jönsson et al., *Curr. Biol.* 2008).
  - lantern_lichen draws on lichens surviving Mars-like conditions (de Vera et al.).
- **Creatures only, non-sexual.** `Genome.combine(a, b)` takes one allele per gene from each parent genome, with a small mutation rate,
  and gives a same-genus hybrid ("a_x_b") its generation number. Personas never get a genome (`Genome.for_persona` returns {}).
  There is no player or companion breeding and nothing romantic. Wyrmlings `breed()` adds an optional `genome` field, so old saves load unchanged.

## 3. Ecology (`Ecology`)

Per-region populations grow logistically toward a carrying capacity K = 200 × viability score. Unfit species halve every 24 game hours.
The closed form makes one step of any length exact, which is what Dormancy catch-up uses.

## 4. Light by design (PR #39 Dormancy + PowerData)

- Only active regions tick, and only at `max(5 s, 1/sim_tick_hz)` from `AutoConfig.budget("sim_tick_hz")`. Ticking stops at 0 Hz in background.
- `Survival.register_region(region, center)` registers with `Dormancy`. A region with no viewer nearby sleeps. On wake, ONE
  `catch_up(region, elapsed_s)` applies survival, disease and ecology in a single step (capped at 7 days).
- The server pages sectors with `SectorPager` (see MINING_AND_MATERIALS §Land).

## 5. Owner exemption and safety

- `LivingGate.exempt(actor)` is true only when `Tiers.tier_of(actor) == "owner"`, meaning owner role AND unlocked vault (`Profile.is_owner()`).
  A locked owner is a guest and is NOT exempt. Exempt covers survival, disease, laws, borders and blueprint gating.
- E-stop (`AutonomyGuard.paused()`) freezes bot and companion vitals and infection, and blocks their writes through `Tiers.can`.
- Per-estate `survival = on|off|softcore` (Estate region key). Only the owner or estate managers can edit it. Defaults by realm: on in Alaskan,
  Venus and cosmic; softcore in cyberpunk, AI forge and ruins; off in social, club, home, welcome and SL-style regions.

## 6. Shipped vs planned

| item | status |
|---|---|
| realm seeds, WorldEnv, suits/habitats/ships | built |
| tolerance genome, viability, spawn lists, non-sexual combine, wyrmling hook | built |
| survival, disease, ecology, Dormancy, budgets | built |
| governance, geology, materials, blueprints, land addressing | built (see module docs) |
| client HUD, scanner, crafting screen, gov screens, client floating origin | planned (Foxy) |
| server persistence of ecology across restarts | planned |
