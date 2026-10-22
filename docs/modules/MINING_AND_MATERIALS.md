# Mining, materials, blueprints and land (LIFE-6, LIFE-7)

Status: built and headless-tested.

## Geology (`Geology`, `data/living/materials.json`)

- Deterministic hash on 4 m vein cells: ore = f(realm, position, surface height, seed). Nothing is stored or sent.
- Real minerals by realm and depth: hematite, magnetite, chalcopyrite, cassiterite, quartz, gold, coal, water ice, sulfur, ilmenite, pentlandite and others.
- Original exotics: emberite, auroralite, voidglass and lattice silicate.
- Hook: `BiomeVoxelGenerator.ore_at(x, y, z)`. Render voxel ids are unchanged.

## Materials (`Materials`, `data/living/recipes.json`)

- Recipes run mine → crush → smelt/electrolyse → alloy → component → build. Stations: hands, crusher, furnace, electrolyzer, fab and assembler.
- `craft()` consumes inputs and only completes when everything is present. `raw_cost(item)` expands the graph to ores, and `validate_graph()` checks it is closed.
- `mine()` needs `Tiers.can build` on the parcel plus the nation's mining law.
- **Builds on the spacesim Industry work:** when the `Industry` class exists, `export_to_industry()` moves stock into its stockpile for long jobs (ME/TE).
  There is no second factory. When the class is absent this is a no-op.

## Blueprints (`Blueprints`)

- An original has unlimited runs. A copy has limited runs.
- Next-owner permissions are copy / modify / transfer, and can only be removed, never re-granted by a next owner.
- Fixed-price listings (creator tier) in free or civic credits. Civic credits are earned only, never bought, and never cashed out.
- **LEGAL REVIEW REQUIRED:** Aethel Coin purchases, seller payouts in Aethel Coin and any cash-out are disabled (`AEC_PAYOUTS = false`, `CASH_OUT = false`).

## Land (`Land`, `SectorPager`)

- There are no artificial object caps: `object_cap` is unlimited (−1) wherever `Tiers.can build`, and 0 elsewhere.
- Phone safety comes from `Land.render_budget(low|med|high|ultra)` for the client renderer (streaming, LOD/HLOD). It is not a land rule.
- Addressing is planet > region (1024 m sector) > chunk (64 m = parcel), e.g. `earth/r12_-3_0/c5_0_7`.
- Floating origin: positions are stored as sector + local, so `distance` and `rebase` keep centimetre precision 10⁹ m out.
- `SectorPager`: the viewer radius cube is active, and others go to an LRU cache with a cap.
