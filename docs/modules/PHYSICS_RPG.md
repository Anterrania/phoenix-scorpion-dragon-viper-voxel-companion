# Physics RPG — PLAN
- Godot 4 physics (Jolt is optional in 4.4+) for CharacterBody3D movement, knockback impulses, and RigidBody3D props.
- Voxel interaction: VoxelTool carve/add drives destructible terrain. Cut-off chunks can become RigidBody debris (budgeted, despawn after N seconds).
- Combat: hitboxes are Area3D. Damage = base × skill multiplier × element vs. resistance. Fire/ice/circuit elements tie into realm biomes.
- Stats affect physics: strength → carry mass, agility → jump impulse, endurance → stamina drain.
- Mobile budget: max ~30 active rigid bodies, 30 Hz physics tick on Android.
