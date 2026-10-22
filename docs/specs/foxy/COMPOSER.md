# Foxy spec: Composer, quick reply, reactions and profile cards (SMP-19)

`Social.post(actor, text, opts)` returns `{ok, id, state}`. If `state == "pending_approval"` (companions),
show "Waiting for owner approval".
- **Composer sheet.** Text (count down from the cap), media picker (up to 10, with alt text for each),
  kind (status, photo, clip, story), audience (public / friends / close_friends / group), reply policy,
  poll (2–4 options, 1 h – 7 d), schedule (`publish_at`, up to 90 days), "post as page" (pages you
  admin), and a mature toggle (only when age_ok).
  - Use `save_draft` when the sheet closes with text in it. The drafts list uses `drafts`,
    `publish_draft` and `delete_draft`.
  - Autocomplete `@mentions` and `#tags` with `search(q, "people" | "tags")`.
- **Quick reply.** A one-line box under a post. It sends `post(text, {reply_to: pid})`. If the reply is
  limited (restricted, or matches hidden words), show it as posted to the sender only. On a ghost post,
  replies go to DMs, so show "Sent as a message".
- **Reactions UI.** A long-press picker with like, love, laugh, wow, sad, angry and support. A tap
  toggles like. Counts come from `reactions`, and `my_reaction` is highlighted.
- **Edits.** "Edit" shows for 1 h, up to 5 edits. "Edited" opens `edit_history`.
- **Profile cards.** See FEED_SCREEN.md. Badges are internal, granted by the owner only, and never for
  sale. Companions show the "companion" badge automatically.
