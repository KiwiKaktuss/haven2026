extends SceneTree
## Real transaction and presentation timing, independent of rendering cadence.
var checks: int = 0
var failures: int = 0
var session: GameSession

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func advance(frames: int) -> void:
    for frame: int in range(frames):
        session.advance_clock(1.0 / 60.0)
        await process_frame

func run() -> void:
    session = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    await advance(3)
    var hud: GameHUD = session.hud
    var view: CardView = hud.get_node("Bottom/Stack/Hand/Card0")
    var timer_size: Vector2 = hud.get_node("Top/TimerSlot").size
    var card_size: Vector2 = view.size
    var used: CardDefinition = session.deck.selected_card()
    var cursor: Vector2 = Vector2(480, 240)
    check(session.try_shot(Vector2(-40, 90), cursor), "Successful shot")
    var replacement: CardDefinition = session.deck.hand[0]
    check(not session.deck.slot_ready(0) and not view.get_node("Artwork").visible, "Played slot stays empty")
    check(not view.get_node("ReadyMark").visible and not view.get_node("SelectionShadow").visible, "Empty slot has no leftover selection line or shadow")
    var flight: CardFlight = hud.get_node("Flights").get_child(0)
    check(flight.get_node("Card").texture == used.artwork and flight.destination == cursor, "Old card travels toward release cursor")
    var before: Array = [session.elixir, session.shots, session.random.state, session.deck.hand.duplicate()]
    check(not session.try_shot(Vector2(-40, 90)), "Pending replacement cannot fire through keyboard or direct transaction")
    check(before == [session.elixir, session.shots, session.random.state, session.deck.hand.duplicate()], "Pending rejection changes no authoritative fields")
    await advance(48)
    check(hud.get_node("Flights").get_child_count() == 0 and not view.get_node("Artwork").visible, "Old card dissolves; no replacement before one second")
    await advance(14)
    check(not view.get_node("Artwork").visible and hud.get_node("Flights").get_child_count() == 1, "Replacement starts only after the one-second gap")
    var draw: CardFlight = hud.get_node("Flights").get_child(0)
    check(draw.get_node("Card").texture == draw.back_texture, "New card starts face down using supplied back")
    check(session.pause_attempt(), "Pause during deal")
    var frozen: Vector2 = draw.position
    var remaining: float = session.deck.replacement_remaining[0]
    await advance(12)
    check(draw.position == frozen and session.deck.replacement_remaining[0] == remaining, "Pause freezes flight and slot readiness together")
    session.resume_attempt()
    session.set_physics_process(false)
    await advance(23)
    check(draw.get_node("Card").texture == replacement.artwork and not session.deck.slot_ready(0), "Card flips to its face in the air before becoming playable")
    await advance(15)
    check(session.deck.slot_ready(0) and view.get_node("Artwork").visible and view.definition == replacement, "Replacement lands and unlocks its original slot")
    check(view.size == card_size and hud.get_node("Top/TimerSlot").size == timer_size, "Animation preserves authored card and text-slot dimensions")
    session.elixir = 10
    check(session.try_shot(Vector2(-30, 60), cursor), "Landed replacement can be played")
    session.deck.select_slot(1)
    session.elixir = 10
    check(session.try_shot(Vector2(-30, 60), cursor + Vector2(50, 0)), "Other cards remain usable while an earlier slot refills")
    check(not session.deck.slot_ready(0) and not session.deck.slot_ready(1) and session.deck.slot_ready(2), "Independent concurrent deal locks")
    session.deck.start_attempt()
    hud.refresh()
    await advance(1)
    check(hud.get_node("Flights").get_child_count() == 0 and session.deck.slot_ready(0), "Redeal cancels all old presentation state")
    var feedback: BallFeedback = session.ball.get_node("Feedback")
    for card: CardDefinition in session.deck.catalog.cards:
        session.ball.play_card(card, Vector2(30, -70))
        var visible_count: int = 0
        for index: int in range(feedback.get_node("Markers").get_child_count()):
            var marker: CanvasItem = feedback.get_node("Markers").get_child(index)
            if marker.visible:
                visible_count += 1
                check(index == card.effect, "Correct active glyph for " + str(card.id))
        check(visible_count == 1, "Exactly one active effect glyph for " + str(card.id))
        check(session.ball.fire_trail.emitting == (card.effect == CardDefinition.Effect.FIRE), "Fire trail follows actual active effect")
        check(is_equal_approx(ShotCalculation.impulse(card, Vector2(0, 160), session.tuning).length(), card.power * session.tuning.shot_power_multiplier), "Increased range shared by each card")
    session.ball.set_card_effect(null)
    check(session.ball.sprite.modulate == Color.WHITE and feedback.get_node("Markers/Classic").visible, "Ghost/reset returns to solid Classic appearance")
    # A differently sized back reference keeps the authored screen-space footprint.
    var alternate: CardFlight = load("res://scenes/ui/card_flight.tscn").instantiate()
    alternate.back_texture = load("res://art/ball.png")
    root.add_child(alternate)
    alternate.begin(used, Vector2.ZERO, cursor, Vector2(88, 124), 0.58, true)
    var sprite: Sprite2D = alternate.get_node("Card")
    check((sprite.texture.get_size() * sprite.scale).is_equal_approx(Vector2(88, 124)), "Replaceable back references preserve alignment independently of source dimensions")
    alternate.free()
    session.free()
    print("Feedback: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
