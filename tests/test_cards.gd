extends SceneTree
var failures: int = 0
var checks: int = 0
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
var session: GameSession
var ball: GolfBall
var lab: Node2D

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", message)

func _initialize() -> void:
    call_deferred("run")

func ticks(count: int) -> void:
    for tick: int in range(count):
        await physics_frame
        await process_frame

func conservation(deck: DeckModel) -> bool:
    var ids: Array[StringName] = []
    for pile: Array[CardDefinition] in [deck.hand, deck.draw_pile, deck.discard_pile]:
        for card: CardDefinition in pile:
            if ids.has(card.id) or not deck.equipped.has(card.id):
                return false
            ids.append(card.id)
    return ids.size() == CardCatalog.DECK_SIZE and deck.hand.size() == 3

func choose(id: StringName) -> void:
    # A fixture hand containing the requested card; production only uses cycling.
    var ids: Array[StringName] = [id]
    for card: CardDefinition in catalog.cards:
        if not ids.has(card.id) and ids.size() < CardCatalog.DECK_SIZE:
            ids.append(card.id)
    session.deck.start_attempt(ids)
    for slot: int in range(3):
        if session.deck.hand[slot].id == id:
            session.deck.select_slot(slot)
            return
    while session.deck.selected_card().id != id:
        session.deck.cycle_selected()

func snapshot() -> Array:
    return [session.state, session.elixir, session.shots, session.elapsed_seconds,
        ball.global_position, ball.velocity, ball.active_effect, ball.attached_body,
        ball.gravity_multiplier, ball.safe_position, session.deck.hand.duplicate(),
        session.deck.draw_pile.duplicate(), session.deck.discard_pile.duplicate(),
        session.deck.selected_slot, session.random.state, ball.ghost_state]

func place(at: Vector2, speed: Vector2 = Vector2.ZERO) -> void:
    ball.reset_motion(at)
    ball.velocity = speed

