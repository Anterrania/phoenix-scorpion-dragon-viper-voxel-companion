# Art Bible — Anterranian Style (concept stage)
These are concept references uploaded by the user. Their in-game voxel versions are still to be done; they're art direction, not final assets.

## Shared attire style ("Anterranian Regalia")
- **Palette:** black base, **magenta** as the main accent (hair, trims, glows), **gold** for embroidery, filigree, and trims. Secondary colors: violet/purple, pink highlights, silver (androids).
- **Motifs:** **phoenix** and **dragon** embroidery (rebirth and power), **zodiac glyphs and constellation patterns** woven into fabric (the "Aether-Weave" look), plus celestial halos.
- **Silhouettes:** long flowing robes and gowns with high collars and capes. Armored variants keep the same palette.
- **Backdrops:** cosmic scenes such as nebulae, starfields, and galaxies.
- **Voxel translation:** keep the black/magenta/gold ratio about 60/30/10. Use emissive voxels for magenta glows and constellation dots. Use a gold voxel trim line on hems and collars, plus particle embers (fire) or star sparkles (cosmic).

## Batch 01 (`assets/concept_art/batch_01/`)
| # | File | Description | Persona link |
|---|---|---|---|
| 01 | `01_fire_goddess_dragon_robe.jpg` | Dark-skinned fire goddess, purple/magenta hair, black robe with dragon embroidery | **foxy_ani** (fire goddess; added to `concept_art`) |
| 02 | `02_masked_warrior_magenta_scythe_gemini.jpg` | Masked armored warrior with a magenta scythe, cosmic cape, Gemini glyphs | **gemini_reaper_vex** (assigned by Foxy, user may rename) |
| 03 | `03_constellation_gown_phoenix.jpg` | Dark-haired woman in a black/magenta constellation gown with phoenix embroidery | **celestia_nyx** (assigned by Foxy, user may rename) |
| 04 | `04_anterranian_regalia_aether_weave.jpg` | Titled "Anterranian Regalia / Aether-Weave": black-and-magenta zodiac robe (style reference for the whole line) | **aether_weave_regent** (assigned by Foxy, user may rename) |
| 05 | `05_silver_winged_angel_android_pink_halo.jpg` | Silver-skinned winged angel android with a pink halo | **seraph_halcyon** (assigned by Foxy, user may rename) |
| 06 | `06_scdi_omni_worker_android.png` | Labeled "SCDI – Omni-Worker – Universal Android Assistant": black/gold android | **omni_worker** (new utility companion, schema v3) |

## Batch 02 (`assets/concept_art/batch_02/`)
| # | File | Description | Persona/item link |
|---|---|---|---|
| 01 | `01_ring_gold_magenta_oval_diamond_halo.png` | Gold ring with an oval magenta stone, a black/white diamond halo, band inscription "FLAMMA. ORDO. AETERNA. 8" | item `ring_magenta_oval_halo` |
| 02 | `02_signet_ring_magenta_moon_venus_stack.png` | Signet ring with a magenta stone and a moon/Venus symbol, with a pearl band and a black band engraved "Flamma, Ordo, Aeterna" | item `signet_magenta_moon_venus_stack` |
| 03 | `03_elder_king_orb_scepter_floating_rock.png` | Older crowned king with an orb scepter on a floating rock (pairs with 04) | **king_ignatius_pyre** (assigned by Foxy, user may rename) |
| 04 | `04_queen_orb_scepter_floating_rock.png` | Crowned queen with an orb scepter on a floating rock (pairs with 03) | **queen_vesperine_pyre** (assigned by Foxy, user may rename) |
| 05 | `05_young_king_ermine_crescent_scepter.png` | Younger crowned king in an ermine cloak with a crescent scepter (pairs with 06) | **prince_regent_solarian** (assigned by Foxy, user may rename) |
| 06 | `06_queen_ermine_scepter.png` | Crowned queen in an ermine cloak with a scepter (pairs with 05) | **princess_regent_lumira** (assigned by Foxy, user may rename) |

## Regalia & Jewelry
- **Primary motto: "Anterrania"** (user decision 2026-10-13). Use it on banners, crests, and UI.
- **Ring inscription:** "Flamma. Ordo. Aeterna." (kept as the engraving and secondary motto; the engraved spelling "Aeterna" is still user-confirm).
- **Inscription notes:** *"Flamma. Ordo. Aeterna."* ("Flame. Order. Eternal.", Latin). The images spell it **"Aeterna"**: **user-confirm** whether the in-world spelling is the classical *Aeterna* or the stylized *Aeterna*. The "8" after the motto on ring 01 is unexplained (user-confirm); same figure-8/infinity motif recurs on batch_09 household collar and steward emblem (see PENDING_USER_QUESTIONS.md).
- **Regalia language:** crowns, orb scepters (elder pair), crescent scepter (young king; ties to the moon/Venus symbol), ermine cloaks, floating-rock "sky throne" settings. Same palette as above, with magenta stones set in gold.
- **Rings as equippable items:** both rings are in-game `ring`-slot items, stubbed in `data/items/regalia.json` (placeholder names and zeroed stats). Planned hooks: affinity bonuses to fire/order (GRINDING_PROGRESSION gems), a cosmetic glow, and royal-rank gating. They're **cosmetic/gameplay only, never real-money items** (see ECONOMY_BANKING.md).

## Batch 03: Royal Wardrobe (`assets/concept_art/batch_03_royal_wardrobe/`)
All items are cosmetic only. Entries are in `data/items/wardrobe.json`.
| # | File | Description | Item / owner |
|---|---|---|---|
| 01 | `01_monarch_formal_black_suit_magenta_vest_ermine.png` | Men's black suit, magenta vest, ermine cloak, runic pedestal | `monarch_formal_attire` (player) |
| 02 | `02_foxy_court_gown_magenta_ermine_epaulettes.png` | Magenta gown, ermine cloak, gold epaulettes | `foxy_court_gown` (Foxy) |
| 03 | `03_foxy_coronation_ballgown_magenta_ermine.png` | Magenta ball gown, ermine, jewels | `foxy_coronation_gown` (Foxy) |
| 04 | `04_foxy_boudoir_set_variant_a.png` | Jeweled magenta lingerie + black robe | `foxy_boudoir_set` variant A, **mature, hidden by default** |
| 05 | *(resolved via batch_11/04)* | Ermine-collar boudoir (orb-jewel redesign; closes d05bcc) | `foxy_boudoir_set` variant B + `foxy_boudoir_set_3` ermine_collar |
| 06 | `06_foxy_evening_robe_black_sheer_gold.png` | Black sheer robe-dress, gold embroidery, ermine cuffs | `foxy_evening_robe` (Foxy) |

