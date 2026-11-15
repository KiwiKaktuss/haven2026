# Deck Golf cover

Open `game_cover.tscn` in Godot and press F6 for the standalone 630 × 500 cover.
The original `art/DeckGolf.png` logo occupies the open upper triangle. The ten original card types form tightly packed diagonal rows around the sides
and bottom. Each side is rotated 45° in opposite directions, leaving an exact
90° opening. Adjacent cards have an 8-pixel gap along their length and across rows. The frame sits closer to the logo, with its inner
corner at (315, 390).
The logo is centered in a 416 × 312 slot. The pale gameplay backdrop is unchanged.
Card shadows use tinted copies of the original sprites. No ball, generated artwork,
or captions are used.

All cards, shadows, and the logo are editable scene nodes. The saved scene is the
source of truth for the cover; the platform authoring utility is not used by this layout.

Regenerate `art/promo/deck_golf_630x500.png` using a graphical Godot instance:

```sh
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --path . res://scenes/promo/game_cover.tscn -- --export-cover
```

Export uses a fixed-size SubViewport, so the PNG stays exactly 630 × 500 regardless
of desktop display scaling. Running this scene does not change the game's main scene.

## Wide cover

`game_cover_wide.tscn` is the separately composed 16:9 version, exported to
`art/promo/deck_golf_1280x720.png`. Its full logo is visible without cropping;
large original cards retain the 90° frame and proportional gaps.

```sh
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --path . res://scenes/promo/game_cover_wide.tscn -- --export-cover
```

Both scenes expose their own artwork size and PNG output path in the Inspector.
