# Smartbot-style Automation & In-world Scripting

> **Future module, not implemented.** Phase: Phase 9. Design notes only.

Inspired by Second Life (Smartbots-style group bots, LSL scripting, mesh bodies, third-party viewer features). Original implementation; no SL assets or protocol.
- **Automation bots:** companions or NPCs run scheduled tasks (greeter, builder, shopkeeper, event host) defined in brain `skills/` files.
- **In-world scripting:** a sandboxed script object (a small event-driven DSL, or GDScript run through a restricted interpreter) with events like `on_touch`, `on_timer` and `on_chat`, and an API limited to its own object plus permitted VoxelTool calls. Scripts never get access to files, network or the OS.
- **Mesh bodies:** a rigged base body with attachment points, clothing layers and HUD-like customization. Genes from DNA_GENETICS.md feed in.
- **Viewer-inspired features:** camera controls, build grid/snap, object inspector, chat history, radar of nearby avatars, photo mode, and environment (sky/water) presets.
