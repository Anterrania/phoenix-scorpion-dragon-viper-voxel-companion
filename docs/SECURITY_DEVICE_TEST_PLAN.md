# Security device test plan (PR #23, owner security)

Scope: owner PIN login (PBKDF2-SHA256, 310k iterations, per-slot salt), session owner gate + auto-lock,
AES-256 + HMAC encrypted saves (`SecureFile`/`CryptoBox`, magic `PXE1`), hash-chained audit log
(`RevisionStore.verify_chain`), e-stop / kill switch (`AutonomyGuard`, `user://security/estop.json`),
and no secrets in the APK or logs.

Code: `scripts/security/*`, `scripts/admin/security_screen.gd`, `scripts/admin/tracker/revision_store.gd`,
`scripts/autoload/profile.gd`. Automated tests: `tests/security_tests.gd` (run via `tests/test_runner.tscn`).

Result key: PASS / FAIL / NOT RUN (reason) / PASS (desktop) = verified by headless suite on Linux, still needs a phone run.

## Run log, 2026-10-22 (Linux box)

| What | Result |
|---|---|
| Headless suite, Godot 4.7.2 (`godot --headless --path . res://tests/test_runner.tscn`) | PASS: 978 PASS lines, `FAILURES: 0`. The two "integrity check failed" errors are expected (the tamper test). |
| Debug APK export (arm64 + x86_64, temporary preset change, reverted) | Built `build/android/pv-debug.apk` (74.6 MB). Warning: `libvoxel.android.editor.x86_64.so` is missing from `addons/zylann.voxel/bin`, so the x86_64 lib in the APK is 0 bytes. |
| Android emulator (API 34 google_apis x86_64) | NOT RUN: the emulator and system image installed, but user `box` has no permission on `/dev/kvm` (not in group 103), so x86_64 emulation won't start. Even with KVM, the empty x86_64 voxel lib would likely break the world scene. An arm64 phone is the real target. |
| APK static scan for secrets | PASS with a note: no API keys, private keys or plaintext owner code. The APK has `Profile.OWNER_CODE_SHA256`, an **unsalted** SHA-256 of the legacy `phoenix-...` owner code (see F1). |

## Re-run after PR #33 (1d4f15c), 2026-10-22 9:45 AM PT

