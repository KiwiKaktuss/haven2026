extends SceneTree
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func visible_rect(cam: CourseCamera) -> Rect2:
    var extent := cam.get_viewport_rect().size / cam.camera.zoom
    return Rect2(cam.camera.global_position + cam.camera.offset - extent*0.5, extent)

func run() -> void:
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    var cam := session.camera_controller
    cam.set_process(false)
    for size: Vector2i in [Vector2i(800,640),Vector2i(960,640),Vector2i(1440,900),Vector2i(2860,1707),Vector2i(640,1200)]:
        root.size = size
        await process_frame
        cam.set_zoom(0.001)
        for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
            cam.pan(direction,100)
            check(cam.bounds.grow(0.01).encloses(visible_rect(cam)),"Zoom-out and pan stay inside map at "+str(size))
        cam.set_zoom(8)
        for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
            cam.pan(direction,100)
            cam._kick = direction * 2.0
            cam._process(1.0/60)
            check(cam.bounds.grow(0.01).encloses(visible_rect(cam)),"Close zoom and impact shake stay inside map at "+str(size))
    root.size = Vector2i(960,640)
    var sea: TileMapLayer = session.course.get_node("Decorations/Sea")
    check(sea.position.y == 32, "Sea is lowered by 32 world pixels")
    var line: float = session.course.void_boundary.global_position.y
    session.ball.reset_motion(Vector2(0,line-session.tuning.ball_radius-0.01))
    session.check_course_end(1.0/60)
    check(session.state == GameSession.State.READY, "Ball just above sea survives")
    session.ball.global_position.y += 0.01
    session.check_course_end(1.0/60)
    check(session.state == GameSession.State.LOST, "First edge contact with sea loses immediately")
    var hand: Control = session.hud.get_node("Bottom/Stack/Hand/Card0")
    check(hand.custom_minimum_size == Vector2(66,93), "Hand artwork has compact 3x pixel size")
    session.free()
    print("Course boundaries: %d checks, %d failure(s)" % [checks,failures])
    quit(0 if failures == 0 else 1)
