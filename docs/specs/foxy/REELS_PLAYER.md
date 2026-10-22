# Foxy spec: Clips player, vertical swipe (SMP-16)

Data: `Social.feed(viewer, "clips")`, `sound:<sid>` and `author:<id>`. Items have `kind == "clip"`, with
`media[0]` as `{type: "video", duration_s, kbps, use_url, thumb_url}`.
- One clip per screen. Swipe up for the next one and down for the previous one.
- Show the poster (`thumb_url`) until the first frame decodes.
- Autoplay only when `item.autoplay` is true (it's false in Net saver mode). In saver mode, tap to play.
- Stream at most `media[0].kbps` (Net.media_kbps("video")). Pause when the app is in the background.
  Loop.
- Side rail: react (double-tap = like), replies sheet (`Social.thread`), repost, bookmark, share to DM
  (`SocialDM.share_post`). The sound chip opens the `sound:<sid>` feed ("Use this sound" opens the
  composer with `sound: {id}`).
- Remix (only when the source allows it, `allow_remix`):
  - Duet: side by side.
  - Stitch: the first 5 s of the source, then yours.
  - Both post with `remix_of: {pid, mode}`.
- `record_view(viewer, pid, watch_ms)` when the user leaves a clip.
- Record and trim in-world (snapshot/clip capture): max 600 s; set `media.duration_s` and
  `thumb_ref` from the first frame. Captured images go through `MediaTools.process_upload` before
  posting.
