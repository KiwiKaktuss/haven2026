extends SceneTree
## Saved layout contracts plus actual sliding/catching and failure behavior.
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 1
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.aim.enabled = false
    session.camera_controller.set_process(false)
    var course := session.course
    check(session.courses.courses[1].id == &"cold_snap", "The second course is Cold Snap")
    for body: TerrainObject in course.get_node("Terrain").get_children():
        check(body.get_node("Tiles").has_method("rebuild_solid"), "Every solid remains paintable: " + str(body.name))
    for title: String in ["WestWall","EastWall","Ceiling","Seabed","RecoveryBeach","EastBeach","WestBreakwater"]:
        check(course.has_node("Terrain/" + title), "Enclosure/recovery terrain: " + title)
    for scenery: Node in course.get_node("Decorations").get_children():
        check(scenery is TileMapLayer and not scenery.collision_enabled, "Frost scenery never adds invisible obstacles")
    check(course.get_node("Routes/Safe").get_child_count() == 5, "The west route has four meaningful climbs")
    check(course.get_node("Routes/Alternate").get_child_count() == 6, "The east loop remains a distinct route")
    var sea: TileMapLayer = course.get_node("Decorations/Sea")
    check(sea.tile_set.get_source(0).get_tile_animation_frames_count(Vector2i.ZERO) == 4, "The sea has animated foam")
    check(course.void_detects_ball_edge and course.void_boundary.position.y == 227, "Visible foam and first-edge defeat align")
    await physics_frame
    await process_frame
    for tick: int in 180:
        session.ball.step_motion(1.0 / 60.0)
    check(session.ball.contact_body == course.get_node("Terrain/StartIsland"), "Spawn settles safely on ordinary turf")
    check(session.ball.world_velocity().length() < 1.0, "The opening hand can be inspected without drifting")
    var classic: CardDefinition = load("res://resources/cards/classic.tres")
    for row: Dictionary in [
        {"origin": Vector2(144,125.95), "velocity": Vector2(135,0), "ice": "IceRunway", "catch": "BrakeBank"},
        {"origin": Vector2(256,-2.05), "velocity": Vector2(-135,0), "ice": "ReturnIce", "catch": "CenterBank"}
    ]:
        session.ball.reset_motion(row.origin)
        session.ball.play_card(classic, row.velocity, false)
        var slid: bool = false
        for tick: int in 240:
            session.ball.step_motion(1.0 / 60.0)
            slid = slid or (session.ball.contact_body == course.get_node("Terrain/" + row.ice) and absf(session.ball.world_velocity().x) > 50)
        check(slid, "The lane preserves useful momentum: " + row.ice)
        check(session.ball.attached_body == course.get_node("Terrain/" + row.catch), "The flush sticky bank catches a sliding Classic ball: " + row.catch)
        check(session.ball.world_velocity().length() < 0.01, "The catch bank supplies a stable planning stop")
    for size: Vector2i in [Vector2i(800,640),Vector2i(960,640),Vector2i(1440,900)]:
        root.size = size
        await process_frame
        var cam := session.camera_controller
        cam.set_zoom(0.01)
        cam.recenter(true)
        var extent := cam.get_viewport_rect().size / cam.camera.zoom
        check(cam.bounds.grow(0.01).encloses(Rect2(cam.camera.global_position + cam.camera.offset - extent * 0.5, extent)), "Overview remains inside the map at " + str(size))
    var line: float = course.void_boundary.global_position.y
    session.ball.reset_motion(Vector2(0, line - session.tuning.ball_radius - 0.01))
    session.check_course_end(1.0 / 60.0)
    check(session.state == GameSession.State.READY, "The ball is recoverable above the water")
    session.ball.global_position.y += 0.02
    session.check_course_end(1.0 / 60.0)
    check(session.state == GameSession.State.LOST, "First contact with the visible sea ends the attempt")
    session.free()
    print("Cold Snap: %d checks, %d failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
