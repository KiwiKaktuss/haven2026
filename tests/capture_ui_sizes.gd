extends SceneTree
var main: Node2D
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    main = load("res://main.tscn").instantiate()
    main.save.path = "user://ui_size_test.json"
    root.add_child(main)
    for size: Vector2i in [Vector2i(800, 640), Vector2i(1440, 900)]:
        root.size = size
        main._show_deck()
        await frames()
        await save_image("deck_%s" % size.x)
        main._start_course(3)
        main.session.camera_controller.set_zoom(main.session.camera_controller.overview_zoom())
        await frames()
        await save_image("hud_%s" % size.x)
        main._pause()
        await frames()
        await save_image("pause_%s" % size.x)
        main._show_menu()
    main.free()
    quit()
func frames() -> void:
    for i: int in range(30):
        await process_frame
func save_image(label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://screenshots/step_5/" + label + ".png")
