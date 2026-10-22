---
title: Media, Voice & Broadcast
slug: media-broadcast
tags: [voice, morph, lip sync, music, dance, broadcast, youtube, soundcloud, streaming]
audience: all
status: partial
updated: 2026-10-17
sources: [scripts/audio/voice_fx.gd, scripts/audio/lip_sync.gd, scripts/audio/beat_detector.gd, scripts/audio/dance_timeline.gd, scripts/media/broadcast.gd, docs/modules/MEDIA_BROADCAST.md]
ticket: PHONE-5
---

# Media, Voice & Broadcast

> **Partial.** Voice morph, lip sync, beat detection, dance timelines and stream entries are built
> and headless-tested. Streaming, uploads, AI music and music videos are **Planned**.
> Design: MediaBroadcast (docs/modules/MEDIA_BROADCAST.md).

## Voice (Admin › ⚙ › Voice)
- **Voice morph**: Natural, Deep, Bright, Dragon, Fae, Radio. Changes your mic voice and the
  companions' speaking pitch.
- **Lip sync**: mouths move with the voice. Companions' lips start when the phone starts speaking
  and stop when it ends.
- **Microphone test**: **Start mic** shows a live level. **Hear myself (use headphones)**.

## Dance (built core)
- The app finds the beat of a song and builds a routine, one move per beat.
- Companions with the same routine dance in sync.
- Public routines at events need your approval.

## Broadcast (Admin › ⚙ › Broadcast)
- **Add a stream**: title, ingest address (rtmps://…), region/parcel, stream key.
- Stream keys are saved **encrypted only**. Unlock in Security first.
- **Go live (owner approves)**: nothing streams without your OK. The streaming engine is not built yet.
- **Parcel media**: a secure https:// video, audio or YouTube embed for a parcel's screen.
- Who can: Premium / Creator and up, with media rights on the parcel (staff, the land group, or
  the parcel's allow list). See Tiers.

## Planned
- AI music and sung vocals from our own engine. AI music videos with in-world cameras.
- Upload to YouTube and SoundCloud with your own accounts (OAuth). Drafts until you publish.
- Live from the phone camera, or as your avatar from an in-world camera, to YouTube Live or your own server.
- In-world screens for YouTube. Voice chat with spatial audio.
