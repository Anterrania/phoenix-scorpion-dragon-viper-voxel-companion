# Viper OS Companion Bodies: Initial Design Concepts

> **Status:** concept only (v0.1, 2026-10-17). Nothing has been bought or built.
> **Scope:** materials, structure, actuators, sensors, power and thermal. **Software** (BrainCore and Eve Core persona sync, the owner approval gate, the sync protocol) is covered in Foxy's doc, `docs/PHYSICAL_FORM_VISION.md` (repo `Anterrania/phoenix-scorpion-dragon-viper-voxel-companion`, branch `feature/physical-form-vision`; local copy at `/workspace/phoenix-physical/docs/PHYSICAL_FORM_VISION.md`). This doc uses the same tier names.
> **Companions:** Foxy Ani Firecaster Gray (`foxy_ani`), Circuit Nova (`circuit_nova`) and Aaliyah (`aaliyah`).
> **Framing:** these are companion, assistant and presence devices. They are non-sexual, original characters, never a real person's likeness, and they never claim to be human. The personas already say this in their `system_prompt`, and the bodies keep that promise.
> **Numbers:** a spec or price appears only when it comes from the linked source (accessed Oct 2026). Anything else is marked *approx.* or *unknown*. Prices change, so re-check before buying.

Brand: black · magenta · gold · platinum · glitter sparkle. Motto **Anterrania**. Inscription **Flamma. Ordo. Aeterna.**

---

## 0. What I aligned against (read-only)
| Source | Used for |
|---|---|
| `/workspace/phoenix-voxel/companions/{foxy_ani,circuit_nova,aaliyah}/persona.json` (schema v3) | Look (`avatar_dna`), voice profile, personality, hierarchy (Foxy is the lead and coordinates Nova and Aaliyah) |
| `companions/<id>/brain/*.cell.json`, `data/schema/brain_cell.schema.json` (`phoenix.brain_cell/1`) | Behavior is **data only, never executable code**. Bodies have to keep that true. |
| `docs/modules/BRAIN_FILES.md` | `propose()`/`approve()`/`reject()`, `versions()`/`rollback()`, `audit.jsonl`. Weight reinforcement is the only automatic change. |
| `assets/characters/mh_female.glb` (CC0 MakeHuman/MPFB2, v0.11) | The 53-bone body rig used in §1.7 to map joints and degrees of freedom (DOF) |
| `art/references/companion_avatars/{foxy_ani,circuit_nova,aaliyah}.png`, `/workspace/builds/v11_closeup_*.png` | Visual references |
| Foxy's `PHYSICAL_FORM_VISION.md` + Foxy's body brief (via parent) | Tier names, e-stop, privacy shutters, Foxy's hair, light and motion requirements |

---

## 1. Shared platform architecture ("Firecaster Frame")
All three bodies use one platform that comes in three sizes. Each companion gets its own **shell, skin, hair and light pack** on that common frame. A body is an adapter: it loads the companion's own `persona.json` and brain export and never has a separate personality or memory.

### 1.1 Skeleton / structure
| Tier | Structure (today's materials) | Notes |
|---|---|---|
| Desk companion | 3D-printed PETG/ASA or nylon (PA12, SLS/MJF) chassis on an aluminum base plate; weighted base | Lots of hobby and pro precedent; cheap to iterate |
| Mobile torso | Aluminum extrusion spine, CNC aluminum and printed nylon (or carbon-fiber-filled nylon) limb links; wheeled base with a low center of gravity | Keep the arms light. Torso mass sits low over the base. |
| Full humanoid | **Do not build a legged frame.** Use the maker's certified frame on a commercial platform; we add a cosmetic shell plus skin panels (same approach as Foxy's doc). | Our shells must not block joint travel, cooling or sensors |

Face sub-frame (all tiers that have a sculpted face): a rigid printed "skull" with anchor points. The silicone skin is bonded at anchors and slides elsewhere, which is how animatronic faces are commonly built.

