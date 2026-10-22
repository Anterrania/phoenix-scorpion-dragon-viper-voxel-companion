# Survival and disease (LIFE-3)

Status: built and headless-tested. API: autoload `Survival` (`Survival.vitals(id)`, signal `vitals_changed(id, vitals)`), plus `Disease` and `LivingGate`.

## Vitals and physiology (simplified, real-ish)

| vital | model | source |
|---|---|---|
| o2_sat | piecewise O2–haemoglobin curve vs inspired pO2 (21 kPa ≈ 98%) | Severinghaus 1979 |
| co2 | load from inspired pCO2; symptoms near 1 kPa, dangerous ≥ 5 kPa | NASA SMAC / OSHA |
| core_c | drifts outside a 10–30 °C band; hypothermia < 35 °C, heat illness > 39.5 °C | WHO / clinical definitions |
| pressure_ok | fails below 6.3 kPa (Armstrong limit) or above 1000 kPa unless sealed | |
| radiation_msv | cumulative; > 1000 mSv brings on "void sickness" (acute radiation syndrome starts ~1 Sv) | ICRP 103 |
| hydration | ~3 days without water, faster in heat | |
| calories | BMR ~83 kcal/h × activity × cold factor | Harris–Benedict scale |
| fatigue | full after ~16 h awake; cleared by ~8 h sleep | |

- Game time runs at 1 real minute = 0.1 game hours. Health reaching 0 means "incapacitated", which is non-graphic: `recover()` is a rescue or waking at home.
- Suits: cold_weather, heat_suit, rebreather (mask), pressure_suit and hardsuit. A sealed suit drains its O2 tank.
- Shelters: tent, habitat, ship and home. A sealed, powered habitat gives 1 atm of air.

## Modes

- `off`: vitals hold still.
- `softcore`: half drain, and health never falls below 10.
- `on`: full rules.
- An unlocked owner is exempt and always shows fresh vitals. A locked owner follows the rules.
- E-stop: companions and bots are held exactly as they are.

## Disease (SIR-style, family-friendly)

- Each disease (`data/living/diseases.json`) has beta, infectious days, incubation, vector (contact / water / tick / environment),
  effects, symptoms, treatments with efficacy, and immunity days.
- Infection chance is 1 − e^(−β·t), with t in days. R0 = β × infectious days. `Disease.sir_step` is the textbook compartment
  update (Kermack & McKendrick 1927) used for region-wide outbreaks.
- Treatments shorten illness, and efficacy ≥ 0.8 cures outright. Vaccines give immunity at their efficacy rate. There is no gore.
- Environment triggers: acid → ember lung, radiation → void sickness, smog + fatigue → smog cough, cold core in Alaska → frostnip.

## Dormancy and budgets

`Survival.register_region` → `Dormancy`. Asleep regions cost nothing, and on wake `catch_up` runs a single step. The tick interval is
`max(5 s, 1/sim_tick_hz)` (PowerData). See [POWER_AND_DATA.md](POWER_AND_DATA.md) §5.
