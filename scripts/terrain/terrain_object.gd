class_name TerrainObject
extends PhysicsBody2D
## All shapes under one body belong to one visually distinct Ghost object.
@export var object_id: StringName = &"terrain"
@export var surface: SurfaceDefinition
var surface_velocity: Vector2 = Vector2.ZERO
var frame_displacement: Vector2 = Vector2.ZERO

func is_moving_surface() -> bool:
    return is_class("AnimatableBody2D")
