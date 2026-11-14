extends SceneTree
var session: GameSession
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://screenshots/step_7/views")
    root.size = Vector2i(960, 640)
    session = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    for card: CardDefinition in session.deck.catalog.cards:
        session.ball.play_card(card, Vector2(15, -40))
        for zoom: float in [session.camera_controller.overview_zoom(), 3.0, 8.0]:
            session.camera_controller.set_zoom(zoom)
            session.camera_controller.recenter(true)
            for frame: int in range(6):
                await process_frame
            RenderingServer.force_draw()
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://screenshots/step_7/views/%s_%.2f.png" % [card.id, zoom])
    session.free()
    quit()
