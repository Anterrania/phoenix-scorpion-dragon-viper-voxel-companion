# Foxy spec: Social feed screen (SMP-16)

Owner: Foxy (client). The server is done: `Social.feed(viewer, cursor)` (docs/modules/SOCIAL.md). Scene
path the menu patch expects: `res://scenes/social/feed_screen.tscn` (patches/social_menu_feed_entry.patch).
This spec covers features only. Follow PhoenixTokens and the Glass kit, and use no more than 5 tabs.

**Tabs:** For you · Following · Clips · Explore · Search.
- Each tab keeps its own `next_cursor`. Load more when you're 5 items from the end. Pull to refresh
  calls the mode with `""`.
- Draw `item.thumb_url` straight away, with a placeholder colour taken from `media[i].hash`. Fetch
  `media[i].use_url` only once the item is on screen.
- If `item.prefetch` is false, don't preload the next item's full media.
- In saver mode (`item.variant == "thumb"`), show thumbnails with a "Tap to load" badge. A tap calls
  `Social.media_url(viewer, pid, i)`. Check `Net.large_download_ok(bytes)` before anything big.

**Item card.**
- Show `author_name` and `badges`, plus the text, carousel dots, reactions bar (long-press opens the
  7-reaction picker), and reply, repost/quote, bookmark and share buttons.
- Show the count of replies, `views`, and a context note banner when `notes` isn't empty.
- Mature posts show a tap-through cover (they only arrive when age_ok).

**Actions:**
- `react/unreact`, `repost`, quotes (`post` with `quote_of`), `bookmark(folder)`, `record_view(watch_ms)`
  when the card leaves the screen, `report`, `mute`.
- "Not interested in #tag" calls `set_feed_pref(tag, false, 7)`.

**Profile card** (on an avatar tap, here and in-world):
- Show `profile`, `badges_of`, the pinned post, `highlights`, follow or "Requested" (`follow` returns
  `state`), message (`SocialDM.open_direct`), and mute, restrict, block and report.
- Show the friends or close-friends toggle if you are friends.
