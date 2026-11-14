extends SceneTree
## Offline authoring utility. Saved scenes remain the source of truth afterward.
func _initialize() -> void:
    var tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
    var source: TileSetAtlasSource = tiles.get_source(0)
    var image: Image = source.texture.get_image()
    for material_index: int in range(4):
        var solid := Vector2i.ZERO
        var found: bool = false
        for row: int in range(material_index * 5, material_index * 5 + 5):
            for column: int in range(12):
                var full: bool = true
                for y: int in range(8):
                    for x: int in range(8):
                        if image.get_pixel(column * 8 + x, row * 8 + y).a < 0.5:
                            full = false
                if full and not found:
                    solid = Vector2i(column, row)
                    found = true
        print("Solid tile for band ", material_index, ": ", solid)
    _build(false, tiles)
    _build(true, tiles)
    _build_lab()
    quit()

func _build(moving: bool, tiles: TileSet) -> void:
    var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
    body.name = "MovingPlatform" if moving else "TerrainObject"
    body.set_script(load("res://scripts/terrain/moving_platform.gd" if moving else "res://scripts/terrain/terrain_object.gd"))
    body.set("object_id", &"platform" if moving else &"island")
    body.set("surface", load("res://resources/terrain/normal.tres"))
    body.collision_layer = 1
    body.collision_mask = 0
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if moving:
        body.set("sync_to_physics", true)
        body.process_physics_priority = -100
    var visual := TileMapLayer.new()
    visual.name = "Tiles"
    visual.tile_set = tiles
    visual.collision_enabled = false
    # (4, 0) is a solid atlas tile; visual and solid rectangles share bounds.
    for column: int in range(8):
        visual.set_cell(Vector2i(column, 0), 0, Vector2i(4, 0))
    body.add_child(visual)
    visual.owner = body
    var shape := CollisionPolygon2D.new()
    shape.name = "SolidSilhouette"
    shape.polygon = PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 8), Vector2(0, 8)])
    body.add_child(shape)
    shape.owner = body
    var scene := PackedScene.new()
    scene.pack(body)
    var path: String = "res://scenes/terrain/moving_platform.tscn" if moving else "res://scenes/terrain/terrain_object.tscn"
    var error: Error = ResourceSaver.save(scene, path)
    if error != OK:
        push_error("Component save failed: " + str(error))
    body.free()

func _owned(parent: Node, child: Node, scene: Node) -> void:
    parent.add_child(child)
    child.owner = scene

