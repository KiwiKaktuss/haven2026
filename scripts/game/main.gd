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

func _ready() -> void:
    save.read_save(cards, courses)
    _show_menu()

func _clear_screens() -> void:
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
    _clear_games()
    var menu: Control = _screen(menu_scene)
    menu.play_requested.connect(_show_levels)
    menu.deck_requested.connect(_show_deck)
    menu.inspect_requested.connect(_inspect_session)
    menu.lab_requested.connect(_open_physics_lab)
    menu.cards_requested.connect(_open_card_lab)

func _show_levels() -> void:
    _clear_games()
    var screen: Control = _screen(level_select_scene)
    screen.course_requested.connect(_start_course)
    screen.back_requested.connect(_show_menu)
    screen.show_records(save.records)

func _show_deck() -> void:
    var screen: Control = _screen(deck_editor_scene)
    screen.configure(save.equipped)
    screen.done_requested.connect(func(ids: Array[StringName]) -> void:
        save.equipped = ids.duplicate()
        if not save.write_save():
            screen.get_node("Margin/Content/Footer/Hint").text = "Could not save. Please try again."
            return
        _show_menu())

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
