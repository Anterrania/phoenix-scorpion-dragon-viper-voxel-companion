# Media, Music, Dance & Broadcasting (Viper OS)

Status: **partial**. Some parts are built and headless-tested (marked **Built**). Everything else is
**Planned**. Nothing here posts, uploads or streams anything without the owner's approval.

Owner rules that apply to every section:
- **Our own AI stays primary.** Gemini, Copilot and Meta AI are only used to *import* data the owner
  chooses (DataImporter). They never generate, post or decide.
- **Owner approval gate.** Anything public (a post, an upload, going live, a public dance routine by
  a companion) goes through the owner: `Tiers.owner_session()` / `Profile.is_owner()` and, for
  companions, the Proposals queue (`EveCore.propose_update` → MENU › Proposals).
- **Tiers.** Every write calls `Tiers.can(actor, action, target)`. Media uses the new action
  `broadcast` (creator tier and up, plus media rights on the parcel: staff and up, the parcel's land
  group, or the parcel allow list), and the existing `upload`, `event_create`, `post`.
- **E-stop.** While companions are paused (`AutonomyGuard`), bots can only browse.

## 1. What exists today (Built)

| Piece | Where | Notes |
|---|---|---|
| Voice morph presets | `scripts/audio/voice_fx.gd` (`VoiceFx`) | Natural, Deep, Bright, Dragon, Fae, Radio. Pitch = `AudioEffectPitchShift` (FFT 1024, low latency). Formant tilt = `AudioEffectEQ6` gains. |
| TTS morph | `CompanionVoice.speak` + `VoiceFx.tts_params` | System TTS can't take bus effects; the preset folds into TTS pitch and rate. |
| Lip sync | `scripts/audio/lip_sync.gd` (`LipSync`) | Amplitude (mic or clip RMS, gate/attack/release) **or** text visemes synced to TTS started/boundary/ended callbacks. Outputs FaceDriver channel names (`jawOpen`, `viseme_*`). |
| Mic capture | `scripts/audio/mic_capture.gd` (`MicCapture`) | `AudioStreamMicrophone` → bus "Mic" [morph chain + `AudioEffectCapture`] → level + lip sync. |
| Beat detection | `scripts/audio/beat_detector.gd` (`BeatDetector`) | Our own energy-flux onsets + autocorrelation tempo (60–180 BPM) + beat grid. Works on `AudioStreamWAV` or raw samples. |
| Dance timeline | `scripts/audio/dance_timeline.gd` (`DanceTimeline`) | One move per beat, 8-beat phrases, seeded (a group dances in sync). Poses HumanoidModel now. |
| Broadcast stub | `scripts/media/broadcast.gd` (`Broadcast`) | Stream entries, parcel media URLs, stream keys saved **encrypted only**, owner approval to go live. No encoder yet (INACTIVE). |
| Admin page | Admin › ⚙ › **Broadcast** | Add a stream, save its key, set parcel media, "Go live (owner approves)". |
| Parcel media fields | `Estate` `media_url`, `music_url` | Existed since v0.9 (SL "About Land › Media"). |
| Music radio | `scripts/world/music_radio.gd`, `soundcloud_source.gd` | Station URL / SoundCloud *playback* (client id entered by the user). |
| Eve Core hooks | `EveCore.create_music`, `create_duet`, `output_audio`, `output_video` | Log-only hooks (no generation yet). |

## 2. AI music creation (Planned)

- **Phase 1 – arrangement from our own engine.** A small pattern sequencer (drums, bass, pad, lead)
  driven by Eve Core moods and realm themes. Output `AudioStreamWAV` rendered offline with
  `AudioStreamGenerator`. No third-party model needed; keeps the APK small.
- **Phase 2 – vocals.** Companions "sing" lyrics with the TTS voice plus `VoiceFx` pitch per note.
  `EveCore.create_duet` pairs two voices.
- **Phase 3 – optional cloud model** behind the same `AIProvider` interface, only if the owner turns it on.
- Every song is saved in the owner's media library (encrypted saves). Public release = owner approval.

## 3. AI music videos (Planned)

- In-world "shoot": a camera rig (`Camera3D` on a path) + the dance timeline + realm lighting presets.
- Render: Godot Movie Maker mode (`--write-movie`, PNG/AVI) on desktop; on the phone a viewport
  capture into frames, then an encoder plugin (Phase 3). Cuts land on detected beats.
- Output goes to the media library, then optionally to upload (§5).

## 4. Synced dance routines for live events (Built core, rest Planned)

- **Built:** `BeatDetector.analyze_wav()` → `DanceTimeline.from_analysis(a, seed)` →
  `timeline.apply(model, t)` each frame with `t` = the music player's playback position
  (`AudioStreamPlayer.get_playback_position() + AudioServer.get_time_since_last_mix()` minus output
  latency), so moves land on the beat.
- **Planned:** RealisticBody bone poses (v0.12 rig), a move library from animation clips,
  formations for groups, a choreography editor in the build HUD (Foxy), cue sheets for concerts
  (lights, particles, stage screens on the same timeline), and live beat tracking from the mic.
- **Approval:** a companion's public routine at an event is a proposal the owner approves.

## 5. YouTube and SoundCloud upload (Planned)

