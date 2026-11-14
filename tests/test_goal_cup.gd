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
    ball.free()
    cup.free()
    print('Goal cup: %d checks, %d failure(s)' % [checks,failures])
    quit(0 if failures == 0 else 1)