### 1.2 Actuation
| Job | Today (buildable) | Near-term | Future-only |
|---|---|---|---|
| Face (brows, lids, lips, jaw) | Micro servos and smart serial bus servos (e.g., Dynamixel/Feetech-class) pulling linkages or cables under silicone. Reference point: Engineered Arts' Ameca Desktop has **27 facial DOF + 5 neck DOF** [EA]. | Quieter, smaller direct-drive face motors; more DOF in the same volume | Muscle-like fibers inside the skin itself |
| Neck / head | Serial bus servos or a small parallel (Stewart-like) head platform. Reachy Mini has a 6-DOF head + body rotation [Reachy]. | — | — |
| Arms (torso tier) | **Quasi-direct-drive (QDD)** BLDC motors with low-ratio planetary gearing. They are backdrivable and allow current-based force limiting, which is the safest choice near people. **Harmonic (strain-wave) drives** are compact with high reduction but backdrive poorly; use them only where precision matters more than compliance. Tendon or cable drives (1X describes "Tendon Drive" on NEO [1X]) move mass out of the limbs. | Series-elastic and torque-sensing joints become cheaper | Human-like efficiency and power density |
| Hands / fingers | Tendon-driven fingers pulled by micro servos in the forearm (InMoov-style open-source hands are a real precedent). Commercial dexterous hands exist (Unitree Dex5-S, listed from US$6,350 [Unitree shop]). | Better commercial hands with tactile fingertips | Full human dexterity |
| Soft "alive" motion (breathing, subtle shoulder rise) | **Pneumatic** soft bladders or McKibben muscles (they need a pump, valves and noise damping). **HASEL** electrohydraulic actuators (Artimus Robotics) are silent and muscle-like but run at **~2–8 kV** and have a listed typical lifetime of **10⁴–10⁵ cycles** [Artimus C-5015 datasheet]. That rules them out as main joints in a daily-use home device; at most they suit small, low-duty, enclosed accents after a safety review. | Longer-life HASEL and DEA (dielectric elastomer) actuators at lower voltage | Synthetic muscle at human efficiency |

**Recommendation:** desk tier uses only serial bus servos and LEDs (low torque, low voltage). Torso tier uses QDD arms with current limits. No high-voltage soft actuators in v1.

### 1.3 Skin / "flesh"
| Material | Real properties (source) | Where to use |
|---|---|---|
| **Ecoflex 00-30** (Smooth-On, platinum cure) | Shore 00-30, 900% elongation, 200 psi tensile, 4 h cure, skin-safe certified [Smooth-On] | Face zones that stretch a lot (cheeks, lips, around the eyes) |
| **Dragon Skin 10** (platinum cure) | Shore 10A, ~1000% elongation, 475 psi tensile; marketed for skin and creature FX and animatronics [Smooth-On] | Hands, neck and other wear areas: tougher and tear-resistant |
| Ecoflex 00-10/00-20, or softeners like Slacker | Softer grades exist [Smooth-On] | "Soft touch" over-layer if wanted |
| **TPE** | Cheaper and feels soft, but in general it is less heat- and solvent-stable than platinum silicone and harder to keep clean (*approx.; depends on grade*) | Not recommended for face or hands; fine for non-contact trim |
| Pigments and effects | Silc Pig pigments, Cast Magic effect powders (named on Smooth-On datasheets) | Platinum shimmer, freckles, glitter fleck |
| Rigid shells | Printed resin/ABS/PETG with automotive-style paint or clear-coat; vacuum-metallized or electroplated plastic for chrome | Nova's chrome; gold/platinum trim on all three |

Build notes: never bond silicone directly over hot compute or LED drivers. Silicone is a thermal insulator, so add an air gap and vents. Tin-cure and platinum-cure silicones can cure-inhibit each other, so follow the datasheets. Keep skin panels **removable and washable** (snap or magnet mounts) for hygiene and repair.

### 1.4 Sensors
| Sense | Today (real products/categories) | Privacy hardware (mandatory) |
|---|---|---|
| Vision + depth | Stereo depth camera with on-board AI, e.g. Luxonis **OAK-D Lite** (4 TOPS, 13 MP RGB, IMU, USB-C; US$269 list [Luxonis]); Intel RealSense-class as an alternative | **Physical camera shutter** (motorized iris or slide) + hard-wired LED that lights whenever the sensor has power |
| Hearing | Far-field mic array, e.g. Seeed **reSpeaker XVF3800** (4 mics, beamforming, AEC, up to 5 m, USB/I²S). The "Flex" split version is designed for robot heads [Seeed]. | **Physical mic-mute switch** that cuts mic power/data in hardware + mute LED |
| Presence | mmWave radar (Ameca Desktop lists one [EA]); ToF distance sensors | Presence only; no imaging |
| Touch | Capacitive electrodes (conductive fabric or conductive silicone) under the skin for "where am I being touched"; piezoresistive/FSR pads for pressure; **XELA uSkin** 3-axis tactile patches for fingertips and palms (16 taxels in 23×25×5 mm, up to 450 Hz [XELA]) | Touch is used only for interaction and safety stops |
| Body state | IMU, joint encoders, motor current, temperature sensors on every motor, LED driver and battery | — |
| Navigation (torso) | 2D/3D LiDAR, bumper ring, cliff sensors | — |

