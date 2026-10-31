# Social (community platform, Dolphin-style concepts)

> **Status: partial.** Profiles, picks, friends, followers, blocks, private messages + offline
> queue, groups (roles, notices, land), activity feed, companion post approval, notifications,
> reports + moderation queue and the tier system are **built and headless-tested** (local, on the
> phone). Everything else below is **roadmap** and returns `INACTIVE` from the same API.
> Not yet tested on a phone. No servers exist.

Code: `scripts/social/social.gd` (API + LocalServices store), `scripts/security/tiers.gd` (tiers +
permissions), `scripts/admin/community_screen.gd` (Admin › Community). Tests: `tests/social_tests.gd`.
Older notes: [COMMUNITY_PLATFORM.md](COMMUNITY_PLATFORM.md). Wiki: [community](../wiki/community.md), [tiers](../wiki/tiers.md).

## Clean-room and licence note
- Phoenix asked for Boonex Dolphin (Dolphin Pro / ProMax) features. We use the **ideas only**:
  feature names that are common across social platforms (profiles, friends, mail, groups...).
- **No Boonex code, assets, templates, language files, database schema or PHP** are copied,
  ported or bundled, and there is no Dolphin server. All code here is our own GDScript.
- Why: Dolphin shipped under BoonEx's own licence terms (link-back/branding requirements, paid
  licences to remove them, terms that changed between versions). That does not fit an app that
  ships its own code, so we treat it as **incompatible** and write everything clean-room.
  This is not legal advice; the Business Setup / Law bots should confirm before any public launch.
- No Phoenix-specific Dolphin Pro/ProMax files (configs, custom modules, exports) were found on the
  dev box. If Phoenix has them, add them as reference only, outside the repo if they hold personal data.

## Architecture
- **LocalServices (now):** one store on the phone, `user://social/social.json` (+ `roles.json`),
  written through `SecureFile`, so it is **AES-256 encrypted** as soon as an OwnerVault exists, like
  every other save. Locked + sealed: reads return nothing and writes are refused (never clobbered).
- **Grid service (later):** the same `Social.*` API backed by a grid "Social" service
  (see [ARCHITECTURE_AURORA_MODEL.md](../ARCHITECTURE_AURORA_MODEL.md)). Callers don't change.
- **Every action checks `Tiers.can(actor, action, target)`.** Owner powers also need
  `Profile.is_owner()` (unlocked owner session). A locked owner acts as a Guest.
- **Blocks always apply**, both ways: no requests, messages, follows, profile views or feed items.
- **Companions are members**, but their public posts go to the **owner approval queue**
  (`EveCore.propose_update` → MENU › Proposals). Unapproved posts never show. E-stop stops them posting.
- Text is plain: trimmed, length-capped, BBCode brackets neutralised.

## Tier rules (summary)
| Tier | Social powers |
|---|---|
| Guest | Browse, report |
| Resident | + post, message, friends, follow, join groups, edit own profile |
| Premium / Creator | + albums, classifieds, uploads, marketplace, create groups / events / polls, broadcast (parcel media rights; MEDIA_BROADCAST.md) |
| Builder / Staff (bots, employees) | + moderate |
| Estate Manager | + land / estate settings, assign group land |
| Owner (unlocked) | Everything, incl. admin + role editor |
Full matrix: [tiers wiki page](../wiki/tiers.md).

## Feature map
| Dolphin concept | Becomes in Viper OS | Lives | Tie-ins | Privacy / moderation | Status |
|---|---|---|---|---|---|
| Profiles + profile fields | Profile linked to the avatar: name, about, interests, **Picks tab** (SL-style favourite places) | LocalServices → grid | avatar (`avatar_ref`), regions/parcels in picks, tier label, groups | own profile only; **owner profile = owner only**; blocked viewers see nothing; reports can clear "about" | **merge now** |
| Friends / connections | Friends (request / accept / remove) + **followers** | LocalServices → grid | notifications, feed "friends" visibility | blocks remove friendship + follows | **merge now** |
| Mail / messaging | Private messages, local inbox, **offline IM queue** | LocalServices; queue drains to grid later | notifications, Foxy's IM toasts | blocks stop both ways; 1000-char cap | **merge now** |
| Groups | Groups with roles (owner / officer / member), notices, invites, **group land** | LocalServices → grid | `Estate`: parcel → `group_only` access, terraform `group`; Foxy's group tags over avatars | officers post notices; only owner/estate manager assigns land | **merge now** |
| Activity / timeline feed | Feed: status, snapshot, build posts; public / friends / group | LocalServices → grid | companions' posts via owner approval | hide via moderation; blocks filter | **merge now** |
| Moderation / reports | Report anything; moderation queue in **Admin › Community › Reports** | LocalServices → grid | tiers (staff+) | staff can't touch the owner profile | **merge now** |
| Membership levels | **Tiers** (6 levels) + membership hooks | LocalServices → grid | build tools (`Tiers.can(actor, "build", parcel)`), estate | owner-only role editor; nobody else can become Owner | **merge now** |
| Notifications | Per-member notification list | LocalServices → grid push | Foxy's toasts | system/staff only for broadcast | **merge now** |
| Events | Events, **merged with the events board** | grid | popular places, regions, groups | staff review | roadmap (INACTIVE stub) |
| Polls | Polls in groups / feed | grid | groups | one vote per member | roadmap (INACTIVE stub) |
| Forums | Forums with topics + replies | grid | groups, wiki | moderation queue | roadmap (INACTIVE stub) |
| Blogs | Blog tab on profiles | grid | profile | moderation queue | roadmap (INACTIVE stub) |
| Photos / media | Photo + video albums, **in-world snapshots** | grid media store | Foxy's snapshot button, feed | uploads only by user action; review queue | roadmap (INACTIVE stub) |
| Marketplace / ads | **Classifieds tied to the ad slots** / carousels; Aethel Coin pricing | grid | economy, land info | **LEGAL REVIEW REQUIRED** before any coin pricing or real-money tie | roadmap (INACTIVE stub) |
| Points | Reputation points | grid | tiers, economy | anti-farming limits | roadmap (no stub yet) |