- **Official APIs only**, with **OAuth 2.0 on the user's own accounts**:
  - YouTube Data API v3 `videos.insert` (resumable upload), OAuth scope `youtube.upload`.
  - SoundCloud API `POST /tracks`, OAuth 2.1 (authorization code + PKCE).
- Mobile OAuth flow: the system browser with PKCE and an app-link redirect. No passwords in the app.
- Tokens are saved through `SecureFile` (encrypted saves, owner vault). Never in git, logs or the wiki.
- **Never posts without the owner's approval:** an upload is a draft until the owner taps
  "Publish" with an unlocked owner session. Default privacy on YouTube: *private* (owner changes it).
- Tier: `upload` (creator and up) to prepare; publishing needs the owner.

## 6. Broadcasting (stub Built, encoder Planned)

**Server-side stub (Built, local today).** `Broadcast` mirrors a planned grid **MediaService**
(Aurora-Sim / OpenSim style service, alongside the planned Social service):

| Planned endpoint | Local call today |
|---|---|
| `POST /media/streams` | `Broadcast.add_stream(actor, title, kind, ingest_url, parcel)` |
| `PUT /media/streams/{id}/key` | `Broadcast.set_stream_key(actor, id, key)` (encrypted only) |
| `POST /media/streams/{id}/live` | `Broadcast.go_live(actor, id)` (owner approval) |
| `POST /media/streams/{id}/end` | `Broadcast.end_stream(actor, id)` |
| `PUT /media/parcels/{region}/{parcel}` | `Broadcast.set_parcel_media(actor, parcel, url, kind)` |
| `GET /media/streams?parcel=` | `Broadcast.list(parcel)` (never returns keys) |

- Stream kinds: `rtmp`, `rtmps`, `hls`, `youtube_live`, `icecast`. Parcel media kinds: `video`,
  `audio`, `web`, `youtube` (https only for video/web/youtube).
- **Stream keys** are written only when the owner's encrypted saves are open
  (`SecureFile` + `OwnerVault`). Otherwise the call is refused. `list()` shows only `has_key`; the
  admin shows a `••••1234` hint once. Only the encoder reads a key, with an owner session.
- Gate: `Tiers.can(actor, "broadcast", parcel)` on every write.

**Encoder (Planned, Phase 3).** Godot has no RTMP encoder built in. Plan: a small Android plugin
(MediaCodec H.264/AAC + RTMP) fed by (a) the phone camera (`CameraServer` feed) or (b) an in-world
camera viewport, with mic audio from the "Mic" bus (with the voice morph). Targets: **YouTube Live**
(RTMPS ingest + key from the owner's YouTube Studio, or `liveBroadcasts` API via OAuth) or a
self-hosted server (nginx-rtmp / SRS / MediaMTX).
- **As yourself:** camera feed.
- **As your avatar:** in-world camera. Later phase: avatar face tracking from the front camera
  (landmarks → FaceDriver channels: blink, smile, jaw, visemes).

## 7. YouTube and Google abilities (Planned)

- **In-world media screens:** a parcel media URL plays on a screen mesh. Native video: Godot's
  `VideoStreamPlayer` plays Ogg Theora only, so YouTube/MP4 needs an Android WebView/ExoPlayer
  plugin (Planned). Until then the screen shows the title and "Open on phone" (system intent).
- **Embeds:** `https://www.youtube.com/embed/<id>` URLs are accepted as `youtube` parcel media.
- **YouTube Live:** watch a live stream on a stage screen; go live per §6.
- **Google sign-in** (optional, Planned) only for YouTube/Drive access, never required to play.

## 8. Communications (Planned unless marked)

- **Built:** local private messages + offline queue (Social), mic capture with morph and level.
- **Voice chat:** Opus over WebRTC (Godot `WebRTCPeerConnection` + the webrtc-native GDExtension)
  peer-to-peer for small groups; a self-hosted SFU for events. Push-to-talk (`voice/push_to_talk`).
- **Spatial audio:** each speaker is an `AudioStreamPlayer3D` with attenuation by distance and
  parcel "voice zones" (Estate flag, like SL parcel voice). Estate managers can mute a parcel.
- **Text/IM:** Social messages today; grid IM service later (same API as Social.message).
- **Moderation:** report/mute/block (Social) apply to voice too.

## 9. Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Device check, permissions, mic driver on, voice morph, lip sync, beat detector, dance timeline, broadcast stub + admin page | **Built** (this PR) |
| 1 | FaceDriver hookup on v0.12 bodies (patch), RealisticBody dance poses, media library, parcel screen placeholder | Planned |
| 2 | Our own music sequencer + sung vocals, music-video shoot + desktop render, OAuth + upload drafts (owner publishes) | Planned |
| 3 | Android encoder plugin (camera / in-world), YouTube Live + self-hosted RTMP, WebView/ExoPlayer media screens | Planned |
| 4 | Voice chat + spatial audio, grid MediaService, face tracking for avatar broadcasts | Planned |

## 10. Must be checked on a real phone

- Camera and mic permission prompts, and that `CameraServer` lists feeds on the phone.
- Mic capture level and the voice morph sound (latency, echo with speakers).
- TTS utterance callbacks on Android (started/ended/boundary). If boundary events don't arrive,
  lip sync still runs on the text timeline from "started" to "ended".
- Notification permission prompt (Android 13+).
- Rotation: auto-rotate vs. Portrait lock, and layouts after turning the phone.
