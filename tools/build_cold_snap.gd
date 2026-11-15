extends SceneTree
## Explicit offline authoring. Runtime uses only the saved, editable course.
## Re-running replaces Cold Snap; normal level edits belong in the scene.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var terrain_tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
var coast_tiles: TileSet = load("res://resources/terrain/coast_tileset.tres")
var frost_tiles: TileSet
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
    body.set("surface", load("res://resources/terrain/%s.tres" % ["normal", "sticky", "ice"][material]))
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

func build_frost_tiles() -> void:
    frost_tiles = TileSet.new()
    frost_tiles.tile_size = Vector2i(16, 16)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = load("res://art/cold_snap_scenery.svg")
    atlas.texture_region_size = Vector2i(16, 16)
    frost_tiles.add_source(atlas, 0)
    for x: int in 8:
        atlas.create_tile(Vector2i(x, 0))
    for x: int in 3:
        atlas.create_tile(Vector2i(x, 1))
    assert(ResourceSaver.save(frost_tiles, "res://resources/terrain/cold_snap_scenery.tres") == OK)
    frost_tiles = load("res://resources/terrain/cold_snap_scenery.tres")

func detail(parent: Node, title: String, tiles: TileSet, at: Vector2, uv: Vector2i, depth: int = 1) -> void:
    var map := layer(parent, title, tiles, depth)
    map.position = at
    map.set_cell(Vector2i.ZERO, 0, uv)

func decorations() -> void:
    var group := scene.get_node("Decorations")
    var sea := layer(group, "Sea", coast_tiles, -2)
    for y: int in range(14, 32):
        for x: int in range(-40, 48):
            var uv := Vector2i(0, posmod(x / 3, 2)) if y == 14 else Vector2i(posmod(x * 7 + y * 3, 8), mini(5, 2 + (y - 15) / 2))
            sea.set_cell(Vector2i(x, y), 0, uv)
    # Sparse scenery leaves every landing and material transition legible.
    detail(group, "StartPine", frost_tiles, Vector2(-136,128), Vector2i(0,0))
    detail(group, "CaveCrystals", frost_tiles, Vector2(-112,-8), Vector2i(1,0))
    detail(group, "SummitPine", frost_tiles, Vector2(24,-72), Vector2i(0,0))
    for x: int in [160]:
        detail(group, "RunwayIcicle%d" % x, frost_tiles, Vector2(x,152), Vector2i(2,0))
    for x: int in [240]:
        detail(group, "UpperIcicle%d" % x, frost_tiles, Vector2(x,24), Vector2i(2,0))
    for x: int in [112]:
        detail(group, "IceGlint%d" % x, frost_tiles, Vector2(x,127), Vector2i(4,0), 2)

    detail(group, "CupSnow", frost_tiles, Vector2(280,-128), Vector2i(3,0))
    detail(group, "EastCrystals", frost_tiles, Vector2(368,48), Vector2i(1,0))
    detail(group, "ReturnGlint200", frost_tiles, Vector2(200,-1), Vector2i(4,0), 2)
    var clouds := layer(group, "Clouds", coast_tiles, -4)
    for cell: Vector2i in [Vector2i(-5,-9),Vector2i(17,-10)]:
        clouds.set_cell(cell, 0, Vector2i(11,2))

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
    build_frost_tiles()
    scene = GolfCourse.new()
    scene.name = "Course"
    scene.camera_bounds = Rect2(-216,-208,656,480)
    for title: String in ["Terrain", "MovingPlatforms", "Decorations", "Hints", "Routes"]:
        var group := Node2D.new()
        group.name = title
        own(scene, group)
    # The west route has roomy, modest climbs and stationary resting points.
    platform("StartIsland", Vector2(-144,144),20,4)
    platform("WestLoop", Vector2(-192,72),12,4)
    platform("StickyStep", Vector2(-136,8),12,4,1)
    platform("UpperTerrace", Vector2(16,-56),16,4)
    # The east loop rewards momentum: each ice lane ends in a flush catch bank.
    platform("IceRunway", Vector2(64,128),20,3,2)
    platform("BrakeBank", Vector2(224,128),7,3,1)
    platform("EastTurn", Vector2(304,64),14,6)
    platform("ReturnIce", Vector2(176,0),18,3,2)
    platform("CenterBank", Vector2(120,0),7,3,1)
    # An exposed middle perch invites direct shots and airborne combinations.
    platform("CentralCut", Vector2(-8,72),10,3)
    # Misses can return to the route instead of always ending the attempt.
    platform("RecoveryBeach", Vector2(-48,184),30,2)
    platform("EastBeach", Vector2(272,176),18,3)
    platform("WestBreakwater", Vector2(-192,192),12,3)
    platform("WestCaveBack", Vector2(-192,104),2,11)
    platform("EastCaveBack", Vector2(400,112),2,8)
    # A small, ordinary-grip green supports a controlled final putt.
    platform("GoalApron", Vector2(152,-112),5,2)
    platform("GoalBackstop", Vector2(256,-112),8,2)
    platform("WestWall", Vector2(-216,-192),3,56)
    platform("EastWall", Vector2(416,-192),3,56)
    platform("Ceiling", Vector2(-216,-208),82,2)
    platform("Seabed", Vector2(-216,256),82,2)
    join_material_edges()
    scene.start_marker = Marker2D.new()
    scene.start_marker.name = "StartMarker"
    scene.start_marker.position = Vector2(-64,141.9)
    own(scene, scene.start_marker)
    scene.goal_cup = load("res://scenes/levels/goal_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    scene.goal_cup.position = Vector2(192,-112)
    own(scene, scene.goal_cup)
    scene.void_boundary = Marker2D.new()
    scene.void_boundary.name = "VoidBoundary"
    scene.void_boundary.position.y = 227
    scene.void_detects_ball_edge = true
    own(scene, scene.void_boundary)
    scene.get_node("Hints").hide()
    route("Safe", ["StartIsland","WestLoop","StickyStep","UpperTerrace","GoalCup"])
    route("Alternate", ["StartIsland","BrakeBank","EastTurn","CenterBank","UpperTerrace","GoalCup"])
    decorations()
    var packed := PackedScene.new()
    assert(packed.pack(scene) == OK)
    var check := packed.instantiate()
    assert(check.get_node("Terrain/IceRunway/Tiles").has_method("rebuild_solid"))
    assert(check.get_node("Terrain/EastWall/SolidSilhouette") != null)
    assert(check.get_node("Decorations/Sea").get_used_cells().size() > 1000)
    check.free()
    assert(ResourceSaver.save(packed, "res://scenes/levels/cold_snap.tscn") == OK)
    scene.free()
    print("Saved Cold Snap: sheltered west climb, ice/catch-bank loop, recovery beaches and frost scenery.")
    quit()
