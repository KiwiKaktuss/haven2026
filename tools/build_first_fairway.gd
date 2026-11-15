extends SceneTree
## Explicit offline authoring tool. The saved scene is the editable source of truth.
## Re-running intentionally replaces First Fairway; never called during play.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var terrain_tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
var coast_tiles: TileSet
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

func tile_for(x: int, y: int, w: int, h: int) -> Vector2i:
    if w == 1 and h == 1: return Vector2i(4, 4)
    if h == 1: return Vector2i(0, 1) if x == 0 else (Vector2i(2, 1) if x == w - 1 else Vector2i(0, 2))
    if w == 1: return Vector2i(1, 0) if y == 0 else (Vector2i(1, 2) if y == h - 1 else Vector2i(0, 3))
    if y == 0: return Vector2i(2, 2) if x == 0 else (Vector2i(3, 2) if x == w - 1 else Vector2i(2, 4))
    if y == h - 1: return Vector2i(2, 3) if x == 0 else (Vector2i(3, 3) if x == w - 1 else Vector2i(3, 4))
    return Vector2i(0, 4) if x == 0 else (Vector2i(1, 4) if x == w - 1 else Vector2i(4, 1))

func platform(title: String, at: Vector2, w: int, h: int) -> PhysicsBody2D:
    var body := StaticBody2D.new()
    body.set_script(load("res://scripts/terrain/terrain_object.gd"))
    body.name = title
    body.position = at
    body.set("object_id", StringName(title.to_snake_case()))
    body.set("surface", load("res://resources/terrain/normal.tres"))
    body.collision_mask = 0
    own(scene.get_node("Terrain"), body)
    var map := layer(body, "Tiles", terrain_tiles)
    map.set_script(EditableTiles)
    for y: int in h:
        for x: int in w:
            var uv := tile_for(x, y, w, h)
            map.set_cell(Vector2i(x, y), 1 if uv == Vector2i(4,1) else 0, Vector2i.ZERO if uv == Vector2i(4,1) else uv)
    map.rebuild_solid()
    return body

func build_coast_tiles() -> void:
    coast_tiles = TileSet.new()
    coast_tiles.tile_size = Vector2i(16, 16)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = load("res://art/coast_tiles.svg")
    atlas.texture_region_size = Vector2i(16, 16)
    coast_tiles.add_source(atlas, 0)
    for row: int in 2:
        var uv := Vector2i(0, row)
        atlas.create_tile(uv)
        atlas.set_tile_animation_columns(uv, 4)
        atlas.set_tile_animation_frames_count(uv, 4)
        atlas.set_tile_animation_speed(uv, 3.0)
    for y: int in range(2, 6):
        for x: int in 8:
            atlas.create_tile(Vector2i(x, y))
    for x: int in range(8, 16):
        atlas.create_tile(Vector2i(x, 0))
    for x: int in range(8, 11):
        atlas.create_tile(Vector2i(x, 2))
        atlas.create_tile(Vector2i(x, 3))
    for x: int in [11, 12]: atlas.create_tile(Vector2i(x, 2))
    assert(ResourceSaver.save(coast_tiles, "res://resources/terrain/coast_tileset.tres") == OK)

