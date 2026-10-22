# Foxy spec: vehicles, mounts and driving (SBX-F3)


> 2026-10-22: written before the dev/Foxy split. Ids like SBX-SIM-n point at the inactive reference model in `scripts/sim/` (Foxy owns those features now). Dev-side APIs: QuestEngine (SBX-2), WorldHost (SBX-3), MarketDelivery (SBX-5), FreePlay (SBX-7).
Owner: **Foxy** (client physics, controls, camera). Dev owns the server record (ownership, garage,
recovery) as a follow-up ticket once the client exists. Concepts from open-world games, our own design.

## Abilities
- Enter / exit a vehicle or mount from any side; seats for driver + passengers (companions can ride).
- Classes: ground (wheeled), hover, boat, flyer, mount (creature). One shared controller with per-class
  tuning (top speed, accel, turn, lift).
- Phone controls: left thumb steer/throttle, right thumb camera, brake and boost buttons; tilt steering
  optional. Auto-centre camera behind the vehicle.
- Ownership: spawn your own vehicles from a garage list; recover a lost one to the nearest landmark.
- Land rules: `Tiers.can(actor, "enter", parcel)` before crossing into a parcel; no spawning where
  `allow_build` is off unless owner/staff. Flying vehicles respect `allow_fly`.
- Collisions with players never deal damage unless the region has `allow_damage` (and then PvE only).
- Radio in vehicles: see `sbx_radio_playback.md`.
- E-stop: companion drivers stop and exit when `AutonomyGuard.paused()`.

## Performance
Physics tick 30 Hz on Android, simplified wheel raycasts, no per-frame allocations, LOD the vehicle mesh.
