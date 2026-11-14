extends Node2D
signal exit_requested
## Debug course only; no card costs or shot gesture are bypassed in game sessions.
@export var balls: Array[GolfBall] = []
@export var launch_impulse: Vector2 = Vector2(24, -95)
var starts: Array[Vector2] = []
var initial_velocities: Array[Vector2] = []

func _ready() -> void:
    for ball: GolfBall in balls:
        starts.append(ball.global_position)
        initial_velocities.append(ball.velocity)

func reset_lab() -> void:
    for index: int in range(balls.size()):
        balls[index].reset_motion(starts[index])
        balls[index].velocity = initial_velocities[index]

func launch_all() -> void:
    for ball: GolfBall in balls:
        ball.launch(launch_impulse)

func _on_exit_pressed() -> void:
    exit_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"lab_reset"):
        reset_lab()
    elif event.is_action_pressed(&"lab_launch"):
        launch_all()