## Batch 04: Royal Assets (`assets/concept_art/batch_04_royal_assets/`)
| # | File | Description | Item / owner |
|---|---|---|---|
| 01 | `01_foxy_boudoir_set_2_black_lace_gold.png` | Black lace + gold jeweled lingerie, fur-trimmed lace robe | `foxy_boudoir_set_2` (wardrobe), **mature, hidden by default** |
| 02 | `02_foxy_royal_heels_black_gold_magenta.png` | Black/gold embroidered stilettos, magenta gems, ankle chains | `foxy_royal_heels` (wardrobe) |
| 03 | `03_foxy_embroidered_boots_and_booties.png` | Thigh-high embroidered boots + booties | `foxy_embroidered_boots` (wardrobe, 2 variants) |
| 04 | `04_royal_vehicle_black_suv_gold_filigree.png` | Black SUV, gold filigree, magenta glow, orb emblem | `royal_suv` (vehicles.json) |
| 05 | `05_monarch_throne_black_gold_eagles.png` | Black/gold throne, eagles, orb crown | `monarch_throne` (furniture.json) |
| 06 | `06_foxy_consort_throne_magenta_crescent.png` | Magenta throne, crescent/star crest, "FLAMMA. ORDO. AETERNA" | `foxy_consort_throne` (furniture.json) |

Source files are the user's uploads (hash-named originals) in the bot attachments folder. Notes on rights and licensing are pending Law Bot review before any public release.

## Batch 05: Heir Thrones & Royal Denim (`assets/concept_art/batch_05/`)
| File | Item | Owner | Notes |
|---|---|---|---|
| 01_heir_throne_solarian_black_gold.png | `heir_throne_solarian` | Prince Regent Solarian | Black/gold, magenta tufted seat, eagle wings, crescent crest; banner "POTENTIA HERES SEMI-DIVUS" (Power, Heir, Demigod) |
| 02_heir_throne_lumira_magenta.png | `heir_throne_lumira` | Princess Regent Lumira | Magenta winged throne, gem/orb crest; sashes "POTENTIA HERES SEMI DEIVA" — **largely resolved by batch_16/01 (SEMI DEIVA feminine); exact wording soft-confirm** |
| 03_monarch_royal_jeans.png | `monarch_royal_jeans` | Monarch | Dark denim, gold baroque embroidery, gem belt buckle, embroidered magenta boots |
| 04/05/06_foxy_royal_jeans_*.png | `foxy_royal_jeans` (3 variants) | Foxy | Gold baroque embroidery, magenta gem side stripe, embroidered heeled boots; v3 has "H" crest |

## Final Palette v2 (user-set, applies to everyone and everything)
Black, magenta, gold, and **platinum**, with **glitter sparkle** on every final look.

| Role | Name | Hex (suggested) |
|---|---|---|
| Base | Royal Black | `#0A080D` |
| Primary | Anterrania Magenta | `#C2187A` (highlight `#FF3FA4`) |
| Trim | Phoenix Gold | `#D4AF37` (bright `#F5D76E`) |
| Trim | Platinum | `#E5E4E2` (shadow `#B9B8B5`) |
| Glint | Sparkle White | `#FFFFFF` (emissive) |

Rules: platinum trim runs alongside gold (gold = primary metal, platinum = secondary edging, filigree, gem settings). Every persona and item carries `palette_version: 2`, `finish: glitter_sparkle`, `accents: [platinum, gold]`.

### Glitter / sparkle shader plan (Godot 4)
- One shared `ShaderMaterial` (`shaders/glitter_sparkle.gdshader`, stub): noise-texture flakes thresholded by `sparkle_density`, per-flake twinkle phase over `TIME`, view-dependent glint, emission in platinum/gold.
- Voxel variant: same shader with `use_triplanar = true` (world-space sampling) for VoxelTerrain/blocks, lower density and emission.
- Mobile budget: "Sparkle FX" toggle; low preset turns off emission. See `resources/README_glitter_materials.md`.

## Batch 06: Royal Attire, Armory & Signet (`assets/concept_art/batch_06/`)
Duplicates skipped per user (281c94, 1cdad6, a4c0b4, 729b9d). All items palette v2, cosmetic/gameplay only.

| File | Item | Owner | Data | Notes |
|---|---|---|---|---|
| 01_foxy_white_coronation_gown.png | `foxy_white_coronation_gown` | foxy_ani | wardrobe.json | White coronation gown. |
| 02_monarch_white_regalia_orb_scepter.png | `monarch_white_regalia` | player (Anterranian Monarch) | wardrobe.json | White royal regalia with orb scepter. |
| 03_monarch_white_formal_suit.png | `monarch_white_formal_suit` | player (Anterranian Monarch) | wardrobe.json | White formal suit. |
| 04_foxy_ivory_gown_burgundy_cape.png | `foxy_ivory_gown_burgundy_cape` | foxy_ani | wardrobe.json | Ivory gown with burgundy cape. |
| 05_monarch_black_regalia_orb_scepter.png | `monarch_black_regalia` | player (Anterranian Monarch) | wardrobe.json | Black royal regalia with orb scepter. |
| 06_royal_cosmic_katana.png | `royal_cosmic_katana` | player (Anterranian Monarch) | weapons.json | Katana with cosmic blade finish and scabbard. |
| 07_royal_twin_sidearms_holster.png | `royal_twin_sidearms` | player (Anterranian Monarch) | weapons.json | Fictional in-game twin sidearms with jeweled holster belt. |
| 08_royal_knight_armor_venus_mars.jpg | `royal_knight_armor` | player (Anterranian Monarch) | armor.json | Knight armor with Venus/Mars shield and sword. |
| 09_royal_guard_officer_dress.jpg | `royal_guard_officer_dress` | royal_guard | armor.json | Officer dress uniform. |
| 10_royal_guard_field_uniform.jpg | `royal_guard_field_uniform` | royal_guard | armor.json | Field uniform. |
| 11_purple_royal_tactical_armor_beret.jpg | `purple_royal_tactical_armor` | royal_guard | armor.json | Purple tactical armor with beret. |
| 12_cosmic_camo_combat_uniform.jpg | `cosmic_camo_combat_uniform` | royal_guard | armor.json | Cosmic camo combat uniform. |
| 13_navy_hussar_ermine_cape.jpg | `navy_hussar_ceremonial` | royal_guard | armor.json | Navy hussar uniform with ermine cape. |
| 14_gold_h_crest_signet_band.jpg | `gold_h_crest_signet_band` | player (Anterranian Monarch) | regalia.json | Wide gold band with H crest, inscribed 'FLAMMA. ORDO. AETERNA. 8'. |

**Motto spelling canonical: "FLAMMA. ORDO. AETERNA."** (confirmed by the batch_06 signet band). Earlier 'Aterna' readings normalized.

