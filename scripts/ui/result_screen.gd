extends Control
signal next_requested
signal restart_requested
signal menu_requested

func _ready() -> void:
    $Center/Content/Next.pressed.connect(func() -> void: next_requested.emit())
    $Center/Content/Restart.pressed.connect(func() -> void: restart_requested.emit())
    $Center/Content/Menu.pressed.connect(func() -> void: menu_requested.emit())

func configure(won: bool, elapsed: float, shots: int, best: float, new_record: bool, last_course: bool) -> void:
    $Center/Content/Title.text = "Course complete" if won else "Into the void"
    $Center/Content/Stats.text = "%s  ·  %s shot%s" % [GameHUD.format_time(elapsed), shots, "" if shots == 1 else "s"]
    $Center/Content/Record.text = ("New best · " if new_record else "Best · ") + GameHUD.format_time(best) if best > 0 else ""
    $Center/Content/Next.visible = won
    $Center/Content/Next.text = "Choose a course" if last_course else "Next course"
