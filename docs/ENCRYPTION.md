# Viper OS encryption, exactly as implemented on main

> VWGAP-4, 2026-10-17. Read from `scripts/security/` (crypto_box, owner_vault, secure_file, save_migration, autonomy_guard, biometric_hook), `scripts/autoload/profile.gd`, `scripts/admin/tracker/revision_store.gd`, [SECURITY.md](SECURITY.md) and [modules/QUANTUM_LATTICE.md](modules/QUANTUM_LATTICE.md). This page describes algorithms and formats. It contains no keys, PINs, codes or hashes of codes. Plain-language version: [wiki/encryption.md](wiki/encryption.md).

## 1. What's encrypted and what isn't
| Data | Path (under `user://`) | Encrypted? |
|---|---|---|
| Eve cores + owner proposals | `eve/*.json` | yes, once a vault exists |
| Brain memory (facts, episodes) | `brains/*/memory/*.jsonl` | yes |
| Chat memory | `memory/*.json` | yes |
| Tickets, wiki, revisions, sign-up | `viper/*.json`, `viper/*.jsonl` | yes |
| Estate / region / parcel settings, covenant | `estate.cfg` | yes |
| Social (profiles, friends, messages, groups), tier roles | `social/*.json` | yes (now also migrated, fix F7) |
| Landmarks, home, teleport history; parcel object registry (ParcelTools) | `world/*.json` | yes (SecureFile; migrated, fix F7) |
| OAR/IAR import log, heightmaps, notecards | `interop/**.json` | yes (new store, SecureFile) |
| Backups | `backups/*.pxb` | yes, the whole archive is one sealed box |
| Profile (name, avatar, **role**) | `profile.json` | **no**, needed before unlock for the guest UI |
| Settings, music prefs, wardrobe | `settings.cfg`, `wardrobe.json` | **no** (inside every encrypted backup) |
| Vault metadata | `security/vault.json` | **no**, holds only salts, iteration counts, wrapped keys, the key check value, and fail counters |
| E-stop state | `security/estop.json` | **no** |
| Shipped seeds | `res://data/**` | no (public) |

"Once a vault exists": before the owner sets a PIN, `SecureFile` writes plaintext exactly as before. That's on purpose, so guests and old installs keep working.

## 2. Algorithms, modes and integrity
All built from Godot 4.7 built-ins (`Crypto`, `AESContext`, `HashingContext`). There are no plugins.
- **Cipher:** AES-256-CBC with a fresh random 16-byte IV per seal (`Crypto.generate_random_bytes`, the OS CSPRNG), PKCS#7 padding.
- **Integrity:** HMAC-SHA256 over `magic | iv | ciphertext` (encrypt-then-MAC). `CryptoBox.open` checks the MAC **before** decrypting, with a constant-time compare (`CryptoBox.equal`). The padding check runs only after the MAC passes, so there's no padding oracle.
- **Key split:** every 64-byte key is used as 32 bytes for AES plus 32 bytes for HMAC. Wrapping keys come from `subkeys(master)`: `enc = HMAC(master, "phoenix/enc")`, `mac = HMAC(master, "phoenix/mac")`.
- **KDF:** PBKDF2-HMAC-SHA256 (RFC 8018), written in GDScript on top of `Crypto.hmac_digest`. 32-byte output, 16-byte random salt per slot.
- **Hashes:** SHA-256 for the audit chain and asset ids.

## 3. Key hierarchy
```
PIN / passphrase  ──PBKDF2-HMAC-SHA256(salt_slot, iter_slot)──►  slot master (32 B)
                                                                   │ subkeys()
                                                                   ▼
                                                       KEK = {enc 32 B, mac 32 B}
                                                                   │ CryptoBox.seal
                                                                   ▼
   vault.json slot.wrapped  =  sealed( DEK 64 B = enc 32 B + mac 32 B )
                                                                   │
                       every save, backup:  CryptoBox.seal(DEK.enc, DEK.mac, plaintext)
```
- **Slots:** `pin` (PIN or passphrase) and `legacy` (the old `phoenix-` owner code, case-insensitive), each wrapping the **same** DEK. Changing the PIN re-wraps the DEK only. Retiring the old code deletes its slot.
- **Key check value (new, fix F1):** `dek_check = base64(HMAC-SHA256(DEK.mac, "phoenix/dek-check"))`. This lets the future biometric path recognise the real DEK without storing it.
- **The DEK is created once** (`CryptoBox.random_bytes(64)`) at PIN setup and never leaves RAM unwrapped.