func run() -> void:
    session = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    ball = session.ball
    ball.simulation_enabled = false
    var deck: DeckModel = session.deck
    check(deck.hand.size() == 3 and deck.draw_pile.size() == CardCatalog.DECK_SIZE - 3 and deck.discard_pile.is_empty(), "Initial piles")
    var invalid: Array[StringName] = [&"classic", &"classic", &"fire", &"slow", &"bounce"]
    check(not deck.start_attempt(invalid), "Duplicate deck rejected")
    invalid[1] = &"missing"
    check(not deck.start_attempt(invalid), "Unknown card rejected")
    invalid.pop_back()
    check(not deck.start_attempt(invalid), "Wrong deck length rejected")
    var openings: Dictionary = {}
    for attempt: int in range(30):
        deck.start_attempt(catalog.default_deck)
        openings[str(deck.hand)] = true
        check(conservation(deck), "Attempt conserves cards")
    check(openings.size() > 1, "Attempts shuffle")
    for turn: int in range(300):
        deck.select_slot(turn % 3)
        var other_a: CardDefinition = deck.hand[(turn + 1) % 3]
        var other_b: CardDefinition = deck.hand[(turn + 2) % 3]
        deck.cycle_selected()
        check(conservation(deck), "Conservation through reshuffle")
        check(deck.selected_slot == turn % 3 and deck.hand[(turn + 1) % 3] == other_a and deck.hand[(turn + 2) % 3] == other_b, "Same-slot replacement; other cards retained")
    choose(&"fire")
    ball.velocity = Vector2(20, -10)
    ball.set_card_effect(catalog.find_card(&"glue"))
    var before: Array = snapshot()
    check(not session.try_shot(Vector2.ZERO) and snapshot() == before, "Zero drag rejection is atomic")
    check(not session.try_shot(Vector2(1, 1)) and snapshot() == before, "Dead zone rejection is atomic")
    check(not session.try_shot(Vector2(NAN, 0)) and snapshot() == before, "Nonfinite drag rejected")
    session.elixir = 3.99
    before = snapshot()
    check(not session.try_shot(Vector2(0, 160)) and snapshot() == before, "Full affordability required")
    for state: GameSession.State in [GameSession.State.PAUSED, GameSession.State.WON, GameSession.State.LOST]:
        session.state = state
        session.elixir = 10
        before = snapshot()
        check(not session.try_shot(Vector2(0, 160)) and snapshot() == before, "Inactive state rejection")
        session.advance_clock(30)
        check(snapshot() == before, "Inactive state freezes clock and regeneration")
    session.state = GameSession.State.READY
    session.elixir = 0
    session.advance_clock(3)
    check(is_equal_approx(session.elixir, 1.0) and session.elapsed_seconds == 0, "Regeneration before first shot without timer")
    session.advance_clock(300)
    check(session.elixir == 10, "Elixir capped")
    check(session.shots == 0 and session.state == GameSession.State.READY, "Rejected shot never queues when elixir returns")
    var shot_events: Array = []
    var nested: Array = []
    session.shot_committed.connect(func(card: CardDefinition) -> void:
        shot_events.append(card.id)
        check(session.shots == 1 and conservation(deck) and session.state == GameSession.State.PLAYING, "Signal sees complete transaction")
        nested.append(session.try_shot(Vector2(0, 160))), CONNECT_ONE_SHOT)
    var old_slot: int = deck.selected_slot
    var old_card: CardDefinition = deck.selected_card()
    var old_velocity: Vector2 = ball.world_velocity()
    var reshuffles_on_play: bool = deck.draw_pile.is_empty()
    check(session.try_shot(Vector2(0, 160)), "Valid release commits")
    check(session.shots == 1 and session.elixir == 6 and shot_events == [&"fire"] and nested == [false], "One commit; no reentrancy")
    var correct_piles: bool = deck.discard_pile.is_empty() and deck.draw_pile.size() == CardCatalog.DECK_SIZE - 3 if reshuffles_on_play else deck.discard_pile.has(old_card)
    check(deck.selected_slot == old_slot and correct_piles and conservation(deck), "Successful play cycles, including a discard reshuffle")
    check(is_equal_approx((ball.velocity - old_velocity).length(), old_card.power * session.tuning.shot_power_multiplier), "Random angle does not randomize power")
    session.advance_clock(3)
    check(session.elapsed_seconds == 3 and session.elixir == 7, "Active clock/regeneration")
    var prior_effect: CardDefinition.Effect = ball.active_effect
    deck.select_slot((deck.selected_slot + 1) % 3)
    check(ball.active_effect == prior_effect, "Selection never activates effect")
    for card: CardDefinition in catalog.cards:
        place(Vector2(-300, -300), Vector2(50, 70))
        var safe: Vector2 = Vector2(-200, -100)
        ball.safe_position = safe
        var impulse: Vector2 = Vector2(10, -20)
        ball.play_card(card, impulse)
        var expected: Vector2 = impulse if ShotCalculation.clears_velocity(card) else Vector2(60, 50)
        check(ball.velocity == expected, "Momentum rule: " + str(card.id))
        check(ball.active_effect == card.effect, "Effect applied: " + str(card.id))
        check(ball.gravity_multiplier == card.gravity_multiplier, "Gravity: " + str(card.id))
        if card.effect == CardDefinition.Effect.REWIND:
            check(ball.global_position == safe and ball.safe_position == safe, "Rewind origin preserves safe point")
        ball.step_motion(1.0 / 60)
        check(ball.velocity.y > expected.y, "Slow/Rewind clear only once: " + str(card.id))
    ball.set_card_effect(catalog.find_card(&"heavy"))
    ball.velocity = Vector2.ZERO
    ball.apply_knockback(Vector2(40, 0))
    check(ball.velocity == Vector2(20, 0), "Heavy reduces knockback")
    ball.set_card_effect(catalog.find_card(&"classic"))
    check(ball.gravity_multiplier == 1 and ball.bounce_retention == -1 and ball.knockback_multiplier == 1 and not ball.glue_enabled, "Replacement clears properties")
    for card: CardDefinition in catalog.cards:
        for surface_name: String in ["normal", "ice"]:
            var surface: SurfaceDefinition = load("res://resources/terrain/" + surface_name + ".tres")
            var retention: float = card.bounce_retention if card.effect in [CardDefinition.Effect.HEAVY, CardDefinition.Effect.BOUNCE] else -1.0
            for normal: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
                var result: Vector2 = BallMotion.impact(-normal * 100, normal, surface, ball.tuning, retention)
                check(result.length() <= 100.001, "No ordinary impact adds energy: " + str(card.id))
                if card.effect == CardDefinition.Effect.BOUNCE:
                    check(is_equal_approx(result.dot(normal), 92), "Bounce on floor/wall/ceiling")
    check(catalog.find_card(&"sniper").spread_curve.sample(1) > 0, "Sniper spread is nonzero")
    check(catalog.find_card(&"fire").power > catalog.find_card(&"dash").power, "Fire strongest")
    check(ShotCalculation.spread(catalog.find_card(&"dash"), 1) < ShotCalculation.spread(catalog.find_card(&"fire"), 1), "Dash more accurate")
    await physics_cases()
    session.free()
    await lab_routes()
    print("Card checks: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)

func physics_cases() -> void:
    # The lab owns this test's collision world. Production courses now extend
    # through these coordinates, so remove their solids before loading fixtures.
    session.course.free()
    session.course = null
    lab = load("res://tests/scenes/physics_lab.tscn").instantiate()
    root.add_child(lab)
    for demo: GolfBall in lab.get("balls"):
        demo.simulation_enabled = false
    ball.simulation_enabled = true
    await ticks(2)
    place(Vector2(392, 70), Vector2(0, 100))
    ball.set_card_effect(catalog.find_card(&"glue"))
    await ticks(8)
    check(ball.attached_body == lab.get_node("Terrain/Bouncy"), "Glue precedes bouncy response")
    choose(&"classic")
    session.elixir = 0
    session.state = GameSession.State.PLAYING
    var before: Array = snapshot()
    check(not session.try_shot(Vector2(0, 160)) and snapshot() == before, "Failed shot preserves attachment")
    session.elixir = 10
    check(session.try_shot(Vector2(0, 80)) and ball.attached_body == null and not ball.glue_enabled, "Successful replacement frees Glue")
    await ticks(6)
    check(ball.global_position.y < 74, "Launch leaves glued bouncy contact")
    place(Vector2(368, 160), Vector2(0, -100))
    ball.set_card_effect(catalog.find_card(&"glue"))
    await ticks(10)
    check(ball.attached_body == lab.get_node("Terrain/Ceiling"), "Glue ceiling")
    ball.play_card(catalog.find_card(&"classic"), Vector2(0, 60))
    await ticks(8)
    check(ball.attached_body == null, "Glue ceiling release")
    place(Vector2(40, 77.95))
    await ticks(40)
    check(ball.safe_position.distance_to(ball.global_position) < 0.3, "Static safe qualification")
    var saved: Vector2 = ball.safe_position
    place(Vector2(152, 77.95), Vector2(15, 0))
    ball.safe_position = saved
    await ticks(40)
    check(ball.safe_position.x > 155, "Rolling ice updates safe point")
    var mover: MovingPlatform = lab.get_node("MovingPlatforms/Vertical")
    saved = ball.safe_position
    place(mover.to_global(Vector2(24, -2.02)), mover.surface_velocity)
    ball.safe_position = saved
    await ticks(50)
    check(ball.safe_position == saved, "Moving attachment cannot replace safe point")
    ball.play_card(catalog.find_card(&"rewind"), Vector2(0, -60))
    check(ball.global_position == saved and ball.velocity == Vector2(0, -60), "Rewind from moving attachment clears carry")
    place(Vector2(280, 60), Vector2(0, 60))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    var passing: bool = false
    for tick: int in range(30):
        await ticks(1)
        if ball.ghost_state == GolfBall.GhostState.PASSING:
            passing = true
            check(ball.attached_body == null and ball.active_effect == CardDefinition.Effect.GHOST, "Ghost bypasses sticky until full exit")
    check(passing and ball.ghost_state == GolfBall.GhostState.SPENT and ball.active_effect == CardDefinition.Effect.CLASSIC and ball.global_position.y > 90, "Ghost exits then becomes Classic")
    check(ball.get_collision_exceptions().is_empty() and ball.sprite.modulate == Color.WHITE, "Ghost restores collision and appearance")
    place(Vector2(40, 77.95))
    await ticks(4)
    ball.play_card(catalog.find_card(&"ghost"), Vector2(0, -80))
    await ticks(3)
    check(ball.ghost_state == GolfBall.GhostState.ARMED and ball.global_position.y < 77, "Ghost outward launch does not consume pass")
    place(Vector2(40, 77.95))
    await ticks(4)
    ball.play_card(catalog.find_card(&"ghost"), Vector2(0, 80))
    await ticks(3)
    check(ball.ghost_state == GolfBall.GhostState.PASSING and ball.ignored_object_id == &"normal", "Ghost inward launch consumes touched object")
    await ticks(15)
    check(ball.ghost_state == GolfBall.GhostState.SPENT, "Inward Ghost clears ground")
    var multi: TerrainObject = lab.get_node("Terrain/MultiShape")
    place(multi.to_global(Vector2(-12, 4)), Vector2(300, 0))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(3)
    check(ball.ghost_body == multi and ball.ghost_state == GolfBall.GhostState.PASSING, "Compound object enters one ignored body")
    await ticks(16)
    check(ball.active_effect == CardDefinition.Effect.CLASSIC and ball.get_collision_exceptions().is_empty(), "Compound object full exit")
    place(Vector2(430, 252), Vector2(10000, 0))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(1)
    check(ball.global_position.x > 460 and ball.active_effect == CardDefinition.Effect.CLASSIC, "Ghost high-speed thin object entry and exit in one tick")
    var cup: TerrainObject = load("res://tests/scenes/cup_terrain_fixture.tscn").instantiate()
    cup.position = Vector2(560, 80)
    root.add_child(cup)
    await ticks(2)
    place(Vector2(592, 75), Vector2(0, 90))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(18)
    check(ball.global_position.y > 100 and ball.ignored_object_id == &"cup" and ball.active_effect == CardDefinition.Effect.CLASSIC, "Cup solids obey Ghost pass-through")
    # Follow a full-speed pass with a different solid in the SAME fixed step.
    var second: TerrainObject = load("res://scenes/terrain/terrain_object.tscn").instantiate()
    second.position = Vector2(560, 112)
    second.object_id = &"second"
    root.add_child(second)
    await ticks(2)
    place(Vector2(592, 75), Vector2(0, 3000))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(1)
    check(ball.global_position.y < 111 and ball.velocity.y < 0 and ball.active_effect == CardDefinition.Effect.CLASSIC, "Only first object bypassed, second collides in same tick")
    cup.free()
    second.free()
    place(mover.to_global(Vector2(24, -8)), mover.surface_velocity + Vector2(0, 90))
    ball.set_card_effect(catalog.find_card(&"ghost"))
    await ticks(20)
    check(ball.active_effect == CardDefinition.Effect.CLASSIC and ball.attached_body == null, "Ghost bypasses moving sticky platform")
    # Brief eligible contacts must not accumulate over separate visits.
    place(Vector2(40, 77.95))
    ball.safe_position = Vector2(-999, -999)
    await ticks(10)
    ball.launch(Vector2(0, -40))
    await ticks(3)
    check(ball.safe_position == Vector2(-999, -999) and ball.safe_contact_elapsed == 0, "Short contact then departure resets safe qualification")
    lab.free()

func lab_routes() -> void:
    var main: Node2D = load("res://main.tscn").instantiate()
    root.add_child(main)
    await ticks(1)
    var menu: Control = main.screen_host.get_child(0)
    menu.cards_requested.emit()
    await ticks(1)
    var trial: Node2D = main.game_host.get_child(0)
    check(trial.session.deck.hand.size() == 3 and trial.session.elixir == 10, "Launcher opens initialized card lab")
    var old_effect: CardDefinition.Effect = trial.session.ball.active_effect
    trial.hand_buttons[1].pressed.emit()
    check(trial.session.deck.selected_slot == 1 and trial.session.ball.active_effect == old_effect, "Hand button changes selection only")
    trial.launch_all()
    check(trial.session.shots == 1 and trial.session.elixir < 10, "Lab shot uses real transaction")
    trial.deck_selector.selected = 1
    trial.reset_lab()
    check(trial.session.deck.equipped == trial.alternate_deck and trial.session.shots == 0 and trial.session.ball.active_effect == CardDefinition.Effect.CLASSIC, "Alternate deck reset")
    trial.exit_requested.emit()
    await ticks(1)
    check(main.game_host.get_child_count() == 0 and main.screen_host.get_child_count() == 1, "Lab returns to launcher")
    main.free()
