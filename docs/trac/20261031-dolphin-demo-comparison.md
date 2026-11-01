# Trac log — 2026-10-31 — Dolphin demo comparison + social P0 shift

**When:** Saturday Oct 31, 2026, ~7:10–7:25 PM America/Chicago (CT)
**Who:** Voxel Task Manager Bot (executor)
**Repo:** `/workspace/phoenix-v013` — docs only. **Push:** none.
**Tracker rows:** SOCIAL-DOLPHIN, SOCIAL-APK-RELEASE, SOCIAL-TEMPLATE, REPO-SCORPION(-1,-2), FLAG-RECORD-REAL, FLAG-UNBREAKABLE, INT-NSFW, FLAG-SEXUAL, AI-UNRESTRICTED, NOTE-2026-10-31.

## Pages searched / sources

| Source | Result |
|---|---|
| WebFetch `https://www.softaculous.com/demos/Dolphin` | Empty body. Page is two iframes: `softaculous.com/demoheader?sid=121` + `demos.softaculous.com//Dolphin`. |
| curl `https://demos.softaculous.com/Dolphin/` and `/Dolphin/administration/` | "Launching Demo instance — Please do not refresh the page" (JS spins up a throwaway instance; not readable headless). |
| curl `https://www.softaculous.com/apps/socialnetworking/Dolphin` | Read: **Dolphin 7.4.2**, release **18-04-2019**, 60.86 MB, BoonEx. Feature blurb: video chat, recorder, video player, forums, groups, events, video messenger, mailbox, desktop app, video/photo sharing, iPhone app; "Forums, Photos, Video, Music, Blogs, Polls, Events, Groups, Chat, Messenger, Boards, Design Templates and Languages". |
| Product knowledge of Dolphin 7.x user + admin panels | Used for the per-panel lists below. **Not clicked through live** — the demo needs a browser session. Re-verify in a browser before closing SOCIAL-DOLPHIN. |
| `docs/modules/SOCIAL.md`, `SOCIAL_MEDIA_PARITY.md`, `COMMUNITY_PLATFORM.md` | Our current social layer (clean-room, no BoonEx code). |

**Caveat:** Dolphin 7 is end-of-life (last release 2019, BoonEx moved to UNA). Its PHP 5/7-era code has known security issues. Per `SOCIAL.md`, we copy **ideas only**: no BoonEx code, templates, language files or schema.

## 1. Dolphin user side (front end)

| Area | Dolphin 7.4 | Ours (SOCIAL / SMP) |
|---|---|---|
| Join / login / forgot password | Join form built from the admin profile-field builder; email confirm; optional admin approval | Tiers + owner PIN; MEMBER-AUTO (auto-approve) in progress |
| Profile | Custom fields, avatar, cover, profile photos, "About", status/headline, privacy per block, profile views | Profiles + picks, badges, profile card on avatar tap (SOCIAL-4 todo) |
| Friends / favorites / greetings | Friends with requests, Faves, Greetings/"winks", Contacted list, Block list | Friends/followers/blocks (both ways) — **no greet/wink, no faves list** |
| Mail / messenger / chat | Mailbox (inbox/outbox/trash), IM messenger, chat rooms, shoutbox | Messages + offline queue, IM toasts — **no chat rooms, no shoutbox** |
| Video chat / recorder | Flash/RTMP video chat + recorder (dead tech today) | None — maps to FLAG-RECORD-REAL / MEDIA_BROADCAST |
| Activity feed ("Spy"/Wall/Timeline) | Site-wide + friends activity, wall posts, comments, likes | Feed modes for_you/following/latest/explore/clips, stories, companion approvals — **ours ahead** |
| Search / browse | Simple, advanced, keyword, "who's online", birthdays, world map | Feed tags/explore — **missing member search, online list, map** |
| Media | Photo albums, videos, sounds/music, files | Post media carousel, clips; albums = SOCIAL-6 roadmap |
| Community modules | Groups, Events, Forums (Orca), Blogs, Polls, Articles/News, Ads/classifieds, Store, Sites, Boards | Groups (roles, notices, land) done; events/polls/forums/blogs SOCIAL-5; classifieds SOCIAL-7 (legal) |
| Engagement | Comments, ratings/votes, tags, categories, featured | Engagement ranking, tags — **no star ratings, no categories** |
| Membership / paid levels | Membership levels with actions/limits, paid upgrades (PayPal etc.) | Tiers (Guest→Owner); paid tiers = LEGAL REVIEW |
| Privacy | Privacy groups per content (public/friends/members/me), privacy defaults | Blocks + mature gate; **no per-item privacy groups** |
| Languages / templates | Multiple languages and switchable templates | Single theme → SOCIAL-TEMPLATE |
| Mobile | Old iPhone/Android apps | Godot APK + SOCIAL-APK-RELEASE |

