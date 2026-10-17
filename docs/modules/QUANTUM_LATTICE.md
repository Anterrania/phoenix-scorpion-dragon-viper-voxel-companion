# Quantum Lattice (concept notes)

> **Speculative. These are concept notes only, waiting for Phoenix's original design.** Nothing here is quantum. The only part that exists in code is the hash-chained audit log described in section 1. Once Phoenix shares the original "quantum lattice" design, it replaces these notes (tracked as VIPER-7 and VIPER-9).

## 1. What exists today: the audit "lattice" (a hash chain)
- Every in-app revision (`RevisionStore`: tickets, wiki pages, brain cells, world-edit summaries, profile) stores `prev`, the SHA-256 of the exact stored text of the revision before it. The first one points to 64 zeros. `head.json` keeps the hash of the newest line.
- `RevisionStore.verify_chain()` walks the log. It catches an edited entry (at the next revision), deleted or reordered entries, and a truncated tail (by comparing against the head hash). Revisions written before the chain existed are counted as "legacy" and the chain starts after them.
- The Admin dashboard (Home › Security card) and the Security panel show ✓ verified or ✗ broken at rN.
- Limits: this is tamper-*evident*, not tamper-*proof*. Someone holding the device key could rewrite the whole chain consistently. The fix is to anchor head hashes somewhere outside the device (for example, the grid services in ARCHITECTURE_AURORA_MODEL.md) or to sign them.
- The name "lattice" is ours. It's a linear chain, not a lattice in the cryptographic sense. A real lattice or DAG (several devices merging histories, Merkle-DAG style) would come with grid sync.

## 2. Future: post-quantum cryptography (research only)
- Today: AES-256-CBC + HMAC-SHA256 for saves, and PBKDF2-HMAC-SHA256 for the PIN. Symmetric AES-256 and SHA-256 are generally considered fine against quantum attacks (Grover's algorithm roughly halves their effective strength).
- What a quantum computer would break is public-key crypto (RSA and elliptic curves), which we would only need for **grid login, device-to-device sync and signed audit heads**. NIST standardised replacements in 2024:
  - **ML-KEM** (FIPS 203, from CRYSTALS-Kyber) for key exchange and encapsulation.
  - **ML-DSA** (FIPS 204, from CRYSTALS-Dilithium) for signatures, for example signing audit-chain heads and brain-cell bundles.
  - SLH-DSA (FIPS 205, SPHINCS+) is a hash-based signature backup option.
- Godot has none of these built in. They would need a GDExtension (for example a wrapper around liboqs) or a server-side implementation. The likely first use is hybrid key exchange (X25519 + ML-KEM) for grid TLS, which follows mainstream TLS stacks.
- None of this is planned for the current milestones.

## 3. Open questions for Phoenix
- What did "quantum lattice" mean in the original design: storage, identity, companion minds, or world simulation?
- Should brain cells and memories be signed per companion (ML-DSA), so a Grok Bot or grid server can verify where they came from?
