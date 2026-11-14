extends SceneTree
## Called by the real editor acceptance plugin before its temporary copies are removed.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var card: CardView = load("res://tests/.editor_check/card.tscn").instantiate()
    root.add_child(card)
    card.bind(load("res://resources/cards/rewind.tres"), true)
    var passed: bool = card.get_node("MarginContainer/VBoxContainer/Heading/NameSlot").custom_minimum_size == Vector2(139, 49)
    passed = passed and card.get_node("MarginContainer/VBoxContainer/DescriptionSlot").custom_minimum_size.y == 83
    passed = passed and card.get_node("MarginContainer/VBoxContainer/Heading/NameSlot/NameLabel").get_theme_font_size("font_size") == 19
    var runtime: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(runtime)
    var hud: GameHUD = load("res://tests/.editor_check/hud.tscn").instantiate()
    root.add_child(hud)
    hud.configure(runtime, "An intentionally long course title")
    hud.refresh()
    passed = passed and hud.get_node("Top/CourseSlot").custom_minimum_size == Vector2(139, 49)
    hud.free()
    runtime.free()
    card.free()
    print("EDITOR LAYOUT RUNTIME: ", "PASS" if passed else "FAIL")
    quit(0 if passed else 1)
