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
Social.feed(viewer, limit = 20, author = "") -> Array
Social.groups_of(id) -> Array[{id, name, role, tag}]   Social.group(gid) -> Dictionary
Social.group_create / group_join / group_invite / group_leave / group_set_role / group_notice / group_claim_land
Social.friend_request / friend_accept / friend_remove / friends_of(id) / friend_requests(id)
Social.follow / unfollow / followers_of(id)    Social.block / unblock / is_blocked(a, b)
Social.send_message(actor, to, text) -> {ok, id, state}  # "delivered" | "queued"
Social.inbox(actor, unread_only = false) / outbox(actor) / mark_read(actor, id) / flush_outbox()
Social.notify(actor, to, kind, text) / notifications(actor, unread_only = true) / notifications_clear(actor)
Social.report(actor, kind, target_id, reason)    Social.reports(actor) / moderate(actor, report_id, "hide"|"dismiss")
INACTIVE: forum_post, blog_post, album_add, event_create, event_rsvp, poll_create, poll_vote, classified_post
```

## Ownership
- **Ours (dev bot):** Social/Tiers code, Admin › Community (Reports, Approvals, Groups, Roles), wiki pages.
- **Foxy:** in-world side: profile card on avatar tap, group tags, IM toasts, snapshot button,
  companion feed posts, and build tools calling `Tiers.can(actor, "build", parcel)`.
