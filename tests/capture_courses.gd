extends SceneTree
## Overview and detail tour of saved course geometry; not a gameplay completion proof.
var course: GolfCourse
var camera: Camera2D
var frame: int = 0
var index: int = -1
const IDS = ['first_fairway', 'cold_snap', 'spring_works', 'final_ascent']
func _initialize() -> void:
    root.size = Vector2i(1200,900)
    call_deferred('setup')
func setup() -> void:
    camera = Camera2D.new()
    root.add_child(camera)
    camera.make_current()
    show_course(0)
func show_course(which: int) -> void:
    if course != null: course.free()
    index = which
    course = load('res://scenes/levels/%s.tscn' % IDS[index]).instantiate()
    root.add_child(course)
    camera.position = course.camera_bounds.get_center()
    var fit: float = minf(880.0 / course.camera_bounds.size.x, 560.0 / course.camera_bounds.size.y)
    camera.zoom = Vector2.ONE * fit
func _process(_delta: float) -> bool:
    if camera == null: return false
    frame += 1
    var desired: int = mini((frame-1) / 112,3)
    if desired != index: show_course(desired)
    var local: int = (frame-1)%112
    if local == 10: capture(IDS[index] + '_overview')
    if local > 25:
        var t: float = clampf((local-25)/86.0,0,1)
        camera.position = course.start_marker.position.lerp(course.goal_cup.position+Vector2(32,0),t)
        camera.zoom = Vector2.ONE * 3.0
    if local == 100: capture(IDS[index] + '_cup')
    return false
func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute('res://screenshots/step_6')
    root.get_texture().get_image().save_png('res://screenshots/step_6/' + label + '.png')
