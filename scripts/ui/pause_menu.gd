extends Control
signal resume_requested
signal restart_requested
signal menu_requested

func _ready() -> void:
    $Center/Content/Resume.pressed.connect(func() -> void: resume_requested.emit())
    $Center/Content/Restart.pressed.connect(func() -> void: restart_requested.emit())
    $Center/Content/Menu.pressed.connect(func() -> void: menu_requested.emit())

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"pause") and not event.is_echo():
        get_viewport().set_input_as_handled()
        resume_requested.emit()
