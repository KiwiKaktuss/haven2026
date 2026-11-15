extends SceneTree
## Offline authoring only: ten small, saved, editor-paintable practice rooms.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var scene: Node2D
var tiles: TileSet = preload("res://resources/terrain/terrain_tileset.tres")

func fill_cell(map: TileMapLayer, cell: Vector2i, material: int, uv: Vector2i) -> void:
    if uv == Vector2i(4, 1):
        map.set_cell(cell, 1, Vector2i(material % 2, material / 2))
    else:
        map.set_cell(cell, 0, uv + Vector2i(0, material * 5))

func own(parent: Node, child: Node) -> void:
    parent.add_child(child)
    child.owner = scene

func platform(title: String, at: Vector2, w: int, h: int, material: String = "normal") -> TerrainObject:
    var body := StaticBody2D.new()
    body.set_script(load("res://scripts/terrain/terrain_object.gd"))
    body.name = title
    body.position = at
    body.set("object_id", StringName(title.to_snake_case()))
    body.set("surface", load("res://resources/terrain/%s.tres" % material))
    body.collision_mask = 0
    own(scene.get_node("Terrain"), body)
    var map := TileMapLayer.new()
    map.name = "Tiles"
    map.tile_set = tiles
    map.collision_enabled = false
    map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    map.set_script(EditableTiles)
    own(body, map)
    var band: int = ["normal", "sticky", "ice", "bouncy"].find(material)
    for y: int in h:
        for x: int in w:
            fill_cell(map, Vector2i(x, y), band, Vector2i(4, 1))
    map.rebuild_solid()
    return body as TerrainObject

