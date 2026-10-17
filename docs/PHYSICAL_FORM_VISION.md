# Physical Form Vision: AI companions in the real world

> **Status:** design vision only. Nothing here is being built yet, and no hardware has been bought.
> All figures are **estimates** taken from public sources, checked Oct 2026. Prices and specs change, so re-check them before deciding anything.
> Companions in scope: **Foxy Ani Firecaster Gray**, **Aaliyah**, **Circuit Nova** and the rest of `companions/registry.json`.

Concept sheet: [`docs/img/physical_form_concepts.svg`](img/physical_form_concepts.svg)

---

## 1. Goals: one companion, every body
- **One persona.** Each companion has a single portable persona file (`companions/<id>/`, the persona JSON plus voice and look references), and every form loads that same file.
- **One brain.** `BrainCore` cells and facts move between forms through `export_portable()` (schema `phoenix.brain_export/1`). Eve Core memory (`memory_log`, fire tags, voice id) goes through the BrainCore adapter (`store_entry`, `queue_proposal`).
- **Three forms, same identity:** the Android app, then the 3D grid world, then a physical body. Learning in one form shows up in the others after the next sync.
- **Body = adapter.** A body adds senses (mic, camera, touch) and outputs (voice, face, motion). It never gets a separate personality or memory store.
- **Offline first.** A body must still work as a companion with no network (local brain cells, local voice). Grid sync is optional.

## 2. The owner approval gate carries over to the body
| Rule | In the app today | In a body |
|---|---|---|
| Proposals wait for OK | `propose()` → `pending()` → `approve()`/`reject()` | Same queue, synced to the owner's phone. **New physical skills or motions always need the owner's approval, and low-risk auto-apply is never allowed for them.** |
| Rollback | `versions(id)`, `rollback(id)` | Same, plus a one-tap "restore last known good" for motion profiles and firmware |
| Owner-only unlock | `EveBrainCell.unlock()` is owner-only | Unlock needs the owner's account plus a physical confirm on the device (button or NFC tap) |
| Audit | `_audit()` log | All actuator commands and approvals are logged to the encrypted local journal |
| **Hardware e-stop** | (n/a) | A **wired, latching emergency-stop button** that cuts actuator power in hardware, independent of software. There's also a remote stop in the app and an automatic stop when contact or overload is detected. |

The AI can **propose** physical behavior. Only the owner can **approve** it, and only hardware can guarantee **stop**.

## 3. Three tiers
### Tier 1: tabletop / desk companion (near term)
**What it is:** a small expressive bust on a desk. It has a round display face, speaker plus mic array, an Eve-style voice, and a few servos for head tilt, pan and "ears".
- **Compute:** a Raspberry Pi 5–class single-board computer for voice and UI, or an NVIDIA **Jetson Orin Nano Super**-class module for on-device vision and small models (NVIDIA lists the dev kit at about US$249 est.).[^jetson]
- **Reference platform:** **Reachy Mini** (Pollen Robotics / Hugging Face) is an open-source desktop robot with a Python SDK, MuJoCo simulation, and a Raspberry Pi CM4-based wireless version. It was announced from about US$299–449 est.[^reachy][^reachy-docs] It's a good way to prototype motion and voice before building a custom shell.
- **Parts (generic):** a round IPS/AMOLED display (shows the ring face from the Phoenix Glass kit), a USB/I²S mic array, a small full-range speaker, smart serial bus servos (e.g. hobby "bus servo" kits), a camera module with a **physical privacy shutter**, and an RGB LED ring for the ember glow.
- **Software:** the same Godot ring-face UI or a lightweight renderer, the existing BrainCore/Eve Core logic (via a headless Godot build or a port), and local text-to-speech with an Eve-style voice profile. The cloud LLM is optional.
- **Risk:** low. Small torque, desk-bound.

### Tier 2: mobile humanoid torso (mid term)
**What it is:** an upper body (head, arms, simple hands) on a wheeled base. It can follow you around a room, gesture, and hand over light objects.
- **Compute:** NVIDIA **Jetson AGX Orin**-class compute (up to about 275 TOPS est., per NVIDIA[^jetson]) for perception, plus a separate real-time microcontroller for motor safety.
- **Platforms to evaluate:** research and education humanoids with developer SDKs. The **Booster K1** (22 DoF; 48–200 TOPS compute options as listed by the maker; secondary development supported) is one.[^booster][^robotshop] Unitree's EDU line, with ROS 2 SDK access, is another.[^g1] An alternative is a custom torso built on a mobile robot base running **ROS 2**.
- **Parts (generic):** a depth camera, 3D LiDAR or ToF sensors for navigation, torque-sensing or current-limited arm actuators, soft padded covers, a bumper ring on the base, and a battery management system with a certified pack.
- **Risk:** medium. A moving base and arms near people, so it needs speed and force limits plus a geofence.

