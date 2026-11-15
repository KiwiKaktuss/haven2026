extends SceneTree
## Explicit offline authoring. Runtime uses only the saved, editable course.
## Re-running replaces Final Ascent; normal level edits belong in the scene.
const EditableTiles = preload("res://scripts/terrain/editable_terrain_tiles.gd")
var terrain_tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
var coast_tiles: TileSet = load("res://resources/terrain/coast_tileset.tres")
var works_tiles: TileSet = load("res://resources/terrain/spring_works_scenery.tres")
var frost_tiles: TileSet = load("res://resources/terrain/cold_snap_scenery.tres")
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
    for y: int in range(17, 38):
        for x: int in range(-40, 48):
            var uv := Vector2i(0, posmod(x / 3, 2)) if y == 17 else Vector2i(posmod(x * 7 + y * 3, 8), mini(5, 2 + (y - 18) / 2))
            sea.set_cell(Vector2i(x,y),0,uv)
    # Garden -> ice harbour -> workshop -> summit. Details never add collision.
    detail("TeeFlowers",Vector2(-152,168),Vector2i(3,0))
    detail("ForkSign",Vector2(-32,168),Vector2i(5,0))
    detail("WestGardenFlowers",Vector2(-224,96),Vector2i(3,0))
    detail("WestGardenPine",Vector2(-184,24),Vector2i(0,0),1,frost_tiles)
    detail("WestVine",Vector2(-128,64),Vector2i(12,0),1,coast_tiles)
    detail("IceGlint",Vector2(200,151),Vector2i(4,0),2,frost_tiles)
    detail("IceIcicles",Vector2(192,176),Vector2i(2,0),1,frost_tiles)
    detail("CatchCrystals",Vector2(248,136),Vector2i(1,0),1,frost_tiles)
    detail("SpringSign",Vector2(48,48),Vector2i(4,0))
    detail("LaunchDockFlowers",Vector2(112,48),Vector2i(3,0))
    detail("EastGalleryCrate",Vector2(440,64),Vector2i(6,0))
    detail("EastGalleryVine",Vector2(352,128),Vector2i(12,0),1,coast_tiles)
    detail("ReturnSign",Vector2(224,-8),Vector2i(5,0))
    detail("ReturnFlowers",Vector2(304,-8),Vector2i(3,0))
    detail("UpperGarden",Vector2(-16,-72),Vector2i(3,0))
    detail("CrownSnow",Vector2(280,-144),Vector2i(3,0),1,frost_tiles)
    detail("CrownPine",Vector2(176,-144),Vector2i(0,0),1,frost_tiles)
    detail("CupFlowers",Vector2(96,-208),Vector2i(3,0))
    detail("CupPennant",Vector2(-32,-208),Vector2i(2,0))
    detail("BeachReeds",Vector2(360,200),Vector2i(11,0),1,coast_tiles)
    detail("RecoveryCrate",Vector2(32,224),Vector2i(6,0))
    detail("WestShore",Vector2(-216,224),Vector2i(13,0),1,coast_tiles)
    # Guide rails communicate the complete optional platform travel.
    var guide := layer(group,"LiftGuide",works_tiles,-1)
    guide.position = Vector2(416,-32)
    for y: int in 6:
        guide.set_cell(Vector2i(0,y),0,Vector2i(0,1))
    detail("LiftUpperPulley",Vector2(416,-48),Vector2i(0,0),-1)
    detail("LiftLowerPulley",Vector2(416,56),Vector2i(0,0),-1)
    var track := layer(group,"ShuttleGuide",works_tiles,-1)
    track.position = Vector2(-176,-128)
    for x: int in 10:
        track.set_cell(Vector2i(x,0),0,Vector2i(1,1))
    detail("ShuttleWestPulley",Vector2(-192,-132),Vector2i(0,0),-1)
    detail("ShuttleEastPulley",Vector2(-16,-132),Vector2i(0,0),-1)
    # A small beacon gives the summit a recognizable silhouette.
    var beacon_tiles: TileSet = load("res://resources/terrain/final_ascent_scenery.tres")
    var beacon := layer(group,"SummitBeacon",beacon_tiles,-1)
    beacon.position = Vector2(264,-176)
    for y: int in 3:
        for x: int in 2:
            beacon.set_cell(Vector2i(x,y),0,Vector2i(x,y))
    var distant := layer(group,"DistantSeaStacks",coast_tiles,-4)
    for cell: Vector2i in [Vector2i(-11,-12),Vector2i(24,-13)]:
        distant.set_cell(cell,0,Vector2i(11,2))
    detail("HighCloud",Vector2(80,-248),Vector2i(11,2),-4,coast_tiles)
    detail("WestCloud",Vector2(-176,-208),Vector2i(11,2),-4,coast_tiles)
    detail("EastCloud",Vector2(384,-192),Vector2i(11,2),-4,coast_tiles)

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
    scene = GolfCourse.new()
    scene.name = "Course"
    scene.camera_bounds = Rect2(-256,-272,752,592)
    for title: String in ["Terrain","MovingPlatforms","Decorations","Hints","Routes"]:
        var group := Node2D.new()
        group.name = title
        own(scene,group)
    # Longer east switchbacks and a steeper west garden meet at the upper fork.
    # Every baseline resting place has ordinary grip and room to change cards.
    platform("StartIsland",Vector2(-168,184),22,4)
    platform("LowerLanding",Vector2(48,152),16,3)
    platform("EastGallery",Vector2(336,88),18,5)
    platform("ReturnGallery",Vector2(192,16),18,4)
    platform("UpperTerrace",Vector2(-32,-56),18,4)
    platform("CrownTerrace",Vector2(160,-128),18,4)
    platform("WestTerrace",Vector2(-232,112),16,4)
    platform("WestGarden",Vector2(-200,40),15,3)
    # Optional momentum line: ice feeds a flush sticky bank beside the east loop.
    platform("IceRunway",Vector2(176,152),8,3,2)
    platform("BrakeBank",Vector2(240,152),6,3,1)
    # Two spring/dock pairs make aimed combinations possible without forcing one.
    platform("LaunchSpring",Vector2(32,64),8,2,3)
    scene.get_node("Terrain/LaunchSpring").set("surface",load("res://resources/terrain/launch_spring.tres"))
    platform("LaunchDock",Vector2(96,64),6,2)
    platform("CrownSpring",Vector2(112,-56),6,3,3)
    # Missed climbs can fall back onto earlier terrain or the sheltered beaches.
    platform("RecoveryBeach",Vector2(-64,240),34,2)
    platform("RecoverySpring",Vector2(208,240),5,2,3)
    platform("EastBeach",Vector2(264,216),24,3)
    platform("WestBreakwater",Vector2(-232,240),12,3)
    platform("WestCaveBack",Vector2(-232,144),2,12)
    platform("EastCaveBack",Vector2(464,128),2,11)
    # A generous normal-grip finishing apron protects the recessed cup.
    platform("GoalApron",Vector2(-48,-192),6,2)
    platform("GoalBackstop",Vector2(64,-192),12,2)
    platform("WestWall",Vector2(-256,-256),3,70)
    platform("EastWall",Vector2(480,-256),2,70)
    platform("Ceiling",Vector2(-256,-272),94,2)
    platform("Seabed",Vector2(-256,304),94,2)
    join_material_edges()
    # Entire sweeps stay out of all stationary solids. Neither ride is required.
    mover("SummitLift",Vector2(400,56),Vector2(0,-88),6.5,7)
    mover("SkyShuttle",Vector2(-176,-128),Vector2(96,0),7.0,7)
    scene.start_marker = Marker2D.new()
    scene.start_marker.name = "StartMarker"
    scene.start_marker.position = Vector2(-80,181.9)
    own(scene,scene.start_marker)
    scene.goal_cup = load("res://scenes/levels/goal_cup.tscn").instantiate()
    scene.goal_cup.name = "GoalCup"
    scene.goal_cup.position = Vector2(0,-192)
    own(scene,scene.goal_cup)
    scene.void_boundary = Marker2D.new()
    scene.void_boundary.name = "VoidBoundary"
    scene.void_boundary.position.y = 275
    scene.void_detects_ball_edge = true
    own(scene,scene.void_boundary)
    scene.get_node("Hints").hide()
    route("Safe",["StartIsland","LowerLanding","EastGallery","ReturnGallery","UpperTerrace","CrownTerrace","GoalCup"])
    route("Alternate",["StartIsland","WestTerrace","WestGarden","UpperTerrace","CrownTerrace","GoalCup"])
    decorations()
    var packed := PackedScene.new()
    assert(packed.pack(scene) == OK)
    var check := packed.instantiate()
    assert(check.get_node("Terrain/IceRunway/Tiles").has_method("rebuild_solid"))
    assert(check.get_node("Terrain/EastWall/SolidSilhouette") != null)
    assert(check.get_node("Decorations/Sea").get_used_cells().size() > 1000)
    check.free()
    assert(ResourceSaver.save(packed,"res://scenes/levels/final_ascent.tscn") == OK)
    scene.free()
    print("Saved Final Ascent: two summit routes, ice harbour, spring combinations, optional rides and coastal recovery.")
    quit()
