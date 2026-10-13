# Physics RPG — PLAN
- Godot 4 physics (Jolt is optional in 4.4+) for CharacterBody3D movement, knockback impulses, and RigidBody3D props.
- Voxel interaction: VoxelTool carve/add drives destructible terrain. Cut-off chunks can become RigidBody debris (budgeted, despawn after N seconds).
- Combat: hitboxes are Area3D. Damage = base × skill multiplier × element vs. resistance. Fire/ice/circuit elements tie into realm biomes.
- Stats affect physics: strength → carry mass, agility → jump impulse, endurance → stamina drain.
- Mobile budget: max ~30 active rigid bodies, 30 Hz physics tick on Android.

## Drivable vehicles (plan)
- `VehicleBody3D` + 4× `VehicleWheel3D`. Tune `engine_force`, `brake`, `steering`, suspension stiffness, and friction slip per vehicle (data/items/vehicles.json).
- The first vehicle is the royal SUV (black/gold, magenta underglow). Enter/exit with a seat swap: the player's CharacterBody3D is parented to a seat and the camera switches to a chase cam.
- Voxel terrain: rely on VoxelTerrain mesh collision. Watch for wheels snagging on blocky steps (smooth terrain or ramp voxels help). Vehicles don't destroy voxels.
- Mobile: on-screen throttle/brake/steer, max 2-3 active vehicles, 60 Hz physics only for the occupied vehicle.
