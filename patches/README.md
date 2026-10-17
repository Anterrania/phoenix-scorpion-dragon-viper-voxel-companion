# Proposed patches for other owners' files

`eve_core_owner_only_unlock.patch` is for Foxy, the owner of `scripts/ai/eve_core.gd`. `EveBrainCell.unlock()` is public and ungated, so any caller can unlock a cell even though `EveCore.refresh_lock()` only unlocks for the owner. The patch makes `unlock()` itself owner-only. It returns bool, so existing callers that ignore the result keep working.
Apply: `git apply patches/eve_core_owner_only_unlock.patch`. Verified that it applies to main at 0c12750 and that the full test suite passes with it applied.
**Status 2026-10-17: already applied on `main`** (`git apply --check -R` succeeds). Kept for history only; do not apply again.

## Added by the 2026-10-17 audit (not applied; see docs/AUDIT_2026-10-17.md)
These touch files Foxy owns (land-tools sheet, minimap, v0.12 avatar textures), so they are patches, not edits.
- `land_tools_terraform_owner_check.patch` (`scripts/ui/ui_root.gd`): the land panel calls `Estate.can_terraform(region, true)`, so the region's `owner_only` terraform rule never applies. The patch passes `EveCore.owner_ok()` instead. Behaviour change: with the owner session locked, terraforming an owner_only region is refused. To be superseded by `Tiers.can` (BUILD-7).
- `minimap_redraw_throttle.patch` (`scripts/ui/minimap.gd`): redraw at most 10×/s and never while hidden, instead of every frame.
- `avatar_textures_vram_compression.patch` (`assets/characters/*.import`): `compress/mode` 0 → 2 (VRAM, ETC2/ASTC on Android). Measured: export pack grows 8,831,216 → 10,846,416 bytes (+2.0 MB) because the lossless PNGs are small on disk, but GPU memory for the 10 textures drops from about 41.9 MB (RGBA8 + mips) to about 10.5 MB (calculated). Apply after v0.12, and only if on-device memory matters more than download size.
Each one passes `git apply --check` on main at b280233.
