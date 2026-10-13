# Relationships

> **Future module, not implemented.** Phase: Phase 6. Design notes only.

Inspired by Seed-like colonist moods and life-sim relationships.
- **Mood:** a valence/arousal pair plus tags (happy, lonely, inspired, irritated), driven by needs, events and conversation sentiment.
- **Affinity** from -100 to 100 per pair (player↔companion and companion↔companion). Interactions add or subtract based on personality traits.
- **Personality drift:** repeated kind or playful interactions slowly nudge trait weights (warmth, playfulness, confidence). The core persona.json stays fixed and drift is saved as a delta layer in memory.
- **Relationship stages:** acquaintance → friend → close friend → partner → married. Thresholds sit on affinity, time spent together and shared milestones. Relationships can also cool down and end (breakups/divorce) after sustained low affinity or by choice.
- **Player consent/opt-in:** romance is off by default. The player turns it on per companion in Settings, and companions ask before moving to a new stage. The player can decline or end things at any time without penalty. Content stays respectful (no explicit content). Companions never pressure, guilt or manipulate the player.
- Companion↔companion relationships run in the background and appear in a social feed.
- Marriage: a ceremony event, shared home, and a combined memory section.
