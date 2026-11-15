extends SceneTree
var failures: int = 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var audio = root.get_node("GameAudio")
    audio.play_menu_music()
    var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
    root.add_child(menu)
    menu.set_process(false)
    check(menu._intro and menu.logo.modulate.a == 0.0, "Logo starts hidden")
    check(menu.play.disabled and menu.deck.disabled, "Hidden buttons cannot activate")
    menu._intro_time = 1.20
    menu._process(0.0)
    check(menu.logo.modulate.a > 0.99 and menu.panel.modulate.a == 0.0, "Impact reveals only the logo")
    menu._intro_time = 2.30
    menu._process(0.0)
    check(not menu.play.disabled and menu.deck.disabled, "Controls reveal on separate musical accents")
    menu._intro_time = 3.0
    menu._process(0.0)
    check(not menu._intro and not menu.deck.disabled and menu.credits.modulate.a == 1.0, "Intro finishes at three seconds")
    audio.music.seek(5.04)
    menu._process(0.0)
    var scale_before: Vector2 = menu.logo.scale
    menu._process(10.0)
    check(menu.logo.scale.distance_to(scale_before) < 0.002, "Idle follows playback, not frame delta")
    menu.free()
    menu = load("res://scenes/ui/main_menu.tscn").instantiate()
    root.add_child(menu)
    check(not menu._intro and not menu.play.disabled, "Returning to menu does not replay intro")
    menu.free()
    print("Menu intro: 7 checks, %s failure(s)" % failures)
    quit(0 if failures == 0 else 1)