## 4. Iteration counts
- `CryptoBox.DEFAULT_ITERATIONS = 310000` (OWASP's 2021 PBKDF2-SHA256 figure; OWASP raised it to 600,000 in 2023, so raising the default for new slots is a cheap win, VWGAP-6). It's stored per slot (`iter`), so it can be tuned per device without breaking old slots.
- Cost: about 0.4 s on desktop, a few seconds on a mid-range phone (GDScript loop). Tests use 1,000.

## 5. File formats
- **Sealed box** (`PXE1`): `"PXE1"(4) | IV(16) | ciphertext(16·n) | HMAC(32)`. `CryptoBox.is_sealed` checks the magic and minimum length.
- **vault.json** (plaintext JSON): `{v: 1, slots: [{kind, kdf: "pbkdf2-hmac-sha256", iter, salt(b64), wrapped(b64 PXE1)}], lock_minutes, fails, retry_at, created, dek_check, migration: {at, backup, files, ok}}`.
- **Backup** `.pxb`: one PXE1 box whose plaintext is JSON `{format: "phoenix-backup/1", created, label, files: {relpath: base64 raw bytes}}`. `vault.json` is left out because you need it to open the backup.
- **Writes:** tmp file → atomic rename (fix F2). A bad MAC never returns data: the file is copied once to `<path>.tampered`, and later writes to it are refused.

## 6. Backup and migration
`SaveMigration.migrate()` runs once after the first PIN: 1) an encrypted backup of all of `user://` (except caches and old backups), 2) seal each target file → read back → compare byte-for-byte → replace (a mismatch restores the original), 3) a manifest in `vault.json`. Running it again does nothing. `restore()` is owner-only and skips paths containing `..`. **If the PIN and the old code are both forgotten, the data can't be recovered.** That's by design.

## 7. Lock states
| State | DEK in RAM | Owner session | What works |
|---|---|---|---|
| No vault | – | legacy code only | plaintext saves, as before |
| Locked after launch | no | no | guest UI. Sealed reads return "" (locked). Writes to sealed files are refused. New files wait in memory and are flushed encrypted on unlock |
| Unlocked | yes | yes | everything. `Profile.is_owner()` is true |
| Auto-locked (30 min idle, 1–240) | yes | no | companions keep memories. Owner powers are off |
| Lock & seal (`lock_all`) | dropped | no | like "locked after launch" |
Brute-force backoff: 5 free tries, then 30 s doubling up to 1 h, persisted in `vault.json`.

## 8. Threat model and limits
**Protects against:** someone reading copied app files (backup extraction, a lost phone without root, a cloud backup) without the PIN. It also protects against casual tampering with saves (the MAC), and against anyone holding an unlocked phone after it auto-locks.

**Does not protect against:**
- **A rooted phone or malware inside the app process.** While unlocked, the DEK sits in GDScript memory. `lock_all` drops the references, but Godot doesn't guarantee the bytes are wiped.
- **Offline guessing of short PINs.** `vault.json` holds the salt and a MAC-checked wrapped key, so an attacker with the file can test PINs at GPU speed. A 6-digit PIN (10⁶ options) falls quickly, even at 310k PBKDF2 rounds. The in-app backoff doesn't help offline. **Use a passphrase**, and see Keystore below.
- **No hardware keystore yet.** Nothing is bound to the device's TEE or StrongBox.
- **Plaintext metadata.** Profile role, settings, wardrobe, e-stop, and the vault's fail counters are unauthenticated.