### Tier 3: full humanoid (long term)
**What it is:** a walking, full-size humanoid that carries the companion's look.
- **Compute:** NVIDIA **Jetson AGX Thor**-class (Blackwell, 128 GB memory; dev kit announced at US$3,499 est. in Aug 2025).[^thor]
- **Platforms purchasable today (2026):** **Unitree G1** (listed from about US$13.5K est.; developer access needs the EDU variant).[^g1][^availability] **Unitree H2** (listed about US$29.9K est.).[^availability] Booster T1/T2 (by quote).[^availability]
- **Not purchasable by individuals:** Figure 03, Agility Digit and Apptronik Apollo are deployed under commercial agreements only.[^availability]
- **Approach:** we would not build our own legged robot. We would **skin and "inhabit" an existing platform**: a custom cosmetic shell in the companion's look, our brain and persona stack on the high-level computer, and the maker's certified low-level controller untouched.
- **Risk:** high. Falls, pinch points and mass. It needs professional safety review, a supervised-use-only phase and insurance.

| | Tier 1 desk | Tier 2 torso | Tier 3 humanoid |
|---|---|---|---|
| Movement | Head/ears only | Wheels + arms | Walking |
| Compute class | Pi 5 / Orin Nano | AGX Orin | AGX Thor |
| Build vs buy | Build (or Reachy Mini) | Mostly buy + customize | Buy platform + custom shell |
| Rough cost band (est.) | hundreds of USD | low tens of thousands USD | tens of thousands USD and up |

