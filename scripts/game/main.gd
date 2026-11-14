extends Node2D
@export var menu_scene: PackedScene
@export var game_scene: PackedScene
@export var level_select_scene: PackedScene
@export var deck_editor_scene: PackedScene
@export var pause_menu_scene: PackedScene
@export var result_scene: PackedScene
@export var card_lab_scene: PackedScene
@export var physics_lab_scene: PackedScene
@export var screen_host: CanvasLayer
@export var game_host: Node2D
@export var cards: CardCatalog
@export var courses: CourseCatalog
var save: SaveStore = SaveStore.new()
var session: GameSession
var course_index: int = 0
const MENU_TRAVEL_SECONDS: float = 1.65
var _menu_screen: Control
var _deck_screen: Control
var _journey_tween: Tween
var _journey_progress: float = 0.0
var _journey_moving: bool = false

func _ready() -> void:
    save.read_save(cards, courses)
    get_viewport().size_changed.connect(_layout_menu_journey)
    _show_menu()

func _clear_screens() -> void:
    if _journey_tween != null:
        _journey_tween.kill()
        _journey_tween = null
    _journey_moving = false
    _journey_progress = 0.0
    _menu_screen = null
    _deck_screen = null
    for screen: Node in screen_host.get_children():
        screen_host.remove_child(screen)
        screen.queue_free()

func _clear_games() -> void:
    if is_instance_valid(session) and session.aim != null:
        session.aim.cancel()
    session = null
    for game: Node in game_host.get_children():
        game_host.remove_child(game)
        game.queue_free()

func _screen(packed: PackedScene) -> Control:
    _clear_screens()
    var screen: Control = packed.instantiate() as Control
    screen_host.add_child(screen)
    return screen

func _show_menu() -> void:
    if _journey_moving:
        return
    if is_instance_valid(_menu_screen) and is_instance_valid(_deck_screen):
        if _journey_progress > 0.0:
            _travel_to_menu_depth(0.0)
        return
    _clear_games()
    var menu: Control = _screen(menu_scene)
    _menu_screen = menu
    menu.clip_contents = true
    menu.get_node("Background").process_mode = Node.PROCESS_MODE_ALWAYS
    menu.play_requested.connect(_show_levels)
    menu.deck_requested.connect(_show_deck)
    menu.inspect_requested.connect(_inspect_session)
    menu.lab_requested.connect(_open_physics_lab)
    menu.cards_requested.connect(_open_card_lab)
    _layout_menu_journey()

func _show_levels() -> void:
    _clear_games()
    var screen: Control = _screen(level_select_scene)
    screen.course_requested.connect(_start_course)
    screen.back_requested.connect(_show_menu)
    screen.show_records(save.records)

func _show_deck() -> void:
    if _journey_moving:
        return
    if not is_instance_valid(_menu_screen):
        _show_menu()
    if not is_instance_valid(_deck_screen):
        _deck_screen = deck_editor_scene.instantiate() as Control
        _deck_screen.clip_contents = true
        screen_host.add_child(_deck_screen)
        _deck_screen.done_requested.connect(_leave_deck)
    _deck_screen.configure(save.equipped)
    _travel_to_menu_depth(1.0)

func _leave_deck(ids: Array[StringName]) -> void:
    if _journey_moving:
        return
    var previous: Array[StringName] = save.equipped.duplicate()
    save.equipped = ids.duplicate()
    if not save.write_save():
        save.equipped = previous
        _deck_screen.show_save_error()
        return
    _show_menu()