## 9. Findings from this review
| # | Finding | Severity | Status |
|---|---|---|---|
| F1 | `OwnerVault.unlock_with_dek()` (biometric entry point) accepted **any** 64 bytes and opened an owner session with a bogus key. No UI reached it, but any in-process code could. | medium | **fixed:** it now requires a matching key check value (and the loaded DEK, if any). Older vaults gain the check on the next PIN unlock. Tests: `tests/interop_tests.gd` (crypto F1) |
| F2 | `SecureFile.write_text` did `remove(path)` then `rename(tmp)`, so a crash in between left no file (the data only in `.tmp`) | low–medium | **fixed:** `SecureFile.replace_file` renames over the old file first (atomic on POSIX and on Godot's Windows backend), falling back to remove + rename. Also used for `vault.json`. Test: crypto F2 |
| F7 | Migration targets missed `social/`, `world/` and `interop/`, so social data written before the first PIN stayed plaintext until rewritten | low–medium | **fixed:** added to `SaveMigration.TARGETS`. Test: crypto F7 |
| F3 | The MAC doesn't bind the file path or a version counter, so someone with file access can **swap** sealed files or **roll back** a file to an older sealed copy undetected. The revision chain only notices if `revisions.jsonl` and `head.json` are rolled back to different points | medium | open: needs a `PXE2` format with associated data (relative path + per-file counter in the vault). Format change, so not done here (VWGAP-6) |
| F4 | Backoff counters live in plaintext `vault.json`, and timing uses the wall clock. Resetting the file or the system clock clears the wait | low | open. It only limits in-app guessing. Real protection is Keystore + passphrase |
| F5 | The legacy owner code is checked against an unsalted SHA-256 constant in the public repo (`Profile`), and it stays a key slot until retired | medium if the code is weak | fixed (SEC-FIX-1): constant removed; legacy code only bootstraps the first PIN via a salted PBKDF2 record kept out of the repo; refused once a pin slot exists; legacy slots migrated away |
| F6 | 6-digit PINs can be brute-forced offline (see §8) | inherent | mitigated by passphrases now, Keystore later |
| F8 | Keys aren't zeroed in RAM on lock | inherent to GDScript | documented |
| – | Per-file IVs: a fresh 16-byte CSPRNG IV per seal. CBC IV reuse odds are negligible. Using one DEK for all files is fine at this volume | ok | no change |
| – | Padding is checked after a successful MAC, and only the last byte is examined. That's safe because the MAC gates it | ok | no change |
Side note: a `static func reload()` on a `class_name` script collides with `Script.reload()` and silently resets static paths (found independently by the 2026-10-17 audit for `Estate`). The new stores use `reload_data()`.

## 10. Recommended improvements (in order)
1. **Android Keystore / StrongBox** through an Android plugin (v2): a non-exportable AES key with `setUserAuthenticationRequired`, used to wrap the DEK as a `biometric` slot (`BiometricHook` already describes this), plus a device-bound slot that makes offline PIN guessing useless off the phone.
2. **Argon2id** (memory-hard) instead of PBKDF2 for new slots, via a small GDExtension (libsodium or the reference implementation). Keep `kdf` per slot so old slots still open.
3. **PXE2 with associated data** (path + counter), fixing F3. Optionally move to AES-256-GCM or XChaCha20-Poly1305 when a vetted binding exists (Godot has no AEAD built in).
4. **Authenticate vault metadata** (fail counters, lock minutes) with an HMAC under a Keystore key.
5. Retire the legacy code by default after PIN setup (F5).
6. **Post-quantum (research only):** symmetric AES-256/SHA-256 are fine. Grid login, device sync and signed audit heads would use hybrid X25519 + ML-KEM (FIPS 203) and ML-DSA (FIPS 204) signatures. See QUANTUM_LATTICE §2.

## 11. Audit chain (for completeness)
`RevisionStore` records carry `prev = SHA-256(previous stored line)` (genesis = 64 zeros), and `head.json` keeps the newest hash. Both files are sealed by `SecureFile`. It's tamper-evident, not tamper-proof: anyone holding the DEK can rewrite the chain consistently. The fix is anchoring heads off-device or signing them.
