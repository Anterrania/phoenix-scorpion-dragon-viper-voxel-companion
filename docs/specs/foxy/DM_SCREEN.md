# Foxy spec: Messages (encrypted DMs) (SMP-20)

Server: `SocialDM` (docs/modules/SOCIAL.md). Messages are sealed at rest once the owner vault exists;
before that they stay in memory only.
- **Inbox tabs:** Chats (`conversations("inbox")`), Requests (`conversations("requests")`, with Accept /
  Decline) and Hidden (`conversations("hidden")`, for messages filtered by hidden words).
- **Chat.** Bubbles, reply-to, reactions (`react`), and Unsend and Edit (15 min) on your own messages.
  Read receipts (`receipts`, only if both sides have them on).
- **Disappearing messages.** Off, 5 min, 1 h, 24 h or 7 d (`set_disappearing`). In groups only admins
  can change it. Show a timer icon in the header.
- **Groups.** Create (up to 32), add, remove, admin, rename, leave and mute.
- **Shared posts.** `share_post` cards open the post if you can see it.
- **Report** on a long-press calls `report_message`. Tell the user that only that one message goes to
  moderators.
- Notifications never include message text (the server already leaves it out).
