extends SceneTree
## Fifteen seconds: real pointer gestures, card switching, affordability and camera.
var lab: Node2D
var frame: int = 0

func _initialize() -> void:
    call_deferred("setup")

func setup() -> void:
    lab = load("res://tests/scenes/card_lab.tscn").instantiate()
    root.add_child(lab)
    lab.camera_controller.following = false
    lab.aim.camera.global_position = Vector2(272, 180)
    prepare(&"classic")

func prepare(id: StringName) -> void:
    lab.reset_lab()
    lab.camera_controller.following = false
    var deck: DeckModel = lab.session.deck
    var ids: Array[StringName] = [id]
    for card: CardDefinition in deck.catalog.cards:
        if ids.size() < CardCatalog.DECK_SIZE and not ids.has(card.id):
            ids.append(card.id)
    deck.start_attempt(ids)
    for slot: int in range(3):
        if deck.hand[slot].id == id:
            deck.select_slot(slot)
            return
    while deck.selected_card().id != id:
        deck.cycle_selected()

func pointer(at: Vector2, pressed: bool) -> void:
    var event: InputEventMouseButton = InputEventMouseButton.new()
    event.position = at
    event.global_position = at
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    root.push_input(event, true)

func motion(at: Vector2) -> void:
    var event: InputEventMouseMotion = InputEventMouseMotion.new()
    event.position = at
    event.global_position = at
    root.push_input(event, true)

func _process(_delta: float) -> bool:
    if not is_instance_valid(lab):
        return false
    frame += 1
    if frame == 5:
        motion(Vector2(300, 260))
        pointer(Vector2(300, 260), true)
    if frame > 5 and frame <= 35:
        motion(Vector2(300, 260) + Vector2(-1.8, 2.2) * (frame - 5))
    if frame == 50:
        pointer(Vector2(246, 326), false)
    if frame == 100:
        prepare(&"fire")
        lab.session.elixir = 3.4
        motion(Vector2(300, 260))
        pointer(Vector2(300, 260), true)
    if frame > 100 and frame <= 130:
        motion(Vector2(300, 260) + Vector2(-1.4, 3.0) * (frame - 100))
    if frame == 180:
        pointer(Vector2(258, 350), false)
    if frame == 220:
        lab.fixture_selector.selected = 2
        prepare(&"ghost")
        motion(Vector2(300, 260))
        pointer(Vector2(300, 260), true)
    if frame > 220 and frame <= 240:
        motion(Vector2(300, 260) + Vector2(0, -3.0) * (frame - 220))
    if frame == 260:
        pointer(Vector2(300, 200), false)
    if frame == 300:
        lab.fixture_selector.selected = 0
        prepare(&"rewind")
        lab.session.ball.safe_position = Vector2(160, 77.9)
        motion(Vector2(300, 260))
        pointer(Vector2(300, 260), true)
        motion(Vector2(260, 330))
    if frame == 330:
        lab.session.deck.select_slot((lab.session.deck.selected_slot + 1) % 3)
    if frame == 350:
        lab.aim.cancel()
        pointer(Vector2(260, 330), false)
    if frame > 355 and frame < 390:
        lab.camera_controller.set_zoom(lab.aim.camera.zoom.x * 1.015)
        lab.camera_controller.pan(Vector2.RIGHT, 1.0 / 30)
    if frame == 400:
        lab.camera_controller.set_zoom(1.0)
        lab.camera_controller.recenter()
    if frame == 420:
        motion(Vector2(300, 260))
        pointer(Vector2(300, 260), true)
        motion(Vector2(270, 320))
    return false