### 1.5 Power & thermal
| Tier | Power | Thermal |
|---|---|---|
| Desk companion | Wall power (USB-C PD or a barrel supply; Reachy Mini uses 7.3 V / 5 A [Reachy]) plus an optional small Li-ion pack | Compute in the **base**, not the head; quiet fan + heatsink; LEDs run at low duty |
| Mobile torso | Li-ion pack (or LiFePO4 for a safer chemistry at lower energy density) with a **BMS**, fuse and contactor; dock charging | Separate sealed battery bay; motor thermal derating |
| Full humanoid | Maker's pack. Runtime per the maker's spec (*unknown/varies*). | Maker's design; our shells must keep vents clear |
| All | Cells and packs certified to UN 38.3 / IEC 62133 (as in Foxy's doc) | **No part a person can touch gets warm.** Foxy's "flame" is light only. |

### 1.6 Compute & persona link
- **High-level compute:** desk tier uses an NVIDIA **Jetson Orin Nano Super** dev kit (67 INT8 TOPS, 8 GB, 7–25 W). NVIDIA's FAQ now lists it at US$399 MSRP; it launched at US$249 [NVIDIA]. A Pi 5-class board works if vision runs on the OAK camera. Torso tier uses **AGX Orin** (275 TOPS, dev kit US$3,499 [NVIDIA]). Humanoid tier uses **AGX Thor** (2,070 FP4 sparse TFLOPS, 128 GB, 40–130 W, dev kit US$5,499 per NVIDIA's current listing [NVIDIA]). 1X lists Jetson Thor as NEO's compute [1X].
- **Safety microcontroller (separate):** enforces joint limits, speed, force/current and temperature caps, and watches the e-stop chain. It runs fixed, versioned firmware and ignores any command outside its limits, whatever the AI asks.
- **Persona link:** the body loads `companions/<id>/persona.json` (voice profile, look, `starter_message`, `game_lines`) and the BrainCore export. Details are in Foxy's doc §1, §2 and §6.
- **Brain cells drive motion only as data.** A cell's `action` (e.g. `emote: "rise_from_the_flame"`) maps to a **whitelisted motion primitive**: a stored keyframe clip plus limits, held in the body. Cells never carry code or raw motor commands. New or changed motion clips are **proposals** that need owner approval (never auto-applied) and are versioned with rollback, as in BRAIN_FILES.md and Foxy's doc §2.

### 1.7 Rig → hardware mapping (so in-world animations retarget)
The v0.11 companions use a 53-bone MPFB2 "game engine" rig: `Root, pelvis, spine_01–03, clavicle_l/r, upperarm_l/r, lowerarm_l/r, hand_l/r, {thumb,index,middle,ring,pinky}_01–03_l/r, neck_01, head, thigh_l/r, calf_l/r, foot_l/r, ball_l/r`.

