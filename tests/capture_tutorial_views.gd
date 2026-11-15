extends SceneTree
var session: TutorialSession
func _initialize() -> void:
    root.size = Vector2i(960,640)
    call_deferred("run")
func capture(path: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://screenshots/tutorial/"+path+".png")
func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://screenshots/tutorial")
    session = load("res://scenes/tutorial/tutorial_session.tscn").instantiate()
    root.add_child(session)
    for index: int in [0,1,2,4,5,6,7,8,9]:
        session.step_index = index
        session.retry_step()
        await capture("lesson_%02d" % (index+1))
    for viewport_size: Vector2i in [Vector2i(800,640), Vector2i(960,640), Vector2i(1440,900)]:
        root.size = viewport_size
        session.step_index = 5
        session.retry_step()
        await capture("cards_%d_intro" % viewport_size.x)
        session.lesson_ui.get_node("CardLesson").inspect(0)
        await capture("cards_%d_hover" % viewport_size.x)
    root.size = Vector2i(960,640)
    session.step_index = 9
    session.retry_step()
    session._advance_step()
    await capture("complete")
    session.free()
    var main: Node = load("res://main.tscn").instantiate()
    root.add_child(main)
    main._menu_screen._finish_intro()
    await capture("menu")
    quit()
