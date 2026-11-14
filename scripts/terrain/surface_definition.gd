class_name SurfaceDefinition
extends Resource
enum SurfaceMaterial { NORMAL, STICKY, ICE, BOUNCY }
@export var id: StringName = &"normal"
@export var material: SurfaceMaterial = SurfaceMaterial.NORMAL
@export_range(0.0, 20.0) var friction: float = 3.0
@export_range(0.0, 1.0) var bounce: float = 0.3
@export var attaches_on_contact: bool = false
@export_group("Bouncy launch")
@export_range(0.0, 1000.0) var minimum_launch_speed: float = 0.0
@export_range(0.0, 2.0) var launch_multiplier: float = 1.0