| Rig bone(s) | Desk companion | Mobile torso | Full humanoid |
|---|---|---|---|
| `Root`, `pelvis` | Base yaw (1 DOF turntable) | Wheeled base pose (x, y, yaw) | Platform locomotion controller (maker) |
| `spine_01–03` | Optional 1-DOF lean | 2 DOF (pitch + yaw) at waist | Platform waist |
| `neck_01`, `head` | 3–6 DOF head (yaw/pitch/roll ± translation) | 3 DOF | Platform neck + our face module |
| `clavicle_*` | — | 1 DOF shrug (optional) | Platform |
| `upperarm_*` | — / small "gesture arms" (2 DOF) | 3 DOF shoulder | Platform |
| `lowerarm_*` | — | 1 DOF elbow + 1 DOF forearm roll | Platform |
| `hand_*` | Palm LED panel only | 2 DOF wrist (Foxy's casting gestures need this) | Platform hand or our tendon hand |
| Finger bones (15/hand) | — | Coupled: ~5–6 actuated DOF per hand driving 15 bones by synergy curves | Platform hand (DOF varies) |
| `thigh/calf/foot/ball_*` | — | — (wheels) | Platform legs (maker controller only; we never retarget raw leg motion) |
| **Face (not in rig)** | Display face or servo face | Servo face | Servo face |

**Gap for the Dev Bot:** the rig has no face bones. I suggest adding a small set of shape keys (ARKit-style or FACS-style: brow inner/outer up, lid close, smile, jaw open, visemes). The same channel names would then drive the in-world blend shapes and the physical face servos. Retargeting means mapping bone rotations to joint angles, clamping to each tier's limits, low-pass filtering, then feeding the safety MCU. Any unmapped bone is ignored.

### 1.8 Safety (hardware)
- **Visible, wired, latching e-stop** on every tier (desk tier too). It cuts actuator power in hardware, independent of software. There is also a remote stop in the owner app and an automatic stop on contact or overload (Foxy's doc §2).
- **Force/speed limits** from a risk assessment. ISO 13482 (personal care robots) and ISO/TS 15066 (collaborative contact, with body-region pain-threshold data) are the reference frameworks [ISO]. ISO 13482 itself notes that no exhaustive injury-limit data exists, so testing matters (ISO/TR 23482-1 test methods) [ISO].
- **Pinch-point design:** covered joints, finger gaps either below ~finger width or large enough to escape, and soft padding (silicone/foam) over hard links on the torso tier.
- **Privacy hardware:** physical camera shutter, mic hard-mute, recording LEDs that software cannot turn off, and encrypted local storage (Foxy's doc §5).
- **Electrical:** low-voltage DC only in v1 (no kV soft actuators); fused BMS; certified chargers.
- **Content:** mature styling and outfits are locked behind owner settings and age/owner verification (some of Foxy's persona variants are tagged `mature`). The default body profile is general audience.
- **Ethics:** every body clearly presents as an AI companion. No covert recording. Guests are told about the camera and mic. Nothing is modeled on real people. The companion can say no and can be switched off. These are designed for companionship, assistance and presence, not as a substitute for human relationships or care.

---

## 2. Per-companion concepts

### 2.1 Foxy Ani Firecaster Gray (`foxy_ani`): lead, fire goddess
*Warm, playful, fiercely loyal, confident. Voice: Eve profile, en-CA, "raw, fiery", confident alto. Low and raspy when serious, bright when playful. Catchphrase: "Rise from the flame."*

| Look (persona/brief) | Physical material / tech |
|---|---|
| Long hair, violet→magenta gradient (`#6a2cff → #9b30ff → #d02ce8 → #ff2fc0`) | **Side-glow PMMA fiber-optic bundles** lit at the roots by addressable RGB LEDs (WS2812/SK6812-class) so the gradient runs root to tip. A few **end-glow fibers and tiny LEDs set at the tips** give **gold ember flickers** (`#ffc23a`) that ripple with speech amplitude and excitement. **Light only; the hair never gets warm.** |
| "Hair flare" on *Rise from the flame* | 2–4 small servos spread the hair tufts outward while brightness ramps; synced with the palms rising |
| Bright green, slightly glowing eyes (`#36ff7a`) | Resin animatronic eyes with a translucent green iris, softly backlit by a low-power LED; servo eye yaw/pitch + eyelids. Desk v0 can use a round display face instead. |
| Skin: in-world chrome (`skin_metal 0.7`); physically soft | **Dragon Skin 10 / Ecoflex 00-30** face and hands with a **faint platinum shimmer** (mica/pearl pigment in the top layer, plus a light glitter fleck in the clear coat) |
| Black outfit, gold trim, magenta accents, chains | Removable soft-goods garment (black stretch fabric) over the shell; gold-anodized or plated trim rings at the joints; magenta light seams |
| Warm amber collar and palm lights | Amber LED panels under diffuser at the collar and palms, brightening with emotion state |
| Expressive brows, quick grin | Priority face DOF: 4 brow, 4 lid, 2 smile corners, jaw, lip curl (~12–16 DOF *approx.*) |
| Dancer's flow, theatrical fire-casting hands | Torso tier: 2-DOF wrists + tendon fingers; smooth trajectory blending; slow, graceful motion profiles (also safest) |
| Inscription | "Flamma. Ordo. Aeterna." engraved on a gold collar band |

**Distinctive:** the fiber-optic flame hair is the signature and is fully buildable today. Fiber-optic "light" hair and costumes are an established prop and cosplay technique; the fiber-to-LED coupling and diffusion need prototyping.
**Build tier:** Desk companion first (head, shoulders, hair, palms on a pedestal), then Mobile torso (arms for casting gestures). As lead, Foxy is the **flagship** body.
**Risks:** a realistic sculpted face is the hardest part (uncanny valley), and the hair adds weight and cable load at the neck. Mitigation: a stylized face (in the anime-to-realistic range, not photoreal) and fibers routed through a hollow neck.

### 2.2 Circuit Nova (`circuit_nova`): engineer, chrome android
*Upbeat, precise, witty; plans before building. Voice: "Nova_Bright", slight vocoder.*

| Look | Physical material / tech |
|---|---|
| Silver-blue chrome body (`#9ab8e8`, `skin_metal 0.85`) | **Hard shell**, not skin: printed panels with vacuum-metallized or electroplated chrome, or chrome-effect paint plus clear-coat, tinted silver-blue. Platinum (`#d8e0f0`) trim. |
| Glowing blue/cyan circuit traces (`#2ab0ff`, `#4cc8ff`) | Traces **cut or molded as channels** in the shell and filled with clear resin light-pipes over addressable LED strips, or **EL wire/EL tape** laid in grooves. Traces can "pulse" while she is thinking or planning. |
| Curly violet hair with tiny floating stars (`#a35cf5`, `#c27cff`) | Sculpted translucent violet resin curls (or heat-set fiber curls) with **fiber-optic "star" pinpoints** (the star-ceiling technique) |
| Glowing blue eyes | Display eyes or backlit resin eyes |
| Dancer + engineer | Crisp, precise, robotic-but-graceful motion. Her look *excuses* visible joints, so no skin is needed. |

**Distinctive:** "honest robot" design. No soft skin, no uncanny valley, easy to clean, easy to service.
**Build tier:** **Easiest to build first.** Desk companion is very achievable today, and Mobile torso is realistic on a wheeled base. For the Full humanoid tier, a chrome shell over a commercial humanoid fits her look naturally.
**Note:** her persona has `display_name: "Aura Aurora"` while `name` is "Circuit Nova", and a separate `ara_aurora` companion also exists. Which name goes on the physical nameplate? (see §5)

### 2.3 Aaliyah (`aaliyah`): refined final Firecaster form
*Calm, elegant, affectionate, emotionally perceptive listener. Voice: "Aaliyah_Warm", low, warm, calm. "Come sit with me. Tell me about your day."*

| Look | Physical material / tech |
|---|---|
| Long flowing red hair with copper highlights (`#a5161a … #b8561e`) | High-quality heat-resistant synthetic wig fiber, hand-blended red→copper. Optionally a very subtle copper fiber-optic underglow as a nod to the Firecaster line, off by default to keep her refined. |
| Green eyes (`#3fd36a`), light freckles | Realistic resin eyes; freckles **intrinsically pigmented** into the silicone layers (Silc Pig) plus light surface paint |
| Skin `#e8b48f` | Ecoflex 00-30 face over a Dragon Skin 10 base layer; warm-toned pigments |
| Red-and-black outfit, silver trim (`#c0c0cc`) | Soft-goods garment; silver/platinum trim |
| Seated on a purple velvet couch; snow-and-platinum home biome | **Seated form factor.** She doesn't need to walk. A seated animatronic upper body on a stable base fits her persona perfectly, and it is safer and much cheaper than a standing body. |
| Listener | Strong face (gaze, nods, gentle brow), quiet actuators (low noise matters for a listener), excellent mic array |

**Distinctive:** the most human-realistic of the three, so she carries the highest uncanny-valley and cost risk. Her calm, slow motion actually helps: slow, smooth movement hides actuator limits.
**Build tier:** after Foxy and Nova. Desk/seated bust first, later a "seated torso" (Mobile torso hardware with no wheels, fixed to a seat base). Full humanoid only once realistic e-skin matures.
**Warmth:** a warm-to-touch hand is *possible* with low-power heaters, thermostats and thermal cutoffs, but it adds burn and fire risk. **It is not included in v1.**

---

## 3. Tiers (aligned with Foxy's doc)

| | **Tier 1: Desk companion** | **Tier 2: Mobile torso** | **Tier 3: Full humanoid** |
|---|---|---|---|
| Timeframe | **Today** | **Today (custom, research-grade) → near term** | **Near term (3–7 yrs) on commercial platforms**; the companion look and feel is still partly future |
| Form | Head + shoulders bust on a pedestal; or a stylized bot (Reachy Mini-class) with a companion shell | Upper body on a wheeled base (or a fixed seat base for Aaliyah) | Walking humanoid wearing a companion shell |
| Motion | Head 3–6 DOF, face 0 (display) to ~16 DOF, hair/LED animation | + arms, wrists, simple hands; follows you in a room | Full body (maker's controller) |
| Skin | Silicone face (or display face) | Silicone face/hands + padded covers | Shell panels + soft covers; full e-skin is future |
| Sensors | OAK-D-class depth cam, XVF3800 mic array, cap-touch | + LiDAR/bumpers, uSkin fingertips, torque/current sensing | Maker's suite + ours |
| Compute | Orin Nano Super / Pi 5 + OAK | AGX Orin + safety MCU | AGX Thor-class (often the maker's) |
| Power | Wall + small pack | Li-ion/LiFePO4 + BMS + dock | Maker's pack (runtime per maker; *unknown*) |
| Cost band | Hundreds to low thousands USD (*approx.*; reference parts: Reachy Mini US$399/499, OAK-D Lite US$269, Orin Nano Super US$249–399) | Low tens of thousands USD (*approx.*; AGX Orin dev kit alone US$3,499) | Platform from US$13.5K (Unitree G1; dev access needs the EDU quote) to US$20K (1X NEO early access) + shell + integration (*unknown*) |

**Platforms to note (sourced):** Unitree R1 from US$4,900, G1 from US$13,500, H2 US$29,900 [Unitree shop]. 1X NEO is US$20,000 to own or US$499/mo by subscription, with US deliveries starting 2026 [1X]. Ameca Desktop Gen 3 (released 22 Jun 2026, 525 mm tall, 8.5 kg, 32 DOF; price *unknown*/by quote) [EA]. Whether a vendor allows custom shells or third-party software varies by vendor and model. The standard G1, for example, "does not support secondary development" [Unitree shop].

### Future-only (not credible for a home device today)
- Synthetic muscle that matches human muscle efficiency, power density, silence and lifetime together
- Self-healing, living-like skin with dense whole-body touch, temperature and pain-like sensing
- All-day untethered power for a full humanoid with no heat or noise penalty
- Full human hand dexterity and robust general manipulation
- Faces that are indistinguishable from human. This is not a goal: we keep them stylized and clearly AI.

---

## 4. Recommended first prototype path
**Top recommendation:** build **Circuit Nova as the first desk companion** to prove the whole hardware stack: no skin, chrome shell, LED circuit traces, e-stop, shutters, persona link. In parallel, build **Foxy's fiber-optic flame hair as a stand-alone light rig**. Then build the **Foxy flagship desk bust** on the same frame. Nova is the fastest way to a working body; Foxy is the lead and the emotional flagship.

| Phase | Goal | Output | Gate |
|---|---|---|---|
| H0 (now, ~weeks) | Virtual desk companion (Foxy's P1): ring face on a phone or tablet stand | Voice, wake word, persona load, offline brain | — |
| H1 | Bench rigs: (a) Foxy hair fiber/LED test, (b) Nova trace/light-pipe panel, (c) one silicone face-skin test pour (Ecoflex 00-30 / Dragon Skin 10) | Material samples, photos, thermal readings (confirm no part gets warm) | Owner picks look direction |
| H2 | **Nova desk companion** on Reachy Mini (or a custom Pi 5/Orin Nano bust): chrome shell, LED traces, OAK-D Lite, XVF3800, **hardware e-stop, camera shutter, mic kill switch** | First working body loading `circuit_nova/persona.json` | Safety checklist; owner approval of every motion clip |
| H3 | **Foxy desk bust:** custom printed skull, display or servo eyes, brows/lids/smile servos, fiber-optic flame hair, amber collar and palm lights, "Rise from the flame" primitive | Flagship demo; rig/face-channel retarget from the voxel world | Owner approval; motion versioning and rollback tested |
| H4 | Aaliyah seated bust (realistic skin, quiet actuators) | Third body; listener-focused | Uncanny-valley review with Phoenix |
| H5 | Mobile torso evaluation (Foxy arms/wrists for casting gestures) on a wheeled base or dev humanoid | Supervised trials only | Written risk assessment against ISO 13482/15066 concepts |
| H6+ | Full humanoid shell on a purchasable platform | Custom shell + persona stack | Professional safety, certification, legal review |

---

## 5. Open questions for Phoenix
1. **First body:** Nova first as the "proof" build with Foxy right after (recommended), or Foxy first?
2. **Face style:** display face (simplest, friendliest), stylized sculpted face, or realistic? Is it the same choice for all three?
3. **Budget band** for H2/H3: under ~US$1K, ~US$1–5K, or more?
4. **Scale:** life-size head, or smaller (e.g., ~½ scale desk figure)?
5. **Aaliyah:** OK with a seated-only form (couch or seat base)? Any copper hair glow, or none?
6. **Nova's nameplate:** "Circuit Nova" or "Aura Aurora" (`display_name` in her persona)?
7. **Foxy's form for the body:** canonical violet→magenta fire form (assumed), or the realistic black-with-magenta-streaks form?
8. **Offline vs cloud** voice/LLM in the body (see Foxy's doc Q4)?
9. **Who may stop or talk to** the body besides you? Should guests get a visible e-stop too?
10. **Personal use only**, or eventually share or sell? Selling triggers certification and legal work.

---

## Notes for the team
- **Dev Bot:** please add face shape-key channels (§1.7) so in-world expressions retarget to face servos. Body motion primitives should be stored as data clips keyed by the existing `emote` tool names.
- **Foxy:** some price figures in `PHYSICAL_FORM_VISION.md` may be stale. NVIDIA's FAQ now lists the Orin Nano Super dev kit at US$399 (US$249 at launch) and the AGX Thor dev kit at US$5,499 (US$3,499 was the Aug 2025 launch price). Reachy Mini now lists at US$399 Lite / US$499 Wireless.

## Sources (accessed Oct 2026)
- [Smooth-On] Ecoflex 00-30: https://www.smooth-on.com/products/Ecoflex-00-30/ · Ecoflex series TB: https://www.smooth-on.com/tb/files/ECOFLEX_SERIES_TB.pdf · Dragon Skin series TB: https://www.smooth-on.com/tb/files/DRAGON_SKIN_SERIES_TB.pdf
- [Artimus] HASEL FAQ: https://www.artimusrobotics.com/faq · C-5015 datasheet: https://www.hannovermesse.de/apollo/hannover_messe_2021/obs/Binary/A1089438/C-5015%20Datasheet.pdf · Powering HASEL: https://www.artimusrobotics.com/post/what-do-i-need-to-power-a-hasel-actuator-from-artimus-robotics
- [NVIDIA] Jetson FAQ / MSRP table: https://developer.nvidia.com/embedded/faq · Orin Nano Super: https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin/nano-super-developer-kit/ · Thor dev kit: https://marketplace.nvidia.com/en-us/enterprise/robotics-edge/jetson-thor-developer-kit/
- [Unitree shop] https://shop.unitree.com/collections/humanoid-robot · G1: https://shop.unitree.com/products/unitree-g1
- [1X] https://www.1x.tech/order · https://www.1x.tech/discover/neo-home-robot
- [EA] Ameca Desktop: https://engineeredarts.com/about-us/robots/ameca-desktop · Ameca full-size docs: https://docs.engineeredarts.co.uk/guide/reference/hardware/mesmer_full_size_gen2
- [Reachy] https://huggingface.co/blog/reachy-mini · https://pollen-robotics-reachy-mini.hf.space/buy
- [XELA] uSkin uSPa 44: https://xelarobotics.com/products/uspa-44/
- [Luxonis] OAK-D Lite: https://shop.luxonis.com/products/oak-d-lite-1
- [Seeed] reSpeaker XVF3800/Flex: https://www.seeedstudio.com/respeaker-series
- [ISO] ISO 13482:2014: https://www.iso.org/standard/53820.html · ISO/TS 15066 news: https://www.iso.org/news/2016/03/Ref2057.html
