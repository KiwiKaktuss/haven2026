class_name BallFeedback
extends Node2D
## Presentation only: no RNG, collision, elapsed-time or trajectory mutation.
@export var ball: GolfBall
@export var burst_scene: PackedScene
@export var trail_seconds: float = 0.22
@export var minimum_marker_pixels: float = 5.0
@export var impact_cooldown: float = 0.07
@export var effect_colors: PackedColorArray = PackedColorArray([
    Color(0.48, 0.67, 0.64), Color(0.2, 0.67, 0.76), Color(0.55, 0.59, 0.85),
    Color(0.43, 0.49, 0.62), Color(0.89, 0.52, 0.23), Color(0.29, 0.73, 0.49),
    Color(0.82, 0.65, 0.18), Color(1, 0.36, 0.12), Color(0.46, 0.71, 0.92), Color(0.7, 0.44, 0.78)])
var _history: Array[Vector3] = []
var _clock: float = 0.0
var _last_impact: float = -1.0
var _effect: int = 0
var _last_position: Vector2

func _ready() -> void:
    ball.effect_changed.connect(_effect_changed)
    ball.launched.connect(_launch)
    ball.struck.connect(_impact)
    ball.ghost_entered.connect(func() -> void: _burst(ball.global_position, effect_colors[CardDefinition.Effect.GHOST], Vector2.UP, 0.8))
    $WorldTrail.set_as_top_level(true)
    $WorldTrail.global_position = Vector2.ZERO
    _last_position = ball.global_position
    _effect_changed(ball.active_effect)

func _effect_changed(effect: CardDefinition.Effect) -> void:
    var was_ghost: bool = _effect == CardDefinition.Effect.GHOST
    _effect = effect
    for index: int in range($Markers.get_child_count()):
        $Markers.get_child(index).visible = index == effect
    $Markers.modulate = effect_colors[effect]
    # Line2D gradients replace default_color; tint the gradient as a whole.
    $WorldTrail.modulate = effect_colors[effect]
    if was_ghost and effect != CardDefinition.Effect.GHOST:
        _burst(ball.global_position, effect_colors[CardDefinition.Effect.GHOST], Vector2.UP, 0.75)
    _history.clear()

func _burst(at: Vector2, color: Color, direction: Vector2, intensity: float) -> void:
    var burst: FeedbackBurst = burst_scene.instantiate()
    # Sibling ownership leaves launch/impact bursts behind as the ball moves.
    ball.get_parent().add_child(burst)
    burst.play(at, color, direction, intensity)

func _launch(card: CardDefinition, impulse: Vector2, _from_position: Vector2) -> void:
    _effect_changed(card.effect)
    _burst(ball.global_position, effect_colors[card.effect], -impulse.normalized(), 0.8 + impulse.length() / 700.0)
    ball.sprite.rotation = impulse.angle()
    ball.effect_animation.stop()
    ball.effect_animation.play(&"launch")
    _history.clear()

func _impact(body: TerrainObject, normal: Vector2, speed: float) -> void:
    if _clock - _last_impact < impact_cooldown:
        return
    _last_impact = _clock
    var color: Color = effect_colors[_effect]
    match body.surface.material:
        SurfaceDefinition.SurfaceMaterial.STICKY: color = effect_colors[CardDefinition.Effect.GLUE]
        SurfaceDefinition.SurfaceMaterial.ICE: color = Color(0.47, 0.75, 0.9)
        SurfaceDefinition.SurfaceMaterial.BOUNCY: color = effect_colors[CardDefinition.Effect.BOUNCE]
    _burst(ball.global_position, color, normal, clampf(speed / 180.0, 0.65, 1.3))
    ball.effect_animation.stop()
    ball.sprite.rotation = normal.angle()
    ball.effect_animation.play(&"impact")

func _process(delta: float) -> void:
    _clock += delta
    var zoom: float = maxf(get_canvas_transform().get_scale().x, 0.01)
    $Markers.scale = Vector2.ONE * maxf(1.0, minimum_marker_pixels / (5.0 * zoom))
    $Markers.rotation = sin(_clock * 3.0) * 0.1
    $Markers.modulate.a = 0.7 + sin(_clock * 5.0) * 0.12
    $Tether.visible = is_instance_valid(ball.attached_body)
    if $Tether.visible:
        $Tether.points = PackedVector2Array([Vector2.ZERO, -ball.contact_normal * 4.0])
    if ball.global_position.distance_to(_last_position) > 80.0:
        _history.clear()
    _last_position = ball.global_position
    if ball.world_velocity().length() > 12.0:
        _history.append(Vector3(ball.global_position.x, ball.global_position.y, _clock))
    while not _history.is_empty() and _history[0].z < _clock - trail_seconds:
        _history.pop_front()
    var points: PackedVector2Array = PackedVector2Array()
    for entry: Vector3 in _history:
        points.append(Vector2(entry.x, entry.y))
    $WorldTrail.points = points
    $WorldTrail.width = (1.4 if _effect in [CardDefinition.Effect.FIRE, CardDefinition.Effect.DASH] else 0.65) / minf(zoom, 1.0)
