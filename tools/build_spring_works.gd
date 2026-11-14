extends SceneTree
## Explicit offline authoring. Runtime uses only the saved, editable course.
## Re-running replaces Spring Works; normal level edits belong in the scene.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var terrain_tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
var coast_tiles: TileSet = load("res://resources/terrain/coast_tileset.tres")
var works_tiles: TileSet
var scene: GolfCourse

func own(parent: Node, child: Node) -> void:
    parent.add_child(child)
    child.owner = scene

func layer(parent: Node, title: String, tiles: TileSet, depth: int = 0) -> TileMapLayer:
    var map := TileMapLayer.new()
    map.name = title
    map.tile_set = tiles
    map.collision_enabled = false
    map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    map.z_index = depth
    own(parent, map)
    return map

func platform(title: String, at: Vector2, w: int, h: int, material: int = 0) -> void:
    var body := StaticBody2D.new()
    body.set_script(load("res://scripts/terrain/terrain_object.gd"))
    body.name = title
    body.position = at
    body.set("object_id", StringName(title.to_snake_case()))
    body.set("surface", load("res://resources/terrain/%s.tres" % ["normal", "sticky", "ice", "bouncy"][material]))
    body.collision_mask = 0
    own(scene.get_node("Terrain"), body)
    var map := layer(body, "Tiles", terrain_tiles)
    map.set_script(EditableTiles)
    for y: int in h:
        for x: int in w:
            map.set_cell(Vector2i(x, y), 1, Vector2i(material % 2, material / 2))

func join_material_edges() -> void:
    # Adjacent ice/sticky banks meet flush, but retain their own material/ID.
    var occupied: Dictionary = {}
    for body: Node2D in scene.get_node("Terrain").get_children():
        var offset := Vector2i(body.position / 8)
        for cell: Vector2i in body.get_node("Tiles").get_used_cells():
            occupied[cell + offset] = true
    for body: TerrainObject in scene.get_node("Terrain").get_children():
        var map: TileMapLayer = body.get_node("Tiles")
        var material: int = body.surface.material
        var offset := Vector2i(body.position / 8)
        for cell: Vector2i in map.get_used_cells():
            var at := cell + offset
            var left := not occupied.has(at + Vector2i.LEFT)
            var right := not occupied.has(at + Vector2i.RIGHT)
            var top := not occupied.has(at + Vector2i.UP)
            var bottom := not occupied.has(at + Vector2i.DOWN)
            var uv := Vector2i(4, 1)
            if top:
                uv = Vector2i(2, 2) if left else (Vector2i(3, 2) if right else Vector2i(2, 4))
            elif bottom:
                uv = Vector2i(2, 3) if left else (Vector2i(3, 3) if right else Vector2i(3, 4))
            elif left:
                uv = Vector2i(0, 4)
            elif right:
                uv = Vector2i(1, 4)
            if uv == Vector2i(4, 1):
                map.set_cell(cell, 1, Vector2i(material % 2, material / 2))
            else:
                map.set_cell(cell, 0, uv + Vector2i(0, material * 5))
        map.rebuild_solid()

func build_works_tiles() -> void:
    works_tiles = TileSet.new()
    works_tiles.tile_size = Vector2i(16, 16)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = load("res://art/spring_works_scenery.svg")
    atlas.texture_region_size = Vector2i(16, 16)
    works_tiles.add_source(atlas, 0)
    for y: int in 3:
        for x: int in 8:
            atlas.create_tile(Vector2i(x, y))
    assert(ResourceSaver.save(works_tiles, "res://resources/terrain/spring_works_scenery.tres") == OK)
    works_tiles = load("res://resources/terrain/spring_works_scenery.tres")

func detail(title: String, at: Vector2, uv: Vector2i, depth: int = 1, tiles: TileSet = null) -> void:
    var map := layer(scene.get_node("Decorations"), title, works_tiles if tiles == null else tiles, depth)
    map.position = at
    map.set_cell(Vector2i.ZERO, 0, uv)

