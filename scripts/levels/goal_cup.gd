class_name GoalCup
extends Node2D
@export var capture_area: Area2D
@export var capture_shape: CollisionShape2D
## Small landing assist: roughly four terrain tiles from the opening.
@export_range(4.0, 40.0) var pull_radius: float = 18.0
@export var pull_acceleration: float = 220.0
@export var pull_max_speed: float = 38.0
var dwell: float = 0.0
var _effect_time: float = 0.0

func _ready() -> void:
    add_to_group(&"goal_cups")

func _process(delta: float) -> void:
    _effect_time = fmod(_effect_time + delta, TAU * 10.0)
    queue_redraw()

func pull_contains(world_position: Vector2) -> bool:
    return world_position.distance_squared_to(to_global(Vector2(32, 0))) < pull_radius * pull_radius

## Shared by live motion and the aiming probe; no teleporting through cup walls.
func attract_velocity(world_position: Vector2, current: Vector2, delta: float) -> Vector2:
    if not pull_contains(world_position):
        return current
    var offset: Vector2 = capture_shape.global_position - world_position
    var desired: Vector2 = (offset * 7.0).limit_length(pull_max_speed)
    # Ease in at the edge, with enough force to overcome rolling friction.
    var distance: float = world_position.distance_to(to_global(Vector2(32, 0)))
    var strength: float = lerpf(0.35, 1.0, 1.0 - distance / pull_radius)
    return current.move_toward(desired, pull_acceleration * strength * delta)

func _draw() -> void:
    var center := Vector2(32, 0)
    var rim := PackedVector2Array()
    # The field's artwork ends at the terrain surface, including inside the cup.
    for index: int in 25:
        rim.append(center + (Vector2.from_angle(PI + PI * index / 24.0) * pull_radius).round())
    draw_colored_polygon(rim, Color(0.34, 0.23, 0.48, 0.09))
    # Hard-edged dashes and square dust match the course's tiny pixel tiles.
    for index: int in 12:
        var angle: float = PI + PI * index / 12.0
        var start: Vector2 = center + (Vector2.from_angle(angle) * pull_radius).round()
        var end: Vector2 = center + (Vector2.from_angle(angle + 0.12) * pull_radius).round()
        draw_line(start, end, Color(0.34, 0.23, 0.48, 0.42), 1.0)
    for index: int in 12:
        var progress: float = fposmod(_effect_time * 0.5 + index / 12.0, 1.0)
        var angle: float = PI + fposmod(index * 2.39996 + progress * 1.2, PI)
        var radius: float = lerpf(pull_radius - 1.0, 2.0, progress)
        var point: Vector2 = center + (Vector2.from_angle(angle) * radius).round()
        point.y = minf(point.y, -1.0)
        draw_rect(Rect2(point, Vector2.ONE), Color(0.29, 0.18, 0.42, sin(progress * PI) * 0.65))

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
