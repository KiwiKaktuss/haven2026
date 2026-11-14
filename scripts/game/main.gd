extends Node2D
@export var menu_scene: PackedScene
@export var game_scene: PackedScene
@export var physics_lab_scene: PackedScene
@export var screen_host: CanvasLayer
@export var game_host: Node2D

func _ready() -> void:
    _show_menu()

func _show_menu() -> void:
    for game: Node in game_host.get_children():
        game.queue_free()
    var menu: Control = menu_scene.instantiate() as Control
    screen_host.add_child(menu)
    menu.inspect_requested.connect(_inspect_session)
    menu.lab_requested.connect(_open_physics_lab)

func _clear_menu() -> void:
    for screen: Node in screen_host.get_children():
        screen.queue_free()

func _inspect_session() -> void:
    _clear_menu()
    var session: GameSession = game_scene.instantiate() as GameSession
    game_host.add_child(session)

func _open_physics_lab() -> void:
    _clear_menu()
    var lab: Node2D = physics_lab_scene.instantiate() as Node2D
    lab.connect(&"exit_requested", _show_menu)
    game_host.add_child(lab)
