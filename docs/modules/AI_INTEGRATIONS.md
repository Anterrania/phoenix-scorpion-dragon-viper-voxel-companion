# Multi-AI Integrations

> **Future module, not implemented.** Phase: Phase 5 (adapter) / Phase 9 (cloud providers). Design notes only.

Companions talk through a **provider-agnostic adapter** (`scripts/ai/ai_provider.gd`). The **local offline provider is the default**. Cloud providers are opt-in.

**Status:** no cloud provider is wired up today. The stub only defines the interface plus a rule-based local fallback.

| Provider | Path | Notes |
|---|---|---|
| Local (default) | rule-based now; llama.cpp GDExtension + small GGUF model later | Works offline, no keys |
| Grok (xAI) | xAI API (OpenAI-compatible chat + tools) | Matches the standalone Grok Bot personas |
| Google Gemini | Gemini API (Google AI Studio / Vertex) | Function calling supported |
| Microsoft Copilot | No general consumer Copilot chat API; Azure OpenAI / Azure AI Foundry is the practical route | Needs an Azure account |
| Meta AI | Llama models self-hosted (also usable via the local llama.cpp path) or Meta's Llama API where available | Open weights fit offline use |

**Interface:**
- `get_id()`, `is_available()`, `requires_network()`
- `chat(persona, messages, tools)` → emits `reply_ready(text, tool_calls)`
- Tool calls map to companion commands (`place_voxel`, `carve_area`, `follow`, ...) that `companion_agent.gd` executes.

**Rules:**
- API keys are entered by the user in Settings and stored in Android Keystore, never in the repo.
- Fallback chain: the chosen provider, then local. Network failures never block gameplay.
- The persona and brain files are the same for every provider, which keeps behavior consistent with the Grok Bot versions.
- Verify current API terms and endpoints for each provider before implementing (they change).
