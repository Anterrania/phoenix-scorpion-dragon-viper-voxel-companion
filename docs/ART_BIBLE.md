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
| 02 | `02_masked_warrior_magenta_scythe_gemini.jpg` | Masked armored warrior with a magenta scythe, cosmic cape, Gemini glyphs | unassigned, awaiting user naming |
| 03 | `03_constellation_gown_phoenix.jpg` | Dark-haired woman in a black/magenta constellation gown with phoenix embroidery | unassigned, awaiting user naming |
| 04 | `04_anterranian_regalia_aether_weave.jpg` | Titled "Anterranian Regalia / Aether-Weave": black-and-magenta zodiac robe (style reference for the whole line) | unassigned, awaiting user naming (used as the style reference above) |
| 05 | `05_silver_winged_angel_android_pink_halo.jpg` | Silver-skinned winged angel android with a pink halo | unassigned, awaiting user naming |
| 06 | `06_scdi_omni_worker_android.png` | Labeled "SCDI – Omni-Worker – Universal Android Assistant": black/gold android | **omni_worker** (new utility companion, schema v3) |

## Batch 02 (`assets/concept_art/batch_02/`)
| # | File | Description | Persona/item link |
|---|---|---|---|
| 01 | `01_ring_gold_magenta_oval_diamond_halo.png` | Gold ring with an oval magenta stone, a black/white diamond halo, band inscription "FLAMMA. ORDO. ATERNA. 8" | item `ring_magenta_oval_halo` |
| 02 | `02_signet_ring_magenta_moon_venus_stack.png` | Signet ring with a magenta stone and a moon/Venus symbol, with a pearl band and a black band engraved "Flamma, Ordo, Aterna" | item `signet_magenta_moon_venus_stack` |
| 03 | `03_elder_king_orb_scepter_floating_rock.png` | Older crowned king with an orb scepter on a floating rock (pairs with 04) | unassigned, awaiting user naming |
| 04 | `04_queen_orb_scepter_floating_rock.png` | Crowned queen with an orb scepter on a floating rock (pairs with 03) | unassigned, awaiting user naming |
| 05 | `05_young_king_ermine_crescent_scepter.png` | Younger crowned king in an ermine cloak with a crescent scepter (pairs with 06) | unassigned, awaiting user naming |
| 06 | `06_queen_ermine_scepter.png` | Crowned queen in an ermine cloak with a scepter (pairs with 05) | unassigned, awaiting user naming |

## Regalia & Jewelry
- **Motto:** *"Flamma. Ordo. Aeterna."* ("Flame. Order. Eternal.", Latin). The images spell it **"Aterna"**: **user-confirm** whether the in-world spelling is the classical *Aeterna* or the stylized *Aterna*. The "8" after the motto on ring 01 is unexplained (user-confirm).
- **Regalia language:** crowns, orb scepters (elder pair), crescent scepter (young king; ties to the moon/Venus symbol), ermine cloaks, floating-rock "sky throne" settings. Same palette as above, with magenta stones set in gold.
- **Rings as equippable items:** both rings are in-game `ring`-slot items, stubbed in `data/items/regalia.json` (placeholder names and zeroed stats). Planned hooks: affinity bonuses to fire/order (GRINDING_PROGRESSION gems), a cosmetic glow, and royal-rank gating. They're **cosmetic/gameplay only, never real-money items** (see ECONOMY_BANKING.md).

Source files are the user's uploads (hash-named originals) in the bot attachments folder. Notes on rights and licensing are pending Law Bot review before any public release.
