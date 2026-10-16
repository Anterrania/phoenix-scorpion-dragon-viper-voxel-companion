# Phoenix Scorpion Dragon Viper — Status (2026-10-13)
**Everything is scaffold/plan.** There is no live server, MySQL instance, Boonex Dolphin site, Trac/Jira server, or installable APK. Nothing has been run in Godot yet.

## Exists (scaffold)
- Godot 4 project with Zylann VoxelTerrain world scenes (`scenes/main.tscn`, `main_world.tscn`) and biome generator plus realm presets.
- Companions are CharacterBody3D using VoxelTool (`scripts/agent/companion_agent.gd`). Player dig/place also uses VoxelTool.
- Shared personas (schema v3) in `companions/{foxy_ani,circuit_nova,aaliyah}/persona.json`. Canonical ids (`foxy-ani-firecaster-grey`, `circuit-nova`, `aaliyah`) are mapped by `companions/registry.json` + `scripts/autoload/persona_registry.gd`.
- AI: Local + Grok providers. Importers are import-only (docs/IMPORTERS.md).
- Plan docs in `docs/modules/`: data/MySQL/backup, asset library, issue tracking + wiki, community platform (Boonex), Android admin, needs, star map, DNA, relationships, city building, MobiGlass, OpenSim/OAR, Second Life, offline-first, Sims/SimCity.

## Added 2026-10-13 (afternoon)
- Legacy v1 personas from the zip were merged into v3. Nothing new was needed; the earlier merge already had every field. Provenance is recorded per persona and in docs/PERSONA_IMPORT_LOG.md.
- 7 role companions (schema v3, registered): wellness-listener (non-clinical + crisis disclaimer), tutor, fitness-coach, storyteller, architect, explorer-guide, economy-advisor.
- Docs: PLATFORMS_TESTING, DEV_TEAM, modules/GRINDING_PROGRESSION, PHYSICS_RPG, MULTIPLAYER, ECONOMY_BANKING (virtual currency only; real money gated on Law Bot review).
- Stubs: scripts/economy/ledger.gd, currency_exchange.gd, scripts/progression/skill_by_use.gd.
- DRAFT CI: .github/workflows/export.yml (manual trigger; never run; only the Android preset exists).

## Added 2026-10-13 (late morning)
- export_presets.cfg: Linux, Windows, macOS, Web (single-threaded), iOS (Xcode project only). Written by hand and never exported.
- export.yml DRAFT: Godot 4.7.2-stable + godot_voxel GDExtension v1.7x (versions checked against the releases; Dev Bot pins the final one), official Java/Android setup, debug keystore generation, and release keystore from secrets.
- PLATFORMS_TESTING.md: web threading/COOP-COEP problem, workarounds, voxel-on-web risk + fallback.
- Blocker for Dev Bot: project.godot still declares Godot 4.3, but the extension needs 4.5+.

## Added 2026-10-13 (midday)
- Concept art batch_01 (6 images) + docs/ART_BIBLE.md; new omni-worker utility companion (schema v3, registered). Images 02–05 are unassigned, awaiting user naming.

- Concept art batch_02 (2 rings + 4 royals), ART_BIBLE Regalia & Jewelry section, data/items/regalia.json stubs. Royals unassigned; motto spelling needs user confirmation.

- Primary motto "Anterrania". Royal wardrobe batch_03 + data/items/wardrobe.json (cosmetic only; boudoir set mature/hidden by default). 8 new named companions (Vex, Celestia Nyx, Aether-Weave Regent, Seraph Halcyon, elder council Ignatius/Vesperine Pyre, heir council Solarian/Lumira): names assigned by Foxy, user may rename. 19 companions are registered in total.

- Batch_04 royal assets: boudoir set II (mature/hidden), royal heels, boots (2 variants), royal SUV (vehicles.json + PHYSICS_RPG vehicles), two thrones (furniture.json) + modules/THRONE_ROOM.md.

## Next
1. Open in Godot 4 with godot_voxel and fix any parse errors.
2. Register PersonaRegistry as an autoload.
3. Authenticate gh, push branches, open PRs.
4. Add the missing export presets and a voxel-enabled Godot build for CI, then do an Android debug APK test on the Motorola.
5. Settle the exchange through the Ledger; add art for the role companions.

