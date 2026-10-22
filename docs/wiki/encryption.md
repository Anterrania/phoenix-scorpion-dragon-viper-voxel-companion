---
title: How Your Saves Are Protected
slug: encryption
tags: [encryption, security, owner, pin, backup]
audience: owner
status: built
updated: 2026-10-17
sources: [scripts/security/crypto_box.gd, scripts/security/owner_vault.gd, scripts/security/secure_file.gd, scripts/security/save_migration.gd, docs/ENCRYPTION.md]
ticket: VWGAP-4
---

# How Your Saves Are Protected

> **Built** (headless-tested). The full technical write-up is [ENCRYPTION.md](../ENCRYPTION.md).

## In one line
After you set a PIN, your companions' memories, proposals, tickets, wiki, estate, social and travel saves are locked with strong encryption. Only your PIN (or the old owner code) opens them.

## What's locked
- Locked: memories, proposals, admin data, estate and covenant, community and messages, landmarks, imports, backups.
- Not locked: your name and look, music and settings, and wardrobe. The app needs these before you unlock, and they're inside every encrypted backup.

## Tips
- **Use a passphrase** (8+ characters), not just 6 digits. It's much harder to guess.
- After you set a PIN, retire the old owner code: Radial › **Security** › *Hold to retire the old owner code*.
- Make a backup: Security › **Export encrypted backup**.
- If you forget the PIN *and* the old code, nobody can open the saves. Not even us.

## Not yet
- Fingerprint unlock and the phone's hardware key store are **Planned**.

See [Owner Lock](owner-lock.md).
