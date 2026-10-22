---
title: Messages
slug: messages
tags: [messages, dm, chat, encrypted, privacy, disappearing]
audience: all
status: partial
updated: 2026-10-22
sources: [scripts/social/social_dm.gd, docs/modules/SOCIAL.md]
ticket: SMP-11
---

# Messages

> **Partial.** Built and tested headless. The chat screen is coming in Foxy's update.

- Private chats and group chats (up to 32 people). They are **encrypted on this phone** once the owner
  has set up the vault. Before that, messages are never written to storage.
- Messages from people you don't know go to **Requests**. Messages with your hidden words go to
  **Hidden**.
- Unsend, edit within 15 minutes, react, and read receipts (only if you both have them on).
- **Disappearing messages:** off, 5 min, 1 hour, 24 hours or 7 days.
- Story replies arrive here.
- Report a message: only that one message goes to the moderators, never the whole chat.

See also: [Social Media](social-media.md) · [How Your Saves Are Protected](encryption.md)
