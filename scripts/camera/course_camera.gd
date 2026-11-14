class_name CourseCamera
extends Node2D
@export var camera: Camera2D
@export var ball: GolfBall
@export var session: GameSession
@export var bounds: Rect2 = Rect2(-160, -120, 320, 240)
@export_range(0.1, 12.0) var minimum_zoom: float = 1.0
@export_range(0.1, 12.0) var maximum_zoom: float = 8.0
@export var pan_speed: float = 200.0
@export var smoothing: float = 5.0
@export var wheel_factor: float = 1.15
## Screen pixels: a fixed offset remains usable at close and overview zoom.
@export var follow_offset: Vector2 = Vector2.ZERO
@export var enabled: bool = true
var following: bool = true

func _ready() -> void:
    session.follow_requested.connect(recenter)
    get_viewport().size_changed.connect(_viewport_changed)
    _viewport_changed()

func configure(course: GolfCourse) -> void:
    bounds = course.camera_bounds
    minimum_zoom = course.minimum_zoom
    maximum_zoom = course.maximum_zoom
    pan_speed = course.camera_pan_speed
    smoothing = course.camera_smoothing
    _viewport_changed()
    recenter(true)

func overview_zoom() -> float:
    var viewport_size: Vector2 = get_viewport_rect().size
    var fit: float = minf(viewport_size.x / maxf(bounds.size.x, 1), viewport_size.y / maxf(bounds.size.y, 1))
    return minf(minimum_zoom, fit)

func _viewport_changed() -> void:
    if not is_inside_tree():
        return
    set_zoom(camera.zoom.x)

func set_zoom(amount: float) -> void:
    camera.zoom = Vector2.ONE * clampf(amount, overview_zoom(), maximum_zoom)
    camera.global_position = clamped(camera.global_position)

func clamped(at: Vector2) -> Vector2:
    var half: Vector2 = get_viewport_rect().size * 0.5 / camera.zoom
    var center: Vector2 = bounds.get_center()
    return Vector2(center.x if half.x * 2 >= bounds.size.x else clampf(at.x, bounds.position.x + half.x, bounds.end.x - half.x), center.y if half.y * 2 >= bounds.size.y else clampf(at.y, bounds.position.y + half.y, bounds.end.y - half.y))

func recenter(snap: bool = false) -> void:
    following = true
    if snap:
        camera.global_position = clamped(ball.global_position + follow_offset / camera.zoom)

func pan(direction: Vector2, delta: float) -> void:
    if direction.is_zero_approx():
        return
    following = false
    camera.global_position = clamped(camera.global_position + direction.limit_length() * pan_speed * delta / camera.zoom.x)

func _unhandled_input(event: InputEvent) -> void:
    if not enabled or session.state not in [GameSession.State.READY, GameSession.State.PLAYING]:
        return
    if event.is_action_pressed(&"zoom_in"):
        set_zoom(camera.zoom.x * wheel_factor)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"zoom_out"):
        set_zoom(camera.zoom.x / wheel_factor)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"recenter"):
        recenter()
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if not enabled or session.state not in [GameSession.State.READY, GameSession.State.PLAYING]:
        return
    pan(Input.get_vector(&"pan_left", &"pan_right", &"pan_up", &"pan_down"), delta)
    if following:
        camera.global_position = camera.global_position.lerp(clamped(ball.global_position + follow_offset / camera.zoom), 1.0 - exp(-smoothing * delta))
