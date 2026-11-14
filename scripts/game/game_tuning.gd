class_name GameTuning
extends Resource
@export_group("Motion")
@export var gravity: float = 260.0
@export var ball_radius: float = 2.0
@export var rest_speed: float = 5.0
@export var rolling_stop_speed: float = 0.5
@export var bounce_threshold: float = 24.0
@export var collision_margin: float = 0.02
@export var contact_probe: float = 0.2
@export var reattach_inward_speed: float = 0.5
@export_range(1, 32) var maximum_contacts_per_step: int = 8
@export_range(0.0, 1.0) var minimum_support_dot: float = 0.1
@export var safe_contact_seconds: float = 0.5
@export var safe_position_clearance: float = 0.1
@export_group("Aiming (screen pixels)")
@export var drag_dead_zone: float = 8.0
@export var maximum_drag: float = 160.0
@export_group("Shot feel")
## Shared by live shots and prediction. 25% more speed gives ~56% more range.
@export_range(1.0, 2.0) var shot_power_multiplier: float = 1.25
@export_range(0.1, 2.0) var card_redraw_delay: float = 1.0
@export_range(0.2, 1.0) var card_deal_seconds: float = 0.58
@export_group("Elixir")
@export var maximum_elixir: int = 10
@export var regeneration_seconds: float = 3.0
@export_group("Cup capture")
@export var capture_speed: float = 8.0
@export var capture_dwell_seconds: float = 0.6
