# Restrictions (RLV-style): decision record

Status: minimal implementation (VIEWER-4), `scripts/security/restrictions.gd`. Concepts only. RLV and
RLVa are viewer features; we copy no code and no command syntax.

## Decision
We ship a **small, prevent-only, opt-in** API and nothing that can take control of someone. In SL, the
RLV family can also force actions (teleport, sit, attach, outfits, chat redirects). We leave all of those
out on purpose. They are the parts that can be abused, and a phone app shared with companions doesn't need them.

## Rules (enforced in code, covered by tests in tests/viewer_tests.gd)
1. **Off by default.** A subject opts in for themselves and confirms they are 18 or older every time they turn it on.
2. **Consent per source.** Only sources the subject listed can add restrictions. Revoking consent clears
   that source's restrictions at once.
3. **Prevent-only list.** fly, tplm, tploc, sendchat, sendim, rez, edit, showinv, showminimap,
   showworldmap, showloc, shownames, unsit, fartouch. Anything else is refused.
4. **Never restrictable:** safeword, e-stop, owner unlock, admin, security, report, block, mute,
   settings, exit app, help, emergency.
5. **Short-lived.** Each restriction expires after at most 240 minutes. Active restrictions only last for
   the session. Opt-in and consent are saved through SecureFile.
6. **Safeword.** The subject can always clear everything on themselves, even while locked, with no tier needed.
7. **Companions.** Only the unlocked owner can opt a companion in or consent for it.
8. **Owner override.** The unlocked owner can clear everyone's restrictions and switch the API off globally.
9. **E-stop.** While `AutonomyGuard.paused()`, every restriction is suspended and none can be added.
10. **Tiers.** A source needs `Tiers.can(source, "message")`: Resident and up, and not a paused bot.

## Age / adult flag
Viper OS has no age verification service. The 18+ confirmation is the subject's own statement, and it is
recorded with the time. Parcels can also be marked adults-only (`ParcelTools.entry_ok(..., adult)`), which
refuses entry unless the caller passes a verified adult flag. A real check is planned with the grid
identity service.

## Consumers
Consumers only call `Restrictions.is_restricted(subject, behaviour)`. Today: the
`patches/viewer_parity_hud_hooks.patch` fly hook (Foxy applies it). The rest are listed in
docs/modules/VIEWER_PARITY.md under "Spec for Foxy".

## Not built (won't)
Forced teleport, forced sit/stand, attach/detach locks, outfit locks, chat redirection, reading the
subject's inventory, location or settings from a script, remote debug-setting changes.
