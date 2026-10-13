# Social Hooks

> **Future module, not implemented.** Phase: Phase 9. Design notes only.

Share screenshots, clips and progress to X, Facebook, Threads, Instagram and YouTube **only via official APIs or the OS share sheet**, and **only after the user approves each post**.
- **Default:** Android share intent. The user picks the app and edits the text, and nothing posts automatically.
- **Optional direct posting:** OAuth through each platform's official API (X API, Meta Graph API for Facebook/Instagram/Threads, YouTube Data API). Tokens are stored in Android Keystore. A preview + confirm dialog appears every time.
- Companions can suggest post text, but never post on their own.
- No scraping, no unofficial clients, no private info in posts.
- See also: [AI_INTEGRATIONS.md](AI_INTEGRATIONS.md) for multi-AI provider hooks.
