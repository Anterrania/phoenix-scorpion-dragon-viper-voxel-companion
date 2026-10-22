# Foxy spec: Stories tray, viewer and capture (SMP-17)

Data: `Social.stories_tray(viewer)` returns the authors that have live stories, with an unseen flag.
Stories (`kind: "story"`) expire 24 h after they publish.
- The tray sits at the top of the feed. Your own story comes first ("+" adds one). Unseen stories get a
  ring, and close-friends stories get a different ring.
- The viewer is full-screen with progress bars at the top. A photo shows for 5 s; a clip lasts as long
  as the clip. Tap right for the next one, tap left to go back, hold to pause, swipe down to close.
- Call `story_view(viewer, sid)` when a story is shown. For your own stories, swipe up for
  `story_viewers`.
- The reply box sends `SocialDM.post_reply_dm(actor, sid, text)`, and the quick-reaction row does the
  same. If the author turned story replies off, hide it.
- Capture in-world (snapshot or clip): add filters (IMAGE_EDITOR.md), text, stickers and a mention
  (`@id`). Pick an audience (public / friends / close_friends). Post with
  `Social.post(actor, text, {kind: "story", media, visibility})`.
- Highlights: on your own story, "Add to highlight" calls `highlight_add(name, sid)`. Profile cards
  show `highlights(owner, viewer)`.
- Data saver: preload only the next story's thumbnail. Load the full media when it's shown.
