extends SceneTree
## Rebuild the logo's amplitude envelope after replacing mainmenu.mp3.
## Run: Godot --headless --path . --script tools/build_menu_motion.gd
## Review the authored cue times against the new music before shipping.
func _initialize() -> void:
    var stream: AudioStreamMP3 = load("res://sound/mainmenu.mp3").duplicate()
    stream.loop = false
    var playback: AudioStreamPlayback = stream.instantiate_playback()
    playback.start()
    var envelope: Array[float] = []
    var level: float = 0.0
    var sample_count: int = ceili(stream.get_length() * 100.0)
    for index: int in range(sample_count):
        var samples: PackedVector2Array = playback.mix_audio(1.0, 441)
        var energy: float = 0.0
        for sample: Vector2 in samples:
            energy += sample.length_squared()
        var target: float = minf(1.0, sqrt(energy / 441.0) / 0.9)
        level = target if target > level else level * 0.90 + target * 0.10
        envelope.append(snappedf(level, 0.001))
    var file := FileAccess.open("res://resources/audio/menu_motion.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({
        "sample_step": 0.01, "impact_time": 1.04, "panel_time": 2.04,
        "deck_time": 2.54, "end_time": 3.0, "envelope": envelope,
    }))
    playback.stop()
    quit()
