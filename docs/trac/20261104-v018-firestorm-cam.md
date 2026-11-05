# v0.18.0 (versionCode 24) — Firestorm-style camera

| ID | Change |
|----|--------|
| CAM-1 | Orbit: in third person, dragging on the right half (or with the mouse) turns the camera around the avatar; the avatar no longer spins. |
| CAM-2 | Zoom: mouse wheel, trackpad pinch, or two fingers on the right half. The distance eases between 0.9 m and 24 m. Zooming all the way in switches to mouselook (first person); zooming out returns to third person, looking the same way. |
| CAM-3 | Snap back: when you walk, the orbit eases back behind the avatar after 0.6 s (like Firestorm's "reset camera on move"). Standing still keeps the orbit so you can look around your avatar. |
| CAM-4 | Collision: a ray from the shoulder pivot pulls the camera in front of terrain and walls (0.25 m margin). |
| CAM-5 | Smoothing follows ComfortPrefs camera_smoothing; the camera snaps after a teleport. Over-the-shoulder offset shrinks as you zoom in. |
| CAM-6 | Flying and swimming already steer toward where the camera looks, so they now follow the orbit too, as in SL. |
| TEST | tests/v018_tests.gd: math checks plus the player wiring (orbit vs body, wheel, mouselook round trip, pinch at 720x1280, 1080x2400 and 2400x1080). |

Scorpion Viper has no 3D view, so it gets no release for this phase.
Code: scripts/camera/firestorm_cam.gd. In scripts/player.gd the old TP_CAM placement is commented out.
