# Beginner tutorial — ten playable lessons

- [x] Add the Tutorial menu button using the existing menu artwork and reveal.
- [x] Author ten saved, editable rooms with generous physical cups and fixed hands.
- [x] Teach aiming, power, selection, replacement, elixir, walls, sticky, ice,
      springs and moving platforms through practical tasks.
- [x] Gate each hole on its lesson mechanic; advance only after actual cup capture.
- [x] Add consistent top-centre instructions, gesture/route guidance, surface
      names and patterns, current-room Retry and local miss recovery.
- [x] Keep timers, scores, random draws and ability lessons out of gameplay.
- [x] Add completion, Begin playing, and an optional real deck-selector preview
      with clickable card explanations. Preview cannot change the saved deck.
- [x] Verify ten holes on real engine ticks using legal aim-and-release inputs.
- [x] Verify menu/pause/retry/first-course flow and existing card/menu/cup tests.
- [x] Inspect the final 30fps proof and encode its fresh screenshots/result/27/ bundle.

Acceptance: `tests/test_tutorial.gd` (95 checks),
`tests/test_tutorial_playthrough.gd` (all 10 holes, 12 legal releases), and a
fresh full-course visual proof. Existing user edits to aim/power flames remain intact.

Final proof: `screenshots/result/27/video.mp4`, 900 original PNG frames,
30 seconds at 30fps. All ten holes finish at frame 702; the remainder shows
completion and the optional card guide. Layout inspected at 800×640,
960×640 and 1440×900.

# Tutorial tile polish

- [x] Replace repeated fill/border tiles with the normal game's connected edges.
- [x] Rebuild the 128px cup bank from native tiles; remove horizontal scaling
      from the cup, hole and flag. Match neighboring bank depths.
- [x] Join touching walls and material transitions; retain independent mover edges.
- [x] Verify every terrain pixel against the saved collision silhouette and
      replay all ten holes with legal shots.
- [x] Inspect and encode the fresh `screenshots/result/28/` proof.

Checks: 112,992 terrain checks, 95 tutorial flow checks, all ten engine-played
holes. Original user edits to aim/power flames remain untouched.

Tile-polish proof: `screenshots/result/28/video.mp4`, 900 original frames,
30 seconds at 30fps. All ten holes finish at frame 777.
