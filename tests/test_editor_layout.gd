extends SceneTree
## Called by the real editor acceptance plugin before temporary copies are removed.
var passed: bool = true
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, label: String) -> void:
    passed = passed and ok
    print("EDITOR RUNTIME ", label, ": ", "PASS" if ok else "FAIL")
func run() -> void:
    var card: CardView = load("res://tests/.editor_check/card.tscn").instantiate()
    root.add_child(card)
    card.bind(load("res://resources/cards/rewind.tres"), true)
    check(card.get_node("Artwork").custom_minimum_size == Vector2(139, 49), "artwork slot")
    check(card.get_node("Information/Margin/Content/Description").custom_minimum_size.y == 83, "description slot")
    check(card.get_node("Information/Margin/Content/Description").get_theme_font_size("font_size") == 19, "font override")
    var runtime: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(runtime)
    var hud: GameHUD = load("res://tests/.editor_check/hud.tscn").instantiate()
    root.add_child(hud)
    hud.configure(runtime, "An intentionally long course title")
    hud.refresh()
    check(hud.get_node("Top/TimerSlot").custom_minimum_size == Vector2(139, 49), "timer slot")
    var flight: CardFlight = load("res://tests/.editor_check/flight.tscn").instantiate()
    root.add_child(flight)
    flight.begin(card.definition, Vector2.ZERO, Vector2(320, 240), Vector2(88, 124), 0.58, true)
    var sprite: Sprite2D = flight.get_node("Card")
    check(flight.back_texture.resource_path == "res://art/ball.png", "back reference swap")
    check((sprite.texture.get_size() * sprite.scale).is_equal_approx(Vector2(88, 124)), "swapped back alignment")
    check(runtime.try_shot(Vector2(-30, 70)), "gameplay after reference swap")
    flight.free()
    hud.free()
    runtime.free()
    card.free()
    print("EDITOR LAYOUT RUNTIME: ", "PASS" if passed else "FAIL")
    quit(0 if passed else 1)
