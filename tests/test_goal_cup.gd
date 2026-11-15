extends SceneTree
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred('run')

func run() -> void:
    var cup: GoalCup = load('res://scenes/levels/goal_cup.tscn').instantiate()
    var ball: GolfBall = load('res://scenes/ball/ball.tscn').instantiate()
    root.add_child(cup)
    root.add_child(ball)
    ball.simulation_enabled = false
    var tuning: GameTuning = ball.tuning
    await physics_frame
    # Every black source pixel is physical; the transparent interior stays open.
    var terrain: TerrainObject = cup.get_node('Terrain')
    var image: Image = (cup.get_node('Terrain/HoleSprite') as Sprite2D).texture.get_image()
    var polygon: PackedVector2Array = terrain.get_node('SolidSilhouette').polygon
    for y in 8:
        for x in 8:
            var solid := Geometry2D.is_point_in_polygon(Vector2(28+x+0.5,y+0.5),polygon)
            check(solid == (image.get_pixel(x,y+8).a > 0.5), 'Cup wall matches sprite at %s' % Vector2i(x,y))
    for outside: Vector2 in [Vector2(32,-2),Vector2(28,-2),Vector2(36,-2),Vector2(30,4),Vector2(34,4),Vector2(32,6)]:
        ball.reset_motion(outside)
        check(not cup.advance_capture(ball,tuning,1.0), 'Ball outside cup cannot win at %s' % outside)
    ball.reset_motion(Vector2(32,4.9))
    check(not cup.advance_capture(ball,tuning,0.3), 'Ball must dwell in the cup')
    ball.velocity = Vector2(30,0)
    check(not cup.advance_capture(ball,tuning,0.4) and cup.dwell == 0.0, 'Fast ball resets capture')
    ball.reset_motion(Vector2(32,4.9))
    check(not cup.advance_capture(ball,tuning,0.3), 'Dwell restarts after movement')
    ball.global_position = Vector2(36,4.9)
    check(not cup.advance_capture(ball,tuning,0.4) and cup.dwell == 0.0, 'Leaving resets capture')
    # Let real collision and gravity settle a dropped ball on the black floor.
    ball.reset_motion(Vector2(32,-12))
    var won := false
    for frame in 240:
        ball.step_motion(1.0/120.0)
        won = cup.advance_capture(ball,tuning,1.0/120.0) or won
    check(won, 'Ball dropped into the hole settles and wins')
    check(absf(ball.position.y-5.0) < 0.1, 'Black floor physically supports the ball')
    check(ball.world_velocity().length() < tuning.capture_speed, 'Ball stays at rest in cup')
    # A stationary near miss on either rim must be pulled across real terrain
    # into the original capture area, rather than merely widening the win zone.
    for offset: float in [-14.0, 14.0]:
        ball.reset_motion(Vector2(32 + offset, -2.02))
        cup.reset_capture()
        won = false
        for frame: int in 480:
            ball.step_motion(1.0 / 120.0)
            won = cup.advance_capture(ball, tuning, 1.0 / 120.0) or won
        check(won, 'Nearby landing pulled into cup from offset %s' % offset)
        check(absf(ball.position.x - 32.0) < 1.0, 'Pull settles at the cup center')
    ball.reset_motion(Vector2(32 + cup.pull_radius + 2, -2.02))
    for frame: int in 120:
        ball.step_motion(1.0 / 120.0)
    check(absf(ball.position.x - (34 + cup.pull_radius)) < 0.1, 'Outside the small field remains unaffected')
    var incoming := Vector2(120, -40)
    check(cup.attract_velocity(Vector2(60, -2), incoming, 1.0) == incoming, 'No velocity change outside field')
    # Glue can be rescued locally; an armed Ghost still passes through normally.
    var catalog: CardCatalog = load('res://resources/cards/catalog.tres')
    ball.reset_motion(Vector2(44, -2.02))
    ball.set_card_effect(catalog.find_card(&'glue'))
    ball.attached_body = terrain
    ball.local_anchor = terrain.to_local(ball.global_position)
    cup.reset_capture()
    won = false
    for frame: int in 480:
        ball.step_motion(1.0 / 120.0)
        won = cup.advance_capture(ball, tuning, 1.0 / 120.0) or won
    check(won, 'Pull rescues a glued landing beside the cup')
    ball.reset_motion(Vector2(44, -10))
    ball.set_card_effect(catalog.find_card(&'ghost'))
    ball.step_motion(1.0 / 120.0)
    check(ball.velocity.x == 0.0, 'Armed Ghost is not pulled into a forced win')
    var preview: TrajectoryPreview = load('res://scenes/game/trajectory_preview.tscn').instantiate()
    root.add_child(preview)
    ball.reset_motion(Vector2(44, -9))
    var drag := Vector2(-10, 0)
    var classic: CardDefinition = catalog.find_card(&'classic')
    var prediction: Dictionary = preview.predict(ball, classic, drag, 0.0, 1)
    ball.launch(ShotCalculation.impulse(classic, drag, tuning, 0.0))
    ball.step_motion(1.0 / Engine.physics_ticks_per_second)
    check(ball.global_position.distance_to(prediction.points[1]) < 0.01, 'Aim preview shares live cup attraction')
    preview.free()
    cup.position = Vector2(130, -70)
    check(cup.pull_contains(cup.to_global(Vector2(44, -2))), 'Field follows cup position on every course')
    check(not cup.pull_contains(Vector2(44, -2)), 'Field does not remain at the scene origin')
    ball.free()
    cup.free()
    print('Goal cup: %d checks, %d failure(s)' % [checks,failures])
    quit(0 if failures == 0 else 1)
