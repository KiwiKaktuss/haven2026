# Final Ascent notes

- Inspiration: First Fairway's route choice/recovery caves, Cold Snap's flush
  ice-to-sticky transitions, Spring Works' optional rides and passive springs.
- Classic power is 180 with gravity 260. Taller climbs may use the game's legal
  airborne card combinations. Baseline routes must work without mover timing.
- Use the existing seeded legal-card search and independent live engine replay;
  an offline search by itself is not completion evidence.

- Default seed 17: Safe 13 shots, Alternate 10 shots, spring shortcut 8 shots;
  all three independently engine-replayed with zero shot-origin drift.
- All 22 constrained Safe-route decks also win on independent engine replay,
  with zero shot-origin drift (seed 17). This is reachability evidence, not an
  exhaustive guarantee about every deck, seed or player strategy.
- The launch spring can bank a single Fireball from spawn to ReturnGallery,
  skipping the lower/east switchback. A complete legal win is tested afterward.
- `test_final_ascent.gd`: 154 checks cover real ice catches, spring recovery,
  rejoining the route from RecoveryBeach, mover rides and clear sweeps, camera
  bounds at three window sizes, and first-edge water defeat.
- `test_course_art.gd`: 369,900 checks pass across all courses, including exact
  per-pixel art/collision agreement. The legacy `test_course_routes.gd` assumes
  Classic-only single hops and fails on unchanged levels 1–3 as well as level 4;
  use the real-card search and independent engine replay for route acceptance.
- Sandbox Godot needs `--log-file` inside the workspace to avoid a user-log
  initialization crash. Desktop rendering uses the approved display path.
  Headless macOS emits a host certificate-store message; it does not affect play.
- Fresh final proof: `screenshots/result/25/`, 900 frames at 30 fps. A complete
  spring win finishes at frame 544, and both ride/launch fixtures finish at 831.
  Native AVFoundation encodes the PNG sequence because ffmpeg is unavailable.
  Its hardware encoder needs the same approved host access as desktop rendering.
