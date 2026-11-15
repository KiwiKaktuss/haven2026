extends SceneTree
## Saved terrain must render at native proportions and match its solid pixels.
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        if failures < 10:
            push_error(message)

func _initialize() -> void:
    call_deferred("run")

func art_image(body: TerrainObject, bounds: Rect2i) -> Image:
    var result := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
    for child: Node in body.get_children():
        if child is TileMapLayer:
            var map: TileMapLayer = child
            check(map.scale == Vector2.ONE, "Native tile size")
            var size: Vector2i = map.tile_set.tile_size
            for cell: Vector2i in map.get_used_cells():
                var atlas: TileSetAtlasSource = map.tile_set.get_source(map.get_cell_source_id(cell))
                result.blend_rect(atlas.texture.get_image(), atlas.get_tile_texture_region(map.get_cell_atlas_coords(cell)), cell * size - bounds.position)
        elif child is Sprite2D:
            check(child.scale == Vector2.ONE, "Native rim and flag proportions")
            if child.name == "HoleSprite":
                result.blend_rect(child.texture.get_image(), Rect2i(child.region_rect), Vector2i(child.position) - bounds.position)
    return result

func run() -> void:
    var catalog: CourseCatalog = load("res://resources/tutorial/courses.tres")
    for definition: CourseDefinition in catalog.courses:
        var course: GolfCourse = definition.scene.instantiate()
        root.add_child(course)
        var bodies: Array = course.get_node("Terrain").get_children() + [course.goal_cup.get_node("Terrain")]
        var ground: Image
        var ground_bounds: Rect2i
        check(course.goal_cup.scale == Vector2.ONE, "Cup parent does not stretch the bank")
        for body: TerrainObject in bodies:
            check(body.global_scale == Vector2.ONE, "Terrain has square pixels")
            var polygons: Array[PackedVector2Array] = []
            var bounds := Rect2i()
            for child: Node in body.get_children():
                if child is CollisionPolygon2D:
                    polygons.append(child.polygon)
                    for at: Vector2 in child.polygon:
                        bounds = bounds.expand(Vector2i(at))
            bounds = bounds.grow(1)
            var rendered: Image = art_image(body, bounds)
            if body.has_node("Rim"):
                ground = rendered
                ground_bounds = bounds
            for y: int in bounds.size.y:
                for x: int in bounds.size.x:
                    var at := Vector2(bounds.position + Vector2i(x,y)) + Vector2(0.5,0.5)
                    var solid: bool = false
                    for polygon: PackedVector2Array in polygons:
                        solid = solid or Geometry2D.is_point_in_polygon(at,polygon)
                    check(solid == (rendered.get_pixel(x,y).a >= 0.5), "%s/%s artwork matches collision at %s" % [definition.id,body.name,at])
        # Both sides of the enlarged bank share the same 32px depth. On the
        # continuous first lessons every pixel across each join must be opaque.
        if definition.id in [&"tutorial_1",&"tutorial_2",&"tutorial_3",&"tutorial_4",&"tutorial_5"]:
            for x: int in [-32,95]:
                for y: int in 32:
                    check(ground.get_pixelv(Vector2i(x,y)-ground_bounds.position).a >= 0.5, "No rounded border or gap inside a connected landing")
        course.free()
    print("Tutorial tiles: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
