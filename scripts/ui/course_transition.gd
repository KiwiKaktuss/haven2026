extends Control
## A closing iris at the click position, then an opening iris at the tee.
const COVER_SECONDS: float = 0.6
const HOLD_SECONDS: float = 1.6
const REVEAL_SECONDS: float = 0.85
var _tween: Tween
var _spawn_ball: GolfBall
var _spawn_camera: Camera2D
var _radius_fraction: float = 1.0
var _center: Vector2

func _ready() -> void:
    set_process(false)

func _input(_event: InputEvent) -> void:
    if visible:
        get_viewport().set_input_as_handled()

func cover(press_position: Vector2) -> void:
    _spawn_ball = null
    _spawn_camera = null
    _center = get_global_transform_with_canvas().affine_inverse() * press_position
    _radius_fraction = 1.0
    show()
    set_process(true)
    _update_mask()
    _tween = create_tween()
    _tween.tween_method(_set_radius_fraction, 1.0, 0.0, COVER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await _tween.finished

func reveal(attempt: GameSession) -> void:
    _spawn_ball = attempt.ball
    _spawn_camera = attempt.camera_controller.camera
    # The ball stays exactly on its physical start point beneath the solid veil.
    _spawn_ball.show()
    _update_mask()
    # Begin the hold after the covered frame, excluding the scene-loading frame.
    await get_tree().process_frame
    var hold_until: int = Time.get_ticks_msec() + roundi(HOLD_SECONDS * 1000.0)
    while Time.get_ticks_msec() < hold_until:
        await get_tree().process_frame
    _tween = create_tween()
    _tween.tween_method(_set_radius_fraction, 0.0, 1.0, REVEAL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.parallel().tween_property(attempt.hud, "modulate:a", 1.0, 0.22).set_delay(REVEAL_SECONDS - 0.22)
    await _tween.finished
    _spawn_ball = null
    _spawn_camera = null
    set_process(false)
    hide()

func _process(_delta: float) -> void:
    # Reproject the ball so resizing never stretches or shifts the reveal.
    _update_mask()

func _set_radius_fraction(fraction: float) -> void:
    _radius_fraction = fraction
    _update_mask()

func _update_mask() -> void:
    var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
    if is_instance_valid(_spawn_ball):
        _spawn_camera.force_update_scroll()
        _center = to_local * _spawn_ball.get_global_transform_with_canvas().origin
    var extent: Vector2 = _center.abs().max((size - _center).abs())
    var veil_material: ShaderMaterial = $Veil.material
    veil_material.set_shader_parameter("viewport_size", size)
    veil_material.set_shader_parameter("circle_center", _center)
    veil_material.set_shader_parameter("radius", (extent.length() + 2.0) * _radius_fraction)
