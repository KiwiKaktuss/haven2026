extends SceneTree
## Offline authoring only: ten small, saved, editor-paintable practice rooms.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var scene: GolfCourse
var tiles: TileSet = preload("res://resources/terrain/terrain_tileset.tres")

func own(parent: Node, child: Node) -> void:
    parent.add_child(child)
    child.owner = scene

func platform(title: String, at: Vector2, w: int, h: int, material: String = "normal", moving: bool = false) -> TerrainObject:
    var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
    body.set_script(load("res://scripts/terrain/moving_platform.gd" if moving else "res://scripts/terrain/terrain_object.gd"))
    body.name = title
    body.position = at
    body.set("object_id", StringName(title.to_snake_case()))
    body.set("surface", load("res://resources/terrain/%s.tres" % material))
    body.collision_mask = 0
    if moving:
        body.process_physics_priority = -100
    own(scene.get_node("Terrain"), body)
    var map := TileMapLayer.new()
    map.name = "Tiles"
    map.tile_set = tiles
    map.collision_enabled = false
    map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    map.set_script(EditableTiles)
    own(body, map)
    var band: int = ["normal", "sticky", "ice", "bouncy"].find(material) * 5
    for y: int in h:
        for x: int in w:
            var uv := Vector2i(4, band) if y == 0 else Vector2i(4, band + 1)
            map.set_cell(Vector2i(x, y), 0, uv)
    map.rebuild_solid()
    return body as TerrainObject

func cup(at: Vector2) -> void:
    scene.goal_cup = preload("res://scenes/tutorial/tutorial_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    # Twice the opening width plus a broad landing field; still a physical hole.
    scene.goal_cup.scale.x = 2.0
    scene.goal_cup.position = at - Vector2(64, 0)
    scene.goal_cup.pull_radius = 36.0
    own(scene, scene.goal_cup)

func _initialize() -> void:
    var catalog := CourseCatalog.new()
    var titles: Array[String] = ["Aiming and shooting", "Shot power", "Selecting a card", "Card replacement", "Elixir", "Normal walls", "Sticky walls", "Ice", "Bouncy surfaces", "Moving platforms"]
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
        elif index == 7:
            target.x = 232
        elif index == 8:
            target = Vector2(200, 24)
        elif index == 9:
            target = Vector2(272, 56)
        cup(target)
        if index < 7:
            # The cup supplies the central 128px of terrain itself.
            platform("Start", Vector2(-48, 72), int((target.x - 16) / 8), 4)
            platform("FarBank", Vector2(target.x + 64, 72), 8, 4)
        match index:
            5:
                platform("BankWall", Vector2(184, -48), 2, 15)
                platform("Overhang", Vector2(48, 16), 10, 2)
            6:
                platform("StickyWall", Vector2(184, -32), 2, 13, "sticky")
            7:
                platform("Start", Vector2(-48, 72), 9, 4)
                platform("Ice", Vector2(24, 72), 18, 4, "ice")
                platform("FarBank", Vector2(target.x + 64, 72), 6, 4)
            8:
                scene.start_marker.position.y = 21.9
                platform("Start", Vector2(-48, 24), 8, 4)
                var spring: TerrainObject = platform("Spring", Vector2(48, 88), 15, 2, "bouncy")
                spring.surface = preload("res://resources/terrain/launch_spring.tres")
                platform("FarBank", Vector2(target.x + 64, 24), 6, 4)
            9:
                platform("Start", Vector2(-48, 72), 12, 4)
                var mover := platform("Ride", Vector2(64, 72), 12, 2, "normal", true) as MovingPlatform
                mover.endpoint_b = Vector2(88, 0)
                mover.period_seconds = 10.0
                platform("FarBank", Vector2(target.x + 64, 56), 2, 4)
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
