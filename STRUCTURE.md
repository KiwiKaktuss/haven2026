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
