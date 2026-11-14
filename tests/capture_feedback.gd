extends SceneTree
## Twenty-second montage of all ten real shot transactions and delayed deals.
## Each two-second section is a fresh effect fixture on a production course.
var frame: int = -1
var session: GameSession
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
var ids: Array[StringName] = [&"classic", &"sniper", &"slow", &"heavy", &"bounce", &"glue", &"dash", &"fire", &"ghost", &"rewind"]
var cursor: Vector2
var anchor: Vector2

func _initialize() -> void:
    root.content_scale_size = Vector2i(800, 640)
    root.size = Vector2i(960, 640)
    call_deferred("prepare", 0)

func prepare(index: int) -> void:
    if session != null:
        session.free()
    session = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = mini(3, index / 2)
    session.deck.random.seed = 14 + index
    session.random.seed = 100 + index
    root.add_child(session)
    # Choose a real fixture opening without changing the authored deck contents.
    var deck_ids: Array[StringName] = [ids[index]]
    for card: CardDefinition in catalog.cards:
        if deck_ids.size() < 6 and not deck_ids.has(card.id):
            deck_ids.append(card.id)
    session.deck.start_attempt(deck_ids)
    var found: bool = false
    for slot: int in range(3):
        if session.deck.hand[slot].id == ids[index]:
            session.deck.select_slot(slot)
            found = true
            break
    while not found and session.deck.selected_card().id != ids[index]:
        session.deck.cycle_selected()
    session.hud.refresh()
    session.camera_controller.set_zoom(4.5 if index in [4, 5, 8, 9] else 3.0)
    session.ball.reset_motion(session.course.start_marker.global_position)
    if index == 8:
        session.ball.reset_motion(session.course.get_node("Terrain/StartIsland").global_position + Vector2(-6, 10))
    if index == 9:
        session.ball.global_position += Vector2(35, -25)
    session.ball.simulation_enabled = index != 8
    session.camera_controller.recenter(true)
    anchor = Vector2(520, 200)
    cursor = anchor + (Vector2(-28, -65) if index in [4, 5, 8] else Vector2(-18, 65))
    if index == 7:
        cursor = anchor + Vector2(-70, 56)
    if index == 8:
        cursor = anchor + Vector2(-50, 72)
    if index == 9:
        cursor = anchor + Vector2(-20, 55)
    session.aim.begin(anchor)
    session.aim.move_pointer(cursor)
    print("Feedback capture: ", ids[index], " on course ", session.course_index)

func _process(_delta: float) -> bool:
    frame += 1
    if frame >= 600:
        return false
    if frame > 0 and frame % 60 == 0:
        prepare(frame / 60)
    if session != null and frame % 60 == 8:
        session.ball.simulation_enabled = true
        assert(session.aim.release(cursor), "Each presentation shot must commit")
    if session != null and frame % 60 == 59:
        assert(session.state == GameSession.State.PLAYING and session.hud.visible, "Every fixture must remain playable through the complete deal")
    RenderingServer.force_draw()
    return false
