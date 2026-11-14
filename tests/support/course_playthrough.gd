extends RefCounted
## Offline search through real GameSession transactions. Rejected branches restore
## the departure checkpoint; the accepted trace is replayed from spawn separately.
## This is seeded reachability evidence, not a measure of human difficulty.
const DT: float = 1.0 / 60.0
const BALL_FIELDS: Array[String] = [
    'global_position', 'velocity', 'active_effect', 'safe_position', 'contact_body',
    'contact_normal', 'attached_body', 'local_anchor', 'support_body',
    'support_transform', 'safe_contact_elapsed', 'departing_body', 'departure_normal',
    'gravity_multiplier', 'bounce_retention', 'glue_enabled', 'knockback_multiplier',
    'ghost_state', 'ghost_body', 'ignored_object_id', 'ghost_expires_on_exit',
]
var session: GameSession
var tick: int = 0
var actions: Array[Dictionary] = []
var rejected: int = 0
var failure: String = ''
var mover_envelopes: Array[Rect2] = []
var entered_mover_envelope: bool = false

func configure(value: GameSession) -> void:
    session = value
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.aim.enabled = false
    for mover: MovingPlatform in session.course.get_node('MovingPlatforms').get_children():
        mover.set_physics_process(false)
        var tiles: TileMapLayer = mover.get_node('Tiles')
        var cells: Rect2i = tiles.get_used_rect()
        var a: Vector2 = mover.authored_origin + mover.endpoint_a
        var b: Vector2 = mover.authored_origin + mover.endpoint_b
        var corner: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) + Vector2(cells.position) * 8.0
        var extent: Vector2 = (b - a).abs() + Vector2(cells.size) * 8.0
        mover_envelopes.append(Rect2(corner, extent).grow(session.tuning.ball_radius + 1.0))

func step() -> void:
    if session.state not in [GameSession.State.READY, GameSession.State.PLAYING]:
        return
    session.ball.step_motion(DT)
    # Search only timing-independent baseline paths. Offline loops do not flush
    # AnimatableBody transforms like engine frames do, so exclude the mover's
    # entire swept envelope rather than treating frozen geometry as evidence.
    for envelope: Rect2 in mover_envelopes:
        if envelope.has_point(session.ball.global_position):
            entered_mover_envelope = true
    session.advance_clock(DT)
    session.check_course_end(DT)
    tick += 1

func shoot(slot: int, impulse: Vector2) -> bool:
    var card: CardDefinition = session.deck.hand[slot]
    var drag: Vector2 = -impulse / card.power * session.tuning.maximum_drag
    if impulse.length() > card.power + 0.001 or not ShotCalculation.valid_drag(drag, session.tuning):
        return false
    var origin: Vector2 = session.ball.global_position
    session.deck.select_slot(slot)
    if not session.try_shot(drag):
        return false
    actions.append({'tick': tick, 'slot': slot, 'card': str(card.id), 'drag': [drag.x, drag.y],
        'origin': [origin.x, origin.y]})
    return true

func snapshot() -> Dictionary:
    var ball: Dictionary = {}
    for key: String in BALL_FIELDS:
        ball[key] = session.ball.get(key)
    var movers: Array[Dictionary] = []
    for mover: MovingPlatform in session.course.get_node('MovingPlatforms').get_children():
        movers.append({'body': mover, 'position': mover.position, 'elapsed': mover.elapsed,
            'last': mover.last_physics_position, 'velocity': mover.surface_velocity, 'displacement': mover.frame_displacement})
    return {'ball': ball, 'movers': movers, 'tick': tick, 'actions': actions.size(),
        'state': session.state, 'elixir': session.elixir, 'shots': session.shots,
        'elapsed': session.elapsed_seconds, 'random': session.random.state,
        'deck_random': session.deck.random.state, 'hand': session.deck.hand.duplicate(),
        'draw': session.deck.draw_pile.duplicate(), 'discard': session.deck.discard_pile.duplicate(),
        'slot': session.deck.selected_slot, 'dwell': session.course.goal_cup.dwell,
        'entered_mover_envelope': entered_mover_envelope}