### What merges now vs roadmap
| Merge now (built, tested) | Roadmap (INACTIVE) |
|---|---|
| Profiles + picks | Events (+ events board) |
| Friends + followers + blocks | Polls |
| Private messages + offline queue | Forums |
| Groups: roles, invites, notices, land | Blogs |
| Activity feed + companion approval | Photo / video albums, snapshots |
| Notifications | Classifieds / marketplace (legal review) |
| Reports + moderation queue | Points / reputation |
| Tiers + role editor + membership hooks | Grid sync, multi-device identity |

## Public API (for Foxy's in-world side)
All return `Dictionary {"ok", "error", ...}` unless noted. `actor` = `"self"`, an id, or `{"id", "tier"}`.
```
Tiers.can(actor, action: String, target = null) -> bool
Tiers.tier_of(actor) -> String            Tiers.label(tier) -> String
Social.profile(id, viewer = null) -> Dictionary      # {} if missing or blocked
Social.set_profile(actor, id, fields) / add_pick(actor, id, pick) / remove_pick(actor, id, i)
Social.post(actor, text, opts = {}) -> {ok, id, state}  # state "published" | "pending_approval"
Social.feed(viewer, limit: int = 20, author = "") -> Array   # legacy, newest first (see "Feed API" below)
Social.feed(viewer, cursor: String) -> {ok, error, items, next_cursor, mode}
Social.groups_of(id) -> Array[{id, name, role, tag}]   Social.group(gid) -> Dictionary
Social.group_create / group_join / group_invite / group_leave / group_set_role / group_notice / group_claim_land
Social.friend_request / friend_accept / friend_remove / friends_of(id) / friend_requests(id)
Social.follow / unfollow / followers_of(id)    Social.block / unblock / is_blocked(a, b)
Social.send_message(actor, to, text) -> {ok, id, state}  # "delivered" | "queued"
Social.inbox(actor, unread_only = false) / outbox(actor) / mark_read(actor, id) / flush_outbox()
Social.notify(actor, to, kind, text) / notifications(actor, unread_only = true) / notifications_clear(actor)
Social.report(actor, kind, target_id, reason)    Social.reports(actor) / moderate(actor, report_id, "hide"|"dismiss")
INACTIVE: forum_post, blog_post, album_add, classified_post, cross_post (events + polls are live since SMP)
```

## Social-media parity API (SMP, 2026-10-22)
Full inventory and plan: docs/modules/SOCIAL_MEDIA_PARITY.md. Client specs: docs/specs/foxy/.

### Post kinds
`Social.post(actor, text, opts)`, with `opts.kind` one of
`"status" | "snapshot" | "build" | "photo" | "clip" | "story" | "repost"`.
- **`"clip"`**: a short vertical video. Needs `media: [{ref, type: "video", duration_s, thumb_ref}]`
  and at most 600 s. Optional `sound: {id}` to reuse a sound, or `{title}` to create an original
  sound. `allow_remix` (default true). `remix_of: {pid, mode: "duet"|"stitch"|"remix"}`; a stitch
  uses at most 5 s of the source.
- **`"story"`**: expires **24 h** after it publishes (`expires_at = t + 86400`). It never shows in feeds,
  only in `stories_tray(viewer)`. Viewers are recorded by `story_view`, and `story_viewers` is visible
  to the author only. Replies go to DMs (`SocialDM.post_reply_dm`). `highlight: "name"` keeps it on
  the profile after expiry.
- Common opts: `media` (a carousel of up to 10 items, each `{ref, alt, type, w, h, thumb_ref}`),
  `visibility` (`public | friends | close_friends | group:<gid>`), `reply_to`, `reply_policy`,
  `quote_of`, `poll`, `mature`, `ghost` (24 h), `publish_at` (scheduled), `as_page`.
