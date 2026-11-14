class_name GolfBall
extends CharacterBody2D
## Motion/contact implementation belongs to plan step 2.
signal effect_changed(effect: CardDefinition.Effect)
@export var tuning: GameTuning
@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var effect_animation: AnimationPlayer
var active_effect: CardDefinition.Effect = CardDefinition.Effect.CLASSIC
var safe_position: Vector2