func decorations() -> void:
    var group := scene.get_node("Decorations")
    var sea := layer(group, "Sea", coast_tiles, -2)
    sea.position.y = 32
    # The first foam pixels begin at y=211; VoidBoundary matches that surface.
    for y: int in range(11, 32):
        for x: int in range(-40, 48):
            var band: int = 0 if y == 11 else mini(5, 2 + (y - 12) / 2)
            sea.set_cell(Vector2i(x, y), 0, Vector2i(0, posmod(x / 3, 2)) if y == 11 else Vector2i(posmod(x * 7 + y * 3, 8), band))
    var grass := layer(group, "GrassAndFlowers", coast_tiles, 2)
    for cell: Vector2i in [Vector2i(-6,7),Vector2i(20,3),Vector2i(2,-4)]:
        grass.set_cell(cell,0,Vector2i(8,0))
    grass.set_cell(Vector2i(6,-4),0,Vector2i(9,0))
    var vines := layer(group, "HangingVines", coast_tiles, 1)
    vines.set_cell(Vector2i(10,2),0,Vector2i(12,0))

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
    preload("res://tools/build_terrain_atlas.gd").add_full_tiles(terrain_tiles)
    assert(ResourceSaver.save(terrain_tiles, "res://resources/terrain/terrain_tileset.tres") == OK)
    build_coast_tiles()
    scene = GolfCourse.new()
    scene.name = "Course"
    scene.camera_bounds = Rect2(-184, -160, 592, 416)
    for title: String in ["Terrain", "MovingPlatforms", "Decorations", "Hints", "Routes"]:
        var group := Node2D.new()
        group.name = title
        own(scene, group)
    # Wide ordinary-surface landings and modest climbs require no special card.
    platform("StartIsland", Vector2(-112,128), 20, 4)
    platform("EastBank", Vector2(72,112), 17, 3)
    platform("EastTurn", Vector2(248,64), 17, 5)
    platform("ReturnShelf", Vector2(152,8), 14, 3)
    platform("UpperBridge", Vector2(16,-48), 14, 3)
    platform("WestRise", Vector2(-160,64), 15, 4)
    platform("WestTurn", Vector2(-128,0), 10, 3)
    # Two open cave mouths beneath the ledges; recovery shelves above the sea.
    platform("RecoveryBeach", Vector2(64,152), 20, 2)
    platform("EastBeach", Vector2(240,128), 18, 3)
    platform("WestBreakwater", Vector2(-160,176), 9, 3)
    platform("EastBreakwater", Vector2(352,176), 4, 3)
    platform("WestCaveBack", Vector2(-160,96), 2, 10)
    platform("EastCaveBack", Vector2(352,104), 4, 3)
    platform("BeachArchPillar", Vector2(176,136), 2, 2)
    # A complete enclosing frame, with a seabed below the defeat line.
    platform("WestWall", Vector2(-184,-144), 3, 49)
    platform("EastWall", Vector2(384,-144), 3, 49)
    platform("Ceiling", Vector2(-184,-160), 74, 2)
    platform("Seabed", Vector2(-184,240), 74, 2)
    preload("res://tools/join_fairway_terrain.gd").join_edges(scene)
    scene.start_marker = Marker2D.new()
    scene.start_marker.name = "StartMarker"
    scene.start_marker.position = Vector2(-32,125.9)
    own(scene, scene.start_marker)
    scene.goal_cup = load("res://scenes/levels/goal_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    scene.goal_cup.position = Vector2(152,-88)
    own(scene, scene.goal_cup)
    scene.void_boundary = Marker2D.new()
    scene.void_boundary.name = "VoidBoundary"
    scene.void_boundary.position.y = 211
    scene.void_detects_ball_edge = true
    own(scene, scene.void_boundary)
    scene.get_node("Hints").hide()
    route("Safe", ["StartIsland","EastBank","EastTurn","ReturnShelf","UpperBridge","GoalCup"])
    route("Alternate", ["StartIsland","WestRise","WestTurn","UpperBridge","GoalCup"])
    decorations()
    var packed := PackedScene.new()
    assert(packed.pack(scene) == OK)
    var check := packed.instantiate()
    assert(check.get_node("Decorations/Sea").get_used_cells().size() > 1000)
    assert(check.get_node("Terrain/EastWall/SolidSilhouette") != null)
    check.free()
    assert(ResourceSaver.save(packed, "res://scenes/levels/first_fairway.tscn") == OK)
    scene.free()
    print("Saved First Fairway: coastal routes, editable solids, sea and scenery tile layers.")
    quit()