func cup(at: Vector2) -> void:
    scene.goal_cup = load("res://scenes/tutorial/tutorial_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    scene.goal_cup.position = at - Vector2(32, 0)
    scene.goal_cup.pull_radius = 18.0
    own(scene, scene.goal_cup)
    # Save the contextual border joins as ordinary editable room nodes.
    scene.goal_cup.scene_file_path = ""
    reown(scene.goal_cup, scene)

func reown(parent: Node, root_node: Node) -> void:
    for child: Node in parent.get_children():
        child.scene_file_path = ""
        child.owner = root_node
        reown(child, root_node)

func build_cup() -> void:
    # Same native-size rim and flag as the normal game. Extend the bank by
    # adding tiles, never by scaling the artwork or its parent.
    scene = preload("res://scenes/levels/goal_cup.tscn").instantiate()
    scene.name = "TutorialCup"
    scene.scene_file_path = ""
    reown(scene, scene)
    var body: TerrainObject = scene.get_node("Terrain")
    var original: TileMapLayer = body.get_node("Tiles")
    var rim := TileMapLayer.new()
    rim.name = "Rim"
    rim.tile_set = preload("res://resources/terrain/cup_quarters.tres")
    rim.collision_enabled = false
    for cell: Vector2i in original.get_used_cells():
        if cell.x >= 6 and cell.x <= 9 and cell.y <= 1:
            rim.set_cell(cell, original.get_cell_source_id(cell), original.get_cell_atlas_coords(cell))
    body.remove_child(original)
    original.free()
    own(body, rim)
    var map := TileMapLayer.new()
    map.name = "Tiles"
    map.tile_set = tiles
    map.collision_enabled = false
    map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    own(body, map)
    for y: int in 4:
        for x: int in range(-4, 12):
            if y == 0 and x in [3, 4]:
                continue
            fill_cell(map, Vector2i(x, y), 0, Vector2i(4, 1))
    var shape := RectangleShape2D.new()
    shape.size = Vector2(3, 5)
    scene.capture_shape.shape = shape
    scene.pull_radius = 18.0
    join_tiles()
    var packed := PackedScene.new()
    assert(packed.pack(scene) == OK)
    assert(ResourceSaver.save(packed, "res://scenes/tutorial/tutorial_cup.tscn") == OK)
    scene.free()

func join_tiles() -> void:
    var bodies: Array[TerrainObject] = []
    if scene is GoalCup:
        bodies.append(scene.get_node("Terrain"))
    else:
        for body: TerrainObject in scene.get_node("Terrain").get_children():
            bodies.append(body)
        bodies.append(scene.goal_cup.get_node("Terrain"))
    var occupied: Dictionary = {}
    for body: TerrainObject in bodies:
        var map: TileMapLayer = body.get_node("Tiles")
        var offset := Vector2i(body.position / 8) if body.get_parent() == scene.get_node("Terrain") else Vector2i(body.get_parent().position / 8)
        for cell: Vector2i in map.get_used_cells():
            occupied[cell + offset] = true
        if body.has_node("Rim"):
            # The native rim occupies these two partial cells around the hole.
            occupied[offset + Vector2i(3, 0)] = true
            occupied[offset + Vector2i(4, 0)] = true
    for body: TerrainObject in bodies:
        var map: TileMapLayer = body.get_node("Tiles")
        var offset := Vector2i(body.position / 8) if body.get_parent() == scene.get_node("Terrain") else Vector2i(body.get_parent().position / 8)
        for cell: Vector2i in map.get_used_cells():
            var at := cell + offset
            var left: bool = not occupied.has(at + Vector2i.LEFT)
            var right: bool = not occupied.has(at + Vector2i.RIGHT)
            var top: bool = not occupied.has(at + Vector2i.UP)
            var bottom: bool = not occupied.has(at + Vector2i.DOWN)
            var uv := Vector2i(4, 1)
            if top:
                uv = Vector2i(2, 2) if left else (Vector2i(3, 2) if right else Vector2i(2, 4))
            elif bottom:
                uv = Vector2i(2, 3) if left else (Vector2i(3, 3) if right else Vector2i(3, 4))
            elif left:
                uv = Vector2i(0, 4)
            elif right:
                uv = Vector2i(1, 4)
            fill_cell(map, cell, body.surface.material, uv)
        if body.has_node("Rim"):
            rebuild_cup_solid(body)
        else:
            map.rebuild_solid()

func rebuild_cup_solid(body: TerrainObject) -> void:
    var mask_image := Image.create(128, 32, false, Image.FORMAT_RGBA8)
    for title: String in ["Tiles", "Rim"]:
        var map: TileMapLayer = body.get_node(title)
        var size: Vector2i = map.tile_set.tile_size
        for cell: Vector2i in map.get_used_cells():
            var source: TileSetAtlasSource = map.tile_set.get_source(map.get_cell_source_id(cell))
            var region: Rect2i = source.get_tile_texture_region(map.get_cell_atlas_coords(cell))
            mask_image.blend_rect(source.texture.get_image(), region, cell * size + Vector2i(32, 0))
    var rim: Sprite2D = body.get_node("HoleSprite")
    mask_image.blend_rect(rim.texture.get_image(), Rect2i(rim.region_rect), Vector2i(rim.position) + Vector2i(32, 0))
    for child: Node in body.get_children():
        if child is CollisionPolygon2D:
            body.remove_child(child)
            child.free()
    var mask := BitMap.new()
    mask.create_from_image_alpha(mask_image, 0.5)
    var polygons := mask.opaque_to_polygons(Rect2i(0, 0, 128, 32), 0.0)
    for index: int in polygons.size():
        var solid := CollisionPolygon2D.new()
        solid.name = "SolidSilhouette" if index == 0 else "Solid%d" % index
        var polygon: PackedVector2Array = polygons[index]
        for point: int in polygon.size():
            polygon[point] -= Vector2(32, 0)
        solid.polygon = polygon
        own(body, solid)

func _initialize() -> void:
    build_cup()
    var catalog := CourseCatalog.new()
    var titles: Array[String] = ["Aiming and shooting", "Shot power", "Selecting a card", "Card replacement", "Elixir", "Card abilities", "Normal walls", "Sticky walls", "Ice", "Bouncy surfaces"]
    for index: int in 10:
        scene = GolfCourse.new()
        scene.name = "TutorialRoom"
        scene.camera_bounds = Rect2(-80, -104, 432, 248)
        var terrain := Node2D.new()
        terrain.name = "Terrain"
        own(scene, terrain)
        scene.start_marker = Marker2D.new()
        scene.start_marker.name = "StartMarker"
        scene.start_marker.position = Vector2(0, 69.9)
        own(scene, scene.start_marker)
        scene.void_boundary = Marker2D.new()
        scene.void_boundary.name = "VoidBoundary"
        scene.void_boundary.position.y = 136
        own(scene, scene.void_boundary)
        var target := Vector2(104, 72)
        if index == 1:
            target.x = 240
        elif index == 8:
            target.x = 232
        elif index == 9:
            target = Vector2(200, 24)
        cup(target)
        if index < 8:
            # The cup supplies the central 128px of terrain itself.
            platform("Start", Vector2(-48, 72), int((target.x - 16) / 8), 4)
            platform("FarBank", Vector2(target.x + 64, 72), 8, 4)
        match index:
            6:
                platform("BankWall", Vector2(184, -48), 2, 15)
                platform("Overhang", Vector2(48, 16), 10, 2)
            7:
                platform("StickyWall", Vector2(184, -32), 2, 13, "sticky")
            8:
                platform("Start", Vector2(-48, 72), 9, 4)
                platform("Ice", Vector2(24, 72), 18, 4, "ice")
                platform("FarBank", Vector2(target.x + 64, 72), 6, 4)
            9:
                scene.start_marker.position.y = 21.9
                platform("Start", Vector2(-48, 24), 8, 4)
                var spring: TerrainObject = platform("Spring", Vector2(48, 88), 15, 2, "bouncy")
                spring.surface = preload("res://resources/terrain/launch_spring.tres")
                platform("FarBank", Vector2(target.x + 64, 24), 6, 4)
        join_tiles()
        var packed := PackedScene.new()
        assert(packed.pack(scene) == OK)
        var path: String = "res://scenes/tutorial/lesson_%02d.tscn" % (index + 1)
        assert(ResourceSaver.save(packed, path) == OK)
        var definition := CourseDefinition.new()
        definition.id = StringName("tutorial_%d" % (index + 1))
        definition.title = titles[index]
        definition.scene = load(path)
        catalog.courses.append(definition)
        scene.free()
    assert(ResourceSaver.save(catalog, "res://resources/tutorial/courses.tres") == OK)
    print("Saved ten deterministic tutorial rooms.")
    quit()
