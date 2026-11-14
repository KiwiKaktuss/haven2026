extends SceneTree
## Exercise audio through real UI input, shot transactions, and swept collisions.
var checks: int = 0
var failures: int = 0
var main: Node2D
var audio: Node
const SAVE_PATH: String = "user://audio_test.json"

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func frames(count: int = 3) -> void:
    for frame: int in range(count):
        await process_frame

func point(at: Vector2) -> void:
    var event := InputEventMouseMotion.new()
    event.position = at
    root.push_input(event, true)

func click_button(button: BaseButton) -> void:
    var at: Vector2 = button.get_global_rect().get_center()
    point(at)
    for down: bool in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event, true)

func finish_travel() -> void:
    main._journey_tween.custom_step(10.0)
    await frames()

func check_loop(player: AudioStreamPlayer, description: String) -> void:
    player.seek(player.stream.get_length() - 0.06)
    await create_timer(0.25).timeout
    check(player.playing and player.get_playback_position() < 1.0, description)

func run() -> void:
    audio = root.get_node("GameAudio")
    root.size = Vector2i(960, 640)
    main = load("res://main.tscn").instantiate()
    main.save.path = SAVE_PATH
    root.add_child(main)
    await frames()
    check(audio.music.playing and audio.music.stream == audio.menu_music, "Main menu starts its music")
    await check_loop(audio.music, "Main menu music really wraps at the end")

    var play: Button = main._menu_screen.get_node("Center/Content/Play")
    audio.hover.stop()
    point(Vector2(4, 4))
    await frames()
    check(not audio.hover.playing, "Empty menu space is silent")
    point(play.get_global_rect().get_center())
    await frames()
    check(audio.hover.playing, "Real button hover plays the hover sound")
    audio.hover.stop()
    point(play.get_global_rect().get_center() + Vector2(2, 0))
    await frames()
    check(not audio.hover.playing, "Moving within the same button does not repeat hover")
    play.disabled = true
    point(Vector2(4, 4))
    await frames()
    point(play.get_global_rect().get_center())
    await frames()
    check(not audio.hover.playing, "Disabled button hover is silent")
    play.disabled = false

    audio.music.seek(3.0)
    click_button(play)
    check(audio.click.playing and main._journey_moving, "Real UI activation plays click")
    await finish_travel()
    check(audio.music.stream == audio.menu_music and audio.music.get_playback_position() >= 3.0, "Menu navigation preserves music position")
    audio.click.stop()
    click_button(main._levels_screen.get_node("Center/Content/Course0"))
    check(audio.click.playing and is_instance_valid(main.session), "Click survives removal of the launching button")
    check(audio.music.playing and audio.music.stream == audio.level_music, "Starting a course switches to level music")
    await check_loop(audio.music, "Level music really wraps at the end")

    var session: GameSession = main.session
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    audio.golfball_hit.stop()
    check(not session.try_shot(Vector2.ZERO) and not audio.golfball_hit.playing, "Rejected shot is silent")
    check(session.try_shot(Vector2(-30, 70)) and audio.golfball_hit.playing, "Committed shot plays golfball_hit")
    audio.golfball_hit.stop()
    check(not session.try_shot(Vector2(-30, 70)) and not audio.golfball_hit.playing, "Locked replacement cannot play a shot sound")

    var wall: TerrainObject = load("res://scenes/terrain/terrain_object.tscn").instantiate()
    wall.position = Vector2(4000, 4000)
    wall.rotation = PI * 0.5
    root.add_child(wall)
    await physics_frame
    await frames()
    audio.wallhit.stop()
    session.ball.reset_motion(wall.position + Vector2(-13, 32))
    session.ball.velocity = Vector2(240, 0)
    session.ball.step_motion(1.0 / 60.0)
    check(audio.wallhit.playing, "Actual swept wall collision plays wallhit")
    audio.wallhit.stop()
    session.ball.reset_motion(wall.position + Vector2(-13, 32))
    session.ball.velocity = Vector2(240, 0)
    session.ball.step_motion(1.0 / 60.0)
    check(not audio.wallhit.playing, "Repeated contacts in the same instant are debounced")
    await create_timer(0.1).timeout
    session.ball.reset_motion(wall.position + Vector2(-13, 32))
    session.ball.velocity = Vector2(240, 0)
    session.ball.step_motion(1.0 / 60.0)
    check(audio.wallhit.playing, "A later separate wall impact plays again")
    wall.free()

    audio.music.seek(3.0)
    main._pause()
    await frames()
    check(audio.music.playing and audio.music.get_playback_position() >= 3.0, "Music continues while the session is paused")
    audio.click.stop()
    click_button(main.screen_host.get_child(0).get_node("Center/Content/Resume"))
    check(audio.click.playing and session.state != GameSession.State.PAUSED, "Pause UI uses the shared click sound")
    for index: int in range(main.courses.courses.size()):
        main._start_course(index)
        await frames()
        check(audio.music.stream == audio.level_music and audio.music.get_playback_position() >= 3.0, "Course %s preserves the shared level loop" % index)
        main.session.ball.simulation_enabled = false
    main.session.finish_attempt(false)
    await frames()
    check(audio.music.stream == audio.level_music and audio.music.playing, "Result keeps the level soundtrack")
    click_button(main.screen_host.get_child(0).get_node("Center/Content/Menu"))
    check(audio.music.playing and audio.music.stream == audio.menu_music, "Returning to main menu restores its soundtrack")
    await frames()
    click_button(main._menu_screen.get_node("Center/Content/Deck"))
    await finish_travel()
    var card: CardView = main._deck_screen.get_node("Margin/Content/Grid/Card0")
    point(Vector2(4, 4))
    await frames()
    audio.hover.stop()
    point(card.get_global_rect().get_center())
    await frames()
    check(audio.hover.playing, "Instantiated deck cards receive hover audio")
    audio.click.stop()
    click_button(card)
    check(audio.click.playing, "Deck card buttons receive click audio")
    main._open_physics_lab()
    await frames()
    audio.click.stop()
    click_button(main.game_host.get_child(0).get_node("CanvasLayer/MainMenuButton"))
    check(audio.click.playing and is_instance_valid(main._menu_screen), "Saved scene connections can navigate before the click listener")
    main.free()
    await frames()
    DirAccess.remove_absolute(SAVE_PATH)
    print("Audio: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
