# Multiplayer — PLAN
- Godot high-level multiplayer: `ENetMultiplayerPeer` (native), `WebSocketMultiplayerPeer`/WebRTC (web). `MultiplayerSpawner` + `MultiplayerSynchronizer` handle players and companions.
- **Topology:** listen-server host (a player hosts) at first. A relay or dedicated headless server comes later. NAT traversal through a relay (e.g. a WebRTC TURN or a small relay VPS). No server exists yet.
- **Voxel sync:** the server is authoritative over edits. Clients send edit requests (RPC). The server validates and broadcasts deltas, using Zylann's VoxelTerrain multiplayer support where available.
- **Permissions:** realm roles are owner / builder / visitor, with per-parcel build rights (Second Life-style). Companions act with their owner's permissions. Admin tools are in ANDROID_ADMIN_TOOLS.md.
- Offline-first: single-player is always available. Joining a session never erases local saves.