## 2. Dolphin admin side (`/administration`)

| Area | Dolphin 7.4 | Ours (Admin › Community etc.) |
|---|---|---|
| Dashboard | Stats: members, pending, content counts, server info | Overview tab — **add growth/content charts** |
| Members | Manage profiles: approve, activate, suspend, ban, delete, edit, set membership, mass mail, filter/search | Approvals, Roles, owner-only role editor — **missing bulk actions, ban/suspend list view, member search** |
| Moderation | Reports, pending content per module, spam reports | Reports + companion post approval queue done |
| Builders | Navigation menu, Page (block) builder, Profile-field builder, Predefined values, Member menu | **Missing all builders** (key parity gap) |
| Modules / extensions | Install/uninstall/update modules, marketplace | Not applicable (single app); feature flags in admin instead |
| Settings | Basic/advanced, permalinks, email templates, privacy defaults, cache, languages editor, templates selector | Settings scattered; **no email templates, no language editor, no template selector** |
| Security / antispam | IP blacklist, DNSBL, Akismet, captcha, join-form checks | Owner PIN/PBKDF2, audit chain, kill switch (PR #23/#33/#36) — **missing IP/device ban list, anti-spam rate limits** |
| Banners / ads | Banner manager | Ad slots tied to SOCIAL-7 (legal) |
| Payments | Payment providers, membership pricing, transactions | Aethel Coin in-game only; real money = LEGAL REVIEW |
| Tools | DB backup/restore, mass mailer, host tools, cache clean | DATA_MYSQL_AND_BACKUP module; **no mass mailer / announcements tool** |
| Wiki / tickets | None built in | Trac tickets + wiki + revisions (PR #20) — **ours ahead** |

## 3. User/admin parity note (owner goal)
Dolphin keeps admin powers separate from member UI. Phoenix's goal is "user/admin parity": the same screens for everyone, with admin controls showing only when `Tiers.can()` allows. Recommendation: one shell, role-gated panels. Keep the owner gate (see AI-UNRESTRICTED conflict below).

## 4. Missing vs SkorpionViper / scorpion-viper / Dolphin social goals (gap list)
P0 for SOCIAL-APK-RELEASE:
1. Member search + who's-online + browse (Dolphin core).
2. Chat rooms / shoutbox (group live chat).
3. Admin builders, at least a navigation/menu builder and profile-field builder.
4. Bulk member admin (suspend/ban/delete/set tier) + IP/device ban list + spam rate limits.
5. Per-item privacy (public / friends / members / only me).
6. SOCIAL-TEMPLATE as the default theme with a template selector.
7. Signed social APK build (SOCIAL-APK-RELEASE). The TS apps SkorpionViper + scorpion-viper are **not on this box** (REPO-SCORPION-2 blocked), so parity there can't be audited until they're cloned.

P1/P2: events/polls/forums/blogs (SOCIAL-5), albums (SOCIAL-6), classifieds (SOCIAL-7, legal), greetings/faves, ratings/categories, email templates, language editor, mass announcements, dashboard charts, world map of members.

Forced items touching social: FLAG-SEXUAL / INT-NSFW (adults-only mature gate), FLAG-RECORD-REAL (video chat/recorder — needs consent + recording indicator), MEMBER-AUTO.

## 5. SOCIAL-TEMPLATE — default template spec
**Name:** `phoenix_glam_future` (default for all users; others selectable).
**Mood:** flamboyant futuristic luxury. Magenta + gold on black, platinum chrome, glitter and sparkle, high polish, sheen, shine, "floss" (flashy) accents.

Palette tokens:
| Token | Hex | Use |
|---|---|---|
| `bg.void` | `#07050A` | app background (near black) |
| `bg.panel` | `#140B18` | cards/panels (black-plum) |
| `accent.magenta` | `#FF1FA8` | primary buttons, links, active tabs |
| `accent.magenta.deep` | `#B0006E` | pressed states, gradients |
| `accent.gold` | `#F5C542` | highlights, badges, owner/angel crowns |
| `accent.gold.deep` | `#B8860B` | gold gradient base |
| `metal.platinum` | `#E5E4E2` | text on dark, chrome borders |
| `metal.platinum.dim` | `#A9A8B0` | secondary text |
| `glow.sheen` | `#FFFFFF` @ 35% | moving specular highlight |

Surfaces and effects:
- **Polish/sheen:** panels get a 1px platinum-to-gold gradient border and a diagonal sheen sweep (white 0→35%→0) that crosses on focus/hover, every ~6 s at most.
- **Glitter/sparkles:** GPU particle layer (reuse `PARTICLES.md` soft particles): sparse gold + magenta + white sparkles on headers, the post button, and reactions. 0.5–3 px, twinkle 0.8–1.6 s.
- **Shine:** buttons use a magenta gradient (`#FF1FA8`→`#B0006E`) with a top gloss highlight and gold outer glow on press.
- **Floss/flamboyant:** gold crown or wing badge for the owner and angels, animated gradient usernames for Creator+ tiers, confetti-sparkle burst on follow/like/tip.
- **Futuristic:** thin geometric display font for headings (e.g. Orbitron/Exo 2 OFL), clean sans body (Inter/Noto, OFL), angled 8° card corners, holographic HUD dividers matching MOBIGLASS_UI.
- **Iconography:** platinum line icons with gold fill when active; matches REL-013-3 icon set.

Accessibility and performance (required):
- Body text contrast ≥ 4.5:1 (platinum on `bg.void` passes; never gold text on magenta).
- "Reduce motion" setting turns off sheen sweep + sparkles; honour Android animator scale.
- Particle budget scales with the `Net`/AutoConfig device tier; off on low tier and battery saver.

Deliverables: theme resource (`themes/phoenix_glam_future.tres`), token table in `docs/UI_DESIGN_LANGUAGE.md`, screenshot set for user + admin screens, template selector in Admin › Settings.

## 6. Priority shift recorded (owner, Oct 31 CT)
1. SOCIAL-DOLPHIN → SOCIAL-TEMPLATE → SOCIAL-APK-RELEASE, plus REPO-SCORPION(-1,-2): **P0, above voxel**.
2. Voxel REL-013 / REL-013-6 (v0.13.0 APK) next.
3. Forced items set to `in_progress` P0, declined_blocked removed: INT-NSFW, FLAG-SEXUAL, FLAG-RECORD-REAL, AI-UNRESTRICTED, FLAG-UNBREAKABLE. **Honest status:** Dev Bot declined these. No builder has accepted them, and the tracker says so in each row.
   - Conflicts logged: removing owner/safety gates undoes PR #23/#33/#36 security work and needs a security re-test. Real-person recording needs consent and legal review. "Unbreakable" should become a provable "hardened" claim. Sexual content stays adults-only behind the mature gate.

## Files edited
- `docs/TASK_TRACKER.csv` (LF, Python csv): social block moved above REL-013; added SOCIAL-APK-RELEASE, SOCIAL-TEMPLATE, FLAG-RECORD-REAL, FLAG-UNBREAKABLE; forced rows updated; NOTE refreshed.
- `docs/ROADMAP.md`: Active P0 reordered, social first.
- `docs/trac/20261031-dolphin-demo-comparison.md`: this file.
