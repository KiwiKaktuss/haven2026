extends SceneTree
func _initialize() -> void:
    call_deferred('run')
func run() -> void:
    var main: Node2D = load('res://main.tscn').instantiate()
    main.save.path = 'user://course_hud_capture.json'
    root.add_child(main)
    for index in 4:
        main._start_course(index)
        main.session.camera_controller.set_zoom(main.session.camera_controller.overview_zoom())
        main.session.camera_controller.recenter(true)
        for frame in 4: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png('res://screenshots/step_6/hud_%d.png'%index)
        main.session.camera_controller.set_zoom(3.0)
        main.session.camera_controller.recenter(true)
        for frame in 4: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png('res://screenshots/step_6/start_%d.png'%index)
    main.free()
    quit()
