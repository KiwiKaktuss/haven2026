extends RefCounted
## Normal engine ticks and synchronized movers; no test-state restoration or
## edits to ball position. Search output alone is not gameplay acceptance.
func verify(tree: SceneTree, row: Dictionary) -> bool:
    if not row.won:
        row.engine_replay_verified = false
        return false
    var session: GameSession = load('res://scenes/game/game_session.tscn').instantiate()
    session.deck.equipped.assign(row.deck)
    for index: int in session.courses.courses.size():
        if str(session.courses.courses[index].id) == row.course:
            session.course_index = index
    session.deck.random.seed = int(row.seed)
    session.random.seed = int(row.seed) + 1000
    tree.root.add_child(session)
    session.aim.enabled = false
    # Keep world simulation on ordinary engine ticks; offscreen label binding
    # and camera easing are covered by UI/capture tests and need no per-frame work.
    session.hud.set_process(false)
    session.camera_controller.set_process(false)
    var next: int = 0
    var ok: bool = true
    var max_origin_drift: float = 0.0
    # Allow a final Bounce to finish settling through ordinary gameplay.
    for tick: int in int(row.end_tick) + 1800:
        while next < row.actions.size() and int(row.actions[next].tick) == tick:
            var action: Dictionary = row.actions[next]
            session.deck.select_slot(int(action.slot))
            var origin: Vector2 = Vector2(action.origin[0], action.origin[1])
            max_origin_drift = maxf(max_origin_drift, session.ball.global_position.distance_to(origin))
            var expected_card: bool = str(session.deck.selected_card().id) == action.card
            var committed: bool = session.try_shot(Vector2(action.drag[0], action.drag[1]))
            ok = ok and expected_card and committed
            next += 1
        await tree.physics_frame
        await tree.process_frame
        var ids: Array[StringName] = []
        for pile: Array[CardDefinition] in [session.deck.hand, session.deck.draw_pile, session.deck.discard_pile]:
            for card: CardDefinition in pile:
                if ids.has(card.id) or not session.deck.equipped.has(card.id):
                    ok = false
                ids.append(card.id)
        ok = ok and ids.size() == CardCatalog.DECK_SIZE and session.deck.hand.size() == 3 and session.elixir >= 0.0 and session.elixir <= session.tuning.maximum_elixir
        if session.state in [GameSession.State.WON, GameSession.State.LOST]:
            break
    ok = ok and next == row.actions.size() and session.state == GameSession.State.WON and session.shots == row.actions.size()
    row.engine_replay_verified = ok
    row.engine_max_origin_drift = max_origin_drift
    row.engine_final_state = GameSession.State.keys()[session.state]
    row.engine_seconds = session.elapsed_seconds
    session.free()
    return ok
