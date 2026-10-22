# Foxy spec: radio stations and playback UI (SBX-F10)


> 2026-10-22: written before the dev/Foxy split. Ids like SBX-SIM-n point at the inactive reference model in `scripts/sim/` (Foxy owns those features now). Dev-side APIs: QuestEngine (SBX-2), WorldHost (SBX-3), MarketDelivery (SBX-5), FreePlay (SBX-7).
Owner: **Foxy**. Dev side exists: `MusicRadio`, `SoundCloudSource`, parcel `music_url` in `Estate`.

## Abilities
- Station list: parcel stream, owner playlists, SoundCloud sources, AI music from EveCore (`create_music`).
- Skip station / skip track, volume, mute, "radio off in vehicles" setting.
- Auto-switch to the parcel stream on entering a parcel with `music_url`; restore your station on leaving.
- Now-playing line (title, source). No lyrics display unless the source provides them.
- Vehicle radio uses the same player (see `sbx_vehicles_driving.md`).
- DJ / event mode: estate managers can push a station to everyone on the parcel (`Tiers.can(actor, "land", parcel)`).

## Limits
Streams only over https; one decoder at a time on Android; pause when the app is backgrounded.
