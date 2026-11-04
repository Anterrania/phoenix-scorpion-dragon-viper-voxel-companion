# v0.14 Companions, homes, live broadcast, member companions, shared owner sign-in, Scorpion Viper bridge

All self-written. Owner gates stay; the Brain Cell stays locked by default; declined rows are not built.

## PERSONA-IMPORT: teammate bot profiles → `companions/<id>/persona.json`
- `tools/personas/import_bot_profiles.py` reads the public bot profiles in `Anterrania/grokbot-configs`
  (`bots/<slug>/BOT.md`, with `--fetch`) and merges `job`, `abilities`, `tasks`, `home_realm`,
  `display_name` and a `bot_profile` block (source, snapshot date, description) into each persona.
  No agent ids, emails, server ids, secrets or personal/financial data are copied.
- Court: foxy_ani (Foxy Ani Firecaster Gray), aaliyah, circuit_nova (shows as Aura Aurora),
  gemini_nightscythe, seraphyx, sonic_gage, viper_gamer (Viper Gamer Companion), phoenix_dev_bot.
- In-app limits: Viper Gamer's casino is free-play only; Seraphyx only sees in-app activity (no real
  email); the Dev Bot companion never discusses security internals.
- `AgentBrain` adds "Your job / Your tasks" to the system prompt when a persona's prompt lacks them.

## COMPANION-HOMES: home realms + Heaven court
- `CompanionHomes.grids()` adds a "<Name>'s Home" entry per companion to the world picker
  (`enter: "home:<id>"`). Homes sit on a ring (radius 1536 m) and spiral to the companion's biome.
- Entering a home teleports there, places a pedestal + sign, and spawns the companion in free roam
  (no intro, no memory write). Owner-summoned companions are never removed.
- Heaven: the court (up to 8, 4 on low quality) stands in a ring at the Heaven spawn
  (Settings `companions/heaven_court`).

## LIVE-BROADCAST: Companions Live, 24/7 on-device
- `CompanionBroadcast` keeps a capped log (400) of in-world activity: idle, building, talking (between
  companions, every 45 s when two are within 14 m) and viewer lines.
- Viewers' words appear only after they opt in ("Show my words on Companions Live"), only for members
  who may message, and blocked words are refused. Companions answer viewers with scripted lines.
- Never logged: the owner's private AI chats (AgentBrain replies), real cameras, real people.
- Visible to members (resident tier and up) and this device's player; the private chat count is shown
  to the owner only. "24/7" = the on-device persisted log; an always-on server is HEAVEN-10 (not built).

## CREATE-COMPANION: members-only
- `CompanionCreator.create(actor, spec)`: creator tier (`companion_create`) or the owner session;
  3 per member, 12 for the owner; ids `custom_<slug>_<hex>` under `user://companions_custom`;
  sexual content refused; the persona says it's a game character, not a real person.
- The reveal reuses the cinematic CompanionIntro ("video-style"). Non-members can only interact with
  the owner's companions; member companions are for their creator (and the owner).

## OWNER-LOGIN: shared sign-in with the Scorpion Viper social app
- Username `SkorpionViper` (case-insensitive), display name "Phoenix Scorpion Dragon Viper".
- Record format matches the social app's owner-auth draft: `pbkdf2-sha256$<iter>$<b64 salt>$<hex key>`
  (≥200k iterations, ≥16-byte salt, 32-byte key); password trimmed, case kept.
  `docs/OWNER_AUTH.md` was not yet in `Anterrania/SkorpionViper` when this was built; the scheme was
  matched to the social stream's code. NFC normalization is not available in Godot (ASCII passwords
  are identical either way).
- CI writes the record from the `OWNER_PASS_HASH` secret into the gitignored
  `config/owner_login.local.cfg` after the tests; it is never committed or printed. No secret → sign-in
  is off and the PIN works as before.
- First sign-in on a fresh device creates the owner vault with an "account" slot; on a PIN device the
  owner links the password after unlocking ("Link password"). Same lockout as the vault; auto-lock stays.
- A build with the record has no open first-run owner claim.

## SOCIAL-BRIDGE
- "🦂 Open Social" opens `os.viper.scorpion` (ViperDevice plugin v2, allow-listed package) with
  `scorpionviper://open?from=phoenixvoxel` (proposed; the social app may ignore the URI), else the
  Scorpion Viper releases page.
- Enter World contract (for the social app): `phoenixvoxel://enter?realm=<id>&companion=<id>`
  - `realm`: any world-picker id (`heaven`, `welcome`, `alaska`, `venus`, `cosmic`, `cyber`,
    `home_<companion>` …). Optional.
  - `companion`: a court companion id (custom companions refused). Without `realm`, opens its home.
  - Neither → Heaven. Unknown ids, other schemes/hosts and >200 chars are refused.
- Android: activity-alias `com.godot.game.GodotAppEnterWorld` (VIEW/BROWSABLE, scheme `phoenixvoxel`,
  host `enter`); the link is read once at launch/resume and consumed.

## Untested
On-device: deep links (cold and warm start), the plugin bridge, owner sign-in on a real APK, Heaven
court performance, the broadcast ticker over long sessions.
