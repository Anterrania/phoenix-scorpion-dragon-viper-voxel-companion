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
- **Inscription notes:** *"Flamma. Ordo. Aeterna."* ("Flame. Order. Eternal.", Latin). The images spell it **"Aeterna"**: **user-confirm** whether the in-world spelling is the classical *Aeterna* or the stylized *Aeterna*. The "8" after the motto on ring 01 is unexplained (user-confirm).
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
| 05 | *(missing: d05bcc…)* | Collar variant of 04 | `foxy_boudoir_set` variant B, pending |
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
| 02_heir_throne_lumira_magenta.png | `heir_throne_lumira` | Princess Regent Lumira | Magenta winged throne, gem/orb crest; sashes "POTENTIA HERES SEMI DEIVA" — **text unclear, user to confirm** |
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

