# Deck Golf 1.0 — itch.io web release

Upload `build/deck-golf-1.0-itch-web.zip` directly. It contains `index.html` at the archive root and all runtime files. The adjacent `.sha256` file identifies the exact archive.

## itch.io settings

1. Set **Kind of project** to **HTML**.
2. Upload the ZIP and select **This file will be played in the browser**.
3. Choose **Embed in page**, width **960**, height **640** (minimum tested size: **800 × 640**).
4. Enable **Click to play** and **Fullscreen button**; leave scrollbars off.
5. Leave **SharedArrayBuffer support** off. This release is single-threaded and needs no cross-origin isolation headers or service worker.
6. Treat this as a desktop browser game; leave mobile-friendly unchecked. Its controls use a mouse and keyboard.
7. Preview the uploaded draft on itch.io before publishing: start a course, take a shot, pause/resume, edit the deck, reload, and check sound after clicking into the game.

Browser saves use IndexedDB. They are local to the browser and hosting origin; local testing saves do not transfer to itch.io. Private browsing or blocked site storage can prevent persistence.

## Rebuild

Requires Godot **4.7 stable** and matching web export templates.

```sh
python3 tools/export_itch.py
```

For another Godot installation, pass `--godot /absolute/path/to/godot` or set `GODOT_BIN`. The script creates the release export, includes font/engine license notices, validates ZIP integrity, and writes a SHA-256 checksum. Only the ZIP is uploaded.

For local play, serve `build/web` over HTTP (opening `index.html` as a file will not work):

```sh
python3 -m http.server 8765 --directory build/web
```

Open `http://localhost:8765` in a browser supporting WebGL 2 and WebAssembly.

## Release checks

- Compatibility renderer; single-threaded release template; automatic canvas resizing; PWA disabled.
- Development labs load only in debug builds. Tests, generators, captures, logs, source artwork, and project notes are excluded from the release package.
- Browser smoke checks use Chrome over HTTP without cross-origin isolation, including menu/deck navigation, course loading, aiming/shooting and card replacement.
- All 25 release regression scripts passed. Regression checks run at 60 FPS so animation assertions have realistic elapsed time. Some existing test fixtures report resource-leak warnings on process exit even when all assertions pass.
- Long route-search/playthrough scripts and the editor-only acceptance fixture are outside the release regression run. This is not an exhaustive browser/device certification; the hosted itch.io preview remains the final hosting check.

Reference: [itch.io HTML5 upload guide](https://itch.io/docs/creators/html5), [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
