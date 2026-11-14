"""Run a temporary Godot editor plugin; restore project configuration afterward."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
project = root / 'project.godot'
original = project.read_bytes()
if b"[editor_plugins]" in original:
    raise SystemExit("Editor check expects no project plugins; refusing to replace their configuration")
plugin = root / 'tests/.editor_check'
if plugin.exists():
    raise SystemExit('Refusing to overwrite existing editor-check temporary directory')
plugin.mkdir()
try:
    (plugin / 'plugin.cfg').write_text('[plugin]\nname="Foundation acceptance"\ndescription="Temporary editor verification"\nauthor="Deck Golf"\nversion="1.0"\nscript="../editor_acceptance.gd"\n')
    project.write_bytes(original + b'\n[editor_plugins]\n\nenabled=PackedStringArray("res://tests/.editor_check/plugin.cfg")\n')
    env = dict(os.environ, DECK_GOLF_EDITOR_CHECK='1')
    result = subprocess.run(['/Applications/Godot 4.7.app/Contents/MacOS/Godot', '--headless', '--path', str(root), '--editor', '--log-file', '/tmp/haven2026-editor-check.log', '--quit-after', '300'], cwd=root, env=env, timeout=90)
    log = Path('/tmp/haven2026-editor-check.log').read_text()
    passed = result.returncode == 0 and 'EDITOR ACCEPTANCE: PASS' in log and 'ERROR' not in log
finally:
    project.write_bytes(original)
    shutil.rmtree(plugin)
raise SystemExit(0 if passed else 1)