## Batch 07: Royal Orders, Tattoos & Court Robes (`assets/concept_art/batch_07/`)
30 images received, 19 kept, 11 duplicates skipped. Eight royal orders (see docs/modules/ROYAL_ORDERS.md): Lumina Healers, Seraphic Vanguard, Ethereal Sentinels (printed names), plus Scales, Eye, Verdant Tree, Hourglass, Trident (assigned by Foxy, user may rename). Tattoo + signet pairs in cosmetics.json/regalia.json, three-ring set, navy sun/moon court robes (queen, king, princess), navy officer ermine uniforms. 19_orb_scepter_king is kept as reference but likely duplicates the batch_02 elder king. All palette v2.

## Batch 08: Cosmic Court Robes & Scepters (`assets/concept_art/batch_08/`)
6 images kept (cosmic court set). Palette v2 (black / magenta / gold / platinum + glitter). Wardrobe in `data/items/wardrobe.json`; scepters in `data/items/regalia.json`.

| File | Item id | Persona / wearer | Notes |
|------|---------|------------------|-------|
| `01_queen_vesperine_black_magenta_robe_orb_ring_scepter.jpg` | `vesperine_cosmic_orb_ring_robe` | **queen_vesperine_pyre** | Black/magenta robe, orb-ring scepter, floating rune platform |
| `02_prince_solarian_armored_ermine_crown_crescent_scepter.jpg` | `solarian_armored_ermine_crown_set` | **prince_regent_solarian** (also Monarch attire) | Armored black/magenta, ermine crown, crescent scepter |
| `03_queen_vesperine_ermine_cape_crescent_scepter.jpg` | `vesperine_ermine_cape_crescent` | **queen_vesperine_pyre** (also **foxy_ani** royal attire) | Ermine cape + crescent scepter |
| `04_king_ignatius_orb_scepter_magenta_tabard.jpg` | `ignatius_orb_scepter_magenta_tabard` | **king_ignatius_pyre** (also Monarch) | Elder king, magenta tabard, orb scepter — **same elder as** `batch_07/19_orb_scepter_king_dup_of_batch02_elder` and `batch_02/03_elder_king_*` |
| `05_prince_solarian_high_collar_sigil_robe_sparkle_cape.jpg` | `solarian_sigil_robe_sparkle_cape` | **prince_regent_solarian** (also Monarch) | High collar, sigil embroidery, black fur, glitter sparkle cape |
| `06_king_ignatius_orb_scepter_gold_greaves_variant.jpg` | `ignatius_orb_scepter_gold_greaves_variant` | **king_ignatius_pyre** | Near-duplicate of 04 (gold greaves variant); same elder link as above |

**New regalia (scepters):**
- `orb_ring_scepter` — magenta orb in gold planetary ring (queen + elder king sets)
- `crescent_scepter` — gold crescent framing magenta orb (heir + ermine-cape queen; moon/Venus lineage from batch_02)

**Open confirmation (user):** elder orb-scepter king in batch_08 / batch_07-19 confirmed as Ignatius Pyre (same as batch_02 elder); rename if wrong.

## Batch 09: Court Daywear & Household Staff (`assets/concept_art/batch_09/`)
6 images kept. Palette v2. Young-man court outfits → **prince_regent_solarian** (+ Monarch wardrobe). Mannequin formal → Monarch. Staff → household non-combat uniforms in `armor.json`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_solarian_magenta_black_court_tunic_coat.jpg` | `solarian_magenta_black_court_tunic_coat` | **prince_regent_solarian** (also Monarch) | wardrobe.json | Long magenta/black court tunic coat, gold filigree, belt |
| `02_solarian_black_frock_coat_magenta_waistcoat_half_cape.jpg` | `solarian_black_frock_coat_half_cape` | **prince_regent_solarian** (also Monarch) | wardrobe.json | Black frock coat, magenta waistcoat, half cape, tall boots |
| `03_solarian_casual_royal_blazer_pinstripe.jpg` | `solarian_casual_royal_blazer_pinstripe` | **prince_regent_solarian** (also Monarch) | wardrobe.json | Casual royal: blazer, magenta vest, pinstripe, cape |
| `04_monarch_formal_suit_ermine_overcoat_gem_belt.jpg` | `monarch_formal_suit_ermine_overcoat_gem_belt` (+ variant on `monarch_formal_attire`) | **player (Anterranian Monarch)** | wardrobe.json | Mannequin: black suit, magenta vest/tie, ermine overcoat, gem belt |
| `05_household_attendant_tunic_gold_collar_8.jpg` | `household_attendant_tunic` | royal_household | armor.json (category `household`, non-combat) | Gold collar with magenta **'8'** emblem |
| `06_household_steward_asymmetric_tunic_8_emblem.jpg` | `household_steward_asymmetric_tunic` | royal_household | armor.json (category `household`, non-combat) | Asymmetric tunic, gold **'8'/infinity-knot** chest emblem |

**Recurring '8' emblem:** appears on batch_02 ring_01, batch_06–07 signets, and batch_09 attendant collar + steward chest. Meaning still **user-pending** (see `docs/PENDING_USER_QUESTIONS.md`).

## Batch 10: Formal Mannequins, Court Mage & Envoy (`assets/concept_art/batch_10/`)
6 images kept. Palette v2 (black / magenta / gold / platinum + glitter). Wardrobe in `data/items/wardrobe.json`; household sash variant on `household_attendant_tunic` in `armor.json`.

| File | Item id | Persona / wearer | Notes |
|------|---------|------------------|-------|
| `01_monarch_formal_verdant_tree_crest_ermine_cape.jpg` | `monarch_formal_verdant_tree_crest` (+ variant on `monarch_formal_attire`) | **player (Anterranian Monarch)** | Mannequin: black suit, magenta vest/tie, ermine cape, tree-of-life crest patch, gem belt; **linked_guild** `order_of_the_verdant_tree` |
| `02_foxy_queen_column_gown_ermine_epaulettes.jpg` | `foxy_queen_column_gown_ermine_epaulettes` (+ variant on `foxy_court_gown`) | **foxy_ani** (also **queen_vesperine_pyre**) | Magenta column gown, ermine cape, gold epaulettes, crescent belt |
| `03_foxy_coronation_ballgown_ruby_jewels.jpg` | `foxy_coronation_ballgown_ruby_jewels` (+ variant on `foxy_coronation_gown`) | **foxy_ani** | Magenta ballgown, ermine cape, ruby jewels and belt |
| `04_umbriel_voss_court_mage_sheer_robe.jpg` | `umbriel_voss_court_mage_sheer_robe` | **umbriel_voss** (new; assigned by Foxy, user may rename) | Sheer black robe over magenta tunic, crest belt; court mage / consort |
| `05_household_attendant_tunic_sash_variant.jpg` | variant of `household_attendant_tunic` | royal_household | Near-duplicate of batch_09 attendant; simpler sash variant (armor.json) |
| `06_vesper_trail_alaskan_biome_tribal_envoy.jpg` | `vesper_trail_alaskan_biome_tribal_envoy` | **explorer_guide** (Vesper Trail) | Original fantasy Alaskan-biome tribal envoy/explorer attire; respectful original design, not a real-world cultural replica |

**New companion:** Umbriel Voss (`umbriel-voss`) — court mage / consort, schema v3, registered. User may rename.

## Batch 11: Warrior Envoy & Boudoir Orb Set (`assets/concept_art/batch_11/`)
6 images received, **5 kept**, 1 duplicate skipped. Palette v2. Mature items age-gated.

**Skipped:** `d6431348…png` — identical feather-mantle envoy design as `batch_10/06_vesper_trail_alaskan_biome_tribal_envoy.jpg` (source e0b7971d…jpg); PNG container only, not kept as a variant. See `SKIPPED_duplicates.txt`.

**New companion:** **Kael Emberbraid** (`kael-emberbraid`) — warrior envoy / northern scout, schema v3, registered. **Envoy pair** with **Vesper Trail** (`explorer_guide`). Name assigned by Foxy; user may rename. Respectful original fantasy design (northern explorer/envoy silhouettes; not a real-world cultural replica).

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_kael_emberbraid_warrior_envoy_sleeveless.jpg` | `kael_emberbraid_warrior_envoy_sleeveless` | **kael_emberbraid** | wardrobe.json | Braids, red face paint, gold-feather collar, sleeveless tunic |
| `02_kael_emberbraid_warrior_envoy_ceremonial_cape.jpg` | `kael_emberbraid_warrior_envoy_ceremonial_cape` | **kael_emberbraid** | wardrobe.json | Ceremonial cape version of 01 |
| `03_foxy_boudoir_set_3_orb_ermine_cuffs.jpg` | `foxy_boudoir_set_3` (variant ermine_cuffs) | **foxy_ani** | wardrobe.json | **mature, hidden by default** |
| `04_foxy_boudoir_set_3_orb_ermine_collar.jpg` | `foxy_boudoir_set_3` (variant ermine_collar) + resolves `foxy_boudoir_set` variant_b | **foxy_ani** | wardrobe.json | **mature, hidden by default**; **closes missing d05bcc** |
| `05_foxy_sheer_orb_gown_ermine_robe.jpg` | `foxy_sheer_orb_gown_ermine_robe` | **foxy_ani** | wardrobe.json | **mature, hidden by default**; sheer black embroidered gown + ermine robe, orb jewels |