## Update: palette v2 + batch 05
- Final palette v2 (black/magenta/gold/platinum + glitter sparkle) documented in ART_BIBLE; applied as tags to all companion personas and all items.
- Stub `shaders/glitter_sparkle.gdshader` (untested; not run in Godot yet).
- Batch 05: heir thrones for Solarian and Lumira (Lumira inscription awaits user confirmation), Monarch and Foxy royal denim.

## Update: batch 06
- 14 designs: 5 wardrobe, 2 weapons (new weapons.json), 6 armor/uniforms (new armor.json), 1 signet band. Duplicates skipped.
- Weapons/armor have placeholder stats tied to PHYSICS_RPG; sidearms fictional, in-game only. All cosmetic/gameplay only, no real money.
- Motto spelling AETERNA now canonical everywhere.

## Batch 07 (royal orders) - done locally
- 19 of 30 images kept (11 duplicates skipped) in assets/concept_art/batch_07/
- 8 guilds in data/guilds.json + docs/modules/ROYAL_ORDERS.md; uniforms in armor.json; robes/officer uniforms in wardrobe.json; rings in regalia.json; tattoos in new data/items/cosmetics.json
- Not pushed (waiting on GitHub sign-in)

## Batch 08 (cosmic court) - done locally
- 6 images in assets/concept_art/batch_08/ (queen/king/prince cosmic robes + scepters)
- Mapped: queen_vesperine_pyre (01, 03), prince_regent_solarian (02, 05), king_ignatius_pyre (04, 06); Monarch/Foxy as also_fits where noted
- Elder orb-scepter king (04/06) linked to batch_07/19 and batch_02 elder king
- New regalia: orb_ring_scepter, crescent_scepter (palette v2)
- Not pushed (waiting on GitHub sign-in)

## Batch 09 (court daywear & household) - done locally
- 6 images in assets/concept_art/batch_09/
- Solarian court daywear (01–03) + Monarch formal mannequin (04) in wardrobe.json; also_fits Monarch on Solarian sets
- Household attendant + steward uniforms (05–06) in armor.json category `household` (non-combat)
- Recurring '8' emblem noted; pending questions saved in docs/PENDING_USER_QUESTIONS.md (silent until user asks)
- Not pushed (waiting on GitHub sign-in)

## Batch 10 (formal mannequins, court mage, envoy) - done locally
- 6 images in assets/concept_art/batch_10/
- Monarch Verdant Tree crest formal (links order_of_the_verdant_tree); Foxy column gown + ruby coronation ballgown variants
- New companion **Umbriel Voss** (court mage/consort) + wardrobe; household attendant sash variant in armor.json
- Vesper Trail explorer attire (alaskan_boreal tribal envoy look; original respectful fantasy design)
- Palette v2 on all new items; not pushed (waiting on GitHub sign-in)

## Batch 11 (warrior envoy & boudoir orb) - done locally
- 5 of 6 images kept in assets/concept_art/batch_11/ (feather-mantle PNG skipped as dup of batch_10/06)
- New companion **Kael Emberbraid** (warrior envoy / northern scout), envoy-paired with Vesper Trail (explorer_guide)
- Boudoir set III (orb jewels; mature/hidden) + sheer orb gown with ermine robe (mature/hidden) for Foxy
- **d05bcc RESOLVED** via batch_11/04 ermine-collar image
- Not pushed (waiting on GitHub sign-in)

## Batch 12 (court coat, boudoir IV, court aide) - done locally
- 3 of 6 images kept in assets/concept_art/batch_12/ (3 re-uploads of batch_11 boudoir/sheer gown skipped)
- Kael Emberbraid court coat + magenta cape (wardrobe); Foxy boudoir set IV purple-fur lace (**mature/hidden**)
- Household court aide tunic coat in armor.json (household uniform; short-haired attendant, not named as new companion)
- Palette v2 on all new items; not pushed (waiting on GitHub sign-in)

## Batch 13 (cosmic companions, vanguard, heels/SUV variants) - done locally
- 6 images in assets/concept_art/batch_13/
- New companions: **Nyxara Voltweave** (cosmic circuit), **Azura Stellaris** (navigator; star_map_pair with Celestia Nyx), **Seraph Caelum** (Seraphic Vanguard captain; distinct from Seraph Halcyon)
- Household court officer sash tunic in armor.json (household uniform; not named)
- `foxy_royal_heels` cosmic_filigree variant; `royal_suv` cosmic_hover variant (same families as batch_04)
- Palette v2 on all new items; not pushed (waiting on GitHub sign-in)

