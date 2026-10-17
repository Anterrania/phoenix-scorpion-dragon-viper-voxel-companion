# Owner login, encrypted saves, audit chain, e-stop

> Implemented in GDScript on Godot built-ins and tested headless (`tests/security_tests.gd`: 93 checks). It has not been tested on a phone yet. Foxy builds the APKs.

## Access paths (where to find each screen)
| Screen | Route |
|---|---|
| **Admin dashboard** | Radial launcher (right edge) › **12 o'clock ◎ Admin**, or MENU › 🛡 Viper Admin. Opens on the Home tab. |
| **Tickets** | Admin › swipe or tap the **Tickets** tab. Ticket links (`#12`) anywhere jump there. |
| **Wiki** | Admin › **Wiki** tab. |
| **Revisions / timeline** | Admin › **Timeline** tab (tap an event to see its diff, hold to revert). Wiki › page › ⟲ History also lands here. |
| **Proposals** (owner approval) | Radial › **8 o'clock ✔ Proposals**, or MENU › 📜 Proposals. |
| **Security** (lock, auto-lock, PIN, e-stop, audit, backup) | Radial › **2 o'clock 🛡 Security** (gold shield). The PIN pad also opens at app start when saves are encrypted. |
| Old owner-code box | MENU › 🧑 Avatar › owner code field (still works; on a phone with no PIN set it continues straight to the set-PIN step) |

Radial order, clockwise from 12: Admin · Security · Chat · Map · Proposals · Menu. It's collapsed to the hub until you tap it.

## Owner login
- `Profile.is_owner()` = role `owner` on this device **and** an unlocked owner session (`OwnerVault.is_unlocked()`). `EveCore.owner_ok()`, `EveCore.decide()`, `EveBrainCell.unlock()` (Foxy's owner-only patch, merged in #18), Inventory owner items and estate owner checks all go through it.
- Owner-only *cosmetics* (the Sovereign avatar preset) use `is_owner_device()`, so Phoenix's look doesn't disappear when the session auto-locks.
- **Old owner code** (starts `phoenix-`, checked against `Profile.OWNER_CODE_SHA256`, case-insensitive): on a phone without a PIN it opens an owner session and the PIN pad moves straight to **Set a PIN**. The code is kept as its own key slot, so it keeps working afterwards too, until the owner taps *Hold to retire the old owner code*.
- PIN: 6+ digits, or a passphrase of 8+ characters. KDF: PBKDF2-HMAC-SHA256, 16-byte random salt, **310,000 iterations** (about 0.4 s on desktop, a few seconds on a mid-range phone, stored per slot so it can be tuned). Argon2 isn't built into Godot.
- Backoff: after 5 wrong tries, wait 30 s, doubling each time up to 1 h. This is persisted.
- **Auto-lock: 30 minutes by default.** The owner can change it in Security › Owner settings (5/15/30/60/120; the API clamps to 1–240). Any touch or keypress resets the timer.
- **Accessibility:** the PIN pad is pure black and white with a 3×4 keypad of 160×128 px keys, 60 px digits, 72 px masked dots, a 44 px prompt and 34 px error text, gold focus rims, and an ABC switch to a large 104 px text field for passphrases or the old code.
- Biometric: `BiometricHook` is a stub. Godot has no built-in biometric API and no plugin is bundled. The design for later is an Android Keystore-wrapped data key as an extra vault slot.

## Encrypted saves
- One random 64-byte data key (32 AES + 32 HMAC) is wrapped once per key slot (PIN, old code). Changing the PIN re-wraps the key; saves are not re-encrypted.
- Format: `PXE1 | IV(16) | AES-256-CBC ciphertext (PKCS#7) | HMAC-SHA256(magic|IV|ct)`. Writes go to a tmp file and then rename. A bad MAC returns no data, saves a `.tampered` copy, and refuses to overwrite it.
- Encrypted: `user://eve/*` (Eve cores and proposals), `user://brains/*/memory/*.jsonl` (facts and episodes), `user://memory/*.json` (chat memory), `user://viper/*` (tickets, wiki, revisions, sign-up), `user://estate.cfg`.
- Plaintext on purpose, but included in every encrypted backup: `profile.json` (name and avatar), `settings.cfg` (music prefs and settings), wardrobe and avatar data. The guest UI needs them before unlock and they aren't sensitive.
- Two lock levels: the **owner session** auto-locks, but the data key stays loaded so companions keep their memories. **Lock & seal** also drops the key. After an app restart, the PIN pad asks once. "Cancel" continues as a guest: encrypted memories stay closed, writes to sealed files are refused (never clobbered), and new files wait in memory and are encrypted on unlock.

## Migration (old phone → encrypted)
Runs once, right after the first PIN is set:
1. An **encrypted backup of everything in user://** (except caches and old backups) goes to `user://backups/pre_encrypt_<time>.pxb`.
2. Each target file is encrypted, read back, decrypted and compared byte-for-byte before it replaces the original. Any mismatch restores the original and is reported.
3. A manifest is written to `vault.json` (`migration`). Running it again does nothing.
Security › Export encrypted backup writes `user://backups/export_<time>.pxb`. `SaveMigration.restore(path)` is owner only. Backups need the PIN (or old code) to open: **if both are forgotten, the data cannot be recovered.**

## Audit chain
See [modules/QUANTUM_LATTICE.md](modules/QUANTUM_LATTICE.md) §1. It's shown in Admin › Home › Security and in the Security panel.

## E-stop / kill switch
Security › **■ STOP ALL COMPANIONS** (one tap, anyone, persisted) pauses companion free roam, `BrainLearner`, `BrainCore.propose` / `propose_to_owner`, and all tool execution (`AgentBrain.dispatch_tool`). Chat still works. Resuming is owner-only and needs a 0.6 s hold.

## Limits
- This is a local device protection, not an account system. Multiplayer needs server-side auth (Aurora-model grid).
- An attacker who can run code inside the unlocked app can read the key from memory.
- PBKDF2 is weaker against GPUs than Argon2. A 6-digit PIN alone is guessable offline by someone who has the files, so a passphrase is better for long-term secrets.
- Full encryption write-up, review findings and fixes: [ENCRYPTION.md](ENCRYPTION.md).
