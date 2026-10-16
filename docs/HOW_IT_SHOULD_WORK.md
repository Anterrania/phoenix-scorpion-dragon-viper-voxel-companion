# How the app should work (v0.5)

This is a plain-language guide. It covers **what's real now** and **what's planned**.

**The idea in one line:** Second Life with voxels in place of prims, modern Star Citizen-style graphics, and living AI companions.

## Second Life concepts mapped to our game
| Second Life | Phoenix Voxel (our version) | Status |
|---|---|---|
| Prims (boxes/spheres you build with) | **Voxels** (smooth Transvoxel + block voxels) and Forge-Prim shapes | v0.6 building |
| Mesh uploads | **.glb uploads** (attachments, clothing, props) | local import ✔, store later |
| Region (256 m sim) | **Region / island** (256×256 m) | data model |
| Parcel | **Parcel** inside a region, with its own permissions and music | data model |
| Estate / private island | **Estate**: regions → **whole planets → star systems** | data model |
| L$ (Linden dollars) | **Aethel Coin (AEC)** | local wallet ✔ |
| Upload fee (L$10) | **AEC upload fee** for mesh / texture / sound | data model |
| Tier / land fees | **Monthly AEC tier fee** for each land tier | data model |
| Groups (land deeding, roles) | **Groups** with roles and deeded land | data model |
| Inventory | **Satchel** (BAG) | ✔ basic |
| Appearance / shapes / alphas | **Avatar creator + DNA blend + alpha masks** | ✔ |
| Attachments (HUD/head/hands…) | **Attachment points** | ✔ |
| Landmarks | **Landmarks** with signs + Teleport list | ✔ |
| Teleport / map TP | **MENU › Teleport** and **◎ MAP** tap-to-teleport | ✔ |
| Fly (Page Up/Down) | **FLY** button + ▲/▼ (keys E/C on PC) | ✔ |
| Parcel music / media | **Phoenix Radio** (user station URL) | ✔ basic |
| Local chat / IM / voice | **TALK** panel, companion voice (TTS), push-to-talk stub | partial |
| Marketplace / vendors | **Creator Market** with SL-style perms + vendor | data model + stub |
| Bots / NPCs | **Autonomous AI companions** (free roam, memory) | ✔ basic |

## Screen layout (v0.7, Firestorm-style)
- **Top status bar:** realm · region · coordinates · Aethel Coin · in-game time.
- **Minimap (top right):** you (white arrow), companions (magenta), creatures (red), landmarks (gold), combat zones (red ring). Use +/− to zoom, and tap it to open the big map.
- **☀ ENV:** sky presets (Sunrise, Midday, Sunset, Midnight, Venus Storm, Cosmic), Day/Night cycle (a 24-minute day), or Region default.
- **◉ NEAR:** list of who's nearby, sorted by distance. Tap one to go to them.
- **Menus:** drag anywhere to scroll (it keeps gliding when you let go). Settings has tabs, and the avatar creator has fold-out sections.

## How the server will work (later)
The grid is built like **Aurora-Sim/OpenSim**: central grid services (login, assets, inventory, avatars, regions, presence, groups, money, land) plus region servers, with Hypergrid to link other grids. See `docs/ARCHITECTURE_AURORA_MODEL.md`.

## Getting around
- **Fly:** tap **FLY**, then hold ▲ / ▼ to go up or down. Let go and you hover in place. Tap **LAND** to walk again.
- **Teleport:** **MENU › Teleport: Landmarks** lists every landmark. **◎ MAP** lets you tap anywhere on the map to teleport there (your companions come along).

## Land & money (planned)
- **Aethel Coin (AEC)** is the money, like L$. Uploading mesh, textures and sounds costs a small AEC fee, the way SL charges L$10.
- Land goes **parcel → region (island) → homestead → whole planet → star system**. Each tier has a buy price and a monthly fee, plus owner and group permissions (build, fly, access, music, bans), rentals and estate tools. All prices are placeholders (YOUR INPUT HERE).

