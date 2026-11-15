extends SceneTree
## Measure actual flight, independent of terrain, then check useful card roles
## and agreement with the preview throughout the longer full-power arcs.
var checks: int = 0
var failures: int = 0
var ball: GolfBall
var preview: TrajectoryPreview
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func flight(card: CardDefinition, direction: Vector2, strength: float = 1.0) -> Dictionary:
    ball.reset_motion(Vector2.ZERO)
    var drag: Vector2 = -direction.normalized() * ball.tuning.maximum_drag * strength
    var predicted: PackedVector2Array = preview.predict(ball, card, drag).points
    ball.play_card(card, ShotCalculation.impulse(card, drag, ball.tuning))
    var dt: float = 1.0 / Engine.physics_ticks_per_second
    var previous: Vector2 = Vector2.ZERO
    var error: float = 0.0
    for step: int in ceili(12.0 / dt):
        ball.step_motion(dt)
        if step + 1 < predicted.size():
            error = maxf(error, ball.global_position.distance_to(predicted[step + 1]))
        if ball.global_position.y >= 0.0 and ball.velocity.y > 0.0:
            var fraction: float = -previous.y / (ball.global_position.y - previous.y)
            check(error < 0.02, "Long-flight preview matches live motion: " + str(card.id))
            check(step + 1 < predicted.size(), "Preview includes the full flight: " + str(card.id))
            return {"distance": lerpf(previous.x, ball.global_position.x, fraction), "seconds": (step + fraction) * dt}
        previous = ball.global_position
    check(false, "Shot must return to launch height: " + str(card.id))
    return {"distance": 0.0, "seconds": 0.0}

func run() -> void:
    ball = load("res://scenes/ball/ball.tscn").instantiate()
    ball.simulation_enabled = false
    ball.collision_mask = 0
    root.add_child(ball)
    preview = load("res://scenes/game/trajectory_preview.tscn").instantiate()
    root.add_child(preview)
    var flights: Dictionary = {}
    for card: CardDefinition in catalog.cards:
        var full: Dictionary = flight(card, Vector2(1, -1))
        flights[card.id] = full
        var gentle: Dictionary = flight(card, Vector2(1, -1), 0.3)
        check(gentle.distance > 10.0 and gentle.distance < full.distance * 0.1, "Short drags retain landing control: " + str(card.id))
        flight(card, Vector2.UP)
        print("%s: %.1f px range, %.2f s flight" % [card.display_name, full.distance, full.seconds])
    var normal: float = flights[&"classic"].distance
    check(normal >= 300.0 and normal <= 350.0, "Normal clears a useful medium gap")
    check(flights[&"sniper"].distance >= normal * 0.9 and flights[&"sniper"].distance < normal, "Snipe trades a little reach for precision")
    check(flights[&"slow"].distance >= 175.0 and flights[&"slow"].distance <= normal * 0.7, "Slow retains its useful range")
    check(flights[&"slow"].seconds >= 6.0, "Slow gives the player time to play another card mid-flight")
    check(flights[&"heavy"].distance >= normal * 0.8 and flights[&"heavy"].distance < normal, "Heavy's gravity no longer makes its range impractical")
    check(flights[&"heavy"].seconds < flights[&"classic"].seconds * 0.75, "Heavy still makes a fast, steep approach")
    for id: StringName in [&"glue", &"ghost", &"rewind", &"bounce"]:
        check(flights[id].distance >= normal * 0.9, "Utility effect retains useful launch range: " + str(id))
    check(flights[&"dash"].distance >= normal * 1.5, "Dash earns its extra cost with long reach")
    check(flights[&"fire"].distance >= flights[&"dash"].distance * 1.3, "Fireball retains the longest reach")
    ball.free()
    preview.free()
    await course_climb()
    print("Shot balance: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)

func course_climb() -> void:
    # The old Snipe and Heavy fell short of this climb. Verify the stronger
    # shots land on the top of the real platform, rather than hit its underside.
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 1
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.aim.enabled = false
    session.camera_controller.set_process(false)
    await physics_frame
    await process_frame
    var departure: TerrainObject = session.course.get_node("Terrain/CentralCut")
    var target: TerrainObject = session.course.get_node("Terrain/StickyStep")
    var drag: Vector2 = Vector2(0.39, 1.0).normalized() * session.tuning.maximum_drag
    for id: StringName in [&"sniper", &"heavy"]:
        session.ball.reset_motion(departure.global_position + Vector2(64, -2.05))
        var card: CardDefinition = catalog.find_card(id)
        session.ball.play_card(card, ShotCalculation.impulse(card, drag, session.tuning))
        for tick: int in 180:
            session.ball.step_motion(1.0 / Engine.physics_ticks_per_second)
            if session.ball.attached_body == target:
                break
        check(session.ball.attached_body == target and session.ball.global_position.y < target.global_position.y, "Full shot makes the Cold Snap climb: " + str(id))
    session.free()
