# Final Ascent authoring

- `tools/build_final_ascent.gd` is an explicit offline scene authoring tool.
- `scenes/levels/final_ascent.tscn` is the editable runtime source of truth.
  Terrain uses saved collision silhouettes and paintable TileMapLayer children.
- `Terrain` contains stationary islands/materials, `MovingPlatforms` contains
  optional rides, and `Decorations` contains collision-free tile scenery.
- `Routes/Safe` and `Routes/Alternate` describe timing-independent baseline
  routes for the existing legal-card search/replay harness.
- Course index 3 and ID `final_ascent` remain in the existing level catalog.

Verification uses Godot 4.7's GDScript parser/import and SceneTree tests; this
project has no C# or .NET build. Runtime captures use the production session/HUD.

Focused checks:
- `tests/test_final_ascent.gd`: materials, recovery, movers, camera and water.
- `tests/test_final_ascent_shortcut.gd`: legal spring bank and full engine replay.
- `tests/test_course_playthroughs.gd -- --course=3`: legal baseline route search;
  use `--alternate` for the west route, `--adverse` for 22 constrained decks.
- `tests/replay_course_playthroughs.gd`: independently replay the generated JSON
  reports from `screenshots/step_6/` through ordinary engine ticks.
- `tests/capture_final_ascent.gd`: overview, details and HUD at three sizes.
- `tests/capture_final_ascent_playthrough.gd`: 900 frames at 30 fps, using the
  independently verified spring trace, followed by explicit ride/launch fixtures.

# Tutorial

- `tools/build_tutorial.gd` authors ten saved `scenes/tutorial/lesson_XX.tscn`
  rooms; runtime loads these scenes through `resources/tutorial/courses.tres`.
- `TutorialSession` inherits the production session scene and shot transaction.
  It supplies known ordinary cards, tracks lesson-specific interactions, and
  advances practical lessons on real cup dwell. The card chapter uses an
  explicit Continue button. Misses/retries never touch course records.
- `tutorial_cup.tscn` uses the production native-size rim/flag within a 128×32
  bank built from square terrain tiles. Rooms save contextual edge joins with
  their neighbors; collision silhouettes include the tile art and physical rim.
  The attraction radius matches the normal game (18px); a small capture-shape
  tolerance still handles 60Hz contact rounding.
- `tutorial_overlay.tscn` owns the consistent lesson/count/instruction layout,
  II pause button, completion and Begin playing. Explanations stay in the top
  panel; passive route/material patterns remain in the field. Camera framing
  centers the saved collision bounds between the header and the hand.
- `card_lesson.tscn` is the in-place sixth lesson. Its ten compact `lesson_card`
  instances reveal catalog descriptions/costs on hover, focus or click in one
  stable detail panel. Continue requires one inspection and leads to walls.
  Gameplay, ball simulation and the hand are hidden for this lesson.
- The tutorial has nine practical holes and one card overview; bouncy surfaces
  finish step ten. There is no moving-platform lesson or separate card preview.
- `main.gd` owns tutorial/menu/first-course navigation and routes paused restart
  back to the current tutorial room.

Verification:
- `tests/test_tutorial.gd`: resources, transactions, lesson gates, real menu and
  pause/restart clicks, centered geometry, normal cup radius, real hover for every
  card, Esc pause, Continue and Begin playing.
- `tests/test_tutorial_playthrough.gd`: all ten lessons through ordinary engine ticks,
  nine physical holes, legal releases and a real sticky attachment/departure.
- `tests/support/tutorial_routes.json`: discovered ordinary-shot route fixtures.
- `tests/support/tutorial_engine_routes.json`: accepted engine input trace.
- `tests/capture_tutorial_views.gd`: screenshots of the menu, lesson HUD and guide.
- `tests/capture_tutorial_playthrough.gd`: complete 2x proof (120 physics ticks/s
  with time_scale 2 preserves the tested 1/60 physics delta), 750 frames at 30fps (25 seconds).

- `tests/test_tutorial_tiles.gd`: native proportions, opaque connected joins,
  and exact art/collision agreement across all ten tutorial rooms.
