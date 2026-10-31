# Social-media parity (TikTok, X, Threads, Instagram, Facebook)

Status: SMP-1..25, branch feature/social-media-parity (2026-10-22). Owners: us (server side, admin, wiki)
and Foxy (client UI). API reference: docs/modules/SOCIAL.md, section "Social-media parity API".

**Rules.** This doc covers features and abilities only, not design. Everything is our own wording and
our own code (Godot APIs only, with no big dependencies). We copy no code, assets, names-in-UI or
trademarks; the platform names here only label where an idea came from. Nothing in this branch posts to
any real platform.

**Columns.** `source | feature | Viper status | owner | tracker id`. Viper status values:
- have: built and tested headless
- partial
- Foxy: the server is done and the client is in Foxy's spec
- planned
- won't

**Sources (web research, 2026-10-17).**
- Public help-centre pages and press coverage for each platform.
- Threads: ghost posts, topic controls ("less/more of" for 1, 3 or 7 days), communities with flair,
  DM requests, long text attachments, spoilers.
- Instagram: highlights, close friends, story viewer lists, reposts, notes, "use as reference".
- TikTok: duet and stitch toggles per post, footnotes, shared collections, creator analytics, sounds.
- X: community notes (a bridging algorithm), bookmark folders, lists, encrypted chat with disappearing
  messages and edit/unsend. X Communities were shut down in 2026, so they are listed as "—".
- Facebook: pages, groups (rules, admins, join questions), events and RSVP, reactions, Messenger.
  Marketplace needs LEGAL REVIEW.
- Where we couldn't confirm a detail, we built the generic concept.

## Cross-platform features

| source | feature | Viper status | owner | tracker id |
|---|---|---|---|---|
| all | Text, photo and carousel posts (up to 10) with alt text | have | dev | SMP-6 |
| TikTok, Instagram | Short vertical clips (`kind: "clip"`, up to 600 s) | have (server) / Foxy (player) | dev / Foxy | SMP-1, SMP-16 |
| Instagram, Facebook | Stories (`kind: "story"`, 24 h), tray, viewer list, archive | have (server) / Foxy (viewer) | dev / Foxy | SMP-3, SMP-17 |
| Instagram | Story highlights on the profile | have | dev | SMP-3 |
| Instagram, Threads | Story and ghost-post replies go to DMs | have | dev | SMP-3 |
| Threads | Ghost posts (24 h, replies to DMs) | have | dev | SMP-1 |
| all | Ranked "For you" feed + Following + Latest | have | dev | SMP-2 |
| all | Paged feed `Social.feed(viewer, cursor)` with a snapshot cursor | have | dev | SMP-1 |
| all | Thumbnails first, lazy full media, data-saver budgets (Net) | have | dev | SMP-2 |
| TikTok | Vertical swipe player, autoplay rules | Foxy | Foxy | SMP-16 |
| TikTok | Original sounds, "use this sound", sound feed | have | dev | SMP-4 |
| TikTok | Duet / stitch (5 s) / remix + per-post allow toggle | have (links) / Foxy (recording) | dev / Foxy | SMP-4 |
| X, Threads | Threads, reply controls (everyone / following / mentioned / nobody) | have | dev | SMP-5 |
| X, Threads | Quote posts, reposts | have | dev | SMP-5 |
| Facebook | Reactions (7 kinds) | have (server) / Foxy (picker) | dev / Foxy | SMP-5, SMP-19 |
| X | Bookmarks with folders | have | dev | SMP-5 |
| TikTok | Views, watch time | have | dev | SMP-5 |
| X, Threads, Facebook | Polls (2–4 options, up to 7 days, private voters) | have | dev | SMP-6 |
| X, Instagram | Drafts and scheduled posts | have | dev | SMP-6 |
| X, Threads | Edit window (1 h, up to 5 edits, visible history) | have | dev | SMP-6 |
| X, Instagram | Pinned post | have | dev | SMP-6 |
| X | Lists (public / private) + list feed | have | dev | SMP-9 |
| all | Hashtags, hashtag feed, search, trending (counts distinct authors) | have | dev | SMP-9 |
| TikTok, Instagram | Explore | have | dev | SMP-9 |
| Threads | Topic controls ("more / less of", 1 / 3 / 7 days) | have | dev | SMP-7 |
| Instagram, X | Private accounts + follow requests | have | dev | SMP-7 |
| all | Mute, block, restrict, hidden words | have | dev | SMP-7 |
| Instagram | Close friends audience | have | dev | SMP-7 |
| Facebook | Pages (admins, post as the page) | have | dev | SMP-8 |
| Facebook | Events: RSVP, capacity, group or page hosts | have | dev | SMP-8 |
| Facebook | Groups: rules, join requests, admin removes posts, mature groups | have | dev | SMP-8 |
| X, TikTok | Community / context notes with bridging ratings | have | dev | SMP-10 |
| Instagram, TikTok, X | Creator analytics, per-post insights | have | dev | SMP-15 |
| all | Encrypted DMs, requests folder, group chats (up to 32) | have (server) / Foxy (screen) | dev / Foxy | SMP-11, SMP-20 |
| X, Instagram | Disappearing messages, unsend, edit (15 min), receipts, reactions | have | dev | SMP-11 |
| all | Report a post / account / DM; moderator queue | have | dev | SMP-12 |
| all | Mature labels + age gating | have | dev | SMP-13 |
| Instagram | Upload validation, metadata (GPS) strip, resize and compress | have | dev | SMP-14 |
| Instagram, TikTok | Filters, adjustments, LUTs, crop, text, stickers | Foxy (spec) | Foxy | SMP-18 |
| all | Composer, quick reply, profile cards | Foxy (spec) | Foxy | SMP-19 |
| Instagram | Notes (short status on the DM list) | planned | dev | SMP-25 |
| Threads | Long text attachments (10k) and spoiler blur | planned | dev | SMP-25 |
| TikTok, Instagram, Facebook | Live video + live chat | planned | dev | SMP-23 |
| Facebook, TikTok, Instagram | Shops / Marketplace | planned (LEGAL REVIEW, Aethel Coin) | dev | SMP-24 |
| all | Multi-device sync, push notifications, server clip transcoding | planned | dev | SMP-25 |
| all | Cross-post export to real platforms | planned, off by default (stub) | dev | SMP-22 |
| X | Communities | — (shut down by the source) | — | — |
| all | Paid verification badges | won't (badges are internal and owner-granted, never sold) | — | — |

