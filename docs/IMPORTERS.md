# Importers: Meta AI, Gemini, Copilot (import-only)
**Our own AI stays primary.** Foxy Ani Firecaster Grey, Circuit Nova, Aaliyah, and the voxel world reason only through LocalProvider and GrokProvider (`scripts/ai/ai_provider.gd`).

Meta AI, Gemini, and Copilot are **data sources only**. They're used to bring in information Anterranian already put on those platforms. They are never used as the main AI or to generate replies.

| Source | Input (user-exported file) | Status |
|---|---|---|
| Meta AI | Meta "Download your information" export (JSON) | scaffolded in `scripts/ai/data_importer.gd` (`Source.META_AI`), not yet run |
| Gemini | Google Takeout → Gemini Apps activity | scaffolded (`Source.GEMINI`), not yet run |
| Copilot | Microsoft privacy dashboard export | scaffolded (`Source.COPILOT`), not yet run |

Flow: user exports file → explicit consent → preview → accept/reject each item → write into `companions/<dir>/memory_export.json` (dir via `companions/registry.json`). Works offline. No live API calls.
