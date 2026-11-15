# Ten-step tutorial with an integrated card lesson

1. Aiming and shooting
2. Shot power
3. Selecting a card
4. Card replacement
5. Elixir
6. Card abilities — hover, focus or click to inspect; Continue leads to walls.
7. Normal walls
8. Sticky walls
9. Ice
10. Bouncy surfaces

- [x] Replace the separate deck-selector preview with an in-place card lesson.
- [x] Show all ten cards with a stable ability/cost detail panel and native art.
- [x] Match the tutorial's existing header, palette, pixel frames and spacing.
- [x] Remove moving-platform tutorial content and the completion-screen guide.
- [x] Keep the polished connected terrain and nine hole-based practical tasks.
- [x] Use only the standard II pause button, with restart/menu inside pause.
- [x] Show title and step count together, followed by one changing description,
      inside a compact 84px panel; remove floating/lower labels,
      the yellow hole marker and the first-step gesture circle.
- [x] Restore the normal 18px cup attraction radius in every room and builder.
- [x] Frame each challenge from its actual geometry, centered in the play area.
- [x] Verify pause/restart, real hover input, Continue and Begin playing.
- [x] Replay all ten steps with legal inputs using the normal cup radius.
- [x] Inspect small/large layouts and the final screenshots/result/31/ proof.

Current checks: 189 tutorial/flow checks, all ten steps completed on engine ticks
(nine physical holes, ten legal releases). Native tile artwork/collision remains
unchanged. Original user aim/power-flame edits remain intact.

Final proof: screenshots/result/31/video.mp4, 750 original frames, 25s at 30fps.
Cards appear at frame 340; completion at frame 686.

Latest visual polish: restored a compact 576×84 panel, centered vertical
spacing, 22px heading and muted 16px description. Checked at 800×640,
960×640 and 1440×900; 189 flow checks pass. Changes left uncommitted as requested.

# Marked walls and native card popovers

- [x] Add the end stop in step 2, the support wall under the step-7 overhang,
      the approach wall in sticky terrain, and the hanging wall over the spring.
- [x] Join new stationary tiles and rebuild matching collision silhouettes.
- [x] Use the real deck-selector card size (144×141) and native above-card
      information popovers in step 6; remove the large persistent detail panel.
- [x] Verify every card's real hover popup and all ten lesson completions.
- [x] Inspect and encode screenshots/result/32/ as the new proof.

Checks: 208 tutorial checks and 116,050 artwork/collision checks. All nine
practical holes replay with legal shots. Leave all changes uncommitted.

Latest proof: screenshots/result/32/video.mp4, 750 original frames, 25s
at 30fps. Card hover lesson at frame 340; all steps complete at frame 697.
