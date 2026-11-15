extends SceneTree
## Real engine ticks cover replacement during penetration, which an offline
## batch of move_and_collide calls can accidentally recover differently.
var checks: int = 0
var failures: int = 0
var ball: GolfBall
var preview: TrajectoryPreview
var catalog: CardCatalog = load('res://resources/cards/catalog.tres')

func _initialize() -> void:
    call_deferred('run')

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print('FAIL: ', message)

func ticks(count: int = 1) -> void:
    for frame: int in count:
        await physics_frame
        await process_frame

func enter(body: TerrainObject) -> void:
    ball.reset_motion(body.to_global(Vector2(32, -3)))
    ball.velocity = Vector2(0, 60)
    ball.set_card_effect(catalog.find_card(&'ghost'))
    for frame: int in 12:
        await ticks()
        if ball.ghost_state == GolfBall.GhostState.PASSING and ball.global_position.y > body.global_position.y + 1:
            break
    check(ball.ghost_body == body and TerrainQuery.overlaps(ball.collision_shape.shape, ball.collision_shape.global_transform, body), 'Fixture enters the whole solid')

func run() -> void:
    var lab: Node2D = load('res://tests/scenes/card_lab.tscn').instantiate()
    root.add_child(lab)
    var session: GameSession = lab.session
    session.set_physics_process(false)
    lab.aim.enabled = false
    ball = session.ball
    preview = lab.aim.preview
    ball.simulation_enabled = true
    await ticks(2)
    for body: TerrainObject in [lab.get_node('Terrain/Normal'), lab.get_node('Terrain/Sticky')]:
        for id: StringName in [&'classic', &'heavy', &'slow', &'glue', &'ghost', &'rewind']:
            await enter(body)
            var card: CardDefinition = catalog.find_card(id)
            var drag: Vector2 = Vector2(0, 160)
            var before: Vector2 = ball.global_position
            session.elixir = 0
            check(not session.try_shot(drag) and ball.active_effect == CardDefinition.Effect.GHOST and ball.ghost_expires_on_exit and ball.get_collision_exceptions().has(body), 'Unaffordable replacement preserves the active passage atomically')
            session.elixir = 10
            var prediction: Dictionary = preview.predict(ball, card, drag)
            check(ball.global_position == before and ball.active_effect == CardDefinition.Effect.GHOST and ball.ghost_expires_on_exit and ball.get_collision_exceptions().has(body), 'Preview preserves the live passage')
            check(not prediction.ghost_points.is_empty() and prediction.ghost_points[0].distance_to(before) < 0.01, 'Replacement preview begins with the existing passage')
            ball.play_card(card, ShotCalculation.impulse(card, drag, ball.tuning))
            check(ball.active_effect == card.effect and ball.gravity_multiplier == card.gravity_multiplier, 'Replacement physics activates immediately')
            check(ball.ghost_state == GolfBall.GhostState.PASSING and ball.get_collision_exceptions().has(body), 'Collision stays disabled until the full circle exits')
            var exited: bool = false
            var steps: int = 0
            for frame: int in 40:
                await ticks()
                steps = frame + 1
                if frame + 1 < prediction.points.size() and (prediction.hit_step < 0 or frame < prediction.hit_step):
                    check(ball.global_position.distance_to(prediction.points[frame + 1]) < 0.08, 'Replacement central preview matches live motion')
                if ball.ghost_body == null:
                    exited = true
                    break
            check(exited and ball.get_collision_exceptions().is_empty(), 'Replacement escapes without being trapped in the solid')
            check(ball.active_effect == card.effect and ball.gravity_multiplier == card.gravity_multiplier, 'Passage exit does not erase the replacement effect')
            if id == &'ghost':
                check(ball.ghost_state == GolfBall.GhostState.ARMED, 'A newly played Ghost keeps its own unused passage')
            for extra: int in 6:
                await ticks()
                var point_index: int = steps + extra + 1
                if point_index < prediction.points.size() and (prediction.hit_step < 0 or point_index <= prediction.hit_step):
                    check(ball.global_position.distance_to(prediction.points[point_index]) < 0.08, 'Preview retains replacement physics after the inherited passage exits')
        await enter(body)
        ball.reset_motion(Vector2(-400, -400))
        check(ball.ghost_state == GolfBall.GhostState.INACTIVE and ball.get_collision_exceptions().is_empty(), 'Reset clears an unfinished passage')
    lab.free()
    print('Ghost replacement: %s checks, %s failure(s)' % [checks, failures])
    quit(0 if failures == 0 else 1)
