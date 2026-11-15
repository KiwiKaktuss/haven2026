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
  advances only on real cup dwell. Misses/retries never touch course records.
- `tutorial_cup.tscn` inherits the production cup with a wider physical opening,
  broader attraction field and capture tolerance for 60Hz contact rounding.
- `tutorial_overlay.tscn` owns the consistent lesson/count/instruction layout,
  Retry, completion and Begin playing. Its script draws passive guidance and
  patterns in viewport space. Camera framing reserves space for header and hand.
- `deck_preview.tscn` inherits the actual deck editor. `preview_mode` inspects
  cards without changing the equipped deck or writing a save.
- `main.gd` owns tutorial/menu/first-course navigation and routes paused restart
  back to the current tutorial room.

Verification:
- `tests/test_tutorial.gd`: resources, transactions, lesson gates, real menu and
  Retry clicks, pause restart, preview isolation and Begin playing.
- `tests/test_tutorial_playthrough.gd`: ten holes through ordinary engine ticks,
  real aim/release and actual sticky/mover boarding and departures.
- `tests/support/tutorial_routes.json`: discovered ordinary-shot route fixtures.
- `tests/support/tutorial_engine_routes.json`: accepted engine input trace.
- `tests/capture_tutorial_views.gd`: screenshots of the menu, lesson HUD and guide.
- `tests/capture_tutorial_playthrough.gd`: complete 2x proof (120 physics ticks/s
  with time_scale 2 preserves the tested 1/60 physics delta), 900 frames at 30fps.
