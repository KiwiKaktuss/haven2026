extends SceneTree
## Deterministic art/editability tour, separate from engine gameplay witnesses.
var frame: int = 0
var camera: Camera2D
var course: GolfCourse

func _initialize() -> void:
    root.size = Vector2i(960, 640)
    call_deferred("setup")

func setup() -> void:
    root.add_child(load("res://scenes/feedback/course_backdrop.tscn").instantiate())
    course = load("res://scenes/levels/first_fairway.tscn").instantiate()
    root.add_child(course)
    var ball: GolfBall = load("res://scenes/ball/ball.tscn").instantiate()
    ball.simulation_enabled = false
    root.add_child(ball)
    ball.reset_motion(course.start_marker.position)
    camera = Camera2D.new()
    camera.position = Vector2(112, 48)
    camera.zoom = Vector2.ONE * 1.45
    root.add_child(camera)
    camera.make_current()

func _process(_delta: float) -> bool:
    if camera == null: return false
    frame += 1
    if frame <= 60:
        camera.position = Vector2(112, 48)
        camera.zoom = Vector2.ONE * 1.45
    else:
        var t: float = clampf(float(frame - 60) / 330.0, 0, 1)
        var points := PackedVector2Array([Vector2(-64,120),Vector2(144,128),Vector2(300,100),Vector2(208,0),Vector2(64,-56),Vector2(-112,16),Vector2(176,-88)])
        var segment: float = t * (points.size() - 1)
        var index: int = mini(int(segment), points.size() - 2)
        camera.position = points[index].lerp(points[index+1], smoothstep(0, 1, segment-index))
        camera.zoom = Vector2.ONE * 2.8
        if frame > 390:
            var finish: float = smoothstep(0, 1, float(frame - 390) / 60.0)
            camera.position = camera.position.lerp(Vector2(112,48), finish)
            camera.zoom = camera.zoom.lerp(Vector2.ONE * 1.45, finish)
    if frame in [10, 105, 180, 280]:
        save_still("overview" if frame == 10 else "detail_%d" % frame)
    RenderingServer.force_draw()
    return false

func save_still(title: String) -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://screenshots/coast")
    root.get_texture().get_image().save_png("res://screenshots/coast/%s.png" % title)
