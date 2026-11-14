extends SceneTree
## Replays saved search traces through the ordinary engine physics loop.
const LiveReplay = preload('res://tests/support/live_playthrough.gd')
var failures: int = 0

func _initialize() -> void:
    call_deferred('run')

func run() -> void:
    var paths: PackedStringArray = OS.get_cmdline_user_args()
    if paths.is_empty():
        paths.append('res://screenshots/step_6/playthroughs_default_safe.json')
    var count: int = 0
    var replay = LiveReplay.new()
    for path: String in paths:
        var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not rows is Array or rows.is_empty():
            push_error('Missing/invalid playthrough report: ' + path)
            failures += 1
            continue
        for row: Dictionary in rows:
            count += 1
            var ok: bool = await replay.verify(self, row)
            if not ok:
                failures += 1
            print('%s engine replay %s/%s: %s shots; deck %s' % ['PASS' if ok else 'FAIL', row.course, row.route, row.shots, row.deck])
        var file := FileAccess.open(path, FileAccess.WRITE)
        file.store_string(JSON.stringify(rows, '  '))
    print('Engine replays: %s run(s), %s failure(s)' % [count, failures])
    quit(0 if failures == 0 else 1)
