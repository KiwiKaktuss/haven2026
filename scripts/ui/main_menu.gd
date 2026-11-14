extends Control
signal play_requested
signal deck_requested
signal inspect_requested
signal lab_requested
signal cards_requested

func _ready() -> void:
    $Center/Content/Play.pressed.connect(func() -> void: play_requested.emit())
    $Center/Content/Deck.pressed.connect(func() -> void: deck_requested.emit())
    $CenterContainer/VBoxContainer/InspectButton.pressed.connect(func() -> void: inspect_requested.emit())
    $CenterContainer/VBoxContainer/PhysicsLabButton.pressed.connect(func() -> void: lab_requested.emit())
    $CenterContainer/VBoxContainer/CardLabButton.pressed.connect(func() -> void: cards_requested.emit())
