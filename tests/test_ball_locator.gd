extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func run() -> void:
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    var ball: GolfBall = session.ball
    ball.simulation_enabled = false
    var feedback: BallFeedback = ball.get_node("Feedback")
    feedback.set_physics_process(false)
    var arrow: Node2D = feedback.get_node("Locator")
    check(arrow.visible, "Locator appears immediately at the course spawn")
    ball.global_position.x += 2.0
    feedback._physics_process(0.1)
    check(not arrow.visible, "Movement hides the initial locator")
    feedback._physics_process(9.9)
    check(not arrow.visible, "Locator stays hidden before ten stationary seconds")
    feedback._physics_process(0.1)
    check(arrow.visible, "Locator returns after ten stationary seconds")
    ball.global_position.x += 0.1
    feedback._physics_process(0.1)
    check(arrow.visible, "Small contact jitter does not hide the locator")
    ball.global_position.x += 0.2
    feedback._physics_process(0.1)
    check(not arrow.visible, "Accumulated slow movement hides the locator")
    feedback._physics_process(9.9)
    check(not arrow.visible, "Movement restarts the full idle delay")
    feedback._physics_process(0.1)
    check(arrow.visible, "Locator reappears on later idle periods")
    ball.play_card(session.deck.selected_card(), Vector2(30, -70))
    check(not arrow.visible, "A shot immediately hides the locator")
    ball.reset_motion(session.course.start_marker.global_position)
    check(arrow.visible, "Respawning restores the locator immediately")
    session.camera_controller.set_zoom(3.0)
    await process_frame
    feedback._process(0.0)
    var screen_scale: Vector2 = arrow.get_global_transform_with_canvas().get_scale()
    check(arrow.scale.is_equal_approx(Vector2.ONE), "Locator keeps its authored world size")
    check(screen_scale.is_equal_approx(feedback.get_canvas_transform().get_scale()), "Locator scales with the camera zoom")
    check(arrow.get_node("Arrow").texture.resource_path == "res://art/red.png", "Locator uses the supplied red arrow texture")
    session.camera_controller.set_zoom(5.0)
    await process_frame
    feedback._process(0.0)
    check(arrow.get_global_transform_with_canvas().get_scale().x > screen_scale.x, "Zooming in makes the arrow larger on screen")
    session.camera_controller.set_zoom(3.0)
    if "--capture" in OS.get_cmdline_user_args():
        session.camera_controller.recenter(true)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("/tmp/haven-ball-locator.png")
    session.free()
    await process_frame
    print("Ball locator: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
