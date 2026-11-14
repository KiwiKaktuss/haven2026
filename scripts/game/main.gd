extends Node2D
@export var menu_scene: PackedScene
@export var game_scene: PackedScene
@export var screen_host: CanvasLayer
@export var game_host: Node2D

func _ready() -> void:
    var menu: Control = menu_scene.instantiate() as Control
    screen_host.add_child(menu)
    menu.inspect_requested.connect(_inspect_session)

func _inspect_session() -> void:
    for screen: Node in screen_host.get_children():
        screen.queue_free()
    var session: GameSession = game_scene.instantiate() as GameSession
    game_host.add_child(session)