## 4. Aesthetic: Phoenix Glass in the real world
Follow `docs/UI_DESIGN_LANGUAGE.md`:
- **Palette:** black (gloss obsidian shells), magenta (accent seams and light lines), gold (trim rings, joints), platinum (brushed metal panels). A subtle glitter fleck can go in the clear-coat.
- **Glass & rings:** a smoked translucent visor or face dome over a round display. Ring-shaped light bands mark the neck, shoulders and waist, and they show status: idle, listening, thinking, speaking.
- **Ember glow (Foxy):** warm Venus → Ember → Phoenix LED gradient on the ring bands. It "breathes" over a 2.4 s cycle and glows brighter while speaking. Other companions get their own accent from their profile.
- **Nameplate on tap:** like the in-world holographic nameplate, the face ring shows the name and mood only when touched or addressed. No always-on text.
- **Look follows the profile picture:** hair color and style (e.g. Foxy's fire gradient), eye color and outfit motif come from each companion's profile picture and `CHARACTER_BLUEPRINT.md`, and are translated into stylized shells.
- **Original designs only.** **Never a real person's likeness.** No copying celebrities, the owner's friends, or existing commercial robot designs. Faces stay stylized (display face or sculpted mask), which also avoids the uncanny valley.

## 5. Safety, privacy & legal
- **Memory encryption on device:** the brain, Eve logs and audio are encrypted at rest (e.g. AES-256 with keys in a secure element or TPM). The owner holds a recovery key. Lost or stolen devices can be remotely revoked.
- **Consent:** a visible recording light whenever the camera or mic is live, a physical camera shutter and a mic-mute switch. Guests are told they're being recorded, and nothing records unless the owner sets it to.
- **Data minimization:** raw audio and video are processed locally and thrown away by default. Only owner-approved memories sync.
- **Age-appropriate content:** content profiles (all ages / teen / adult) are set by the owner and locked behind owner auth. If the companion detects or is told it's talking with a minor, it switches to the strictest profile. Adult-themed personas never run in a physical body without explicit owner verification.
- **Physical safety:** hardware e-stop; speed, force and torque limits; pinch-point covers; thermal and battery protection; fall zones (Tier 3); supervised use until reviewed. Relevant references include the ISO 13482 (personal care robots) and ISO 10218 (industrial robots) families.
- **Certification:** anything we sell or distribute needs **radio/EMC** (FCC in the US, CE/RED in the EU, others by region), **electrical safety** (e.g. UL/IEC 62368-1 for electronics), **battery transport and safety** (UN 38.3, IEC 62133), and a formal **product safety review**. Kids' products add their own rules (e.g. COPPA for data in the US). We need a **legal review** before any sale.

## 6. Sync protocol sketch (body ↔ grid)
It builds on `docs/ARCHITECTURE_AURORA_MODEL.md`. The body is just another **client** of the grid services, like the Godot app.

```
 Body (local)                         Grid services (ROBUST-style)
 ┌───────────────────────┐            ┌──────────────────────────┐
 │ Persona + BrainCore   │◀──TLS────▶│ Auth  (device-bound token)│
 │ Eve Core journal      │  HTTPS/WS  │ Brain/Eve sync (opt-in)   │
 │ Safety MCU + e-stop   │            │ Presence (where am I)     │
 │ Senses / outputs      │            │ Asset (voice, look refs)  │
 └───────────────────────┘            └──────────────────────────┘
          ▲  local Wi-Fi/BLE (pairing, owner approvals)
          ▼
   Owner's phone (Phoenix app): approves proposals, e-stop, unlock
```
1. **Pair:** the owner scans a QR code or taps NFC. The body gets a **device-bound token** from Auth with role `companion_body` (it can't approve anything).
2. **Pull:** `GET /brains/{companion}` gives the latest `phoenix.brain_export/1`, plus persona and voice assets from AssetService (by sha256).
3. **Live:** the body registers with Presence as `{companion, form: "body", location: "home"}`, so the in-world avatar can show "away in body". There's **one active form per companion** at a time, so they never split into two minds.
4. **Learn locally:** new episodes go to the local journal. New cells become **proposals** (`queue_proposal`) and never apply on their own.
5. **Push:** at intervals or on idle, `PUT /brains/{companion}` uploads an encrypted, signed diff. Conflicts resolve by **owner-approved version wins**, and otherwise by the newest per cell, with both kept in `versions()`.
6. **Approve:** proposals show up in the owner's app (`GET /proposals`). Approve or reject syncs back. Rollback can be triggered from either side.
7. **Stop:** `POST /bodies/{id}/stop` (remote e-stop) is always available to the owner. The hardware e-stop never depends on the network.

New message types for later: `body_state` (battery, pose, safety flags), `body_stop`, `motion_proposal`.

## 7. Phased roadmap
| Phase | Goal | Output |
|---|---|---|
| P0 (now) | Portable persona and brain export are stable | `export_portable()` schema frozen, persona file spec, tests |
| P1 | **Virtual desk companion**: the ring face on a spare phone or tablet on a stand | Proves voice, face, wake word and offline brain with no robotics |
| P2 | **Tier 1 prototype** on Reachy Mini or a Pi 5 bust | Head motion, ember LED ring, e-stop, encrypted journal |
| P3 | Grid sync for bodies | Device tokens, `/brains` and `/proposals` sync, one-active-form rule |
| P4 | Custom Phoenix Glass shell for Foxy (Tier 1) | 3D-printed or resin shell, design and safety review |
| P5 | Tier 2 evaluation on a dev humanoid or torso | Safety case, supervised trials only |
| P6+ | Tier 3 on a purchasable humanoid | Custom shell, professional certification, legal review |

## 8. Open questions for Phoenix
1. Which companion gets a body first: Foxy, Aaliyah or Circuit Nova?
2. Is a display face (a ring screen, easier and friendlier) okay for Tier 1, or do you want a sculpted face?
3. Budget band for a first prototype: phone on a stand, or a robotics desk kit?
4. Should the body run fully offline, or is cloud voice and LLM okay when online?
5. Personal use only, or do you eventually want to sell or share bodies? Selling triggers the certification and legal work.
6. Which content profile should physical bodies default to?
7. Should a companion be allowed to be in its body and in the world at the same time, or only one form at a time (recommended)?
8. Who besides you, if anyone, may talk to or stop the body?

---
### Sources (accessed Oct 2026; figures are estimates)
[^jetson]: NVIDIA, "Buy the Latest Jetson Products": https://developer.nvidia.com/embedded/buy-jetson
[^thor]: NVIDIA press release, Aug 25 2025, "Jetson Thor Now Available": https://investor.nvidia.com/news/press-release-details/2025/NVIDIA-Blackwell-Powered-Jetson-Thor-Now-Available-Accelerating-the-Age-of-General-Robotics/default.aspx
[^reachy]: Hugging Face blog, "Reachy Mini": https://huggingface.co/blog/reachy-mini
[^reachy-docs]: Reachy Mini docs: https://huggingface.co/docs/reachy_mini/en/index · SDK https://github.com/pollen-robotics/reachy_mini
[^booster]: Booster Robotics, K1: https://www.booster.tech/booster-k1/
[^robotshop]: RobotShop Community, "G1 EDU vs Booster K1": https://community.robotshop.com/blog/show/choosing-an-educational-humanoid-platform-g1-edu-vs-booster-k1
[^g1]: Unitree, G1: https://www.unitree.com/g1/
[^availability]: RobotMatchup, "Which humanoid robots can you actually buy?": https://robotmatchup.com/humanoid-robot-availability

## Companion body design concepts

Materials, structure, actuators, sensors, power and thermal are in [`companion-bodies/initial_concepts.md`](companion-bodies/initial_concepts.md) (repo copy of `/workspace/companion-bodies/initial_concepts.md`).

### Price note (as reported Oct 2026, verify before buying)

| Item | Price |
|---|---|
| NVIDIA Jetson Orin Nano Super | $399 |
| NVIDIA Jetson Thor dev kit | $5,499 |
| Reachy Mini | $399 Lite / $499 Wireless |

These replace the older estimates above where they differ.