## Two kinds of players
- **Owner (Phoenix).** You own the world. On first launch you make an avatar like everyone else. Then tap **My Avatar & Profile**, enter your private **owner code**, and tap Unlock. That gives you the **Sovereign** preset (your merged look), the Monarch outfits, and later the admin powers (land, rules, banning, world settings).
- **Guests (your son, friends, the SL/OpenSim community).** They install the same APK. On first launch they build their *own* avatar. They never get your look or your Monarch outfits.
- Profiles are saved **on each phone** for now. When multiplayer arrives, accounts move to a server and the owner role is verified there. The current code is only a lock for local testing, not real security.

## Your avatar
- First launch opens **Create Your Avatar**. Choose a name, body type, skin tone, hair color and style, multi-color streaks, eyes, facial hair, jacket, top, pants, glow accent, metal trim, and a crown, chains or horns.
- **DNA blend:** pick 2–3 parent looks (Ember, Frost, Nova, Titan, Sylph), slide how much of each you want, then fine-tune height, build, shoulders, head, jaw, legs and arms.
- **Attachments (like Second Life):** add a halo, crown, wings, cape or scepter to attachment points (head, back, hands…). **Alpha masks** hide body parts under clothing.
- **Your own 3D items:** put a `.glb` file in the phone's Download folder and tap **Import .glb wearable**. It attaches to your avatar and goes into the review queue. Newer Android versions may block apps from reading Download directly; if so, a file picker is coming next.
- **Export avatar file:** saves your whole look (colors, DNA, attachments) as one file you can share or back up.
- You can change it anytime: **MENU › My Avatar & Profile**. Your clothes go in the **BAG** (wardrobe).

## Companions
- Foxy, Aura and Aaliyah walk with you. Tap **TALK** to chat. Right now they answer with offline replies taken from their persona files. With an API key in **Settings › Companion AI** (set to LIVE), they think for real.
- They speak out loud with the phone's voice (turn it off in Settings). The 🎤 button is a placeholder for voice chat.
- **Follow me / Free roam:** in Free roam they live on their own. They explore, gather, build little cairns, travel to landmarks and rest. Ask "what did you do?" and they'll tell you. Tap **All follow** to call them back.
- Planned: each player gets their own companions, and the owner's companions are the world's royal court.

## Realms & landmarks
- There are three realms: Alaskan Aurora Tundra (spawn), Venus Fire Wastes, and Cosmic Glitter Expanse. Each has its own trees, rocks, crystals, lava vents, obsidian spires or floating islands.
- There are seven placeholder landmarks with gold **YOUR INPUT HERE** signs. Visit them with **MENU › Travel**.

## Creator Market (planned; data model ready)
- Creators upload .glb wearables and set permissions (copy / modify / transfer, like Second Life) and a price in **Aethel Coin**. Items are reviewed before they can be sold. 18+ items only show to people who turned on the age gate. A vendor near spawn shows where the shop will be.

## Building (planned v0.6)
- Place and save blocks, shapes and smooth-voxel builds on your land. Companions help build.

## Music (SoundCloud)
- Phoenix Radio near spawn uses **SoundCloud**. By default it plays Phoenix's own SoundCloud music (Anterranian Monarch, set in `data/music.json`).
- **MENU › Music › ▶ Play on SoundCloud** opens the SoundCloud app. Anyone can paste **their own** SoundCloud link there.
- Playing SoundCloud songs *inside* the game needs a SoundCloud Artist Pro API key; otherwise they play in the SoundCloud app.

