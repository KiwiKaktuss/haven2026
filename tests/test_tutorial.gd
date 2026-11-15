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
        await process_frame
        check(session.course != null, "Room %d loads" % step)
        var marked_walls: Dictionary = {1:"EndWall",6:"GateWall",7:"ApproachWall",9:"BounceGuideWall"}
        if marked_walls.has(step):
            check(session.course.has_node("Terrain/" + marked_walls[step]), "Marked lesson wall is saved")
        check(session.course.goal_cup.pull_radius == 18.0, "Normal game hole attraction radius")
        var center: Vector2 = session.get_canvas_transform() * session.challenge_bounds().get_center()
        check(absf(center.x - session.get_viewport_rect().size.x * 0.5) < 1.0, "Challenge is centered horizontally")
        check(absf(center.y - (176.0 + session.get_viewport_rect().size.y - 171.0) * 0.5) < 1.0, "Challenge is centered in the playable area")
        check(not session.lesson_ui.has_node("Hint") and not session.lesson_ui.has_node("Menu") and not session.lesson_ui.has_node("Retry"), "Clean tutorial controls and no lower label")
        check(session.lesson_ui.get_node("PauseButton").text == "II", "Standard pause button")
        check(session.deck.hand.size() == 3, "Fixed hand")
        check(session.hud.get_node("Top").visible == false, "No timer")
        check(not session.objective_met(), "No automatic lesson completion")
        check(session.lesson_ui.get_node("Lesson/Content/Title").text.ends_with("%d / 10" % (step+1)), "Title includes the step counter")
        for body: TerrainObject in session.course.get_node("Terrain").get_children():
            check(not body is MovingPlatform, "No moving-platform tutorial remains")
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
    click(session.lesson_ui.get_node("PauseButton"))
    check(session.state == GameSession.State.PAUSED, "Pause button opens the normal pause menu")
    main._restart()
    check(main.session == session and session.step_index == 4 and session.state == GameSession.State.READY, "Pause restart retries current tutorial lesson")
    await process_frame
    click(session.lesson_ui.get_node("PauseButton"))
    await process_frame
    await process_frame
    click(main.screen_host.get_child(0).get_node("Center/Content/Restart"))
    check(session.step_index == 4 and session.elixir < 2.0 and session.shots == 0, "Pause restart resets lesson resources")
    await process_frame
    var equipped: Array[StringName] = main.save.equipped.duplicate()
    session.step_index = TutorialSession.CARD_STEP
    session.retry_step()
    await process_frame
    await process_frame
    var cards: Control = session.lesson_ui.get_node("CardLesson")
    check(cards.visible and not session.hud.visible and not session.course.visible, "Card lesson uses its own in-place layout")
    check(not session.aim.enabled and not session.ball.simulation_enabled, "Card overview does not accept shots")
    check(cards.next_button.disabled, "Explore a card before continuing")
    session.complete_card_lesson()
    check(session.step_index == 5, "Continue cannot skip unexplored cards")
    for index: int in session.deck.catalog.cards.size():
        var hover := InputEventMouseMotion.new()
        hover.position = cards.grid.get_child(index).get_global_rect().get_center()
        root.push_input(hover,true)
        await process_frame
        await process_frame
        var view: CardView = cards.grid.get_child(index)
        var information: Control = view.get_node("Information")
        check(information.get_node("Margin/Content/Description").text == session.deck.catalog.cards[index].description, "Real hover explains each card")
        check(information.visible and information.get_global_rect().end.y < view.get_global_rect().position.y, "Hover information appears above its card")
    check(session.card_explored and not cards.next_button.disabled, "Inspection enables Continue")
    check(main.save.equipped == equipped, "Card overview cannot change the saved deck")
    click(session.lesson_ui.get_node("PauseButton"))
    await process_frame
    await process_frame
    click(main.screen_host.get_child(0).get_node("Center/Content/Restart"))
    check(not session.card_explored and cards.next_button.disabled and session.step_index == 5, "Pause restart resets only the card overview")
    cards.grid.get_child(1).grab_focus()
    check(session.card_explored and cards.grid.get_child(1).get_node("Information/Margin/Content/Title").text.begins_with("Snipe"), "Keyboard focus also explains a card")
    var pause_key := InputEventKey.new()
    pause_key.physical_keycode = KEY_ESCAPE
    pause_key.keycode = KEY_ESCAPE
    pause_key.pressed = true
    root.push_input(pause_key, true)
    check(session.state == GameSession.State.PAUSED, "Esc pauses the card lesson")
    pause_key = InputEventKey.new()
    pause_key.physical_keycode = KEY_ESCAPE
    root.push_input(pause_key, true)
    main._resume()
    check(not session.hud.visible and cards.visible, "Resume preserves the card overview")
    click(cards.next_button)
    check(session.step_index == 6 and session.course.has_node("Terrain/BankWall"), "Card lesson continues directly to walls")
    check(session.aim.enabled and session.ball.simulation_enabled and session.hud.visible, "World controls return after cards")
    session.step_index = 9
    session.retry_step()
    check(session.course.has_node("Terrain/Spring") and not session.course.has_node("Terrain/Ride"), "Bouncy surfaces finish the tutorial")
    session._advance_step()
    session.lesson_ui.get_node("Complete/Center/Panel/Content/Begin").pressed.emit()
    check(main.session is GameSession and not main.session is TutorialSession and main.course_index == 0, "Begin playing launches first course")
    main.free()
    await process_frame
    print("Tutorial: %d / %d checks passed" % [checks-failures,checks])
    quit(1 if failures else 0)