## Batch 14 (court aide dress, field courier, chancellor) - done locally
- 3 of 6 attachments kept in assets/concept_art/batch_14/ (3 PNG container dups skipped; JPGs only)
- Household court aide officer dress uniform (armor.json) — same short-haired aide as batch_12/03
- New companion **Nyra Coil** (field courier / royal technician) + jumpsuit wardrobe
- **Ledger Vale** (`economy_advisor`) chancellor officer coat with gold ledger box (wardrobe); persona appearance/role updated
- Palette v2 on all new items; not pushed (waiting on GitHub sign-in)

## Batch 15 (chancellor formal, jeweled boots, flagship, throne variants) - done locally
- 6 of 6 images kept in assets/concept_art/batch_15/ (no exact duplicates vs batch_04/05/13/14)
- Ledger Vale chancellor formal sash+medallion variant (wardrobe); same treasurer as batch_14
- Foxy jeweled thigh boots + ankle booties variant of `foxy_embroidered_boots`
- New space vehicle `royal_flagship_starfighter` (vehicles.json) linked to STAR_MAP.md
- Throne variants: Monarch black-tufted; Foxy consort (ATERNA art vs AETERNA official); Solarian heir confirms SEMI-DIVUS
- Lumira SEMI DEIVA largely resolved via batch_16; palette v2 on all; not pushed (waiting on GitHub sign-in)

## Batch 16 (Lumira heir throne text + Monarch jeans variant) - done locally
- 2 of 6 images kept in assets/concept_art/batch_16/ (4 re-uploads of batch_15 skipped)
- Lumira heir throne variant confirms feminine **SEMI DEIVA** (+ SERVA; possible HERES) — pending question largely resolved
- Monarch royal jeans baroque rhinestone variant of batch_05/03 (distinct hash; not Foxy jeans)
- Palette v2 on all; not pushed (waiting on GitHub sign-in)

## Batch 17 (royal jeans collection) - done locally
- 4 of 5 images kept in assets/concept_art/batch_17/ (`140d8d66…` skipped as exact batch_16/02 Monarch jeans)
- Checked vs batch_05 jeans (03–06): no exact matches; all four kept as new variants
- New wardrobe **collection** `royal_jeans` (palette v2) unifying Monarch + Foxy denim across batch_05/16/17
- Monarch: ruby-buckle heeled boots variant; Foxy: oval buckle, square gem stripe, and crowned H-crest gold-cuff booties
- H crest meaning still pending (linked to batch_06 `gold_h_crest_signet_band`); not pushed (waiting on GitHub sign-in)

## Batch 18 (white regalia variants, Seraph Emberion, heavy trooper, phoenix mount) - done locally
- 6 of 6 images kept in assets/concept_art/batch_18/ (no exact dups vs batch_02/06 white regalia; variants only)
- White regalia variants: Foxy coronation/wedding gown (ruby cloak); Monarch white regalia (orb-ring scepter); Monarch white tuxedo + ermine cape
- New companion **Seraph Emberion** (Seraphic Vanguard phoenix android) — distinct from Halcyon / Caelum / Circuit Nova
- Ethereal Sentinels heavy trooper armor + phoenix plasma cannon (armor.json + weapons.json)
- New `data/creatures.json` with **Phoenix Emberwing** pet/mount (project Phoenix emblem lore)
- Palette v2 on all; not pushed (waiting on GitHub sign-in)

## Batch 19 (defense projects, ivory regalia, SCDI) - done locally
- 5 of 6 images kept in assets/concept_art/batch_19/ (Royal Aegis PNG skipped as dup of JPG)
- Foxy ivory queen regalia variant of `foxy_white_coronation_gown` (distinct from batch_18 white wedding gown)
- Project Crusader rifle + soldier armor (weapons.json + armor.json); printed Magnelcration/Phamx typo notes
- Project Aegis-Guard Triton coast guard attire → armor.json, linked Order of the Trident navy
- SCDI Dominion Shotgun (SHOTGUAN art spelling noted) + Dominion heavy trooper armor
- New `data/items/mechs.json` with SCDI Royal Aegis mech
- New `docs/modules/DEFENSE_PROJECTS.md`; pending: what SCDI stands for
- Palette v2; all game-only virtual items; not pushed (waiting on GitHub sign-in)

