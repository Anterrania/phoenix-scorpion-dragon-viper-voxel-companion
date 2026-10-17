---
title: Owner Lock
slug: owner-lock
tags: [owner, security, pin, encryption, lock]
audience: owner
status: built
updated: 2026-10-17
sources: [scripts/security/owner_vault.gd, scripts/security/crypto_box.gd, scripts/admin/security_screen.gd, docs/SECURITY.md]
ticket: VIPER-1
---

# Owner Lock

> **Built** (headless-tested). Not yet tested on a phone.

## Open it
- Radial › **Security** (gold shield, 2 o'clock).
- The PIN pad also opens at app start when saves are encrypted.

## Set a PIN
1. Tap **Set a PIN now**.
2. Enter 6+ digits, or tap ABC for a passphrase of 8+ characters.
- Change it later with **Change PIN**.

## Lock
- **Lock now** ends the owner session. Companions keep their memories.
- **Lock & seal saves** also closes the encrypted files.
- Auto-lock: 30 min by default.
- **Unlock** opens it again with your PIN.

## Safety
- 5 wrong tries → wait 30 s, doubling up to 1 h.
- **Export encrypted backup** saves a backup. It needs your PIN.
- **If you forget the PIN and old code, data cannot be recovered.**
- **Hold to retire the old owner code** turns off the old `phoenix-` code.

## Kill switch
- **■  STOP ALL COMPANIONS**. Resume with **Hold to resume companions** (owner).

Details: [SECURITY.md](../SECURITY.md)