func restore(saved: Dictionary) -> void:
    session.ball._clear_ghost()
    for entry: Dictionary in saved.movers:
        var mover: MovingPlatform = entry.body
        mover.position = entry.position
        mover.force_update_transform()
        mover.elapsed = entry.elapsed
        mover.last_physics_position = entry.last
        mover.surface_velocity = entry.velocity
        mover.frame_displacement = entry.displacement
    for key: String in BALL_FIELDS:
        session.ball.set(key, saved.ball[key])
    if is_instance_valid(session.ball.ghost_body):
        session.ball.add_collision_exception_with(session.ball.ghost_body)
    tick = saved.tick
    actions.resize(saved.actions)
    session.state = saved.state
    session.process_mode = Node.PROCESS_MODE_INHERIT
    session.elixir = saved.elixir
    session.shots = saved.shots
    session.elapsed_seconds = saved.elapsed
    session.random.state = saved.random
    session.deck.random.state = saved.deck_random
    session.deck.hand.assign(saved.hand)
    session.deck.draw_pile.assign(saved.draw)
    session.deck.discard_pile.assign(saved.discard)
    session.deck.selected_slot = saved.slot
    session.course.goal_cup.dwell = saved.dwell
    entered_mover_envelope = saved.entered_mover_envelope

func support() -> TerrainObject:
    return session.ball.attached_body if is_instance_valid(session.ball.attached_body) else session.ball.contact_body

func slots_by_preference() -> Array[int]:
    var slots: Array[int] = [0, 1, 2]
    var order: Array[int] = [CardDefinition.Effect.GLUE, CardDefinition.Effect.SNIPER,
        CardDefinition.Effect.CLASSIC, CardDefinition.Effect.DASH, CardDefinition.Effect.REWIND,
        CardDefinition.Effect.FIRE, CardDefinition.Effect.SLOW, CardDefinition.Effect.HEAVY,
        CardDefinition.Effect.BOUNCE, CardDefinition.Effect.GHOST]
    slots.sort_custom(func(a: int, b: int) -> bool:
        return order.find(session.deck.hand[a].effect) < order.find(session.deck.hand[b].effect))
    return slots

func solve(route_name: String) -> bool:
    for initial_tick: int in 60:
        step()
    var route: Node = session.course.get_node('Routes/' + route_name)
    for stop: Marker2D in route.get_children().slice(1):
        var target_name: String = stop.get_meta('support')
        var target: TerrainObject = session.course.get_node('GoalCup/Terrain') if target_name == 'GoalCup' else session.course.get_node('Terrain/' + target_name)
        var reached: bool = false
        for attempt: int in 12:
            if find_hop(target):
                reached = true
                break
            if find_airborne_hop(target):
                reached = true
                break
            if not cycle_or_position(target, attempt):
                break
        if not reached:
            failure = '%s from %s; hand %s' % [target_name, session.ball.global_position,
                session.deck.hand.map(func(c: CardDefinition) -> String: return str(c.id))]
            return false
    return session.state == GameSession.State.WON

func find_airborne_hop(target: TerrainObject) -> bool:
    # Several low-power hands cannot clear a tall/wide gap in one shot. The
    # approved mechanics explicitly permit a second launch while airborne.
    var saved: Dictionary = snapshot()
    var direction: float = signf(target.global_position.x + 24.0 - session.ball.global_position.x)
    for slot: int in slots_by_preference():
        var card: CardDefinition = session.deck.hand[slot]
        for horizontal: float in [0.25, 0.5, 0.0]:
            for delay: int in [18, 30]:
                restore(saved)
                var impulse: Vector2 = Vector2(direction * horizontal, -1.0).normalized() * card.power * 0.9
                if not shoot(slot, impulse):
                    continue
                for frame: int in delay:
                    step()
                if not entered_mover_envelope and session.state == GameSession.State.PLAYING and find_hop(target):
                    return true
    restore(saved)
    return false

func find_hop(target: TerrainObject) -> bool:
    var saved: Dictionary = snapshot()
    var cup: bool = target == session.course.goal_cup.get_node('Terrain')
    var bounds: Rect2i = target.get_node('Tiles').get_used_rect()
    var width: float = bounds.size.x * 8.0
    var low: float = 24.0 if cup else 10.0
    var high: float = 40.0 if cup else width - 10.0
    for slot: int in slots_by_preference():
        var card: CardDefinition = session.deck.hand[slot]
        var origin: Vector2 = ShotCalculation.origin(card, session.ball)
        var incoming: Vector2 = Vector2.ZERO if ShotCalculation.clears_velocity(card) else session.ball.world_velocity()
        for x_fraction: float in [0.5, 0.25, 0.75, 0.0, 1.0]:
            var destination: Vector2 = target.global_position + Vector2(lerpf(low, high, x_fraction), 6.0 if cup else -2.05)
            for time_index: int in range(22, 97, 3):
                var time: float = time_index * DT
                var gravity: float = session.tuning.gravity * card.gravity_multiplier
                var desired: Vector2 = (destination - origin) / time - Vector2.DOWN * gravity * (time + DT) * 0.5
                var impulse: Vector2 = desired - incoming
                if desired.y + gravity * time < 0 or impulse.length() > card.power or impulse.length() < card.power * 0.05:
                    continue
                for correction: bool in [false, true]:
                    restore(saved)
                    if not shoot(slot, impulse):
                        continue
                    if finish_hop(target, cup, time, correction):
                        return true
                    rejected += 1
    restore(saved)
    return false

