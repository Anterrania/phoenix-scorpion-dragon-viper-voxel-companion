# Particles & VFX

> **Future module, not implemented.** Phase: Phase 4–6. Design notes only.

- Use GPUParticles3D on the Mobile renderer. Keep particle counts low (<2k on screen) and offer a CPUParticles3D fallback for low-end devices.
- Effects: Foxy Ani fire-casting and ember trail, phoenix rebirth burst, Circuit Nova star particles and circuit glow, snow/aurora (Alaskan), stardust (cosmic), lava sparks/heat haze (Venus), neon rain (cyberpunk), block break/place puffs.
- Use shared texture atlases and a quality setting slider.
