class_name ShotCalculation
extends RefCounted
## One screen-space drag and impulse calculation for transactions and preview.
static func valid_drag(drag: Vector2, tuning: GameTuning) -> bool:
    return drag.is_finite() and drag.length() >= tuning.drag_dead_zone and drag.length_squared() > 0.0

static func strength(drag: Vector2, tuning: GameTuning) -> float:
    return clampf(drag.length() / maxf(tuning.maximum_drag, 0.001), 0.0, 1.0)

static func spread(card: CardDefinition, amount: float) -> float:
    return deg_to_rad(card.spread_curve.sample(clampf(amount, 0.0, 1.0))) if card.spread_curve != null else 0.0

static func clears_velocity(card: CardDefinition) -> bool:
    return card.effect in [CardDefinition.Effect.SLOW, CardDefinition.Effect.REWIND]

static func impulse(card: CardDefinition, drag: Vector2, tuning: GameTuning, angular_offset: float = 0.0) -> Vector2:
    return -drag.normalized().rotated(angular_offset) * card.power * strength(drag, tuning)

static func origin(card: CardDefinition, ball: GolfBall) -> Vector2:
    return ball.safe_position if card.effect == CardDefinition.Effect.REWIND else ball.global_position

static func velocity_after(card: CardDefinition, ball: GolfBall, drag: Vector2, tuning: GameTuning, angular_offset: float = 0.0) -> Vector2:
    var momentum: Vector2 = Vector2.ZERO if clears_velocity(card) else ball.world_velocity()
    return momentum + impulse(card, drag, tuning, angular_offset)