func _build_lab() -> void:
    var lab := Node2D.new()
    lab.name = "PhysicsLab"
    lab.set_script(load("res://scripts/game/physics_lab.gd"))
    var terrain := Node2D.new()
    terrain.name = "Terrain"
    _owned(lab, terrain, lab)
    var movers := Node2D.new()
    movers.name = "MovingPlatforms"
    _owned(lab, movers, lab)
    var balls := Node2D.new()
    balls.name = "Balls"
    _owned(lab, balls, lab)
    var terrain_scene: PackedScene = load("res://scenes/terrain/terrain_object.tscn")
    var moving_scene: PackedScene = load("res://scenes/terrain/moving_platform.tscn")
    var ball_scene: PackedScene = load("res://scenes/ball/ball.tscn")
    var names: Array[String] = ["Normal", "Ice", "Sticky", "Bouncy", "Horizontal", "Vertical", "Slope", "Wall", "Ceiling", "Thin"]
    var positions: Array[Vector2] = [Vector2(24, 80), Vector2(136, 80), Vector2(248, 80), Vector2(360, 80), Vector2(24, 204), Vector2(136, 204), Vector2(248, 260), Vector2(432, 144), Vector2(336, 144), Vector2(448, 240)]
    var surfaces: Array[String] = ["normal", "ice", "sticky", "bouncy", "normal", "sticky", "normal", "bouncy", "sticky", "normal"]
    for index: int in range(names.size()):
        var is_mover: bool = index == 4 or index == 5
        var body: TerrainObject = (moving_scene if is_mover else terrain_scene).instantiate()
        body.name = names[index]
        body.object_id = StringName(names[index].to_snake_case())
        body.position = positions[index]
        body.surface = load("res://resources/terrain/%s.tres" % surfaces[index])
        _owned(movers if is_mover else terrain, body, lab)
        lab.set_editable_instance(body, true)
        var visual: TileMapLayer = body.get_node("Tiles")
        var band: int = ["normal", "sticky", "ice", "bouncy"].find(surfaces[index]) * 5
        for column: int in range(8):
            visual.set_cell(Vector2i(column, 0), 0, Vector2i(4, band))
        if index == 4:
            body.set("endpoint_b", Vector2(40, 0))
        elif index == 5:
            body.set("endpoint_b", Vector2(0, -40))
        elif index == 6:
            body.rotation_degrees = -15.0
        elif index == 7:
            body.rotation_degrees = 90.0
        elif index == 9:
            body.scale = Vector2(1.0 / 64.0, 4.0)
    # One visible L-shaped object with two solid shapes sharing one body/ID.
    var multi: TerrainObject = terrain_scene.instantiate()
    multi.name = "MultiShape"
    multi.object_id = &"multi_shape"
    multi.position = Vector2(336, 240)
    _owned(terrain, multi, lab)
    var side_tiles := TileMapLayer.new()
    side_tiles.name = "SideTiles"
    side_tiles.tile_set = load("res://resources/terrain/terrain_tileset.tres")
    side_tiles.collision_enabled = false
    for row: int in range(1, 5):
        side_tiles.set_cell(Vector2i(0, row), 0, Vector2i(4, 0))
    _owned(multi, side_tiles, lab)
    var side_shape := CollisionPolygon2D.new()
    side_shape.name = "SideSilhouette"
    side_shape.polygon = PackedVector2Array([Vector2(0, 8), Vector2(8, 8), Vector2(8, 40), Vector2(0, 40)])
    _owned(multi, side_shape, lab)
    var demo_balls: Array[GolfBall] = []
    var ball_positions: Array[Vector2] = [Vector2(40, 40), Vector2(152, 40), Vector2(280, 40), Vector2(392, 40), Vector2(48, 200), Vector2(160, 200), Vector2(272, 230), Vector2(412, 174), Vector2(368, 170)]
    for index: int in range(9):
        var ball: GolfBall = ball_scene.instantiate()
        ball.name = names[index] + "Ball"
        ball.position = ball_positions[index]
        if index < 2:
            ball.velocity = Vector2(25, 0)
        elif index == 7:
            ball.velocity = Vector2(100, 0)
        elif index == 8:
            ball.velocity = Vector2(0, -90)
        _owned(balls, ball, lab)
        demo_balls.append(ball)
    lab.set("balls", demo_balls)
    var camera := Camera2D.new()
    camera.name = "Camera2D"
    camera.position = Vector2(240, 148)
    camera.zoom = Vector2(2, 2)
    _owned(lab, camera, lab)
    var canvas := CanvasLayer.new()
    canvas.name = "CanvasLayer"
    _owned(lab, canvas, lab)
    var label := Label.new()
    label.name = "Instructions"
    label.position = Vector2(24, 12)
    label.add_theme_font_size_override("font_size", 18)
    label.text = "PHYSICS LAB · R reset · Space launch all (debug only)\nNormal / Ice / Sticky / Bouncy     |     lower: horizontal / vertical / slope / wall / ceiling / thin"
    _owned(canvas, label, lab)
    var exit_button := Button.new()
    exit_button.name = "MainMenuButton"
    exit_button.position = Vector2(24, 590)
    exit_button.custom_minimum_size = Vector2(140, 36)
    exit_button.text = "Main Menu"
    _owned(canvas, exit_button, lab)
    exit_button.pressed.connect(Callable(lab, "_on_exit_pressed"), CONNECT_PERSIST)
    var packed := PackedScene.new()
    packed.pack(lab)
    var error: Error = ResourceSaver.save(packed, "res://tests/scenes/physics_lab.tscn")
    if error != OK:
        push_error("Lab save failed: " + str(error))
    lab.free()