## v0.6 playable: combat, roleplay, breedables
- **Combat ✔:** the **Ember Arena** in Venus is the only damage-enabled zone (red ring and sign); everywhere else is safe, and the HUD shows ⚔/🛡. You have health plus a regenerating shield. **⚔ swipe** (melee) and **🔥 fire bolt** (magic) buttons. Three **Cinder Stalkers** (original creatures) patrol, chase and bite, then respawn 15 s after defeat. If you die, you respawn at spawn with full health and shield.
- **Roleplay ✔:** a floating **RP titler** (name, title, faction, IC/OOC/AFK), a **character sheet** (🎭 RP), an **IC/OOC** switch in TALK, **/me** emotes, and poses (wave, bow, sit, dance).
- **Breedables ✔:** **Ember Wyrmlings** live in the Wyrmling Nest near spawn. Genes: color, horn and wing, two alleles each, with dominance and a 2% mutation chance; rarity and generation come from those. Feed them, then breed a fed pair (with a cooldown) to hatch an offspring that inherits traits. Saved on the phone.

## Marketplace (web + in-app, like the SL Marketplace) — server phase 0.8+
- Listings with categories, search, filters, reviews from verified buyers, free demo items, stock, and the mature gate.
- **Delivery to inventory:** purchases land in the Satchel's "Received Items", with redelivery from purchase history. A **merchant outbox** holds items for sale.
- **List from inventory:** long-press or tap **List on Marketplace** on a Satchel item. **v0.6 stub ✔:** this saves a local draft listing (`user://ugc/listings.json`).
- One catalog shows up in three places: web store, in-app store panel, and in-world vendors.
- Data model: `data/economy/marketplace_exchange_model.json`.

## Aethel Exchange (like the classic LindeX) — server phase 0.8+
- Buy/sell order book for AEC between users, with market and limit orders, price-time matching, a rate chart (1h/1d/1w) and a small trade fee.
- **⚠ Compliance:** a real-money exchange needs legal and compliance review before launch. That covers money-transmitter licensing (FinCEN MSB plus state licenses in the US), KYC/AML, sanctions, tax reporting and app-store payment rules. Until then AEC is a closed in-game currency with no cash-out.

## Combat, roleplay & breedables (planned)
- **Combat:** only on land where the owner turned damage on (spawn and landmarks stay safe). Melee, fire magic and ranged, with shields, respawn, creatures to fight, and optional RP dice meters.
- **Roleplay:** titlers, character sheets, IC/OOC chat, /me emotes, poses, factions (groups), and RP regions with rules.
- **Breedables:** pets with genetics. Feed them, breed them, and trade them for Aethel Coin. Creators can make new traits.

## Music & voice
- **Phoenix Radio** near spawn plays music while you stand near it, like Second Life parcel music. Put your own station link (MP3/OGG) in Settings. Live endless radio streams are planned next.
- Planned: talk to companions by voice, and voice chat with other players nearby.

## Autonomy & the living world
- Today, companions only live while the app is open. Planned: a server keeps the world running, so companions keep travelling and building while you're away and tell you what happened when you come back.

## Updates
- Install each new APK over the old one, with no uninstall needed. Your avatar, wardrobe and settings stay. Planned: an in-app "update available" button.

## Online / offline
- The world, avatar, wardrobe and offline companion replies all work without internet. Live AI, the radio and (later) multiplayer need internet.

## Where to give your input
- Gold ★ YOUR INPUT HERE tags in the game, plus `docs/WHERE_TO_GIVE_INPUT.md`.

## Welcome Island, helpers and destinations (v0.7)
- On first launch you spawn on **Welcome Island**, a floating orientation island at (640, 90, 640). It has a ring of 10 tutorial stations: move/look, fly, teleport, menus, minimap/map, chat IC/OOC, wardrobe/avatar, building, combat zone rules, getting help. MENU › Welcome Island lets you skip it or come back. Station text lives in `data/welcome/welcome_island.json`.
- **Welcome Guide** and **Help Desk** are original guide bots. They answer FAQs from `data/welcome/help_faq.json` (keyword match) and point you to the matching station. Ask them in MENU › Help.
- The **Destination Guide** (MENU › Destinations) groups places by category with one-tap teleport (`destinations.json`). It includes an **Events board** (`events.json`) with sample events.
- **Radio Club**: an animated light-up dance floor next to Phoenix Radio.
