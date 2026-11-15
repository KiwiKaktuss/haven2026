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
const MENU_TRAVEL_SECONDS: float = 1.15
var _menu_screen: Control
var _deck_screen: Control
var _levels_screen: Control
var _journey_tween: Tween
var _journey_progress: float = 0.0
var _journey_moving: bool = false
var _background_scroll_time: float = 0.0

func _ready() -> void:
    save.read_save(cards, courses)
    get_viewport().size_changed.connect(_layout_menu_journey)
    _show_menu()

func _process(delta: float) -> void:
    _background_scroll_time += delta
    _synchronize_menu_backgrounds()

func _synchronize_menu_backgrounds() -> void:
    for room: Control in [_menu_screen, _levels_screen]:
        if is_instance_valid(room):
            room.get_node("Background").synchronize_scroll(_background_scroll_time)

func _clear_screens() -> void:
    if _journey_tween != null:
        _journey_tween.kill()
        _journey_tween = null
    _journey_moving = false
    _journey_progress = 0.0
    _menu_screen = null
    _deck_screen = null
    _levels_screen = null
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
    get_node("/root/GameAudio").play_menu_music()
    if is_instance_valid(_menu_screen):
        if not is_zero_approx(_journey_progress):
            _travel_to_menu_depth(0.0)
        return
    _clear_games()
    var menu: Control = _screen(menu_scene)
    _menu_screen = menu
    menu.clip_contents = true
    menu.get_node("Background").process_mode = Node.PROCESS_MODE_ALWAYS
    menu.play_requested.connect(_show_levels)
    menu.deck_requested.connect(_show_deck)
    menu.tutorial_requested.connect(_start_tutorial)
    menu.inspect_requested.connect(_inspect_session)
    menu.lab_requested.connect(_open_physics_lab)
    menu.cards_requested.connect(_open_card_lab)
    _layout_menu_journey()

func _show_levels() -> void:
    if _journey_moving:
        return
    _clear_games()
    if not is_instance_valid(_menu_screen):
        _show_menu()
    if not is_instance_valid(_levels_screen):
        _levels_screen = level_select_scene.instantiate() as Control
        _levels_screen.clip_contents = true
        screen_host.add_child(_levels_screen)
        _levels_screen.course_requested.connect(_start_course)
        _levels_screen.back_requested.connect(_show_menu)
    _levels_screen.show_records(save.records)
    _travel_to_menu_depth(-1.0)

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
    if is_equal_approx(depth, _journey_progress):
        return
    _journey_moving = true
    # Room coordinates: selector above the surface, deck editor below it.
    var rooms: Array[Control] = [_levels_screen, _menu_screen, _deck_screen]
    for room: Control in rooms:
        if is_instance_valid(room):
            room.show()
            room.process_mode = Node.PROCESS_MODE_DISABLED
    if is_instance_valid(_deck_screen):
        for card: Node in _deck_screen.find_children("*", "Button", true, false):
            if card is CardView:
                card._hide_information()
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()
    var destination: Control = _levels_screen if depth == -1.0 else (_deck_screen if depth == 1.0 else _menu_screen)
    var focus_path: String = "Center/Content/Play" if _journey_progress < 0.0 else "Center/Content/Deck"
    if depth == -1.0:
        focus_path = "Center/Content/Course0"
    elif depth == 1.0:
        focus_path = "Margin/Content/Footer/Back"
    screen_host.move_child(destination, 0)
    _layout_menu_journey()
    _journey_tween = create_tween()
    _journey_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _journey_tween.tween_method(_set_menu_depth, _journey_progress, depth, MENU_TRAVEL_SECONDS * absf(depth - _journey_progress))
    _journey_tween.finished.connect(func() -> void:
        _journey_moving = false
        _journey_tween = null
        for room: Control in rooms:
            if is_instance_valid(room):
                room.visible = room == destination
        destination.process_mode = Node.PROCESS_MODE_INHERIT
        var button: Button = destination.get_node(focus_path)
        button.grab_focus())

func _set_menu_depth(depth: float) -> void:
    _journey_progress = depth
    _layout_menu_journey()

func _layout_menu_journey() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var rooms: Array[Control] = [_levels_screen, _menu_screen, _deck_screen]
    for index: int in range(rooms.size()):
        var room: Control = rooms[index]
        if not is_instance_valid(room):
            continue
        # Fixed anchors keep viewport resize deltas out of moving room geometry.
        room.set_anchors_preset(Control.PRESET_TOP_LEFT)
        room.size = viewport_size
        var room_depth: float = float(index - 1)
        room.position.y = (room_depth - _journey_progress) * viewport_size.y
        if room != _deck_screen:
            room.get_node("Background").world_origin_y = room_depth * viewport_size.y
    _synchronize_menu_backgrounds()

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
    if session is TutorialSession:
        _clear_screens()
        session.resume_attempt()
        session.retry_step()
        return
    _start_course(course_index)

func _start_tutorial() -> void:
    _clear_screens()
    _clear_games()
    session = preload("res://scenes/tutorial/tutorial_session.tscn").instantiate()
    session.pause_requested.connect(_pause)
    session.menu_requested.connect(_show_menu)
    session.begin_playing.connect(func() -> void: _start_course(0))
    game_host.add_child(session)

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
    get_node("/root/GameAudio").play_level_music()
    var lab: Node2D = packed.instantiate() as Node2D
    lab.connect(&"exit_requested", _show_menu)
    game_host.add_child(lab)