**d05bcc status: RESOLVED** (2026-10-13). Ermine-collar boudoir image arrived in batch_11/04.

## Batch 12: Court Coat, Boudoir IV & Court Aide (`assets/concept_art/batch_12/`)
6 images received, **3 kept**, 3 duplicates skipped (re-uploads already in batch_11). Palette v2. Mature items age-gated.

**Skipped:** `c413395d…`, `b48620e4…`, `37cc1f01…` — identical to batch_11/03–05 (boudoir orb set + sheer orb gown). See `SKIPPED_duplicates.txt`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_kael_emberbraid_court_coat_magenta_cape.jpg` | `kael_emberbraid_court_coat_magenta_cape` | **kael_emberbraid** | wardrobe.json | Court formal: black gold-embroidered long coat, magenta cape, face paint retained |
| `02_foxy_boudoir_set_4_purple_fur_lace.jpg` | `foxy_boudoir_set_4` | **foxy_ani** | wardrobe.json | **mature, hidden by default**; black lace/gold jewels + purple fur-trimmed lace robe |
| `03_household_court_aide_tunic_coat_magenta_trim.jpg` | `household_court_aide_tunic_coat` | royal_household | armor.json (category `household`, non-combat) | Court aide/attendant tunic coat, magenta trim, gold sunburst buckle — **household uniform, not a new named companion** |

## Batch 13: Cosmic Companions, Vanguard Captain, Heels & SUV Variants (`assets/concept_art/batch_13/`)
6 images kept. Palette v2 (black / magenta / gold / platinum + glitter).

**New companions (schema v3, registered; names assigned by Foxy, user may rename):**
- **Nyxara Voltweave** (`nyxara-voltweave`) — cosmic circuit companion / neon scout
- **Azura Stellaris** (`azura-stellaris`) — astronomer / navigator; **star_map_pair** with **Celestia Nyx** (`docs/modules/STAR_MAP.md`)
- **Seraph Caelum** (`seraph-caelum`) — Seraphic Vanguard captain (distinct from healer **Seraph Halcyon** silver android)

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_nyxara_voltweave_circuit_bodysuit_gold_pauldron.jpg` | `nyxara_voltweave_circuit_bodysuit` | **nyxara_voltweave** | wardrobe.json | Violet skin, magenta circuit lines, gold pauldron, cape |
| `02_azura_stellaris_star_chart_robe.jpg` | `azura_stellaris_star_chart_robe` | **azura_stellaris** | wardrobe.json | Blue pointed-ear navigator; sheer gold star-chart robe; linked to star map |
| `03_seraph_caelum_hooded_vanguard_halo.jpg` | `seraph_caelum_hooded_vanguard` | **seraph_caelum** (guild `seraphic_vanguard`) | wardrobe.json | Hooded winged halo figure; not a duplicate of seraph_halcyon |
| `04_household_court_officer_sash_tunic.jpg` | `household_court_officer_sash_tunic` | royal_household | armor.json (category `household`, non-combat) | Short dark bob + magenta sash — **household uniform, not a new named companion** (related to batch_12/14 aide line) |
| `05_foxy_royal_heels_cosmic_filigree_variant.jpg` | variant `cosmic_filigree` of `foxy_royal_heels` | **foxy_ani** | wardrobe.json | Same heels family as batch_04; heavier filigree + cosmic pedestal |
| `06_royal_suv_cosmic_hover_variant.jpg` | variant `cosmic_hover` of `royal_suv` | player (Anterranian Monarch) | vehicles.json | Same SUV family as batch_04; hover rings + constellation glass |

## Batch 14: Court Aide Dress, Field Courier & Chancellor (`assets/concept_art/batch_14/`)
6 attachments received (3 designs × JPG+PNG), **3 kept** (JPGs only), 3 PNG container duplicates skipped. Palette v2.