## Batch 20 (SCDI Aura Cannon + suit series 0–3) - done locally
- 5 of 6 images kept in assets/concept_art/batch_20/ (Aura Cannon PNG skipped as dup of JPG)
- SCDI Aura Cannon (rockets/grenade launcher plasma heavy) → weapons.json
- SCDI Suit Series cards 0–3 → armor.json: Universal Sentinel (links Ethereal Sentinels trooper), Aegis Prime, Void Weaver (pilot/EVA), Abyssal Sovereign (Order of the Trident)
- Printed typos recorded: EXOSKELTON, SPACRACT, SOVEREGIN → corrected Exoskeleton / Spacecraft / Sovereign
- Submarine stub `scdi_abyssal_submarine` in vehicles.json (background of Abyssal Sovereign art)
- Updated `docs/modules/DEFENSE_PROJECTS.md` with suit series table
- Palette v2; all game-only virtual items; not pushed (waiting on GitHub sign-in)

## Batch 21 (SCDI suit series 4/5/6/8/14 + Skyfall) - done locally
- 6 of 6 images kept in assets/concept_art/batch_21/ (no duplicates)
- SCDI Suit Series cards **4** Firestorme Warden (Venus fire), **5** Terra Explorer, **6** Verdant Guardian (Order of the Verdant Tree + energy machete + jungle rifle), **8** Cosmic Habitation → armor.json / weapons.json
- Unnumbered **Skyfall Harness** (PARCHUTE/BUNNGE typos noted) → armor.json mobility_harness
- Card **14** Omni-Worker → `data/npcs.json` worker unit `scdi_omni_worker_unit` (not a new named companion); batch_01 `omni_worker` remains template
- Extended `docs/modules/DEFENSE_PROJECTS.md`; **missing cards 7, 9–13** noted
- Palette v2; all game-only virtual items; not pushed (waiting on GitHub sign-in)

## Batch 22 (Phoenix God regalia, wing throne, Anterranian Capitol) - done locally
- 3 of 6 images kept in assets/concept_art/batch_22/ (Omni-Worker PNG + 2 PNG containers skipped)
- Wardrobe: `monarch_phoenix_god_regalia` (crystal crown, flame shoulders, phoenix cloak; gold '8' floor seal; title Phoenix God)
- Furniture: `phoenix_wing_throne` + throne-room scene (distinct from eagle-orb monarch_throne)
- New `data/items/structures.json`: landmark `anterranian_capitol` (prints PHOENIX GOD / ANTERRANIAN MONORCH [sic MONARCH])
- Pending notes: '8' again (floor seal + capitol banners); Phoenix God title recorded
- Palette v2; game-only; not pushed (waiting on GitHub sign-in)

## Batch 23 (capitol variants, coin, heraldry) - done locally
- 6 of 6 images kept in assets/concept_art/batch_23/ (no duplicates)
- Capitol variants on `anterranian_capitol`: floating pads + plaques (8 / PHOENIX GOD / ANTERRANIAN MONAACH [sic]); gold-dome dragon crest + 8 archway → structures.json
- New `data/items/currency.json`: `phoenix_god_coin` (obverse phoenix, reverse magenta 8/galaxy; mottos Divine Right / Universal Wealth) — **virtual only, not real money/crypto**
- New `data/lore/heraldry.json` + `docs/modules/HERALDRY.md`: national flag (phoenix radiating), great seals phoenix + dragon, vertical flag variants, title Phoenix God / Anterranian Monarch, mottos
- ECONOMY_BANKING.md updated with coin face; pending: phoenix vs dragon primary?; recurring 8
- Palette v2; not pushed (waiting on GitHub sign-in)


## Batch 24 (Aethel economy) - done locally
- 6 of 6 images kept in assets/concept_art/batch_24/ (no duplicates)
- Extended `data/items/currency.json` with `economies.aethel` + items: banknotes (100/1000), lion coin, sigil, stasis (stable), ascendant (variable; ASCENDAND→ASCENDANT), key (wallet/access card)
- New `docs/modules/ECONOMY.md` (strictly fictional game-only virtual currency; no real-money/crypto/exchange)
- ECONOMY_BANKING.md cross-linked; ART_BIBLE + pending Qs updated
- Pending: Aethel ↔ Phoenix coin relationship; lion coin meaning
- Palette v2; not pushed (waiting on GitHub sign-in)


