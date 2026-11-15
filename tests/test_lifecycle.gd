extends SceneTree
var checks: int = 0
var failures: int = 0
var main: Node2D
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
var courses: CourseCatalog = load("res://resources/levels/catalog.tres")
var test_path: String = "user://lifecycle_test.json"

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", message)

func ticks(count: int = 1) -> void:
    for tick: int in range(count):
        await physics_frame
        await process_frame

func screen() -> Control:
    return main.screen_host.get_child(0)

func click(path: String) -> void:
    screen().get_node(path).pressed.emit()

func finish_menu_travel() -> void:
    while main._journey_moving:
        await process_frame

func pointer(at: Vector2, down: bool) -> void:
    var move := InputEventMouseMotion.new()
    move.position = at
    root.push_input(move, true)
    var event := InputEventMouseButton.new()
    event.position = at
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = down
    root.push_input(event, true)

func escape(echo: bool = false) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_ESCAPE
    event.pressed = true
    event.echo = echo
    root.push_input(event, true)
    event = InputEventKey.new()
    event.physical_keycode = KEY_ESCAPE
    root.push_input(event, true)

func run() -> void:
    DirAccess.remove_absolute(test_path)
    var store := SaveStore.new()
    store.path = test_path
    store.read_save(catalog, courses)
    check(store.equipped == catalog.default_deck and store.records.is_empty(), "Fresh save defaults")
    for raw: String in ["not json", "[]", '{"version":2}', '{"version":1,"deck":["classic","classic","fire","slow","glue","bounce"],"records":{"first_fairway":-1,"cold_snap":"bad"}}']:
        var file := FileAccess.open(test_path, FileAccess.WRITE)
        file.store_string(raw)
        file.close()
        store.read_save(catalog, courses)
        check(store.equipped == catalog.default_deck and store.records.is_empty(), "Invalid save safely defaults")
    var legacy := FileAccess.open(test_path, FileAccess.WRITE)
    legacy.store_string('{"version":1,"deck":["heavy","dash","ghost","rewind","classic","slow"],"records":{"first_fairway":9.5}}')
    legacy.close()
    store.read_save(catalog, courses)
    check(store.equipped == [&"heavy", &"dash", &"ghost", &"rewind", &"classic"], "Legacy deck retains its first five cards")
    check(store.records.get("first_fairway") == 9.5, "Deck migration preserves course records")
    legacy = FileAccess.open(test_path, FileAccess.WRITE)
    legacy.store_string('{"version":1,"deck":["heavy","dash","ghost","rewind"]}')
    legacy.close()
    store.read_save(catalog, courses)
    check(store.equipped == [&"heavy", &"dash", &"ghost", &"rewind", &"classic"], "Four-card save gains a fifth card without losing choices")
    store.records.clear()
    store.equipped = [&"classic", &"heavy", &"dash", &"ghost", &"slow"]
    check(store.record_win(courses.courses[0].id, 12.34), "First win sets record")
    check(not store.record_win(courses.courses[0].id, 13.0), "Slower win cannot replace record")
    check(not store.record_win(courses.courses[0].id, NAN), "Invalid time rejected")
    check(store.write_save(), "Atomic save writes")
    var restored := SaveStore.new()
    restored.path = test_path
    restored.read_save(catalog, courses)
    check(restored.equipped == store.equipped and restored.records == store.records, "Deck and record survive reload")
    main = load("res://main.tscn").instantiate()
    main.save.path = test_path
    root.add_child(main)
    await ticks(2)
    click("Center/Content/Deck")
    await finish_menu_travel()
    check(screen().selected == store.equipped, "Deck editor retains equipped choices")
    var original: Array[StringName] = screen().selected.duplicate()
    screen()._toggle(original[0])
    check(screen().selected.size() == CardCatalog.DECK_SIZE - 1 and not screen().get_node("Margin/Content/Footer/Back").disabled, "Back remains available with four cards")
    var done_events: Array = []
    screen().done_requested.connect(func(_ids: Array[StringName]) -> void: done_events.append(true))
    screen()._done()
    check(done_events.size() == 1 and main.save.equipped == original, "Leaving an incomplete edit preserves the saved deck")
    await finish_menu_travel()
    click("Center/Content/Deck")
    await finish_menu_travel()
    screen()._toggle(&"glue")
    check(screen().selected.size() == CardCatalog.DECK_SIZE and not screen().selected.has(&"glue") and screen().pending_swap == &"glue", "Five-card cap stages a replacement")
    screen()._cancel_swap()
    click("Margin/Content/Footer/Back")
    await finish_menu_travel()
    click("Center/Content/Play")
    await finish_menu_travel()
    check(screen().get_node("Center/Content/Grid/Course3").visible, "All four courses immediately available")
    click("Center/Content/Back")
    await finish_menu_travel()
    click("Center/Content/Play")
    await finish_menu_travel()
    click("Center/Content/Grid/Course0")
    while main._course_entering:
        await process_frame
    await ticks(4)
    var session: GameSession = main.session
    check(main.screen_host.get_child_count() == 0 and session.deck.equipped == main.save.equipped, "Course launch uses equipped deck")
    check(session.state == GameSession.State.READY and session.elapsed_seconds == 0 and session.elixir == 10, "Initial attempt is ready, full and untimed")
    escape()
    check(session.state == GameSession.State.PAUSED and main.screen_host.get_child_count() == 1, "Esc opens the pause menu without immediately closing it")
    escape(true)
    check(session.state == GameSession.State.PAUSED, "Holding Esc does not toggle the pause menu")
    escape()
    check(session.state == GameSession.State.READY and main.screen_host.get_child_count() == 0, "Esc resumes the paused attempt")
    var button: Button = session.hud.get_node("Bottom/Stack/Hand/Card1")
    pointer(button.get_global_rect().get_center(), true)
    pointer(button.get_global_rect().get_center(), false)
    await ticks()
    check(session.deck.selected_slot == 1 and not session.aim.aiming and session.shots == 0, "Real hand click selects without aiming/firing")
    var pause_button: Button = session.hud.get_node("PauseButton")
    var hover := InputEventMouseMotion.new()
    hover.position = pause_button.get_global_rect().get_center()
    root.push_input(hover, true)
    await ticks()
    pointer(pause_button.get_global_rect().get_center(), true)
    pointer(pause_button.get_global_rect().get_center(), false)
    check(session.state == GameSession.State.PAUSED and session.shots == 0, "Top-left pause button opens the menu without firing a shot")
    click("Center/Content/Resume")
    session.aim.begin(Vector2(400, 240))
    session.aim.move_pointer(Vector2(370, 290))
    escape()
    check(session.state == GameSession.State.PAUSED and not session.aim.aiming and session.hud.visible, "Pause cancels gesture and keeps HUD visible beneath overlay")
    var at: Vector2 = session.ball.global_position
    var amount: float = session.elixir
    await ticks(10)
    check(session.ball.global_position == at and session.elixir == amount and session.elapsed_seconds == 0, "Pause freezes physics and resources")
    click("Center/Content/Resume")
    check(session.state == GameSession.State.READY and session.hud.visible, "Resume restores ready state")
    check(not session.aim.release(Vector2(370, 290)) and session.shots == 0, "Canceled drag cannot fire after resume")
    check(session.try_shot(Vector2(-30, 70)), "First real shot succeeds")
    await ticks(3)
    check(session.elapsed_seconds > 0 and session.shots == 1, "First successful shot starts clock")
    main._pause()
    var frozen: Array = [session.elapsed_seconds, session.elixir, session.ball.global_position]
    await ticks(10)
    check(frozen == [session.elapsed_seconds, session.elixir, session.ball.global_position], "Playing pause freezes complete attempt")
    click("Center/Content/Restart")
    await ticks(3)
    session = main.session
    check(session.state == GameSession.State.READY and session.shots == 0 and session.elapsed_seconds == 0 and session.elixir == 10, "Restart resets counters/state")
    check(session.ball.active_effect == CardDefinition.Effect.CLASSIC and session.ball.safe_position.distance_to(session.course.start_marker.global_position) < 0.3, "Restart restores Classic and start safe point")
    check(session.deck.equipped == main.save.equipped and session.deck.hand.size() == 3 and session.deck.draw_pile.size() == CardCatalog.DECK_SIZE - 3, "Restart preserves equipped deck and redeals")
    var mover: MovingPlatform = load("res://scenes/terrain/moving_platform.tscn").instantiate()
    session.course.get_node("MovingPlatforms").add_child(mover)
    await ticks(4)
    main._pause()
    var mover_position: Vector2 = mover.position
    var mover_time: float = mover.elapsed
    await ticks(8)
    check(mover.position == mover_position and mover.elapsed == mover_time, "Pause freezes moving platforms too")
    click("Center/Content/Resume")
    await ticks(4)
    check(mover.elapsed > mover_time, "Moving platforms resume")
    mover.free()
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    var cup: GoalCup = session.course.goal_cup
    session.ball.reset_motion(cup.global_position + Vector2(32, 4.9))
    await ticks(3)
    check(cup.capture_area.overlaps_body(session.ball), "Authored capture area detects ball")
    session.ball.velocity = Vector2(200, 0)
    check(not cup.advance_capture(session.ball, session.tuning, 1) and cup.dwell == 0, "Fast cup overshoot is not a win")
    session.ball.velocity = Vector2.ZERO
    check(not cup.advance_capture(session.ball, session.tuning, 0.3), "Settling requires complete dwell")
    session.ball.reset_motion(Vector2(200, -30))
    await ticks(2)
    check(not cup.advance_capture(session.ball, session.tuning, 0.4) and cup.dwell == 0, "Exit resets dwell")
    session.ball.reset_motion(cup.global_position + Vector2(32, 4.9))
    session.ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(2)
    check(not cup.advance_capture(session.ball, session.tuning, 1), "Armed Ghost not forcibly captured before floor passage")
    session.ball.set_card_effect(null)
    session.elapsed_seconds = 10.5
    session.shots = 3
    session.check_course_end(0.7)
    check(session.state == GameSession.State.WON and screen().has_node("Center/Content/Next"), "Settled cup ends attempt and shows result")
    check(float(main.save.records[String(courses.courses[0].id)]) == 10.5, "Only winning result records faster time")
    var won_time: float = session.elapsed_seconds
    await ticks(3)
    check(session.elapsed_seconds == won_time and not session.try_shot(Vector2(0, 80)), "Result freezes clock and forbids shots")
    click("Center/Content/Next")
    await ticks(2)
    check(main.course_index == 1 and main.session.state == GameSession.State.READY, "Next starts following course")
    session = main.session
    session.ball.simulation_enabled = false
    session.ball.reset_motion(Vector2(24, session.course.void_boundary.global_position.y - session.tuning.ball_radius - 1))
    session.check_course_end(0.02)
    check(session.state == GameSession.State.READY and session.try_shot(Vector2(0, 80)), "Rescue shot still allowed above void")
    session.ball.global_position.y = session.course.void_boundary.global_position.y
    var before_records: Dictionary = main.save.records.duplicate()
    session.check_course_end(0.02)
    check(session.state == GameSession.State.LOST and main.save.records == before_records, "Crossing boundary immediately loses without changing records")
    check(not session.try_shot(Vector2(0, 80)) and not screen().get_node("Center/Content/Next").visible, "Defeat rejects rescue and hides next")
    click("Center/Content/Restart")
    await ticks(2)
    main._pause()
    click("Center/Content/Menu")
    check(main.game_host.get_child_count() == 0 and screen().has_node("Center/Content/Deck"), "Pause to main menu cleans whole attempt")
    for index: int in range(4):
        main._show_levels()
        await finish_menu_travel()
        click("Center/Content/Grid/Course%s" % index)
        while main._course_entering:
            await process_frame
        check(main.course_index == index and main.session.course.goal_cup != null, "Selectable course has lifecycle targets")
        main.session.finish_attempt(true)
        if index == 3:
            check(screen().get_node("Center/Content/Next").text == "Choose a course", "Final result offers course selection")
            click("Center/Content/Next")
            await finish_menu_travel()
            check(screen().has_node("Center/Content/Grid/Course0"), "Final next returns to course selection")
        else:
            click("Center/Content/Menu")
    main.free()
    DirAccess.remove_absolute(test_path)
    print("Lifecycle checks: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