## Per platform (summary)
- **TikTok.** We have clips, sounds, remix links, the ranked clips feed, views and analytics. Foxy owns
  the swipe player, recording and duet layout. Live video is planned.
- **X.** We have threads, quotes, reposts, bookmarks with folders, lists, context notes, edit history,
  polls, scheduling and encrypted DMs.
- **Threads.** We have ghost posts, topic controls, reply controls, hidden words and DM requests. Long
  text attachments (10k) are planned (SMP-25); posts are capped at 2,000 characters.
- **Instagram.** We have the image pipeline (headless), carousels with alt text, stories, highlights,
  close friends, restrict and explore. Foxy owns the filters and editor (spec).
- **Facebook.** We have pages, groups with rules and join requests, events with RSVP, reactions and
  Messenger-style group DMs. Marketplace is LEGAL REVIEW.

## Export / cross-post adapter plan (SMP-22, future, OFF by default)
- `Social.cross_post(actor, pid, network)` exists today only as an **INACTIVE** stub. It needs the
  `admin` tier and returns `INACTIVE`.
- When built, each network gets an adapter behind the Settings switch "Allow cross-posting". That
  switch is off by default and only the unlocked owner can change it.
- **Owner approval for every post.**
  - Every outbound cross-post becomes an `EveCore.propose_update` proposal.
  - The owner sees the exact text and media that will leave the device.
  - Nothing goes out without that approval.
  - When the owner is locked, they count as Guest, so nothing can be approved.
  - The e-stop (`AutonomyGuard`) blocks every adapter.
- **Gemini Nightscythe** posts publicly and is a companion account. Gemini's posts already need owner
  approval inside Viper OS, and an outbound cross-post keeps that same owner approval step.
  - Gemini can't approve their own cross-posts.
  - Gemini can't change the switch.
- Adapters strip metadata (`MediaTools.strip_metadata`) and never include security internals (vault,
  tiers, e-stop, file paths), personal or financial info, mature posts, DMs, or friends-only, close
  friends or group content. Only `public` posts can be exported.
- Credentials for any network go in OwnerVault (sealed), never in the repo or in settings files.
- Rate limits and an audit entry (`modlog`) are written for every export attempt.

## Moderation and safety summary
- Reports: one open report per reporter per target. Three distinct reporters auto-hold a post.
- A moderator decision closes every open report on that target and is written to `modlog`.
- DM reports carry only the reported message.
- Age gating: see SOCIAL.md "Age gating". Mature content stays out of search, trending and explore for
  anyone who isn't age_ok.
