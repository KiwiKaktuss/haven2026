#!/usr/bin/env python3
"""Build and package the Godot release preset for itch.io."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or shutil.which("godot") or "/Applications/Godot 4.7.app/Contents/MacOS/Godot")
args = parser.parse_args()
output = ROOT / "build" / "web"
output.mkdir(parents=True, exist_ok=True)
(output.parent / ".gdignore").touch()
# Only clean generated export files; retain other build artifacts.
for path in output.glob("index.*"):
    if path.is_file():
        path.unlink()
subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--export-release", "Itch Web", str(output / "index.html")], check=True)
required = ["index.html", "index.js", "index.wasm", "index.pck"]
for name in required:
    if not (output / name).is_file() or (output / name).stat().st_size == 0:
        raise SystemExit(f"Missing export file: {name}")
shutil.copyfile(ROOT / "fonts/Barlow/OFL.txt", output / "Barlow-OFL.txt")
(output / "LICENSES.txt").write_text(
    "Deck Golf 1.0\n\nGodot Engine: MIT license.\n"
    "Copyright (c) 2014-present Godot Engine contributors.\n"
    "Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.\n"
    "Engine license: https://godotengine.org/license/\n"
    "Third-party engine notices: https://godotengine.org/license/#thirdparty\n\n"
    "Barlow font: SIL Open Font License 1.1; see Barlow-OFL.txt.\n",
    encoding="utf-8",
)
archive = output.parent / "deck-golf-1.0-itch-web.zip"
extensions = {".html", ".js", ".wasm", ".pck", ".png", ".txt"}
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    for path in sorted(output.iterdir()):
        if path.is_file() and path.suffix in extensions:
            bundle.write(path, path.name)
with zipfile.ZipFile(archive) as bundle:
    assert "index.html" in bundle.namelist()
    assert bundle.testzip() is None
    assert len(bundle.namelist()) < 1000
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
print(f"\nUpload: {archive}\nSize: {archive.stat().st_size / 1024 / 1024:.2f} MiB\nSHA256: {digest}")
