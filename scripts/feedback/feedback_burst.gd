class_name FeedbackBurst
extends Node2D

func play(at: Vector2, tint: Color, direction: Vector2 = Vector2.UP, intensity: float = 1.0) -> void:
    global_position = at
    modulate = tint
    scale = Vector2.ONE * clampf(intensity, 0.65, 1.5)
    $Particles.direction = direction
    $Particles.restart()
    $Particles.emitting = true
    $AnimationPlayer.play(&"pop")
    $AnimationPlayer.animation_finished.connect(func(_name: StringName) -> void: queue_free(), CONNECT_ONE_SHOT)
