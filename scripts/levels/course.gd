class_name GolfCourse
extends Node2D
@export var camera_bounds: Rect2 = Rect2(-160, -120, 320, 240)
@export_range(0.1, 12.0) var minimum_zoom: float = 1.0
@export_range(0.1, 12.0) var maximum_zoom: float = 8.0
@export var camera_pan_speed: float = 200.0
@export var camera_smoothing: float = 5.0
@export var start_marker: Marker2D
@export var goal_cup: GoalCup
@export var void_boundary: Marker2D
