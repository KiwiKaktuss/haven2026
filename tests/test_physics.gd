extends SceneTree
var failures: int = 0
var lab: Node2D
var ball: GolfBall
var collisions: Array[StringName] = []

func check(condition: bool, message: String) -> void:
    print("PASS: " if condition else "FAIL: ", message)
    if not condition:
        failures += 1

func _initialize() -> void:
    call_deferred("run")

func ticks(count: int) -> void:
    for tick: int in range(count):
        await physics_frame
        await process_frame

func place(at: Vector2, speed: Vector2) -> void:
    ball.reset_motion(at)
    ball.velocity = speed
    collisions.clear()

func run() -> void:
    lab = load("res://tests/scenes/physics_lab.tscn").instantiate()
    root.add_child(lab)
    for demo: GolfBall in lab.get("balls"):
        demo.simulation_enabled = false
    ball = load("res://scenes/ball/ball.tscn").instantiate()
    root.add_child(ball)
    ball.contacted.connect(func(body: TerrainObject, _normal: Vector2) -> void: collisions.append(body.object_id))
    var object_ids: Array[StringName] = []
    for host: Node in [lab.get_node("Terrain"), lab.get_node("MovingPlatforms")]:
        for terrain: TerrainObject in host.get_children():
            check(not object_ids.has(terrain.object_id), "Unique whole-object terrain ID: " + str(terrain.object_id))
            object_ids.append(terrain.object_id)
            check(not terrain.get_node("Tiles").collision_enabled, "Visual tiles do not duplicate body collision")
    var multi: TerrainObject = lab.get_node("Terrain/MultiShape")
    check(multi.get_node("SolidSilhouette").get_parent() == multi.get_node("SideSilhouette").get_parent(), "Multiple solid shapes share one terrain body")
    await ticks(2)
    var normal: SurfaceDefinition = load("res://resources/terrain/normal.tres")
    for angle: int in range(0, 360, 15):
        var direction: Vector2 = Vector2.UP.rotated(deg_to_rad(angle))
        var result: Vector2 = BallMotion.impact(-direction * 200 + direction.orthogonal() * 60, direction, normal, ball.tuning)
        check(result.length() <= Vector2(200, 60).length() + 0.001, "Ordinary impacts cannot add energy at %s degrees" % angle)
    place(Vector2(40, 70), Vector2(24, 15))
    await ticks(110)
    check(ball.support_body == lab.get_node("Terrain/Normal"), "Normal ground contact persists")
    check(ball.velocity.length() < 1.0, "Normal landing settles within two seconds")
    check(ball.safe_position.distance_to(ball.global_position) < 0.3, "Stationary rolling/resting updates safe point")
    place(Vector2(152, 77.95), Vector2(20, 0))
    await ticks(60)
    check(ball.velocity.x > 16.0, "Ice preserves rolling momentum")
    place(Vector2(280, 60), Vector2(0, 60))
    await ticks(20)
    check(ball.attached_body == lab.get_node("Terrain/Sticky"), "Sticky impact attaches fully")
    var anchor: Vector2 = ball.global_position
    await ticks(30)
    check(ball.global_position.distance_to(anchor) < 0.001, "Sticky attachment holds stationary")
    ball.launch(Vector2(0, -90))
    check(ball.attached_body == null, "Successful launch detaches")
    await ticks(6)
    check(ball.global_position.y < anchor.y - 5, "Launch leaves old sticky contact")
    await ticks(65)
    check(ball.attached_body == lab.get_node("Terrain/Sticky"), "Sticky reattaches on genuine return impact")
    place(Vector2(392, 70), Vector2(0, 100))
    await ticks(6)
    check(ball.velocity.y < -150, "Bouncy floor enforces outward minimum speed")
    place(Vector2(410, 174), Vector2(120, 0))
    await ticks(8)
    check(collisions.has(&"wall") and ball.velocity.x < -150, "Bouncy wall launches along actual horizontal normal")
    place(Vector2(368, 160), Vector2(0, -100))
    await ticks(10)
    check(ball.attached_body == lab.get_node("Terrain/Ceiling") and ball.contact_normal.y > 0.9, "Sticky ceiling attachment")
    place(Vector2(430, 252), Vector2(10000, 0))
    await ticks(1)
    check(collisions.has(&"thin") and ball.global_position.x < 446.1, "Swept circle cannot tunnel through one-pixel object at 10000 px/s")
    place(Vector2(272, 230), Vector2.ZERO)
    await ticks(30)
    check(collisions.has(&"slope") and ball.velocity.x < 0, "Gravity projects into downhill rolling on slope")
    var horizontal: MovingPlatform = lab.get_node("MovingPlatforms/Horizontal")
    place(horizontal.to_global(Vector2(24, -2.02)), horizontal.surface_velocity)
    await ticks(10)
    check(ball.support_body == horizontal, "Moving normal platform supports ball")
    var platform_before: Vector2 = horizontal.global_position
    await ticks(1)
    var measured_velocity: Vector2 = (horizontal.global_position - platform_before) * 60.0
    check(measured_velocity.length() > 1.0 and horizontal.surface_velocity.distance_to(measured_velocity) < 0.01, "Surface velocity matches independently measured motion")
    var local: Vector2 = horizontal.to_local(ball.global_position)
    await ticks(30)
    check(horizontal.to_local(ball.global_position).distance_to(local) < 0.3, "Resting ball follows horizontal movement without drift")
    check(ball.world_velocity().distance_to(horizontal.surface_velocity) < 0.5, "Resting world velocity equals measured platform velocity")
    var momentum: Vector2 = horizontal.surface_velocity
    ball.launch(Vector2(40, -50))
    check(ball.velocity.distance_to(momentum + Vector2(40, -50)) < 0.001, "With-motion launch receives carry velocity exactly once")
    place(horizontal.to_global(Vector2(24, -2.02)), horizontal.surface_velocity)
    await ticks(10)
    momentum = ball.world_velocity()
    ball.launch(Vector2(-40, -50))
    check(ball.velocity.distance_to(momentum + Vector2(-40, -50)) < 0.001, "Against-motion launch receives carry velocity exactly once")
    var vertical: MovingPlatform = lab.get_node("MovingPlatforms/Vertical")
    place(vertical.to_global(Vector2(24, -2.02)), Vector2(0, 5))
    ball.safe_position = Vector2(999, 999)
    # A descending platform can initially move away from this slow ball.
    # Wait for contact rather than assuming it happens in ten physics ticks.
    for tick: int in range(120):
        await ticks(1)
        if ball.attached_body == vertical:
            break
    check(ball.attached_body == vertical, "Moving sticky contact attaches")
    local = vertical.to_local(ball.global_position)
    await ticks(45)
    check(vertical.to_local(ball.global_position).distance_to(local) < 0.001, "Sticky local anchor follows vertical movement")
    check(ball.safe_position == Vector2(999, 999), "Moving contact never qualifies as a safe point")
    momentum = ball.world_velocity()
    ball.launch(Vector2(0, -90))
    check(ball.velocity.distance_to(momentum + Vector2(0, -90)) < 0.001, "Sticky launch transfers moving-surface velocity once")
    await ticks(6)
    check(ball.attached_body == null, "Moving sticky launch separates cleanly")
    await ticks(120)
    check(ball.attached_body == vertical, "Moving sticky object permits later recontact")
    vertical.surface = normal
    place(vertical.to_global(Vector2(24, -2.02)), vertical.surface_velocity)
    await ticks(10)
    local = vertical.to_local(ball.global_position)
    await ticks(30)
    check(ball.support_body == vertical and vertical.to_local(ball.global_position).distance_to(local) < 0.3, "Normal material also carries on vertical mover")
    ball.launch(Vector2(0, -50), true)
    check(ball.velocity == Vector2(0, -50), "Explicit momentum reset clears platform carry once")
    ball.free()
    lab.free()
    print("Physics checks: %s failure(s)" % failures)
    quit(0 if failures == 0 else 1)
