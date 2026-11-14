class_name GoalCup
extends Node2D
@export var capture_area: Area2D
@export var capture_shape: CollisionShape2D
var dwell: float = 0.0

func reset_capture() -> void:
    dwell = 0.0

func advance_capture(ball: GolfBall, tuning: GameTuning, delta: float) -> bool:
    # Armed/passing Ghost can penetrate the floor and must never be forced into a win.
    var eligible: bool = ball.ghost_state not in [GolfBall.GhostState.ARMED, GolfBall.GhostState.PASSING]
    var rectangle: RectangleShape2D = capture_shape.shape as RectangleShape2D
    var inside: bool = rectangle != null and Rect2(-rectangle.size * 0.5, rectangle.size).has_point(capture_shape.to_local(ball.global_position))
    # Query the current transform: Area2D's overlap cache can lag a teleport or exit.
    if not eligible or not inside or ball.world_velocity().length() > tuning.capture_speed:
        dwell = 0.0
        return false
    dwell += delta
    return dwell >= tuning.capture_dwell_seconds
