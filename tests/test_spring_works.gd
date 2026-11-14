extends SceneTree
## Layout contracts, passive spring recovery, and actual engine mover rides.
var checks: int = 0
var failures: int = 0
var session: GameSession
var hits: Array[StringName] = []
var normals: Array[Vector2] = []

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func ticks(count: int) -> void:
    for tick: int in count:
        await physics_frame
        await process_frame

func body_bounds(body: TerrainObject) -> Rect2:
    var cells: Rect2i = body.get_node("Tiles").get_used_rect()
    return Rect2(body.position + Vector2(cells.position) * 8.0, Vector2(cells.size) * 8.0)

func run() -> void:
    session = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 2
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.aim.enabled = false
    session.camera_controller.set_process(false)
    var course := session.course
    check(session.courses.courses[2].id == &"spring_works", "Third course remains Spring Works")
    var bodies: Array = course.get_node("Terrain").get_children() + course.get_node("MovingPlatforms").get_children()
    for body: TerrainObject in bodies:
        check(body.get_node("Tiles").has_method("rebuild_solid"), "Paintable saved solids: " + str(body.name))
    for scenery: Node in course.get_node("Decorations").get_children():
        check(scenery is TileMapLayer and not scenery.collision_enabled, "Scenery never creates hidden obstacles")
    for route: Node in course.get_node("Routes").get_children():
        for stop: Marker2D in route.get_children():
            var title: String = stop.get_meta("support")
            if title == "GoalCup":
                continue
            var body: TerrainObject = course.get_node("Terrain/" + title)
            check(body.surface.material == SurfaceDefinition.SurfaceMaterial.NORMAL and body_bounds(body).size.x >= 104, "Both baseline routes offer broad ordinary-grip planning stops")
    for mover: MovingPlatform in course.get_node("MovingPlatforms").get_children():
        var sweep: Rect2 = body_bounds(mover)
        sweep.position += Vector2(minf(mover.endpoint_a.x,mover.endpoint_b.x),minf(mover.endpoint_a.y,mover.endpoint_b.y))
        sweep.size += (mover.endpoint_b-mover.endpoint_a).abs()
        for solid: TerrainObject in course.get_node("Terrain").get_children():
            check(not sweep.intersects(body_bounds(solid)), "Full mover sweep clears " + str(solid.name))
    await ticks(2)
    for tick: int in 180:
        session.ball.step_motion(1.0/60)
    check(session.ball.contact_body == course.get_node("Terrain/StartIsland") and session.ball.world_velocity().length() < 0.1, "Spawn remains still while choosing the opening shot")
    session.ball.contacted.connect(func(body: TerrainObject, normal: Vector2) -> void: hits.append(body.object_id); normals.append(normal))
    var classic: CardDefinition = load("res://resources/cards/classic.tres")
    for title: String in ["LaunchSpring","UpperSpring","WestSpring","RecoverySpring"]:
        hits.clear()
        normals.clear()
        var pad: TerrainObject = course.get_node("Terrain/" + title)
        session.ball.reset_motion(pad.position + Vector2(body_bounds(pad).size.x/2,-10))
        session.ball.play_card(classic,Vector2(0,50),false)
        var launched: bool = false
        for tick: int in 40:
            session.ball.step_motion(1.0/60)
            if hits.has(pad.object_id):
                launched = session.ball.world_velocity().y < -150
                break
        check(launched,"The saved spring launches a real ball upward: " + title)
    # A miss above the eastern recovery spring returns to the higher beach by
    # physics alone. No card replacement, free brake, or position fix is used.
    hits.clear()
    session.ball.reset_motion(Vector2(226,204))
    session.ball.play_card(classic,Vector2(40,40),false)
    for tick: int in 240:
        session.ball.step_motion(1.0/60)
    check(hits.has(&"recovery_spring"),"The falling shot actually touches the recovery spring")
    check(session.ball.contact_body == course.get_node("Terrain/EastBeach") and session.ball.world_velocity().length() < 1,"Passive spring recovery reaches a stable higher beach")
    # Test both authored movers on ordinary engine ticks, at multiple phases.
    session.ball.simulation_enabled = true
    for mover: MovingPlatform in course.get_node("MovingPlatforms").get_children():
        for phase: int in 2:
            session.ball.reset_motion(mover.to_global(Vector2(24,-2.02)))
            session.ball.velocity = mover.surface_velocity
            await ticks(12)
            check(session.ball.support_body == mover,"Ball boards the actual moving platform: " + str(mover.name))
            var local := mover.to_local(session.ball.global_position)
            var before := session.ball.global_position
            await ticks(60)
            check(session.ball.support_body == mover and mover.to_local(session.ball.global_position).distance_to(local) < 0.5,"Riding preserves the local foothold: " + str(mover.name))
            check(before.distance_to(session.ball.global_position) > 8,"The ride changes the player's launch position")
            var carry := session.ball.world_velocity()
            session.ball.launch(Vector2(40,-90))
            check(session.ball.velocity.distance_to(carry + Vector2(40,-90)) < 0.01,"A launch inherits the authored mover momentum once")
            await ticks(10)
    session.ball.simulation_enabled = false
    for size: Vector2i in [Vector2i(800,640),Vector2i(960,640),Vector2i(1440,900)]:
        root.size = size
        await process_frame
        var cam := session.camera_controller
        cam.set_zoom(0.01)
        cam.recenter(true)
        var extent := cam.get_viewport_rect().size/cam.camera.zoom
        check(cam.bounds.grow(0.01).encloses(Rect2(cam.camera.global_position+cam.camera.offset-extent*0.5,extent)),"Overview stays inside the course at " + str(size))
    check(course.void_detects_ball_edge and course.void_boundary.position.y == 243,"The first visible foam pixels match the loss boundary")
    session.ball.reset_motion(Vector2(0,240.99))
    session.check_course_end(1.0/60)
    check(session.state == GameSession.State.READY,"A ball just clear of the sea survives")
    session.ball.position.y += 0.02
    session.check_course_end(1.0/60)
    check(session.state == GameSession.State.LOST,"The first ball-edge contact with the water loses")
    session.free()
    print("Spring Works: %d checks, %d failure(s)" % [checks,failures])
    quit(0 if failures == 0 else 1)
