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
@export_group("Feedback")
@export_range(0.0, 4.0) var maximum_kick_pixels: float = 2.0
@export_range(1.0, 30.0) var kick_decay: float = 16.0
var _kick: Vector2 = Vector2.ZERO

func _ready() -> void:
	session.follow_requested.connect(recenter)
	session.shot_committed.connect(_shot_kick)
	ball.struck.connect(_impact_kick)
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
	var viewport_size: Vector2 = get_viewport_rect().size.max(Vector2.ONE)
	var cover: float = maxf(viewport_size.x / maxf(bounds.size.x, 1), viewport_size.y / maxf(bounds.size.y, 1))
	return maxf(minimum_zoom, cover)

func _viewport_changed() -> void:
	if not is_inside_tree():
		return
	set_zoom(camera.zoom.x)

func set_zoom(amount: float) -> void:
	var closest_overview := overview_zoom()
	camera.zoom = Vector2.ONE * clampf(amount, closest_overview, maxf(maximum_zoom, closest_overview))
	camera.offset = _kick / camera.zoom
	camera.global_position = clamped(camera.global_position + camera.offset) - camera.offset

func clamped(at: Vector2) -> Vector2:
	var half: Vector2 = get_viewport_rect().size * 0.5 / camera.zoom
	var center: Vector2 = bounds.get_center()
	return Vector2(center.x if half.x * 2 >= bounds.size.x else clampf(at.x, bounds.position.x + half.x, bounds.end.x - half.x), center.y if half.y * 2 >= bounds.size.y else clampf(at.y, bounds.position.y + half.y, bounds.end.y - half.y))

func recenter(snap: bool = false) -> void:
	following = true
	if snap:
		camera.global_position = clamped(ball.global_position + follow_offset / camera.zoom + camera.offset) - camera.offset

func pan(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		return
	following = false
	camera.global_position = clamped(camera.global_position + direction.limit_length() * pan_speed * delta / camera.zoom.x + camera.offset) - camera.offset

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
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-kick_decay * delta))
	camera.offset = _kick / camera.zoom
	# Clamp after easing and shake too, including a resize or a changed zoom.
	camera.global_position = clamped(camera.global_position + camera.offset) - camera.offset

func _shot_kick(_card: CardDefinition) -> void:
	_kick = -ball.world_velocity().normalized() * maximum_kick_pixels

func _impact_kick(_body: TerrainObject, normal: Vector2, speed: float) -> void:
	_kick = normal * maximum_kick_pixels * clampf(speed / 300.0, 0.0, 0.75)