## Batch 25 (Crowned Dragon-Phoenix house emblem) - done locally
- 6 of 6 images kept in assets/concept_art/batch_25/ (no duplicates)
- Extended `data/lore/heraldry.json`: house emblem `crowned_dragon_phoenix` (Scorpion Dragon Viper Phoenix hybrid) + 6 variants (holo flag, tapestry, 2 neon UI cards, magenta constellation banner, landscape galaxy flag)
- HERALDRY.md + ART_BIBLE updated; neon cards noted as UI card backs / loading screens
- Note: hybrid may answer phoenix-vs-dragon primary; **question kept open** (hybrid_candidate)
- Palette v2; not pushed (waiting on GitHub sign-in)

## Batch 26 (fleet heraldry, Aethel coin, citadel, Great Sigil) - done locally
- 5 of 6 images kept in assets/concept_art/batch_26/ (PNG Great Sigil dup skipped)
- Heraldry: `fleet_war_banner`, `orb_banner_seven_glyphs` (7 glyphs pending), `great_sigil_crowned_dragon_phoenix_flames` (primary Great Sigil candidate)
- Currency: `aethel_coin` (AETHEL COIN - UNIVERSAL CURRENCY; zodiac rim) — game-only
- Structures: `aethel_citadel` orbital fortress (name assigned by Foxy; pending approve)
- ECONOMY.md / HERALDRY.md / ART_BIBLE / PENDING updated
- Palette v2; not pushed (waiting on GitHub sign-in)

## Batch 27 (writing systems + geometric medallion) - done locally
- 3 of 6 images kept in assets/concept_art/batch_27/ (3 PNG dups skipped)
- New `data/lore/scripts.json`: Ignis Solis Glyphs + Aethelian Runes (in-game writing systems; art typos recorded)
- Heraldry: `great_sigil_crowned_dragon_geometric_medallion` (alternate Great Sigil candidate)
- Palette v2; not pushed (waiting on GitHub sign-in)

## Batch 28 (command citadel, fortress, tattoo, title ring, ballgown) - done locally
- 5 of 6 images kept in assets/concept_art/batch_28/ (JPG gown dup skipped)
- Structures: `zodiac_command_citadel` (glyph-ring command citadel), `phoenix_eight_fortress` ('8' panels) — names pending approve
- Cosmetics: `tattoo_dragon_phoenix_divine_right_back` (body-art; real-world flags noted; pending Monarch personal?)
- New `data/items/rings.json`: `moonstone_phoenix_title_ring` with **placeholder** inscription only (source art named a real public figure — name NOT in game data)
- Wardrobe: Foxy white ermine ballgown variant on `foxy_white_coronation_gown`
- Palette v2; not pushed (waiting on GitHub sign-in)

## Batch 29 (Monarch white regalia/tuxedo + Foxy ivory gown) - done locally
- 3 of 6 images kept in assets/concept_art/batch_29/ (3 JPG dups skipped)
- Wardrobe variants: `monarch_white_regalia` (white tunic + white ermine cape + orb-ring staff); `monarch_white_formal_suit` (white tuxedo + black ermine cape); `foxy_ivory_gown_burgundy_cape` (ermine + rune platform)
- Palette v2; not pushed (waiting on GitHub sign-in)


## v0.8.0 (versionCode 10) - graphics + physics
- Terrain: procedural detail normal maps (triplanar, 2 scales), macro variation, AO
- Sky: procedural fbm clouds with sun-lit silver edges; per-biome cover
- Water: Gerstner waves (Cosmic water, slow lava swell), fresnel sky reflection, crest glow; SSR/SSAO on High
- GPU particles: snow (Alaska), embers + ash (Venus), star dust (Cosmic), footstep dust, fire-bolt trail + impact, dragon-wing sparkle; wind gusts; counts scale with GFX
- Physics: acceleration/decel + air control, coyote time, jump buffer, floor snapping, swimming, ragdoll-lite knockback, prop mass/friction/damping
- Vala "better world" code: not found on box, repo, Drive search, or Gmail (Drive Takeout .tgz archives could not be opened)