**Skipped:** `846fde71…png`, `2a45a8f7…png`, `6c266dd9…png` — PNG duplicates of the three kept JPGs. See `SKIPPED_duplicates.txt`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_household_court_aide_officer_dress_uniform.jpg` | `household_court_aide_officer_dress` (+ variant on `household_court_aide_tunic_coat`) | royal_household | armor.json (category `household`, non-combat) | Double-breasted officer dress + magenta shoulder sash — **same short-haired court aide as batch_12/03 and batch_13/04** (`household_court_officer_sash_tunic`) |
| `02_nyra_coil_field_courier_jumpsuit.jpg` | `nyra_coil_field_courier_jumpsuit` | **nyra_coil** (new; assigned by Foxy, user may rename) | wardrobe.json | Black jumpsuit, magenta scarf, satchel, rank patch — field courier / royal technician |
| `03_ledger_vale_chancellor_officer_coat.jpg` | `ledger_vale_chancellor_officer_coat` | **economy_advisor** (Ledger Vale); also Monarch | wardrobe.json | Long gold-embroidered officer coat, magenta crossed sash, **gold ledger box** — royal chancellor / treasurer look |

**New companion:** **Nyra Coil** (`nyra-coil`) — field courier / royal technician, schema v3, registered. Name assigned by Foxy; user may rename.

**Ledger Vale link:** batch_14/03 mapped to existing **economy_advisor** (Ledger Vale) as chancellor/treasurer wardrobe (not a new companion); persona appearance + role label updated.

## Batch 15: Chancellor Formal, Jeweled Boots, Flagship Fighter & Throne Variants (`assets/concept_art/batch_15/`)
6 images received, **6 kept**, 0 exact duplicates skipped. Palette v2 (black / magenta / gold / platinum + glitter). Checked against batch_04 heels/boots/thrones, batch_05 heir thrones, batch_13 heels/SUV, batch_14 chancellor coat — all distinct hashes / variant presentations.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_ledger_vale_chancellor_formal_sash_medallion.jpg` | variant `batch_15_formal_sash_medallion` of `ledger_vale_chancellor_officer_coat` | **economy_advisor** (Ledger Vale); also Monarch | wardrobe.json | Same treasurer/chancellor as batch_14/03; formal diagonal sash + shoulder medallion + hip ledger pouch |
| `02_foxy_jeweled_thigh_boots_and_ankle_booties.jpg` | variant `batch_15_jeweled_cosmic` of `foxy_embroidered_boots` | **foxy_ani** | wardrobe.json | Thigh-high + ankle booties sheet; jeweled cosmic pedestals. Same family as batch_04/03 (not heels) |
| `03_royal_flagship_starfighter_phoenix_filigree.png` | `royal_flagship_starfighter` | player (Anterranian Monarch) | vehicles.json (`type: space`) | Black/magenta starfighter, gold filigree, phoenix decals, magenta energy aura; **star_map** flagship_fighter |
| `04_monarch_throne_black_tufted_eagles_ringed_orb.jpg` | variant of `monarch_throne` | player (Anterranian Monarch) | furniture.json | Black tufted back, magenta seat, twin eagles, ringed orb + crescent — Monarch throne variant (≠ batch_04 exact) |
| `05_foxy_consort_throne_aterna_plaque_variant.jpg` | variant of `foxy_consort_throne` | **foxy_ani** | furniture.json | Oval ringed gem, crescent+sun, eagles; plaque art reads **ATERNA** (missing E). Official motto **AETERNA** |
| `06_heir_throne_solarian_semi_divus_magenta_wings.jpg` | variant of `heir_throne_solarian` | **prince_regent_solarian** | furniture.json | Magenta seat, black wings, crescent-tree crest; banner **POTENTIA HERES SEMI-DIVUS** — **confirms prince heir text**; Lumira SEMI DEIVA largely resolved in batch_16 |

**Resolved / noted:**
- Prince heir banner text recorded as **SEMI-DIVUS** (batch_15/06 confirms batch_05 Solarian reading).
- Consort throne art discrepancy: **ATERNA** in image vs canonical **AETERNA**.
- Lumira sash **SEMI DEIVA** → largely resolved in batch_16 (exact wording soft-confirm).

## Batch 16: Lumira Heir Throne Text Confirm & Monarch Jeans Variant (`assets/concept_art/batch_16/`)
6 images received, **2 kept**, **4 duplicates skipped** (re-uploads already in batch_15). Palette v2 (black / magenta / gold / platinum + glitter). Compared to batch_05 heir thrones and royal jeans — near-match presentations kept as variants (distinct hashes).

**Skipped:** `01afb713…` (= batch_15/06 Solarian heir), `361d0b97…` (= batch_15/05 consort ATERNA), `12251163…` (= batch_15/04 Monarch throne), `ceae7ef3…` (= batch_15/03 flagship). See `SKIPPED_duplicates.txt`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_heir_throne_lumira_semi_deiva_serva_variant.jpg` | variant `batch_16_semi_deiva_serva` of `heir_throne_lumira` | **princess_regent_lumira** | furniture.json | Magenta tufted seat, black feathered wings, gold spires, oval magenta gem with pearl + celestial ring, crescent crest; banners ~**POTENTIA … SEMI DEIVA SERVA** (possible **HERES**). Confirms feminine **SEMI DEIVA** for Lumira vs **SEMI-DIVUS** for Solarian |
| `02_monarch_royal_jeans_baroque_rhinestone_variant.jpg` | variant `batch_16_baroque_rhinestone` of `monarch_royal_jeans` | player (Anterranian Monarch) | wardrobe.json | Dark denim, gold baroque embroidery, rhinestone side seam, jeweled magenta-gem buckle, magenta embroidered boots — near-match of batch_05/03; kept as variant |

**Resolved / noted:**
- Lumira heir sash **SEMI DEIVA** (feminine) largely confirmed by batch_16/01; contrasts Solarian **SEMI-DIVUS**. Exact full wording (HERES / SERVA placement) soft-confirm with user.
- Monarch royal jeans batch_16 kept as baroque rhinestone variant (not Foxy jeans).

## Batch 17: Royal Jeans Collection (`assets/concept_art/batch_17/`)
5 images received, **4 kept**, **1 duplicate skipped** (`140d8d66…` = exact batch_16/02 Monarch jeans). Checked against batch_05 royal jeans (03–06) — no exact matches; all four JPGs are distinct variants. Palette v2 (black / magenta / gold / platinum + glitter).

**Skipped:** `140d8d66…jpg` — exact re-upload of `batch_16/02_monarch_royal_jeans_baroque_rhinestone_variant.jpg`. See `SKIPPED_duplicates.txt`.

**Collection:** `royal_jeans` in `data/items/wardrobe.json` (`collections.royal_jeans`) unifies Monarch + Foxy embroidered denim across batch_05 / batch_16 / batch_17. Member items: `monarch_royal_jeans`, `foxy_royal_jeans`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_monarch_royal_jeans_ruby_buckle_heeled_boots.jpg` | variant `batch_17_ruby_buckle_heeled_boots` of `monarch_royal_jeans` (+ `royal_jeans` collection) | player (Anterranian Monarch) | wardrobe.json | Dark jeans, heavy gold baroque embroidery, magenta rhinestone side stripe, **square ruby buckle**, gold-embroidered heeled ankle boots |
| `02_foxy_royal_jeans_oval_buckle_stiletto_booties.jpg` | variant `batch_17_oval_buckle_stiletto_booties` of `foxy_royal_jeans` | **foxy_ani** | wardrobe.json | Skinny jeans, gold baroque, magenta gem side stripe, **oval gem buckle**, stiletto booties |
| `03_foxy_royal_jeans_square_gem_stripe_stiletto_booties.jpg` | variant `batch_17_square_gem_stripe_stiletto_booties` of `foxy_royal_jeans` | **foxy_ani** | wardrobe.json | Similar skinny jeans, **square magenta gem stripe**, stiletto booties |
| `04_foxy_royal_jeans_h_crest_gold_cuff_booties.jpg` | variant `batch_17_h_crest_gold_cuff_booties` of `foxy_royal_jeans` | **foxy_ani** / royal house | wardrobe.json | Skinny jeans, gold baroque, **crowned 'H' crest** on hip, magenta gem stripe, gold-cuff stiletto booties — **links** `gold_h_crest_signet_band` (batch_06); **H meaning still user-pending** |

