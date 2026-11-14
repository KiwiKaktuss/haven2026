class_name MovingPlatform
extends TerrainObject
## Endpoints are offsets from the saved scene transform, in parent coordinates.
@export var endpoint_a: Vector2 = Vector2.ZERO
@export var endpoint_b: Vector2 = Vector2(48, 0)
@export_range(0.2, 30.0) var period_seconds: float = 4.0
@export_range(0.0, 1.0) var starting_phase: float = 0.0
@export var motion_enabled: bool = true
var elapsed: float = 0.0
var authored_origin: Vector2
var last_physics_position: Vector2

func _ready() -> void:
	authored_origin = position
	elapsed = starting_phase * period_seconds
	position = authored_origin + endpoint_a.lerp(endpoint_b, _weight())
	last_physics_position = global_position

func _weight() -> float:
	return (1.0 - cos(TAU * elapsed / period_seconds)) * 0.5

func _physics_process(delta: float) -> void:
	# sync_to_physics keeps queries and contacts aligned. Measure the completed
	# displacement, before submitting the next target (which Godot defers).
	var actual_position: Vector2 = global_position
	frame_displacement = actual_position - last_physics_position
	surface_velocity = frame_displacement / delta
	last_physics_position = actual_position
	if motion_enabled:
		elapsed += delta
		position = authored_origin + endpoint_a.lerp(endpoint_b, _weight())
		force_update_transform()
