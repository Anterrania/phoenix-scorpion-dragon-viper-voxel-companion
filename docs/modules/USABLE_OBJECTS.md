# Usable Objects

> **Future module, not implemented.** Phase: Phase 6. Design notes only.

- An `Interactable` component with `get_actions(user) -> Array` and `use(user, action)`.
- Objects advertise which needs they satisfy, so companion utility AI can find them (Sims "smart objects").
- Examples: bed (sleep), couch (sit/cuddle, comfort), stove (cook), fridge (food), shower, dance floor, forge (craft), terminal (open MobiGlass), seat in a vehicle.
- Animation sockets: sit/lie/use positions defined as Marker3D children.
- Objects are placed as VoxelInstancer instances or regular scenes on top of voxels. Ownership and permissions follow the city/land rules.
