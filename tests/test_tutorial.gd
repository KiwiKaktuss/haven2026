extends SceneTree
var failures: int = 0
var checks: int = 0
var session: TutorialSession

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func click(button: Button) -> void:
    var at: Vector2 = button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion, true)
    for down: bool in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event, true)

func run() -> void:
    session = load("res://scenes/tutorial/tutorial_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    for step: int in 10:
        session.step_index = step
        session.retry_step()
        await physics_frame
        check(session.course != null, "Room %d loads" % step)
        check(session.deck.hand.size() == 3, "Fixed hand")
        check(session.hud.get_node("Top").visible == false, "No timer")
        check(not session.objective_met(), "No automatic lesson completion")
        check(session.lesson_ui.get_node("Lesson/Content/Count").text == "%d / 10" % (step+1), "Counter")
        for body: TerrainObject in session.course.get_node("Terrain").get_children():
            if step < 6:
                check(body.surface.material == SurfaceDefinition.SurfaceMaterial.NORMAL, "Early lessons have ordinary terrain only")
        session.ball.reset_motion(session.course.goal_cup.capture_shape.global_position)
        session.check_course_end(1.0)
        check(not session.transitioning, "Arriving without a shot cannot skip a lesson")
    session.step_index = 4
    session.retry_step()
    check(not session.try_shot(Vector2(-60,60)), "Elixir lesson starts below cost")
    check(session.shots == 0, "Rejected shot does not consume a card")
    session.advance_clock(2.5)
    check(session.elixir >= 2.0, "Elixir refills")
    check(session.try_shot(Vector2(-60,60)), "Affordable shot succeeds")
    check(session.elixir < 1.0, "Shot spends elixir")
    session.step_index = 2
    session.retry_step()
    check(session.deck.select_slot(1), "Different card can be selected")
    check(session.ball.active_effect == CardDefinition.Effect.CLASSIC, "Selection does not play effect")
    check(session.try_shot(Vector2(-60,60)), "Selected card can be played")
    check(session.used_other and session.ball.active_effect == CardDefinition.Effect.SNIPER, "Shot activates selected card")
    session.step_index = 3
    session.retry_step()
    check(session.try_shot(Vector2(-60,60)), "Cycle shot")
    check(not session.deck.slot_ready(0), "Played slot has real deal delay")
    check(session.deck.hand[0].id == &"sniper", "Deterministic replacement")
    session.advance_clock(1.7)
    session.check_course_end(1.0/60)
    check(session.replacement_seen, "Replacement arrival observed")
    session.retry_step()
    check(session.step_index == 3 and session.shots == 0, "Retry only current lesson")
    session.free()
    await process_frame
    var main: Node = load("res://main.tscn").instantiate()
    main.save.path = "res://logs/tutorial-flow-save.json"
    root.add_child(main)
    main._menu_screen._finish_intro()
    await process_frame
    await process_frame
    click(main._menu_screen.get_node("Center/Content/Tutorial"))
    check(main.session is TutorialSession, "Real menu click opens tutorial")
    session = main.session
    session.step_index = 4
    session.retry_step()
    main._pause()
    check(session.state == GameSession.State.PAUSED, "Tutorial pauses")
    main._restart()
    check(main.session == session and session.step_index == 4 and session.state == GameSession.State.READY, "Pause restart retries current tutorial lesson")
    await process_frame
    click(session.lesson_ui.get_node("Retry"))
    check(session.step_index == 4 and session.elixir < 2.0 and session.shots == 0, "Real Retry resets lesson resources")
    var equipped: Array[StringName] = main.save.equipped.duplicate()
    session.step_index = 9
    session.retry_step()
    session._advance_step()
    session.lesson_ui._show_cards()
    session.lesson_ui.preview._toggle(&"fire")
    check(main.save.equipped == equipped, "Optional card preview cannot change the saved deck")
    session.lesson_ui.preview._done()
    check(session.lesson_ui.preview == null, "Card guide returns to completion")
    session.lesson_ui.get_node("Complete/Center/Panel/Content/Begin").pressed.emit()
    check(main.session is GameSession and not main.session is TutorialSession and main.course_index == 0, "Begin playing launches first course")
    main.free()
    await process_frame
    print("Tutorial: %d / %d checks passed" % [checks-failures,checks])
    quit(1 if failures else 0)
