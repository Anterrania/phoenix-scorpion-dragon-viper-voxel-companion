# AI Integrations & Data Import

> **Planned module, not implemented.** Phase 5 (local AI + importer UI) / Phase 9 (Grok online). No live connections exist.

## Reasoning backends (only these two), via `scripts/ai/ai_provider.gd`
| Backend | Role | Status |
|---|---|---|
| **Local (default)** | Offline. Rule-based now; llama.cpp GDExtension + small GGUF later | Keyword fallback stub |
| **Grok (xAI API)** | Optional online reasoning, matching the standalone Grok Bot personas | Stub only |
Fallback: Grok → Local. Gameplay never blocks on the network.

## Data import hooks (NOT backends), via `scripts/ai/data_importer.gd`
Microsoft Copilot, Google Gemini and Meta AI are used **only to bring the user's own existing info into companion memory**. They never generate replies or make decisions in Phoenix.
| Source | Planned input |
|---|---|
| Microsoft Copilot | The user's exported data (Microsoft privacy dashboard export) |
| Google Gemini | Google Takeout export of Gemini activity |
| Meta AI | Meta "Download your information" export |
| Generic | Any text/JSON file the user picks |

**Flow:** the user opts in → picks an export file → it's parsed into candidate facts → **preview** with accept/reject per item → accepted facts go into the chosen companion's `brain/memory/facts.jsonl`, tagged with `source`.

**Rules:** explicit consent every time, on-device processing, nothing uploaded, no scraping or credential collection. Use official exports (or official APIs later, only with user authorization). Verify export formats before writing parsers. Imported facts can be removed by source.
