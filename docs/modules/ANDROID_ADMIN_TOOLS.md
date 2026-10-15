# Android Admin / Dev Tools

> **Planned module, not implemented. No live servers or services exist.** Phase: 4–5.

In-app tools for the developer and owner, hidden behind a developer-mode toggle (e.g. tap the version 7 times + confirm).
- **Debug overlay:** FPS, draw calls, loaded chunks, voxel task queue, memory, companion states.
- **Console:** run whitelisted commands (`tp`, `realm <id>`, `give`, `companion <id> <cmd>`, `regen`). No arbitrary code.
- **Data tools:** export/import backup, clear the world cache, reset needs and relationships, view and edit brain files (with a confirm step).
- **AI tools:** switch Local/Grok, test prompt, see token timing, kill switch for companion tool execution.
- **Logs:** a rotating log file in `user://logs`, shareable through the share sheet.
- **Desktop side:** `adb logcat -s godot`, `adb install -r`, and remote debug over Wi-Fi from the Godot editor.
