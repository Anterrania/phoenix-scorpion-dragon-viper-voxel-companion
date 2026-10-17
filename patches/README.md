# Proposed patches for other owners' files (not applied)

`eve_core_owner_only_unlock.patch` is for Foxy, the owner of `scripts/ai/eve_core.gd`. `EveBrainCell.unlock()` is public and ungated, so any caller can unlock a cell even though `EveCore.refresh_lock()` only unlocks for the owner. The patch makes `unlock()` itself owner-only. It returns bool, so existing callers that ignore the result keep working.
Apply: `git apply patches/eve_core_owner_only_unlock.patch`. Verified that it applies to main at 0c12750 and that the full test suite passes with it applied.
