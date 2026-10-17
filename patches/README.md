# Proposed patches for other owners' files (not applied)

`eve_core_owner_only_unlock.patch` is for Foxy, the owner of `scripts/ai/eve_core.gd`. `EveBrainCell.unlock()` is public and ungated, so any caller can unlock a cell even though `EveCore.refresh_lock()` only unlocks for the owner. The patch makes `unlock()` itself owner-only. It returns bool, so existing callers that ignore the result keep working.
Apply: `git apply patches/eve_core_owner_only_unlock.patch`. Verified that it applies to main at 0c12750 and that the full test suite passes with it applied.

`viewer_parity_hud_hooks.patch` is for Foxy, the owner of `scripts/player.gd`. It adds one line so that `set_flying(true)` does nothing while the player has an opt-in `fly` restriction (`Restrictions.is_restricted`, VIEWER-4; see docs/modules/RESTRICTIONS.md). With no restrictions, behaviour is unchanged.
Apply: `git apply patches/viewer_parity_hud_hooks.patch`. Verified with `git apply --check` on main at 1a07535 and on feature/v012-avatar.
