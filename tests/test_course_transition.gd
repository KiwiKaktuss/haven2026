extends SceneTree
## Real selector input, frozen entrance state, resize and playable handoff.
var main: Node2D
var checks: int = 0
var failures: int = 0
var capture_enabled: bool = false

func _initialize() -> void:
    capture_enabled = "--capture" in OS.get_cmdline_user_args()
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func click(button: Button, offset: Vector2 = Vector2.ZERO) -> void:
    var at: Vector2 = button.get_global_rect().get_center() + offset
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion, true)
    for down: bool in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event, true)

func capture(label: String) -> void:
    if capture_enabled:
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://screenshots/course_transition/" + label + ".png")

func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://screenshots/course_transition")
    root.size = Vector2i(960, 640)
    main = load("res://main.tscn").instantiate()
    main.save.path = "res://.capture/transition_unused_save.json"
    root.add_child(main)
    await process_frame
    main._menu_screen._finish_intro()
    for index: int in range(4):
        main._show_levels()
        while main._journey_moving:
            await process_frame
        await process_frame
        var source: Button = main._levels_screen.get_node("Center/Content/Grid/Course%d" % index)
        var click_offset: Vector2 = Vector2(-72, 35) if index % 2 == 0 else Vector2(64, -28)
        var pressed_at: Vector2 = source.get_global_rect().get_center() + click_offset
        click(source, click_offset)
        check(main._course_entering and main.course_transition.visible, "Real course click starts the transition")
        check(main.course_transition._center.is_equal_approx(pressed_at), "Closing iris targets the exact off-center mouse press")
        var move := InputEventMouseMotion.new()
        move.position = Vector2(10, 10)
        root.push_input(move, true)
        check(not main._levels_screen.can_process() and not is_instance_valid(main.session), "Selector freezes before the course is created")
        main._enter_course((index + 1) % 4)
        main._show_menu()
        main._restart()
        check(main._course_entering and main._levels_screen.visible, "Repeated navigation cannot interrupt entrance")
        var key := InputEventKey.new()
        key.physical_keycode = KEY_ESCAPE
        key.pressed = true
        root.push_input(key, true)
        await create_timer(0.28).timeout
        check(main.course_transition._center.is_equal_approx(pressed_at), "Closing origin stays at the press after the cursor moves")
        check(main.course_transition._radius_fraction > 0.0 and main.course_transition._radius_fraction < 1.0, "Circle closes progressively from every edge")
        await capture("%d_closing" % index)
        while not is_instance_valid(main.session):
            await process_frame
        var session: GameSession = main.session
        var at: Vector2 = session.ball.global_position
        check(main.course_index == index and session.state == GameSession.State.PAUSED, "Correct incoming course is frozen")
        var covered_at: int = Time.get_ticks_msec()
        check(session.ball.visible and session.hud.modulate.a == 0.0, "Ball is ready at the tee beneath the solid color")
        check(main.course_transition._radius_fraction == 0.0, "Scene swap occurs beneath the fully closed iris")
        check(main.course_transition.get_child_count() == 1, "Hold screen contains only the solid color")
        await capture("%d_solid" % index)
        check(not session.try_shot(Vector2(-30, 70)), "Shots are rejected during entrance")
        root.size = Vector2i(800, 640) if index % 2 == 0 else Vector2i(1440, 900)
        await create_timer(0.7).timeout
        check(main.course_transition._radius_fraction == 0.0, "Solid color stays fully opaque during the hold")
        while main.course_transition._radius_fraction == 0.0:
            await process_frame
        check(Time.get_ticks_msec() - covered_at >= 1570, "Reveal waits 1.6 seconds after the screen is fully covered")
        await create_timer(0.28).timeout
        check(main.course_transition._radius_fraction > 0.0 and main.course_transition._radius_fraction < 1.0, "Opening circle progressively reveals terrain")
        var ball_screen: Vector2 = session.ball.get_global_transform_with_canvas().origin
        check(main.course_transition._center.is_equal_approx(ball_screen), "Reveal is centered exactly on the ball after resize")
        check(session.ball.global_position == at and session.elapsed_seconds == 0.0 and session.shots == 0, "Spawn animation never changes physical position or counters")
        check(session.elixir == 10.0 and not session.can_process(), "Resources and course physics remain frozen through spawn")
        check(main.course_transition.size == main.get_viewport_rect().size, "Transition follows viewport resize")
        await capture("%d_opening" % index)
        while main._course_entering:
            await process_frame
        check(not main.course_transition.visible and session.can_process(), "Handoff removes the input blocker and resumes gameplay")
        check(session.state == GameSession.State.READY and session.hud.modulate.a == 1.0, "Handoff restores the ready state and full HUD")
        check(session.ball.sprite.position == Vector2.ZERO and session.ball.sprite.scale == Vector2.ONE and session.ball.sprite.modulate.a == 1.0, "Sprite finishes in its original presentation state")
        await capture("%d_ready" % index)
        check(session.try_shot(Vector2(-30, 70)), "First shot works after entrance")
        main._restart()
        check(not main._course_entering and main.session.state == GameSession.State.READY, "Quick retry stays immediate")
        main._show_menu()
    main.free()
    await process_frame
    print("Course transition: %d checks, %d failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
