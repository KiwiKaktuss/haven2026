extends SceneTree
## Verify that tile painting changes the actual saved collision, including
## negative cell coordinates and erasure, without touching the authored course.
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func ray(from: Vector2, to: Vector2) -> Dictionary:
    return root.world_2d.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1))

func run() -> void:
    var course: GolfCourse = load("res://scenes/levels/first_fairway.tscn").instantiate()
    root.add_child(course)
    var map: TileMapLayer = course.get_node("Terrain/EastBank/Tiles")
    check(map.tile_set.get_source(0).texture.resource_path == "res://art/all_tiles2.png", "Replacement atlas is in use")
    for node: Node in course.get_node("Terrain").get_children():
        check(node.get_node("Tiles").has_method("rebuild_solid"), "Terrain is paintable with collision updates")
    for node: Node in course.get_node("Decorations").get_children():
        check(node is TileMapLayer and not node.collision_enabled, "Scenery is editable without invisible obstacles")
    var sea: TileMapLayer = course.get_node("Decorations/Sea")
    check(sea.tile_set.get_source(0).get_tile_animation_frames_count(Vector2i.ZERO) == 4, "Sea foam is animated")
    check(course.void_boundary.position.y == 211 and course.void_detects_ball_edge, "Lower sea kills on first ball-edge contact")
    for title: String in ["WestWall","EastWall","Ceiling","Seabed"]:
        check(course.has_node("Terrain/"+title), "Course has enclosing walls")
    # Paint outside the original used rectangle, rebuild and reload a PackedScene.
    map.set_cell(Vector2i(-2,-2),0,Vector2i(4,1))
    map.rebuild_solid()
    var packed := PackedScene.new()
    check(packed.pack(course) == OK, "Edited course packs")
    check(ResourceSaver.save(packed,"user://coast_edit_test.tscn") == OK, "Tile and collision edits save")
    course.free()
    var saved: PackedScene = ResourceLoader.load("user://coast_edit_test.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
    course = saved.instantiate()
    root.add_child(course)
    await physics_frame
    await process_frame
    check(not ray(Vector2(60,80),Vector2(60,110)).is_empty(), "Painted negative cell has collision after reload")
    map = course.get_node("Terrain/EastBank/Tiles")
    map.erase_cell(Vector2i(-2,-2))
    map.rebuild_solid()
    await physics_frame
    await process_frame
    check(ray(Vector2(60,80),Vector2(60,110)).is_empty(), "Erasing cell removes collision")
    course.free()
    DirAccess.remove_absolute("user://coast_edit_test.tscn")
    print("First Fairway editing: %d checks, %d failure(s)" % [checks,failures])
    quit(0 if failures == 0 else 1)