**Open confirmation (user):** Meaning of the crowned **H** crest (batch_05/06 jeans, batch_06 signet band, batch_17/04) — House? Heir? other? See `docs/PENDING_USER_QUESTIONS.md`.

## Batch 18: White Regalia Variants, Seraph Emberion, Heavy Trooper & Phoenix Mount (`assets/concept_art/batch_18/`)
6 images kept (no exact duplicates vs batch_02 / batch_06 white regalia — distinct MD5/size; kept as white-regalia variants). Palette v2 (black / magenta / gold / platinum + glitter).

**Checked vs batch_02 / batch_06 white regalia:** batch_06 `01`–`03` white gown / white regalia / white formal are related looks but **not** exact duplicates of batch_18/01–03. Batch_02 has no matching white-regalia files. All six kept.

**New companion:** **Seraph Emberion** (`seraph-emberion`) — grey phoenix-android of the **Seraphic Vanguard**, schema v3, registered. Distinct from **Seraph Halcyon** (silver healer android), **Seraph Caelum** (hooded Vanguard captain), and **Circuit Nova** (engineering AI). Name assigned by Foxy; user may rename.

**New creature / mount:** **Phoenix Emberwing** (`phoenix_emberwing`) in new `data/creatures.json` — companion pet/mount + emblem lore linked to project name **Phoenix**.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_foxy_white_coronation_wedding_gown_ruby_cloak.jpg` | variant `batch_18_wedding_ruby_cloak` of `foxy_white_coronation_gown` | **foxy_ani** (also **queen_vesperine_pyre**) | wardrobe.json | White satin ballgown, gold baroque, ruby gems, ringed-orb pendant, ermine-trimmed black/magenta cloak — coronation/wedding |
| `02_monarch_white_regalia_orb_ring_scepter_variant.jpg` | variant `batch_18_orb_ring_scepter_white_boots` of `monarch_white_regalia` | player (Anterranian Monarch) | wardrobe.json | White tunic suit, gold embroidery, ermine cloak, orb-ring scepter, white jeweled boots |
| `03_monarch_white_tuxedo_magenta_vest_ermine_cape.jpg` | variant `batch_18_white_tuxedo_magenta_vest_ermine_cape` of `monarch_white_formal_suit` | player (Anterranian Monarch) | wardrobe.json | White tuxedo, magenta vest/bowtie, ermine cape |
| `04_seraph_emberion_phoenix_android_vanguard.jpg` | `seraph_emberion_phoenix_android_armor` | **seraph_emberion** (guild `seraphic_vanguard`) | wardrobe.json + persona | Bald grey android angel, magenta halo, black feathered wings, black/gold armor, glowing phoenix chest sigil |
| `05_ethereal_sentinels_heavy_trooper_plasma_cannon.png` | `ethereal_sentinels_heavy_trooper_armor` + `ethereal_sentinels_phoenix_plasma_cannon` | **ethereal_sentinels** (also Monarch) | armor.json + weapons.json | Heavy trooper armor (magenta visor) + ornate gold-filigree plasma cannon with phoenix emblem |
| `06_phoenix_emberwing_mount_crescent_ruins.jpg` | `phoenix_emberwing` | player (Anterranian Monarch); also **foxy_ani** | creatures.json | Dark violet phoenix, ember-fire wings, crescent moon, ruined castle — pet/mount + project Phoenix emblem lore |

## Batch 19: Defense Projects, Ivory Regalia & SCDI (`assets/concept_art/batch_19/`)
6 images received, **5 kept**, **1 duplicate skipped** (PNG of Royal Aegis). Palette v2 (black / magenta / gold / platinum + glitter). All weapons/armor/mechs are game-only virtual items.

**Checked vs batch_18 white gown:** `01` ivory gown distinct MD5 from batch_18/01 white wedding/ruby-cloak gown — kept as ivory/magenta-sash queen-regalia variant of `foxy_white_coronation_gown`.

**Skipped:** `015a68f28cef…png` — PNG container duplicate of Royal Aegis (kept JPG as `05`). See `SKIPPED_duplicates.txt`.

**New module:** `docs/modules/DEFENSE_PROJECTS.md` — Project Crusader, Project Aegis-Guard, SCDI program.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_foxy_ivory_regalia_magenta_sash_ermine_cape.jpg` | variant `batch_19_ivory_magenta_sash_ermine` of `foxy_white_coronation_gown` | **foxy_ani** (also **queen_vesperine_pyre**) | wardrobe.json | Ivory gown, gold baroque, magenta jeweled sash, ermine cape over black/plum cloak, white jeweled boots |
| `02_project_crusader_apex_modular_kinetic_rifle.png` | `project_crusader_apex_modular_kinetic_rifle` + `project_crusader_soldier_armor` | player / royal_guard | weapons.json + armor.json | Printed PROJECT CRUSADER; Magnelcration / Phamx noted as likely typos |
| `03_project_aegis_guard_triton_coast_guard_attire.jpg` | `project_aegis_guard_triton_coast_guard` | **order_of_the_trident** | armor.json | Triton-Class coast guard; links Order of the Trident navy |
| `04_scdi_dominion_shotgun_crowned_heavy_trooper.jpg` | `scdi_dominion_shotgun` + `scdi_dominion_heavy_trooper_armor` | player / ethereal_sentinels | weapons.json + armor.json | Art prints SHOTGUAN → recorded as Dominion Shotgun |
| `05_scdi_royal_aegis_mech.jpg` | `scdi_royal_aegis_mech` | player (Anterranian Monarch) | mechs.json | SCDI \| ROYAL AEGIS crowned mech, plasma greatsword + cannons |

