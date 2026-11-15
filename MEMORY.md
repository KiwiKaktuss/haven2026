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

# Tutorial notes

- Keep the numbered course at ten lessons; the user's extra card-explanation
  request is an optional deck-selector preview after completion, not an ability
  lesson or an eleventh practical challenge.
- Tutorial uses the existing GameSession shot/deal/elixir transaction and actual
  terrain physics. Fixed Normal/Snipe hands and reserved replacements bypass
  random draws. Gameplay hand tooltips are hidden to keep abilities out of lessons.
- Ordinary cup capture height ends exactly at the 60Hz settled contact (5px),
  which can round a fraction past the shape. The tutorial-only inherited cup
  uses a 3x5 local capture rectangle and 2x horizontal scaling; base cups stay intact.
- Save inherited child shape overrides in tutorial_cup.tscn; editing an instanced
  child's shape in the room builder alone does not persist it in the packed room.
- Spring lesson uses the existing launch_spring resource for a dependable 208px/s
  rebound. The mover is a 96px-wide ordinary surface, 88px travel, 10s period.
- Real engine replay passes all ten holes with twelve releases. Structural/flow
  checks: 95/95. Existing cards: 799/799; cup: 88/88; menu journey: 32/32;
  menu intro: 7/7. Lifecycle remains 55/56: its old rescue assertion puts the
  ball centre 1px above a sea boundary that now detects the 2px lower edge.
  This is outside tutorial code; sea-course defeat behavior was not changed.
- Menu/lifecycle save-writing tests require approved host access for temporary
  user:// files; otherwise their missing writable file can leave a test waiting.
- Full proof captures use 2x playback with the same 1/60 physics step, not ball
  teleports, synthetic wins or accelerated gravity. All holes still require dwell.
- Final tutorial proof: `screenshots/result/27/video.mp4` plus 900 original PNGs,
  30s at 30fps. Ten holes complete by frame 702, then completion/card guide.
  Visually checked the minimum 800×640 window, 960×640 and 1440×900 layouts.