- Companion (bot) posts always return `state: "pending_approval"`. They go through
  `EveCore.propose_update` and appear only after the owner approves them.

### Feed API: `Social.feed(viewer, cursor)`
```
Social.feed(viewer, "")              -> first page of "for_you"
Social.feed(viewer, "following")     -> first page of a mode
Social.feed(viewer, page.next_cursor)-> the next page
=> {ok: bool, error: String, items: Array[Dictionary], next_cursor: String ("" = end), mode: String}
```
- Modes: `for_you`, `following`, `latest`, `explore`, `clips`, `list:<id>`, `tag:<tag>`,
  `author:<id>`, `group:<gid>`, `sound:<sid>`. A guest asking for `following` gets `latest`.
- Treat the cursor as an opaque string (`mode|at|offset|maxseq`). Pages are a **snapshot**: posts made
  after page one never shift or repeat items. Start again from `""` to refresh.
- Each item is a decorated post: `id, author, author_name, badges, kind, text, t, tags, media,
  reactions{kind: n}, likes, my_reaction, reposts, reposted, replies, views, bookmarked, poll, original,
  notes`.
- **Thumbnails first.** Every item has a top-level `thumb_url`. Each media entry has `thumb_url, low_url,
  full_url, use_url, hash, lazy: true, max_px, thumb_px` and, for video, `kbps`. Draw `thumb_url` first.
  Fetch `use_url` only when the item is on screen, or call `Social.media_url(viewer, pid, i)` when the
  user opens it.
- **Net data mode guard.** Budgets come from `Net` (scripts/system/net.gd, set by AutoConfig from
  PowerData):
  - `full`: full variant, autoplay, `prefetch: true`.
  - `normal`: low variant, autoplay, no prefetch.
  - `saver`: `variant: "thumb"`, `use_url` = thumbnail, `autoplay: false`. Opening an item streams the
    low variant.
  - `max_px`/`thumb_px` come from `Net.image_px`, and `kbps` comes from `Net.media_kbps("video")`.
- Ranked modes (`for_you`, `explore`, `clips`) score posts by follows, engagement, recency (6 h
  half-life) and topic preferences (`set_feed_pref`). No more than 2 posts in a row come from one author.

### Other server APIs (all `{ok, error, ...}`)
`react/unreact` (like, love, laugh, wow, sad, angry, support), `repost/unrepost`, `bookmark(folder)`,
`thread`, `edit_post` (1 h, up to 5 edits, with history), `pin_post`, `poll_create/poll_vote/poll_results`,
`save_draft/publish_draft`, `list_*`, `stories_tray/story_view/story_viewers/highlight_*`,
`page_create` (Creator+), `event_create/event_rsvp/event_cancel/events`, `search(q, kind)`,
`trending` (counts distinct authors), `note_add/note_rate/context_notes` (bridging context notes),
`analytics/post_insights`, `sound/sounds_top/remixes_of`, `mute/restrict/close_friends_*`,
`set_privacy`, `set_hidden_words`, `follow_requests/follow_approve`, `age_ok`,
`moderation_queue/moderate(hide|mature|restore|dismiss)/modlog`.

**Encrypted DMs: `SocialDM`.** Stored in `user://social/dm.json` through SecureFile, sealed once the
owner vault exists. Before that, DMs are kept in memory only and never written to disk.
`open_direct, group_create (up to 32), send, messages, conversations(inbox|requests|hidden), accept_request,
receipts, react, unsend, edit (15 min), set_disappearing (5 min / 1 h / 24 h / 7 d), share_post,
report_message` (the moderator sees only that one message).

**Images: `MediaTools`.** Godot Image only, no dependencies. `validate` checks magic bytes and header
size before decoding, with caps of 12 MB and 8192 px. `strip_metadata` removes EXIF/GPS/XMP/text
losslessly from JPEG, PNG and WebP. `process_upload` handles EXIF rotation, then writes WebP files at
1440 px (full), 640 px (low) and a 320 px square thumbnail, sized to the Net budgets. Filters and
editing are Foxy's (docs/specs/foxy/IMAGE_EDITOR.md).

**Age gating.** `age_ok(viewer)` is true for:
- the unlocked owner;
- this device's player, with Settings `mature_enabled()`, or with the Restrictions self-confirmed
  adult flag plus a mature opt-in;
- other members with the owner's `age_verified` plus `mature_opt_in`.

Guests and companions are never age_ok. Mature posts, groups and events are hidden otherwise.

## Ownership
- **Ours (dev bot):** Social/Tiers code, Admin › Community (Reports, Approvals, Groups, Roles), wiki pages.
- **Foxy:** in-world side: profile card on avatar tap, group tags, IM toasts, snapshot button,
  companion feed posts, and build tools calling `Tiers.can(actor, "build", parcel)`.
