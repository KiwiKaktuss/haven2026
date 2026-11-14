class_name GameTuning
extends Resource
@export_group("Motion")
@export var gravity: float = 260.0
@export var ball_radius: float = 2.0
@export var rest_speed: float = 5.0
@export var safe_contact_seconds: float = 0.5
@export var safe_position_clearance: float = 0.1
@export_group("Aiming (screen pixels)")
@export var drag_dead_zone: float = 8.0
@export var maximum_drag: float = 160.0
@export_group("Elixir")
@export var maximum_elixir: int = 10
@export var regeneration_seconds: float = 3.0
@export_group("Cup capture")
@export var capture_speed: float = 8.0
@export var capture_dwell_seconds: float = 0.6
