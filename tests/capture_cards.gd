extends SceneTree
## Deterministic visual walkthrough of real card transactions and physics.
var lab: Node2D
var frame: int = 0
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
var sequence: Array[StringName] = [&"classic", &"sniper", &"slow", &"heavy", &"bounce", &"glue", &"dash", &"fire", &"ghost", &"rewind"]

func _initialize() -> void:
    call_deferred("setup")

func setup() -> void:
    lab = load("res://tests/scenes/card_lab.tscn").instantiate()
    root.add_child(lab)
    prepare(0)

func prepare(index: int) -> void:
    var session: GameSession = lab.session
    var id: StringName = sequence[index]
    var ids: Array[StringName] = [id]
    for card: CardDefinition in catalog.cards:
        if ids.size() < 6 and not ids.has(card.id):
            ids.append(card.id)
    lab.fixture_selector.selected = 2 if id == &"ghost" else (3 if id == &"glue" else 0)
    lab.reset_lab()
    session.deck.start_attempt(ids)
    for slot: int in range(3):
        if session.deck.hand[slot].id == id:
            session.deck.select_slot(slot)
            break
    while session.deck.selected_card().id != id:
        session.deck.cycle_selected()
    lab.get_node("CanvasLayer/Instructions").text = "CARD LAB · %s / 10 · %s\nReal costs, shot count and same-slot card replacement; fixed debug shots." % [index + 1, session.deck.selected_card().display_name]

func _process(_delta: float) -> bool:
    if not is_instance_valid(lab):
        return false
    frame += 1
    var phase: int = (frame - 1) % 45
    var index: int = (frame - 1) / 45
    if phase == 0 and frame > 1:
        prepare(index)
    if phase == 10:
        var drag: Vector2 = Vector2(-20, 50)
        if sequence[index] in [&"glue", &"ghost"]:
            drag = Vector2(0, -40)
        if sequence[index] == &"rewind":
            lab.session.ball.global_position += Vector2(40, -25)
        assert(lab.session.try_shot(drag))
    return false