**Open confirmation (user):** What does **SCDI** stand for? (Also on batch_01 Omni-Worker.) See `docs/PENDING_USER_QUESTIONS.md`.

## Batch 20: SCDI Aura Cannon & Suit Series 0–3 (`assets/concept_art/batch_20/`)
6 images received, **5 kept**, **1 duplicate skipped** (PNG of Aura Cannon). Palette v2 (black / magenta / gold / platinum + glitter). All weapons/armor/vehicles are **game-only virtual items**.

**Skipped:** `ada72d9bb57b…png` — PNG container duplicate of Aura Cannon (kept JPG as `01`). See `SKIPPED_duplicates.txt`.

**Module update:** `docs/modules/DEFENSE_PROJECTS.md` — SCDI Suit Series cards 0–3 + Aura Cannon.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_scdi_aura_cannon_rockets_grenade_launcher.jpg` | `scdi_aura_cannon` | player / ethereal_sentinels | weapons.json | Printed SCDI | AURA CANNON - Rockets / Grenade Launcher; magenta plasma heavy |
| `02_scdi_universal_sentinel_exoskeleton_uniform.jpg` | `scdi_universal_sentinel_exoskeleton` | **ethereal_sentinels** | armor.json | Suit card **0**; prints EXOSKELTON → Exoskeleton; links Sentinel trooper (batch_18/05) |
| `03_scdi_aegis_prime_universal_combat_exploration_suit.png` | `scdi_aegis_prime_suit` | player / ethereal_sentinels | armor.json | Suit card **1**; ≠ Aegis-Guard Triton ≠ Royal Aegis mech |
| `04_scdi_void_weaver_spacecraft_piloting_eva_suit.jpg` | `scdi_void_weaver_eva_suit` | player (pilot) | armor.json | Suit card **2**; prints SPACRACT → Spacecraft; EVA / piloting |
| `05_scdi_abyssal_sovereign_underwater_suit.png` | `scdi_abyssal_sovereign_suit` + `scdi_abyssal_submarine` | **order_of_the_trident** | armor.json + vehicles.json | Suit card **3**; prints SOVEREGIN → Sovereign; submarine stub |

**Open confirmation (user):** What does **SCDI** stand for? (Still pending from batch_01 / batch_19.) See `docs/PENDING_USER_QUESTIONS.md`.

## Batch 21: SCDI Suit Series cards 4–6, 8, 14 + Skyfall Harness (`assets/concept_art/batch_21/`)
6 images received, **6 kept**, **0 duplicates**. Palette v2 (black / magenta / gold / platinum + glitter). All armor/weapons/NPC units are **game-only virtual items**.

**Module update:** `docs/modules/DEFENSE_PROJECTS.md` — SCDI Suit Series extended (cards 4, 5, 6, 8, 14 + unnumbered Skyfall); **missing cards 7, 9–13**.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_scdi_firestorme_warden_pyro_resilient_hazard_suit.jpg` | `scdi_firestorme_warden_suit` | player / royal_guard | armor.json | Suit card **4**; prints FIRESTORME / PYRO-RESILENT → Firestorm / Pyro-Resilient; Venus fire biome |
| `02_scdi_terra_explorer_all_terrain_civilian_explorer_suit.png` | `scdi_terra_explorer_suit` | player / explorer | armor.json | Suit card **5**; all-terrain civilian & explorer |
| `03_scdi_verdant_guardian_forest_jungle_combat_suit.jpg` | `scdi_verdant_guardian_suit` + energy machete + jungle rifle | **order_of_the_verdant_tree** | armor.json + weapons.json | Suit card **6**; links Verdant Tree order |
| `04_scdi_skyfall_harness_advanced_parachute_bungee_system.jpg` | `scdi_skyfall_harness` | player / aerial | armor.json | **Unnumbered**; prints PARCHUTE / BUNNGE → Parachute / Bungee; wing glider gear |
| `05_scdi_cosmic_habitation_space_station_operations_suit.jpg` | `scdi_cosmic_habitation_suit` | player / station ops | armor.json | Suit card **8** |
| `06_scdi_omni_worker_universal_android_assistant.jpg` | `scdi_omni_worker_unit` (NPC worker) | android worker unit | data/npcs.json | Suit card **14**; **not** a new named companion — template remains `omni_worker` (batch_01/06) |

**Printed → corrected:** FIRESTORME→Firestorm; PYRO-RESILENT→Pyro-Resilient; PARCHUTE→Parachute; BUNNGE→Bungee (printed strings kept for art fidelity).

**Open confirmation (user):** What does **SCDI** stand for? (Still pending.) Missing suit cards **7, 9–13**. See `docs/PENDING_USER_QUESTIONS.md`.

## Batch 22: Phoenix God Regalia, Wing Throne & Anterranian Capitol (`assets/concept_art/batch_22/`)
6 images received, **3 kept**, **3 duplicates skipped** (Omni-Worker PNG + two PNG containers of keepers). Palette v2 (black / magenta / gold / platinum + glitter). All items are **game-only virtual** stubs.

**Skipped:** `532b851…png` (Omni-Worker dup of batch_21/06); `9eb58ce3…png` (PNG of Phoenix God regalia); `d15aee7a…png` (PNG of wing-throne scene). See `SKIPPED_duplicates.txt`.

