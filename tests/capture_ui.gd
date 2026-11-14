extends SceneTree
var main: Node2D
var frame: int = 0
var folder: String = "res://screenshots/step_5"

func _initialize() -> void:
    call_deferred("setup")

func setup() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    main = load("res://main.tscn").instantiate()
    main.save.path = "user://capture_ui_save.json"
    root.add_child(main)

func _process(_delta: float) -> bool:
    if main == null:
        return false
    if main._journey_moving:
        return false
    frame += 1
    if frame == 8:
        capture("menu")
    if frame == 30:
        main._show_deck()
    if frame == 45:
        capture("deck")
    if frame == 85:
        main._show_levels()
    if frame == 95:
        capture("courses")
    if frame == 120:
        main._start_course(0)
    if frame == 145:
        main.session.aim.begin(Vector2(340, 230))
        main.session.aim.move_pointer(Vector2(270, 310))
    if frame == 165:
        capture("aim")
    if frame == 175:
        main.session.aim.release(Vector2(270, 310))
    if frame == 210:
        capture("game")
    if frame == 225:
        main._pause()
    if frame == 240:
        capture("pause")
    if frame == 260:
        main._resume()
    if frame == 290:
        main._restart()
    if frame == 320:
        main.session.shots = 4
        main.session.elapsed_seconds = 22.38
        main.session.ball.reset_motion(main.session.course.goal_cup.global_position + Vector2(32, 4.9))
    if frame == 370:
        capture("result")
    if frame == 390:
        main._start_course(1)
    if frame == 415:
        main.session.ball.global_position.y = main.session.course.void_boundary.global_position.y + 1
    if frame == 435:
        capture("defeat")
    if frame == 449:
        DirAccess.remove_absolute("user://capture_ui_save.json")
    return false

func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder + "/" + label + ".png")