| What | Result |
|---|---|
| Fresh worktree of 1d4f15c, `--import`, then the suite with `XDG_DATA_HOME=$(mktemp -d)` | PASS: 1500 PASS lines, `FAILURES: 0`. sec1–sec4 all pass, including "Android export is arm64-only" and "tests leave no test folders". |
| Debug APK, arm64-only, from the preset as committed | Built `/workspace/pv-debug-arm64.apk` (45,961,339 bytes). The export fails under a temporary `XDG_DATA_HOME` (it can't find the templates or editor settings), so it was built with the normal environment. |
| APK secret re-scan | PASS: see case 18. |
| Emulator / phone | NOT RUN: there is no KVM permission and no arm64 device. |

## Test cases

| # | Area | Steps | Expected | Result |
|---|---|---|---|---|
| 1 | PIN set | (a) Upgraded phone that already has a vault: it unlocks with the PIN. (b) Fresh install: open Security and set a PIN. | (a) The vault opens and the legacy slot is stripped. (b) The owner can set a first PIN. | (a) PASS (headless, sec1 migration). (b) **FAIL (by code review, after PR #33):** no bootstrap cfg ships, `setup()` refuses without bootstrap unless `allow_fresh`, and no caller passes `allow_fresh=true`. A fresh install cannot set a PIN. Needs a phone to confirm. |
| 2 | PIN rules | Try a 5-digit PIN and an 8+ char passphrase in ABC mode. | The short PIN is rejected (minimum 6) and the passphrase is accepted (minimum 8). | PASS (desktop) |
| 3 | Login | Lock the app, then enter the correct PIN. | The session opens, the owner gate is on, and saves can be read. Writes made while locked are flushed encrypted. | PASS (desktop) |
| 4 | Wrong PIN | Enter the wrong PIN once. | It's refused, no data is unlocked, and the error message doesn't reveal the PIN. | PASS (desktop) |
| 5 | Lockout/backoff | Enter 5 or more wrong PINs, then the right PIN. | A wait is enforced ("Too many…") and the right PIN also waits. Login works after the wait. | PASS (desktop) |
| 6 | Unlock timing | Time unlock on the phone. | Unlock takes under ~2 s. If it's slower, tune `DEFAULT_ITERATIONS` per device. | NOT RUN (needs phone) |
| 7 | Gate blocks admin | While locked, open Admin, then Security, tickets, wiki and estate settings, and try edits, timeout changes and e-stop release. | Every owner action is refused (`Profile.is_owner()`, `EveCore.owner_ok()` false, and `EveBrainCell.unlock` refused). | PASS (desktop) |
| 8 | Session expiry | Set the timeout to 1 min (allowed range 1–240) and leave the app idle for 2 min. | The session locks and asks for the PIN again. Saves stay open for gameplay. Activity extends the session. | PASS (desktop, fake clock); phone NOT RUN |
| 9 | App restart | Swipe-kill the app and reopen it. | It starts locked and owner actions need the PIN. | NOT RUN (needs phone) |
| 10 | Change PIN | Change the PIN in Security. Try the old one, then the new one. | The old PIN fails and the new one works. Data stays readable without re-encryption. | PASS (desktop) |
| 11 | Legacy code refused | After a PIN exists, try the old `phoenix-` owner code. Check that Security has no "Hold to retire" button. | The code is refused. There is no retire button, because the button only shows when `has_legacy_slot()` and migration strips that slot. | PASS (headless: sec1 "legacy refused once vault has a pin slot", "migration strips the legacy slot", "nothing left to retire"). Phone UI NOT RUN |
| 12 | Encrypted at rest | `adb shell run-as com.anterrania.phoenixvoxel` (debug build). `head -c4` on `files/eve/*.json`, `memory/*`, `viper/*`, `estate.cfg` and `revisions.jsonl`. | The first 4 bytes are `PXE1` and there's no readable JSON. `profile.json`, `settings.cfg` and wardrobe are plaintext by design (see F2). | PASS (desktop); phone NOT RUN |
| 13 | Tampered save | Flip one byte in a sealed save and relaunch or reload. | The load fails (no data), a `.tampered` copy is kept, and the app won't overwrite it. | PASS (desktop) |
| 14 | Audit chain verifies | Make 5 wiki/ticket edits, then Security → Verify chain, then reload the app. | `ok`, count 5, and the log is sealed. It still verifies after reload. | PASS (desktop) |
| 15 | Audit tamper | On a plaintext (no-vault) store, edit a line, truncate the tail, or reorder lines. | Each one is detected. An edit to r2 is flagged at r3. | PASS (desktop) |
| 16 | Kill switch halts | Engage the e-stop in Security, then chat with a companion that would place a voxel or learn. | `dispatch_tool` returns an e-stop error and learning proposals are refused. | PASS (desktop) |
| 17 | Kill switch persists + fail-closed | Engage the e-stop and restart. Tamper with `estop.json` (set paused=false, strip the MAC, or replace it with old plain JSON). | It stays engaged across a restart. Tampered, unsigned or unreadable states fail closed (engaged). Only the owner can release. | PASS (headless: estop persists, sec3 MAC, tamper, strip and legacy-JSON all fail closed, owner release). Phone NOT RUN |
| 18 | No secrets in APK | Unzip the APK and grep for API keys, private keys, the old owner hash and any bootstrap cfg. | None found. | PASS (arm64 APK from 1d4f15c): old hash `8ae5a770…` absent, no `owner_bootstrap.local.cfg`, no sk-/xai- keys. The PEM strings found are Godot engine messages. |
| 19 | No secrets in logs | `adb logcat \| grep -iE "pin\|secret\|api_key\|dek\|phoenix-"` during setup, login, wrong PIN and change PIN. | Nothing sensitive in the log. A code review found no print/push of PIN, key or secret values. | PASS (code review); logcat NOT RUN |
| 20 | Backup | Security → Backup, then inspect `user://backups`. | The archive is sealed (`PXE1`). | NOT RUN |
| 21 | API key sealed | Enter an LLM API key in Settings, restart, and lock the app. Optionally inspect `settings.cfg` via run-as. | `settings.cfg` has no key. The key sits in the sealed store, can't be read while sealed, and comes back after unlock. A tampered store gives no key. A plaintext key migrates once at first unlock. | PASS (headless, sec2, 8 checks). Phone NOT RUN |

## Findings / fixes needed

- **F1 (medium):** `Profile.OWNER_CODE_SHA256` is an unsalted, fast SHA-256 shipped in every APK. Anyone can brute-force it offline if the code is guessable. Fix: once owners have set a PIN, retire the legacy code by default, or replace it with a PBKDF2 hash plus salt.
- **F2 (medium):** `settings.cfg` stays plaintext on purpose, but it has `[llm] api_key`. A key the user enters is stored in clear. (On this box it is currently empty.) Fix: move `api_key` into a SecureFile, or into Android Keystore later.
- **F3 (low):** `user://security/estop.json` is plain JSON. Anyone with file access (a rooted phone or adb backup) can clear the e-stop without the owner PIN. Fix: seal the file or MAC it with the vault key, and fail closed (paused) if the MAC check fails.
- **F4 (build):** `addons/zylann.voxel/bin/libvoxel.android.editor.x86_64.so` is missing, so x86_64 APKs and emulators can't load the voxel world. Add the lib, or keep x86_64 off and test on an arm64 phone.
- **F5 (hygiene):** test runs leave `test_viper_*` and `brains_test_*` folders in desktop `user://`. Clean them up in teardown.

## Phone checklist (about 10 min, no developer tools)

Install the new APK **over** the existing app (don't uninstall it), then open the app.

**One-time upgrade effects (expected, not bugs):**
- The kill switch (e-stop) shows as **engaged** on first launch, because the old unsigned state fails closed. After you log in, hold "Resume companions" to release it.
- An API key you saved earlier moves into the encrypted store at your first PIN unlock. Settings still shows that it's set.
- Your old `phoenix-…` owner code stops working, and there's no "Hold to retire" button any more, because it was removed automatically.

1. Open Admin, then Security. Unlock with your PIN. ☐
2. You should see the e-stop engaged. Hold "Resume companions" and it releases. ☐
3. Try the old `phoenix-` code. It's refused. ☐
4. Check there's no "Hold to retire the old owner code" button. ☐
5. Open Settings. If you had an API key, chat with a companion and check it still answers online. ☐
6. Close the app fully and reopen it. Owner tools ask for the PIN, and the e-stop stays released. ☐
7. Enter a wrong PIN once (refused), then 5 more times. You have to wait, even with the right PIN. ☐
8. Note how long unlock takes. Under 2 s is good: ____ s ☐
9. Set auto-lock to 1 min and leave the phone for 2 min. It asks for the PIN again. Set it back. ☐
10. Without logging in, try to edit a wiki page. It's blocked. ☐
11. Log in, edit one wiki page, then tap "Verify chain". It says OK. ☐
12. Engage the e-stop, ask a companion to build, and it refuses. Reopen the app and it's still engaged. Release it with your PIN. ☐
13. Change your PIN. The old PIN fails and the new one works. ☐

Report anything that behaves differently, with a screenshot. Don't test on a fresh install yet (see case 1b).

## Fix status (branch fix/security-device)

| Finding | Tracker | Fix | Tests |
|---|---|---|---|
| F1 | SEC-FIX-1 (P0) | `OWNER_CODE_SHA256` removed from the release path (value deleted). Legacy code only bootstraps the first PIN via a salted PBKDF2 record in gitignored `config/owner_bootstrap.local.cfg`; refused once `vault.json` has a pin slot; one-time migration strips legacy slots. | `tests/sec_fix_tests.gd` sec1 |
| F2 | SEC-FIX-2 (P0) | `[llm] api_key` sealed in `user://security/secrets.bin` (vault data key); one-time migration blanks it from `settings.cfg`. | sec2 |
| F3 | SEC-FIX-3 (P1) | `estop.json` MAC'd under the vault data key; tampered, unsealed, unreadable or unverifiable = engaged (fail closed). | sec3 |
| F4/F5 | SEC-FIX-4 (P2) | Android preset stays arm64-v8a only (no x86_64 voxel lib exists); tests delete `test_viper_*`, `brains_test_*`, `test_sec*` roots. | sec4 |

Rebuild the APK from `main` after this merges and re-run test cases 1, 11, 17 and 18 on an arm64 phone. Case 1 and 11 change: the old code now only bootstraps the first PIN and is refused afterwards.
