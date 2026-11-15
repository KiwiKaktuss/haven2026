class_name CardDefinition
extends Resource
## Balance data only. Selecting a definition never changes the ball.
enum Effect { CLASSIC, SNIPER, SLOW, HEAVY, BOUNCE, GLUE, DASH, FIRE, GHOST, GRAVITY }
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 10) var cost: int = 1
@export_range(1.0, 1000.0) var power: float = 180.0
@export var spread_curve: Curve
@export var effect: Effect = Effect.CLASSIC
@export var artwork: Texture2D
@export_group("Persistent physics")
@export_range(-4.0, 4.0) var gravity_multiplier: float = 1.0
@export_range(0.0, 1.0) var bounce_retention: float = 0.3
@export_range(0.0, 1.0) var knockback_multiplier: float = 1.0