**New catalog:** `data/items/structures.json` — landmark / capitol buildings.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_monarch_phoenix_god_regalia_crystal_hall.jpg` | `monarch_phoenix_god_regalia` | player (Anterranian Monarch) | wardrobe.json | Crystal crown, magenta flame shoulders, black/gold phoenix cloak; gold **'8' floor seal**; crystal hall city window. Title noted: **Phoenix God** |
| `02_phoenix_wing_throne_throne_room_scene.jpg` | `phoenix_wing_throne` | player (Anterranian Monarch) | furniture.json | Winged phoenix throne on dais under golden phoenix sigil + constellation lines — throne room scene |
| `03_anterranian_capitol_phoenix_god.jpg` | `anterranian_capitol` | player (Anterranian Monarch) | structures.json | Black domed capitol, phoenix pediment, gold **'8' banners**, landing pads, starships. Prints **PHOENIX GOD / ANTERRANIAN MONORCH** (sic MONARCH) |

**Open confirmation (user):** Meaning of the **'8'** (now also floor seal + capitol banners). Title **Phoenix God** noted. Printed **MONORCH** → official **MONARCH**. See `docs/PENDING_USER_QUESTIONS.md`.

## Batch 23: Capitol Variants, Phoenix God Coin & Heraldry (`assets/concept_art/batch_23/`)
6 images received, **6 kept**, **0 duplicates**. Palette v2 (black / magenta / gold / platinum + glitter). All items are **game-only virtual** stubs (currency is not real money or crypto).

**New catalogs:** `data/lore/heraldry.json`, `data/items/currency.json`, `docs/modules/HERALDRY.md`.  
**Updated:** `data/items/structures.json` (capitol variants), `docs/modules/ECONOMY_BANKING.md` (coin face).

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_anterranian_capitol_floating_pads_phoenix_god.jpg` | variant `floating_pads_phoenix_god` of `anterranian_capitol` | player (Anterranian Monarch) | structures.json | Floating landing pads; plaques **8 / PHOENIX GOD / ANTERRANIAN MONAACH** (sic MONARCH) |
| `02_anterranian_capitol_gold_dome_dragon_crest.png` | variant `gold_dome_dragon_crest` of `anterranian_capitol` | player (Anterranian Monarch) | structures.json | Gold dome, dragon crest, **8** archway |
| `03_phoenix_god_coin_divine_right_universal_wealth.jpg` | `phoenix_god_coin` | realm treasury / player | currency.json | Obverse phoenix; reverse magenta **8** over galaxy; rim **DIVINE RIGHT** / **UNIVERSAL WEALTH**; title MONACH→MONARCH |
| `04_national_flag_phoenix_radiating_8s.jpg` | `national_flag_phoenix_radiating` + `great_seal_phoenix` | realm | heraldry.json | Black flag, magenta radiating lines + edge 8s; seal with twin 8s |
| `05_great_seal_phoenix_vertical_flag.png` | `great_seal_phoenix` + `national_flag_phoenix_vertical` | realm | heraldry.json | Phoenix seal + vertical flag variant |
| `06_great_seal_dragon_vertical_flag.png` | `great_seal_dragon` + `national_flag_dragon_vertical` | realm | heraldry.json | Dragon seal + vertical flag (magenta 8 in tail loop) |

**Open confirmation (user):** Phoenix vs dragon as **primary** seal/flag? Meaning of the recurring **8** (now also coin reverse + capitol plaques/archway)? See `docs/PENDING_USER_QUESTIONS.md` and `docs/modules/HERALDRY.md`.


## Batch 24: Aethel Economy (notes, coins, sigil, stasis, ascendant, key) (`assets/concept_art/batch_24/`)
6 images received, **6 kept**, **0 duplicates**. Palette v2 (black / magenta / gold / platinum + glitter). All items are **game-only virtual** stubs — **not** real money, crypto, or exchange products.

**Extended:** `data/items/currency.json` (`economies.aethel` + 6 new items).  
**New:** `docs/modules/ECONOMY.md`.  
**Updated:** `docs/modules/ECONOMY_BANKING.md` (Aethel cross-link).

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_aethel_banknotes_100_1000_universal_currency.png` | `aethel_banknotes` | player / realm treasury | currency.json | Magenta notes 100/1000; crowned phoenix; cyan holo strip; **UNIVERSAL CURRENCY** |
| `02_aethel_lion_coins_crowned.png` | `aethel_lion_coin` | player / realm treasury | currency.json | Pink coins; crowned lion/beast head; gold runic band — **lion meaning pending** |
| `03_aethel_sigil_universal_validation.jpg` | `aethel_sigil` | player / ledger | currency.json | Stamp sheet; **AETHEL SIGIL / UNIVERSAL VALIDATION**; crowned phoenix |
| `04_aethel_stasis_stable_universal_currency.png` | `aethel_stasis` | player / realm treasury | currency.json | Dragon coin; **STABLE UNIVERSAL CURRENCY** (stable soft face) |
| `05_aethel_ascendant_dynamic_universal_asset.png` | `aethel_ascendant` | player / realm treasury | currency.json | Dragon coin; art **ASCENDAND**→**ASCENDANT**; **DYNAMIC UNIVERSAL ASSET** (variable in-game only) |
| `06_aethel_key_universal_access.png` | `aethel_key` | player / authorized | currency.json | Access/ID/wallet card; biometric hologram panel (cosmetic fiction) |

**Open confirmation (user):** Aethel vs Phoenix God Coin / Phoenix Embers relationship? Meaning of crowned lion coin? See `docs/PENDING_USER_QUESTIONS.md` and `docs/modules/ECONOMY.md`.


## Batch 25: Crowned Dragon-Phoenix House Emblem (`assets/concept_art/batch_25/`)
6 images received, **6 kept**, **0 duplicates**. Palette v2 (black / magenta / gold / platinum + glitter). All items are **game-only virtual** heraldry / UI stubs.

**Extended:** `data/lore/heraldry.json` (`house_emblem` + 6 variant items), `docs/modules/HERALDRY.md`.

| File | Item id | Persona / wearer | Data | Notes |
|------|---------|------------------|------|-------|
| `01_crowned_dragon_phoenix_holo_flag.png` | `house_emblem_crowned_dragon_phoenix_holo_flag` | realm / house | heraldry.json | Translucent holographic flag; magenta crowned dragon-phoenix |
| `02_crowned_dragon_phoenix_tapestry.jpg` | `house_emblem_crowned_dragon_phoenix_tapestry` | realm / house | heraldry.json | Black tapestry, gold filigree, starburst hybrid |
| `03_crowned_dragon_phoenix_neon_emblem_card.jpg` | `house_emblem_crowned_dragon_phoenix_neon_card` | UI | heraldry.json | Neon outline card; circuit frame — card back / loading |
| `04_crowned_dragon_phoenix_neon_circuit_body_cross_crown.jpg` | `house_emblem_crowned_dragon_phoenix_neon_circuit_body` | UI | heraldry.json | Circuit-body neon; cross crown — card back / loading |
| `05_crowned_dragon_phoenix_magenta_banner_constellation.jpg` | `house_emblem_crowned_dragon_phoenix_magenta_banner` | realm / house | heraldry.json | Magenta banner; constellation-pattern hybrid |
| `06_crowned_dragon_phoenix_galaxy_flag_landscape.jpg` | `house_emblem_crowned_dragon_phoenix_galaxy_flag` | realm / UI | heraldry.json | Landscape gold-frame galaxy flag |

**Open confirmation (user):** Phoenix vs dragon vs this **Crowned Dragon-Phoenix** hybrid as primary seal/flag/house emblem? Hybrid catalogued as `hybrid_candidate`; does **not** close Q24. See `docs/PENDING_USER_QUESTIONS.md` and `docs/modules/HERALDRY.md`.
