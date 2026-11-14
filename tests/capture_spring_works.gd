extends SceneTree
## Still inspection of the saved course and production HUD at player sizes.
func _initialize() -> void:
    root.size = Vector2i(960,640)
    call_deferred("run")

func save_still(title: String) -> void:
    for frame: int in 3:
        await process_frame
    RenderingServer.force_draw()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://screenshots/spring_works/%s.png" % title)

func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://screenshots/spring_works")
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 2
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.aim.enabled = false
    session.camera_controller.set_process(false)
    var camera := session.camera_controller.camera
    session.hud.hide()
    camera.position = Vector2(120,32)
    camera.zoom = Vector2.ONE * 1.25
    await save_still("overview")
    camera.position = Vector2(120,88)
    camera.zoom = Vector2.ONE * 2.5
    await save_still("spring_shortcuts")
    camera.position = Vector2(256,72)
    await save_still("lift_and_east_gallery")
    camera.position = Vector2(-40,-104)
    await save_still("summit_shuttle")
    session.hud.show()
    for size: Vector2i in [Vector2i(800,640),Vector2i(960,640),Vector2i(1440,900)]:
        root.size = size
        await process_frame
        session.camera_controller.set_zoom(3.0)
        session.camera_controller.recenter(true)
        await save_still("hud_%dx%d" % [size.x,size.y])
    session.free()
    quit()
