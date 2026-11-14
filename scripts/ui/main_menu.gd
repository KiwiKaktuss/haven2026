extends Control
signal play_requested
signal deck_requested
signal inspect_requested
signal lab_requested
signal cards_requested

func _ready() -> void:
    var logo: TextureRect = $Center/Content/LogoSlot/Logo
    logo.scale = Vector2.ONE * 0.97
    var idle: Tween = create_tween().set_loops()
    idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    idle.tween_property(logo, "scale", Vector2.ONE * 1.03, 2.8)
    idle.tween_property(logo, "scale", Vector2.ONE * 0.97, 2.8)
    $Center/Content/Play.pressed.connect(func() -> void: play_requested.emit())
    $Center/Content/Deck.pressed.connect(func() -> void: deck_requested.emit())
    $CenterContainer/VBoxContainer/InspectButton.pressed.connect(func() -> void: inspect_requested.emit())
    $CenterContainer/VBoxContainer/PhysicsLabButton.pressed.connect(func() -> void: lab_requested.emit())
    $CenterContainer/VBoxContainer/CardLabButton.pressed.connect(func() -> void: cards_requested.emit())
