extends SceneTree
var session: GameSession
var frame: int = 0

func _initialize() -> void:
    root.size = Vector2i(960,640)
    call_deferred("setup")

func setup() -> void:
    session = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.camera_controller.set_process(false)
    session.aim.enabled = false

func _process(delta: float) -> bool:
    if session == null: return false
    frame += 1
    var cam := session.camera_controller
    if frame < 60:
        cam.set_zoom(3)
        cam.recenter(true)
    elif frame < 150:
        cam.set_zoom(cam.camera.zoom.x*0.97)
    elif frame < 210:
        cam.pan(Vector2.UP,delta*3)
    elif frame < 270:
        cam.pan(Vector2.DOWN,delta*3)
    elif frame < 330:
        cam.set_zoom(3)
        cam.pan(Vector2.RIGHT,delta*3)
    elif frame < 390:
        cam.pan(Vector2.LEFT,delta*5)
    else:
        cam.set_zoom(3)
        cam.recenter(true)
    cam._process(0)
    if frame in [20,145,240,300]: save_still()
    RenderingServer.force_draw()
    return false

func save_still() -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://screenshots/refinements")
    root.get_texture().get_image().save_png("res://screenshots/refinements/view_%d.png"%frame)
