# v0.12 avatars

- Player on the MakeHuman male base (`phoenix_player.glb`). `RealisticBody.player_style()` fills owner-look defaults (jewelry, studded jacket, body id) only when the save lacks them; no save format changes.
- DNA sliders on the rig: height and build scale the model; shoulders, head, legs and arms scale bones; jaw drives the `jaw` blend shape. Attachments go on bones (`AvatarDNA.POINTS_RIG`, `BoneAttachment3D`).
- Face blend shapes: eyeBlinkLeft/Right, mouthSmile, browInnerUp/OuterUp/Down, jawOpen, mouthPucker/Press/Frown, noseSneer, viseme_aa/O/E/I/U/PP/FF. These are built from MPFB expression units. `FaceDriver` runs blink, smile and a talk-jaw/viseme cycle when `CompanionAgent.speak()` fires. `FaceDriver.channels()` gives 0..1 values that future face motors can use.
- Skin detail normals use a screen-space cotangent frame, because mesh tangents broke under blend shapes.
- Screenshot and test runs: `tools/shot_isolated.sh` uses a throwaway `user://`, so no test proposals or memories land in the box's app data.