func mover(title: String, at: Vector2, end: Vector2, period: float, width: int) -> void:
    var body := AnimatableBody2D.new()
    body.set_script(load("res://scripts/terrain/moving_platform.gd"))
    body.name = title
    body.position = at
    body.process_physics_priority = -100
    body.collision_mask = 0
    body.set("object_id", StringName(title.to_snake_case()))
    body.set("surface", load("res://resources/terrain/normal.tres"))
    body.set("endpoint_b", end)
    body.set("period_seconds", period)
    own(scene.get_node("MovingPlatforms"), body)
    var map := layer(body, "Tiles", terrain_tiles)
    map.set_script(EditableTiles)
    for x: int in width:
        map.set_cell(Vector2i(x,0), 0, Vector2i(0,1) if x == 0 else (Vector2i(2,1) if x == width-1 else Vector2i(0,2)))
    map.rebuild_solid()

func decorations() -> void:
    var group := scene.get_node("Decorations")
    var sea := layer(group, "Sea", coast_tiles, -2)
    for y: int in range(15, 34):
        for x: int in range(-40, 48):
            var uv := Vector2i(0, posmod(x / 3, 2)) if y == 15 else Vector2i(posmod(x * 7 + y * 3, 8), mini(5, 2 + (y - 16) / 2))
            sea.set_cell(Vector2i(x, y), 0, uv)
    # Workshop details sit behind the playable surfaces; landings stay clear.
    var guide := layer(group, "LiftGuide", works_tiles, -1)
    guide.position = Vector2(240,80)
    for y: int in 5:
        guide.set_cell(Vector2i(0,y),0,Vector2i(0,1))
    var track := layer(group, "ShuttleGuide", works_tiles, -1)
    track.position = Vector2(-160,-112)
    for x: int in 9:
        track.set_cell(Vector2i(x,0),0,Vector2i(1,1))
    detail("LiftTopPulley",Vector2(240,64),Vector2i(0,0),-1)
    detail("LiftBasePulley",Vector2(240,144),Vector2i(0,0),-1)
    detail("ShuttleWestPulley",Vector2(-176,-116),Vector2i(0,0),-1)
    detail("ShuttleEastPulley",Vector2(-24,-116),Vector2i(0,0),-1)
    detail("StartFlowers",Vector2(-144,136),Vector2i(3,0))
    detail("ForkSign",Vector2(-48,136),Vector2i(5,0))
    detail("WestFlowers",Vector2(-192,48),Vector2i(3,0))
    detail("WestCog",Vector2(-160,88),Vector2i(0,0),1)
    detail("LaunchArrows",Vector2(56,48),Vector2i(4,0))
    detail("LaunchDockCrate",Vector2(128,48),Vector2i(6,0))
    detail("EastCog",Vector2(344,96),Vector2i(0,0))
    detail("ReturnFlowers",Vector2(272,-32),Vector2i(3,0))
    detail("ReturnSign",Vector2(184,-32),Vector2i(5,0))
    detail("SummitFlowers",Vector2(24,-96),Vector2i(3,0))
    detail("CupFlowers",Vector2(288,-160),Vector2i(3,0))
    detail("BeachCrate",Vector2(64,192),Vector2i(6,0))
    detail("BeachReeds",Vector2(368,160),Vector2i(11,0),1,coast_tiles)
    detail("WestVine",Vector2(-120,16),Vector2i(12,0),1,coast_tiles)
    detail("GalleryVine",Vector2(200,16),Vector2i(12,0),1,coast_tiles)
    var distant := layer(group, "DistantWorkshop", works_tiles, -4)
    for cell: Vector2i in [Vector2i(-10,-9),Vector2i(23,-10),Vector2i(4,-12)]:
        distant.set_cell(cell,0,Vector2i(0,2))
        distant.set_cell(cell+Vector2i.DOWN,0,Vector2i(1,2))
    detail("WestCloud",Vector2(-160,-176),Vector2i(11,2),-4,coast_tiles)
    detail("EastCloud",Vector2(336,-176),Vector2i(11,2),-4,coast_tiles)

func route(title: String, stops: Array[String]) -> void:
    var path := Node2D.new()
    path.name = title
    own(scene.get_node("Routes"), path)
    for i: int in stops.size():
        var marker := Marker2D.new()
        marker.name = "Stop%02d" % i
        var support: Node2D = scene.goal_cup if stops[i] == "GoalCup" else scene.get_node("Terrain/" + stops[i])
        marker.position = support.position + Vector2(24, -2.1)
        marker.set_meta("support", stops[i])
        own(path, marker)