func finish_hop(target: TerrainObject, cup: bool, flight_time: float, correction: bool) -> bool:
    var stable: float = 0.0
    var corrected: bool = false
    for frame: int in 2100:
        step()
        if entered_mover_envelope:
            return false
        if session.state == GameSession.State.WON:
            return cup
        if session.state == GameSession.State.LOST:
            return false
        var ball: GolfBall = session.ball
        # A second real play replaces Ghost/Bounce before contact; it also gives
        # ice a legal braking/attachment action. No free discards or effect edits.
        if correction and not corrected and (frame >= int(flight_time * 0.70 / DT) or support() == target):
            corrected = true
            for slot: int in slots_by_preference():
                var card: CardDefinition = session.deck.hand[slot]
                if card.effect in [CardDefinition.Effect.GHOST, CardDefinition.Effect.BOUNCE, CardDefinition.Effect.REWIND] or session.elixir < card.cost:
                    continue
                var remaining: float = maxf(0.16, flight_time - frame * DT)
                var center_x: float = target.global_position.x + (32.0 if cup else target.get_node('Tiles').get_used_rect().size.x * 4.0)
                var destination: Vector2 = Vector2(center_x, target.global_position.y + (6.0 if cup else -2.05))
                var velocity: Vector2 = (destination - ball.global_position) / remaining - Vector2.DOWN * session.tuning.gravity * card.gravity_multiplier * (remaining + DT) * 0.5
                var impulse: Vector2 = velocity - (Vector2.ZERO if ShotCalculation.clears_velocity(card) else ball.world_velocity())
                if impulse.length() < card.power * 0.055:
                    impulse = Vector2.UP * card.power * 0.055
                if shoot(slot, impulse):
                    break
        # Side attachment is legal gameplay, but is not the authored route's
        # top landing and can leave the next hop behind the same solid island.
        var on_target: bool = support() == target and (cup or ball.global_position.y < target.global_position.y + 1.0)
        if on_target and ball.world_velocity().length() < 8.0:
            stable += DT
            if not cup and stable >= 0.65 and session.elixir >= 9.999:
                return true
        else:
            stable = 0.0
        # Fail fast after a missed landing, while allowing bouncing candidates
        # enough time to settle on the same island.
        if frame > int((flight_time + 2.0) / DT) and not on_target and ball.global_position.y > target.global_position.y + 30:
            return false
    return false

func cycle_or_position(target: TerrainObject, attempt: int) -> bool:
    var saved: Dictionary = snapshot()
    var ground: TerrainObject = support()
    if ground == null:
        return false
    var width: float = ground.get_node('Tiles').get_used_rect().size.x * 8.0
    var center: float = ground.global_position.x + width * 0.5
    var direction: float = signf(target.global_position.x + 24.0 - session.ball.global_position.x)
    for slot: int in slots_by_preference():
        var card: CardDefinition = session.deck.hand[slot]
        # Rewind can step back; Ghost can be safely replaced in flight, but is
        # deliberately reserved while another legal cycling play is available.
        if card.effect == CardDefinition.Effect.GHOST:
            continue
        for offset: float in [direction * 16.0, direction * 32.0, 0.0]:
            restore(saved)
            var aim_x: float = clampf(session.ball.global_position.x + offset, ground.global_position.x + 12.0, ground.global_position.x + width - 12.0)
            if attempt % 3 == 2:
                aim_x = center
            var impulse: Vector2 = Vector2((aim_x - session.ball.global_position.x) / 0.3, -session.tuning.gravity * card.gravity_multiplier * 0.15)
            if not ShotCalculation.clears_velocity(card):
                impulse -= session.ball.world_velocity()
            if shoot(slot, impulse) and finish_hop(ground, false, 0.3, false):
                return true
    restore(saved)
    return false
