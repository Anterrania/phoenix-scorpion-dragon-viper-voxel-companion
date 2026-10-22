# Foxy spec: Camera, image editor and filter pipeline (SMP-18)

The headless side (ours) is `MediaTools`: validate, strip EXIF/GPS, EXIF rotation, then WebP output at
full 1440 px, low 640 px and a 320 px thumbnail. The client produces the edited `Image` and hands its
bytes to `MediaTools.process_upload(actor, bytes, alt)`, then `store_media`, then the `ref` /
`thumb_ref` / `low_ref` go into `post(... media)`. Build everything with Godot's Image, shaders and
viewports. Don't use third-party filter packs or LUT files from other apps.

**Pipeline order** (non-destructive; keep a recipe Dictionary so edits can be redone):
1. Crop and rotate: free, 1:1, 4:5, 9:16 and 16:9; straighten ±45°.
2. Adjustments, each from -100 to 100:
   - exposure, brightness, contrast, highlights, shadows
   - saturation, vibrance, warmth, tint
   - fade, sharpen, vignette, grain
3. Filter: our own presets, each a recipe plus an optional 3D LUT (we make our own .png 16³ or 32³
   strip). Strength 0–100%.
4. Overlays: text (our fonts), stickers (our art), drawing, mentions and hashtag chips.
5. Export: render at no more than `Net.image_px("image")` for preview. The upload always goes through
   MediaTools, which sets the stored sizes.

**Rules.**
- Run the GPU shader preview at the screen size, and the full-size render only on Save.
- Ask for alt text. Suggest it from the companion if the owner allows that; never send it automatically.
- Location: never add GPS. A place tag is only a region name chosen by hand.
- Mature toggle: only offer it when `Social.age_ok("self")`.
- Clips: the same adjustment recipe as a shader on playback. Trim, speed (0.5×, 1×, 2×) and a cover
  frame (which becomes `thumb_ref`).
