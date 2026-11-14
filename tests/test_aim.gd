extends SceneTree
var failures: int = 0
var checks: int = 0
var lab: Node2D
var session: GameSession
var aim: AimController
var preview: TrajectoryPreview
var ball: GolfBall
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
var contact_positions: Array[Vector2] = []
var contact_bodies: Array[TerrainObject] = []

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", message)

func _initialize() -> void:
    call_deferred("run")

func ticks(count: int = 1) -> void:
    for tick: int in range(count):
        await physics_frame
        await process_frame

func choose(id: StringName) -> void:
    var ids: Array[StringName] = [id]
    for card: CardDefinition in catalog.cards:
        if ids.size() < 6 and not ids.has(card.id):
            ids.append(card.id)
    session.deck.start_attempt(ids)
    for slot: int in range(3):
        if session.deck.hand[slot].id == id:
            session.deck.select_slot(slot)
            return
    while session.deck.selected_card().id != id:
        session.deck.cycle_selected()

func event_button(at: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
    var event: InputEventMouseButton = InputEventMouseButton.new()
    event.position = at
    event.global_position = at
    event.button_index = button
    event.pressed = pressed
    root.push_input(event, true)

func event_motion(at: Vector2) -> void:
    var event: InputEventMouseMotion = InputEventMouseMotion.new()
    event.position = at
    event.global_position = at
    root.push_input(event, true)

func run() -> void:
    lab = load("res://tests/scenes/card_lab.tscn").instantiate()
    root.add_child(lab)
    await ticks(2)
    session = lab.session
    session.set_physics_process(false)
    aim = lab.aim
    ball = session.ball
    ball.simulation_enabled = false
    preview = aim.preview
    ball.contacted.connect(func(body: TerrainObject, _normal: Vector2) -> void:
        contact_positions.append(ball.global_position)
        contact_bodies.append(body))
    for body: MovingPlatform in lab.get_node("MovingPlatforms").get_children():
        body.motion_enabled = false
    await ticks(2)
    choose(&"classic")
    aim.begin(Vector2(300, 240))
    aim.move_pointer(Vector2(340, 320))
    aim.update_preview()
    var drag: Vector2 = aim.drag_vector()
    var power: float = ShotCalculation.strength(drag, session.tuning)
    check(aim.aiming and preview.visible, "Valid gesture previews")
    lab.camera_controller.set_zoom(4)
    lab.camera_controller.pan(Vector2.RIGHT, 0.2)
    aim.update_preview()
    check(aim.drag_vector() == drag and ShotCalculation.strength(aim.drag_vector(), session.tuning) == power, "Camera motion/zoom preserve screen gesture")
    check(is_equal_approx(preview.central_line.width * aim.camera.zoom.x, preview.line_screen_width), "Constant on-screen line width")
    var shots: int = session.shots
    aim.cancel()
    check(not aim.release(Vector2(340, 320)) and session.shots == shots, "Cancel then left release cannot fire")
    aim.begin(Vector2(200, 200))
    check(not aim.release(Vector2(203, 202)) and session.shots == shots, "Click/deadzone cancels")
    choose(&"rewind")
    ball.safe_position = Vector2(50, 50)
    aim.begin(Vector2(200, 200))
    aim.move_pointer(Vector2(200, 280))
    aim.update_preview()
    check(preview.central.points[0] == ball.safe_position, "Rewind preview uses saved origin")
    var old_drag: Vector2 = aim.drag_vector()
    session.deck.select_slot((session.deck.selected_slot + 1) % 3)
    aim.update_preview()
    check(aim.drag_vector() == old_drag and preview.central.points[0] == ball.global_position, "Mid-drag selection preserves gesture and updates origin")
    aim.cancel()
    choose(&"fire")
    session.elixir = 3.9
    aim.begin(Vector2(300, 200))
    aim.move_pointer(Vector2(300, 360))
    aim.update_preview()
    check(preview.envelope.visible and preview.envelope.polygons.size() > 0, "Spread draws as explicit filled sections")
    var different_boundaries: bool = preview.lower.points[-1].distance_to(preview.upper.points[-1]) > 0.5
    check(different_boundaries, "Spread boundary paths differ")
    for section: PackedInt32Array in preview.envelope.polygons:
        var tri: PackedVector2Array = PackedVector2Array()
        for vertex: int in section:
            tri.append(preview.envelope.polygon[vertex])
        check(Geometry2D.triangulate_polygon(tri).size() == 3, "Envelope section triangulates")
    check(is_equal_approx(preview.modulate.a, preview.unaffordable_opacity), "Unaffordable preview dimmed")
    var feedback: AimFeedback = lab.get_node("CanvasLayer/AimFeedback")
    check(feedback.power.value == 100 and feedback.label.text.contains("Need "), "Power meter and affordability feedback")
    check(not aim.release(Vector2(300, 360)) and session.shots == shots, "Early unaffordable release does not fire")
    session.advance_clock(30)
    check(session.shots == shots, "Regeneration does not queue a shot")
    session.elixir = 3.9
    aim.begin(Vector2(300, 200))
    aim.move_pointer(Vector2(300, 360))
    session.advance_clock(0.6)
    aim.update_preview()
    check(preview.modulate.a == 1 and not feedback.label.text.contains("Need "), "Held drag becomes affordable")
    check(aim.release(Vector2(300, 360)) and session.shots == shots + 1, "Held affordable release commits")
    check(not aim.release(Vector2(300, 360)) and session.shots == shots + 1, "Release fires at most once")
    check(lab.camera_controller.following, "Successful shot restores follow")
    aim.begin(Vector2(300, 200))
    aim.move_pointer(Vector2(300, 300))
    session.state = GameSession.State.PAUSED
    aim._physics_process(0)
    session.state = GameSession.State.PLAYING
    check(not aim.release(Vector2(300, 300)), "Pause invalidates pending gesture")
    aim.begin(Vector2(300, 200))
    aim._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    check(not aim.aiming, "Focus loss cancels")
    # Full viewport input dispatch, including GUI interception.
    session.elixir = 10
    shots = session.shots
    event_motion(Vector2(400, 260))
    await ticks()
    event_button(Vector2(400, 260), true)
    event_motion(Vector2(420, 320))
    await ticks()
    check(aim.aiming, "World mouse-down begins gesture through viewport")
    event_button(Vector2(420, 320), true, MOUSE_BUTTON_RIGHT)
    event_button(Vector2(420, 320), false)
    await ticks()
    check(not aim.aiming and session.shots == shots, "Right cancel through input dispatch suppresses release")
    var slot_button: Button = lab.hand_buttons[1]
    var ui_point: Vector2 = slot_button.get_global_rect().get_center()
    event_motion(ui_point)
    await ticks()
    event_button(ui_point, true)
    event_button(ui_point, false)
    await ticks()
    check(not aim.aiming and session.shots == shots and session.deck.selected_slot == 1, "Hand click is selection, never world shot")
    event_motion(Vector2(400, 260))
    await ticks()
    event_button(Vector2(400, 260), true)
    event_motion(Vector2(410, 310))
    await ticks()
    var held_drag: Vector2 = aim.drag_vector()
    var key: InputEventKey = InputEventKey.new()
    key.physical_keycode = KEY_3
    key.pressed = true
    root.push_input(key, true)
    check(session.deck.selected_slot == 2 and aim.drag_vector() == held_drag, "Number key switches during drag")
    event_motion(ui_point)
    await ticks()
    event_button(ui_point, false)
    check(session.shots == shots and not aim.aiming, "World drag released over UI cancels")
    # Minimum zoom must include the whole bounds even for a tall course.
    var cam: CourseCamera = lab.camera_controller
    var old_bounds: Rect2 = cam.bounds
    cam.bounds = Rect2(0, 0, 800, 1600)
    cam.minimum_zoom = 1
    cam.set_zoom(0.01)
    var world_view: Vector2 = cam.get_viewport_rect().size / cam.camera.zoom
    check(world_view.x + 0.01 >= cam.bounds.size.x and world_view.y + 0.01 >= cam.bounds.size.y, "Overview fits entire course")
    check(cam.camera.global_position.distance_to(cam.bounds.get_center()) < 0.01, "Oversized viewport centers on bounds")
    cam.bounds = old_bounds
    cam.set_zoom(1.6)
    # Holding a gesture never pauses the live simulation or attempt clock.
    ball.reset_motion(Vector2(48, 45))
    ball.simulation_enabled = true
    session.set_physics_process(true)
    session.state = GameSession.State.PLAYING
    aim.begin(Vector2(400, 260))
    aim.move_pointer(Vector2(400, 300))
    var prior_position: Vector2 = ball.global_position
    var prior_time: float = session.elapsed_seconds
    await ticks(5)
    check(ball.global_position.y > prior_position.y and session.elapsed_seconds > prior_time, "Simulation and clock continue during aiming")
    check(preview.central.points[0].distance_to(ball.global_position) < 0.01, "Preview origin follows moving ball during held drag")
    aim.cancel()
    ball.simulation_enabled = false
    session.set_physics_process(false)
    # Query current geometry anew while aiming; there is no stale cached course.
    ball.reset_motion(Vector2(48, 50))
    choose(&"classic")
    var first: Dictionary = preview.predict(ball, session.deck.selected_card(), Vector2(0, -80))
    var terrain: TerrainObject = lab.get_node("Terrain/Normal")
    var old_terrain_position: Vector2 = terrain.position
    terrain.position.x += 500
    await ticks()
    var changed: Dictionary = preview.predict(ball, session.deck.selected_card(), Vector2(0, -80))
    check(first.collider != changed.collider, "Prediction refreshes after geometry moves")
    terrain.position = old_terrain_position
    await ticks()
    await prediction_cases()
    lab.free()
    print("Aim checks: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)

func prediction_cases() -> void:
    var dt: float = 1.0 / Engine.physics_ticks_per_second
    for id: StringName in [&"classic", &"heavy", &"slow", &"ghost", &"rewind"]:
        ball.reset_motion(Vector2(48, 50))
        ball.safe_position = Vector2(48, 50)
        ball.velocity = Vector2(4, 20)
        if id == &"rewind":
            ball.global_position = Vector2(400, 30)
        var card: CardDefinition = catalog.find_card(id)
        var drag: Vector2 = Vector2(0, -80)
        var before: Array = [ball.global_position, ball.velocity, ball.active_effect, session.random.state]
        var predicted: Dictionary = preview.predict(ball, card, drag)
        check(before == [ball.global_position, ball.velocity, ball.active_effect, session.random.state], "Prediction is side-effect free: " + str(id))
        check(preview.probe.get_collision_exceptions().is_empty(), "Query exceptions cleaned: " + str(id))
        ball.play_card(card, ShotCalculation.impulse(card, drag, ball.tuning))
        contact_positions.clear()
        contact_bodies.clear()
        var points: PackedVector2Array = predicted.points
        check(points[0] == ball.global_position, "Actual launch origin: " + str(id))
        for step: int in range(points.size() - 1):
            ball.step_motion(dt)
            if not contact_positions.is_empty():
                check(step == predicted.hit_step and contact_bodies[0] == predicted.collider, "Same first real hit tick/body: " + str(id))
                check(contact_positions[0].distance_to(points[-1]) < 0.05, "Same collision point: " + str(id))
                break
            check(ball.global_position.distance_to(points[step + 1]) < 0.01, "Flight agrees with preview: " + str(id))
        check(predicted.hit_step >= 0 and not contact_positions.is_empty(), "Stops at first hit, not bounces: " + str(id))
        if id == &"ghost":
            check(predicted.ignored_id == &"normal" and predicted.ghost_points.size() > 1, "Ghost preview marks whole-object passage")
    ball.reset_motion(Vector2(48, 77.95))
    ball.step_motion(dt)
    var ghost: CardDefinition = catalog.find_card(&"ghost")
    var outward: Dictionary = preview.predict(ball, ghost, Vector2(0, 80))
    check(outward.ghost_entry_step == -1 or outward.ghost_entry_step > 1, "Ghost outward departure does not consume current contact immediately")
    var inward: Dictionary = preview.predict(ball, ghost, Vector2(0, -80))
    check(inward.ignored_id == &"normal" and inward.ghost_entry_step == 0, "Ghost inward preview passes touched floor immediately")
    # Moving support contributes its current velocity exactly once to both paths.
    var mover: MovingPlatform = lab.get_node("MovingPlatforms/Horizontal")
    ball.reset_motion(mover.to_global(Vector2(24, -2.02)))
    ball.support_body = mover
    ball.contact_body = mover
    ball.support_transform = mover.global_transform
    mover.surface_velocity = Vector2(17, 0)
    var card: CardDefinition = catalog.find_card(&"classic")
    var drag: Vector2 = Vector2(0, 80)
    var predicted: Dictionary = preview.predict(ball, card, drag)
    var expected: Vector2 = ball.global_position + BallMotion.accelerate(Vector2(17, -90), ball.tuning.gravity, dt) * dt
    check(predicted.points[1].distance_to(expected) < 0.01, "Preview uses carry exactly once")
    ball.play_card(card, ShotCalculation.impulse(card, drag, ball.tuning))
    ball.step_motion(dt)
    check(ball.global_position.distance_to(predicted.points[1]) < 0.01, "Moving-platform launch agrees with preview")
