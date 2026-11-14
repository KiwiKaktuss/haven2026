extends SceneTree
## Check saved art against actual body silhouettes at every pixel center.
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred('run')
func run() -> void:
    var catalog: CourseCatalog = load('res://resources/levels/catalog.tres')
    for definition: CourseDefinition in catalog.courses:
        var course: GolfCourse = definition.scene.instantiate()
        var ids: Dictionary = {}
        var bodies: Array = course.get_node('Terrain').get_children()+course.get_node('MovingPlatforms').get_children()+[course.get_node('GoalCup/Terrain')]
        for body: TerrainObject in bodies:
            check(not ids.has(body.object_id),'Unique island ID: '+str(body.object_id))
            ids[body.object_id] = true
            check(body.scale == Vector2.ONE,'No stretched platform sprites')
            var layer: TileMapLayer = body.get_node('Tiles')
            check(not layer.collision_enabled,'One body owns the whole island')
            var size := layer.tile_set.tile_size
            var polygons: Array[PackedVector2Array] = []
            for child: Node in body.get_children():
                if child is CollisionPolygon2D: polygons.append(child.polygon)
            for cell: Vector2i in layer.get_used_cells():
                var atlas: TileSetAtlasSource = layer.tile_set.get_source(layer.get_cell_source_id(cell))
                var image := atlas.texture.get_image()
                var uv := layer.get_cell_atlas_coords(cell)
                for y in size.y:
                    for x in size.x:
                        var opaque: bool = image.get_pixelv(uv*size+Vector2i(x,y)).a >= 0.5
                        var point := Vector2(cell*size+Vector2i(x,y))+Vector2(0.5,0.5)
                        var solid: bool = false
                        for polygon: PackedVector2Array in polygons:
                            solid = solid or Geometry2D.is_point_in_polygon(point,polygon)
                        check(opaque == solid,'%s/%s visual/collision mismatch at %s'%[definition.id,body.name,point])
            if layer.get_used_cells().size() == 1:
                var uv := layer.get_cell_atlas_coords(Vector2i.ZERO)
                check(uv.x == 4 and uv.y%5 == 4,'Single platforms use the enclosed tile')
        var route_names: Array = []
        for route: Node in course.get_node('Routes').get_children():
            var left: bool = false
            var right: bool = false
            var up: bool = false
            var previous := course.start_marker.position
            for marker: Marker2D in route.get_children():
                var delta := marker.position-previous
                left = left or delta.x < -16
                right = right or delta.x > 16
                up = up or delta.y < -16
                previous = marker.position
            check(left and right and up,'Route travels left, right and up')
            route_names.append(route.name)
        check(route_names.size() >= 2,'Multiple routes are saved for each course')
        course.free()
    var session: GameSession = load('res://scenes/game/game_session.tscn').instantiate()
    session.course_index = 3
    root.add_child(session)
    for viewport_size: Vector2i in [Vector2i(800,640),Vector2i(960,640),Vector2i(1440,900)]:
        root.size = viewport_size
        var camera := session.camera_controller
        camera.set_zoom(camera.overview_zoom())
        camera.recenter(true)
        var extent := camera.get_viewport_rect().size/camera.camera.zoom
        var visible := Rect2(camera.camera.position-extent*0.5,extent)
        check(session.course.camera_bounds.grow(0.01).encloses(visible),'Camera viewport stays within the course at '+str(viewport_size))
    session.free()
    print('Course art: ',checks,' checks, ',failures,' failure(s)')
    quit(0 if failures == 0 else 1)