func _travel_to_menu_depth(depth: float) -> void:
    _journey_moving = true
    _menu_screen.show()
    _deck_screen.show()
    # Disabled processing also keeps cards, tooltips, and keyboard focus from
    # reacting while the camera is travelling between the two rooms.
    _menu_screen.process_mode = Node.PROCESS_MODE_DISABLED
    _deck_screen.process_mode = Node.PROCESS_MODE_DISABLED
    for card: Node in _deck_screen.find_children("*", "Button", true, false):
        if card is CardView:
            card._hide_information()
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()
    var destination: Control = _deck_screen if depth == 1.0 else _menu_screen
    screen_host.move_child(destination, 0)
    _layout_menu_journey()
    _journey_tween = create_tween()
    _journey_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _journey_tween.tween_method(_set_menu_depth, _journey_progress, depth, MENU_TRAVEL_SECONDS)
    _journey_tween.finished.connect(func() -> void:
        _journey_moving = false
        _journey_tween = null
        _menu_screen.visible = depth == 0.0
        _deck_screen.visible = depth == 1.0
        destination.process_mode = Node.PROCESS_MODE_INHERIT
        var button: Button = destination.get_node("Margin/Content/Footer/Back" if depth == 1.0 else "Center/Content/Deck")
        button.grab_focus())

func _set_menu_depth(depth: float) -> void:
    _journey_progress = depth
    _layout_menu_journey()

func _layout_menu_journey() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var height: float = viewport_size.y
    if is_instance_valid(_menu_screen):
        # The journey owns room geometry. Fixed anchors prevent viewport resize
        # notifications from also adding their delta to a moving room's size.
        _menu_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
        _menu_screen.size = viewport_size
        _menu_screen.position.y = -_journey_progress * height
        _menu_screen.get_node("Center").modulate.a = 1.0 - smoothstep(0.0, 0.65, _journey_progress)
    if is_instance_valid(_deck_screen):
        _deck_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
        _deck_screen.size = viewport_size
        _deck_screen.position.y = (1.0 - _journey_progress) * height
        _deck_screen.get_node("Margin").modulate.a = smoothstep(0.25, 1.0, _journey_progress)

func _start_course(index: int) -> void:
    _clear_screens()
    _clear_games()
    course_index = clampi(index, 0, courses.courses.size() - 1)
    session = game_scene.instantiate() as GameSession
    session.course_index = course_index
    session.deck.equipped = save.equipped.duplicate()
    session.pause_requested.connect(_pause)
    session.attempt_finished.connect(_result)
    game_host.add_child(session)

func _restart() -> void:
    _start_course(course_index)

func _pause() -> void:
    if not is_instance_valid(session) or not session.pause_attempt():
        return
    var screen: Control = _screen(pause_menu_scene)
    screen.resume_requested.connect(_resume)
    screen.restart_requested.connect(_restart)
    screen.menu_requested.connect(_show_menu)

func _resume() -> void:
    _clear_screens()
    session.resume_attempt()

func _result(won: bool) -> void:
    var id: StringName = courses.courses[course_index].id
    var new_record: bool = false
    if won:
        new_record = save.record_win(id, session.elapsed_seconds)
        if not save.write_save():
            push_warning("The winning record could not be saved.")
    var screen: Control = _screen(result_scene)
    screen.configure(won, session.elapsed_seconds, session.shots, float(save.records.get(String(id), 0.0)), new_record, course_index == courses.courses.size() - 1)
    screen.restart_requested.connect(_restart)
    screen.menu_requested.connect(_show_menu)
    screen.next_requested.connect(func() -> void:
        if course_index + 1 < courses.courses.size():
            _start_course(course_index + 1)
        else:
            _show_levels())

func _inspect_session() -> void:
    _clear_screens()
    _clear_games()
    session = game_scene.instantiate() as GameSession
    session.inspection_mode = true
    game_host.add_child(session)

func _open_physics_lab() -> void:
    _open_lab(physics_lab_scene)

func _open_card_lab() -> void:
    _open_lab(card_lab_scene)

func _open_lab(packed: PackedScene) -> void:
    _clear_screens()
    _clear_games()
    var lab: Node2D = packed.instantiate() as Node2D
    lab.connect(&"exit_requested", _show_menu)
    game_host.add_child(lab)
