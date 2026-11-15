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

- Current tutorial order has ten lessons: aim, power, selection, replacement,
  elixir, card abilities, walls, sticky, ice, bouncy. The user replaced the old
  moving-platform lesson with the card overview before walls and removed the
  separate post-completion deck-selector preview.
- Tutorial uses the existing GameSession shot/deal/elixir transaction and actual
  terrain physics. Fixed Normal/Snipe hands and reserved replacements bypass
  random draws. Gameplay hand tooltips are hidden to keep abilities out of lessons.
- Ordinary cup capture height ends exactly at the 60Hz settled contact (5px),
  which can round a fraction past the shape. The tutorial-only inherited cup
  uses a 3x5 local capture rectangle; base cups stay intact. The tile-polish
  follow-up removes the old 2x horizontal scaling entirely.
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

# Tutorial tile polish

- Native tile proportions throughout: the cup bank is authored 128×32, with
  unscaled 8×8 tiles, original 4×4 rim quarters and original 8px hole/flag art.
  Its root remains at target−(32,0), preserving GoalCup's mouth coordinates.
- Paint exposed corners/edges with the normal-game atlas and interiors from
  full.png. Contextual occupancy joins cup banks, wall bases and ice transitions.
  Moving platforms get independent borders, rather than joins at their initial pose.
- The rim and main tile layer share one alpha-derived collision silhouette.
  Bake the cup as owned room nodes after clearing nested scene_file_path values;
  leaving the old cup-body instance path silently reintroduces renamed children.
- Tests: 112,992 tile checks, 95 flow checks, all ten holes on real engine ticks.
  Updated accepted input fixtures for the native-size rim and proper corner solids.
- Final tile-polish proof: `screenshots/result/28/video.mp4`, 900 PNGs,
  30 seconds at 30fps; all ten holes complete at frame 777.

# Integrated card lesson

- Step 6/10 reuses the tutorial header and pale course backdrop. Compact card
  views occupy two rows; hover, keyboard focus or click updates a fixed detail
  panel with the real catalog ability and cost, rather than floating popovers.
- The Continue button enables after one inspection and opens walls (step 7).
  No card is played, no elixir is spent and no saved loadout changes. Retry
  resets only this lesson. Esc pause/resume preserves the gallery without HUD.
- World/hand visibility and aim/ball simulation are restored when leaving cards.
  The ten-step catalog ends on bouncy surfaces; tutorial mover state was removed.
- Verification: 139 flow checks; real hover for all ten cards; nine engine-played
  holes and ten legal releases across the ten lessons; 112,586 tile checks;
  32 existing menu journey checks. Layout verified at 800×640 through 1440×900.
- Final revised-flow proof: `screenshots/result/29/video.mp4` with 900 frames
  at 30fps (30 seconds). Card lesson at 402; walls at 495; completion at 790.

# Tutorial HUD simplification

- Only II remains in the top-left. Restart and Menu use the ordinary pause
  screen; do not reintroduce direct Menu/Retry buttons on the lesson overlay.
- Instructions and changing lesson explanations belong together in the top box.
  Removed the lower caption, floating surface names, yellow hole arc, HOLE tag,
  and the first-step drag-gesture circle/path/text.
- Cup pull_radius is the normal 18px in all saved rooms and the builder.
  Stopped misses now reset based on that real radius, not the former hardcoded
  38px. Accepted legal-shot traces were refreshed for the smaller attraction field.
- Camera centers the union of terrain/cup collision bounds, reserving the top
  panel and bottom hand. This centers every challenge at every supported width.
- Tests: 189 flow checks, including actual pause/restart, horizontal/vertical
  centering and normal hole radius in all ten steps. All practical holes replay.
- Fresh proof: screenshots/result/30/video.mp4, 750 PNGs, 25s at 30fps. Cards at
  frame 340; full tutorial completes at frame 686.