func _initialize() -> void:
    build_works_tiles()
    scene = GolfCourse.new()
    scene.name = "Course"
    scene.camera_bounds = Rect2(-232,-224,704,512)
    for title: String in ["Terrain", "MovingPlatforms", "Decorations", "Hints", "Routes"]:
        var group := Node2D.new()
        group.name = title
        own(scene, group)
    # A generous five-climb east loop has stationary, ordinary-grip landings.
    platform("StartIsland",Vector2(-160,152),22,4)
    platform("LowerLanding",Vector2(64,120),16,4)
    platform("EastGallery",Vector2(296,56),19,5)
    platform("ReturnGallery",Vector2(160,-16),18,4)
    platform("UpperTerrace",Vector2(-24,-80),20,4)
    # Short west route: players can choose fewer, taller climbs.
    platform("WestGallery",Vector2(-208,64),16,4)
    platform("WestPerch",Vector2(-168,-8),13,3)
    # Springs invite bank shots/airborne combinations, with a stable dock beside
    # the central pad. Bounce is useful without being mandatory for any deck.
    platform("LaunchSpring",Vector2(40,64),8,2,3)
    scene.get_node("Terrain/LaunchSpring").set("surface",load("res://resources/terrain/launch_spring.tres"))
    platform("LaunchDock",Vector2(104,64),6,2)
    platform("UpperSpring",Vector2(64,-16),8,2,3)
    platform("WestSpring",Vector2(-64,-8),4,3,3)
    # Missed gaps have a second chance above the water; the east spring can
    # return a falling ball to EastBeach without spending a card.
    platform("RecoveryBeach",Vector2(-40,208),31,2)
    platform("RecoverySpring",Vector2(208,208),5,2,3)
    platform("EastBeach",Vector2(248,176),21,3)
    platform("WestBreakwater",Vector2(-208,208),11,3)
    platform("WestCaveBack",Vector2(-208,96),2,14)
    platform("EastCaveBack",Vector2(432,96),2,10)
    platform("GoalApron",Vector2(144,-144),5,2)
    platform("GoalBackstop",Vector2(248,-144),10,2)
    platform("WestWall",Vector2(-232,-208),3,60)
    platform("EastWall",Vector2(448,-208),3,60)
    platform("Ceiling",Vector2(-232,-224),88,2)
    platform("Seabed",Vector2(-232,272),88,2)
    join_material_edges()
    # Full sweeps are clear of static geometry. Both stationary routes remain
    # possible regardless of phase, while riders can skip entire climbs.
    mover("Lift",Vector2(216,144),Vector2(0,-64),6.5,8)
    mover("Shuttle",Vector2(-176,-112),Vector2(120,0),6.5,7)
    scene.start_marker = Marker2D.new()
    scene.start_marker.name = "StartMarker"
    scene.start_marker.position = Vector2(-72,149.9)
    own(scene, scene.start_marker)
    scene.goal_cup = load("res://scenes/levels/goal_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    scene.goal_cup.position = Vector2(184,-144)
    own(scene, scene.goal_cup)
    scene.void_boundary = Marker2D.new()
    scene.void_boundary.name = "VoidBoundary"
    scene.void_boundary.position.y = 243
    scene.void_detects_ball_edge = true
    own(scene, scene.void_boundary)
    scene.get_node("Hints").hide()
    route("Safe",["StartIsland","LowerLanding","EastGallery","ReturnGallery","UpperTerrace","GoalCup"])
    route("Alternate",["StartIsland","WestGallery","WestPerch","UpperTerrace","GoalCup"])
    decorations()
    var packed := PackedScene.new()
    assert(packed.pack(scene) == OK)
    var check := packed.instantiate()
    assert(check.get_node("Terrain/RecoverySpring/Tiles").has_method("rebuild_solid"))
    assert(check.get_node("MovingPlatforms/Lift/SolidSilhouette") != null)
    assert(check.get_node("Decorations/Sea").get_used_cells().size() > 1000)
    check.free()
    assert(ResourceSaver.save(packed,"res://scenes/levels/spring_works.tscn") == OK)
    scene.free()
    print("Saved Spring Works: coastal workshop, two roomy routes, spring shortcuts, recovery and movers.")
    quit()
