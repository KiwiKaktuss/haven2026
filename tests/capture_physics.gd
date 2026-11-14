extends SceneTree
## Deterministic 15-second visual proof. Invoke with --fixed-fps 30 --quit-after 450.
var lab: Node2D
var frame: int = 0

func _initialize() -> void:
    call_deferred("setup")

func setup() -> void:
    lab = load("res://tests/scenes/physics_lab.tscn").instantiate()
    root.add_child(lab)

func _process(_delta: float) -> bool:
    frame += 1
    if is_instance_valid(lab):
        if frame % 120 == 0:
            lab.call("reset_lab")
        elif frame % 120 == 60:
            lab.call("launch_all")
    return false
