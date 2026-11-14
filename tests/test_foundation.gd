extends SceneTree
## Headless structural/serialization checks for the step-1 contract.
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    for surface_id: String in ["normal", "sticky", "ice", "bouncy"]:
        var surface: SurfaceDefinition = load("res://resources/terrain/%s.tres" % surface_id)
        check(surface != null and surface.id == StringName(surface_id), "Surface resource loads")
    var catalog: CardCatalog = load("res://resources/cards/catalog.tres")
    check(catalog.cards.size() == 10, "Exactly ten card resources")
    var ids: Array[StringName] = []
    for card: CardDefinition in catalog.cards:
        check(not ids.has(card.id), "Unique stable card ID")
        ids.append(card.id)
        check(card.spread_curve.sample(1.0) > 0.0, "Nonzero angular spread")
    check(catalog.default_deck.size() == 6, "Six equipped cards")
    for id: StringName in catalog.default_deck:
        check(catalog.find_card(id) != null, "Default deck references catalog")
    var courses: CourseCatalog = load("res://resources/levels/catalog.tres")
    check(courses.courses.size() == 4, "Four course references")
    for definition: CourseDefinition in courses.courses:
        var course: GolfCourse = definition.scene.instantiate()
        check(course.start_marker != null, "Saved spawn reference")
        course.free()
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    for path: String in ["CourseHost", "Ball/Sprite2D", "Ball/CollisionShape2D", "AimController", "TrajectoryPreview/CentralPath", "CameraRig/Camera2D", "CanvasLayer/HUD"]:
        check(session.has_node(path), "Authored node exists: " + path)
    check(session.tuning != null and session.ball.tuning != null, "Saved tuning references")
    # Round-trip a scene transform and a resource edit without modifying source assets.
    session.get_node("ArtInspection").position = Vector2(17, 23)
    var packed := PackedScene.new()
    check(packed.pack(session) == OK, "Pack editor-authored session")
    check(ResourceSaver.save(packed, "user://foundation_roundtrip.tscn") == OK, "Save scene edit")
    session.free()
    var saved: PackedScene = ResourceLoader.load("user://foundation_roundtrip.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
    session = saved.instantiate()
    check(session.get_node("ArtInspection").position == Vector2(17, 23), "Transform persists after reload")
    root.add_child(session)
    check(session.course_host.get_child_count() == 1, "Session loads saved course scene")
    var tuning: GameTuning = session.tuning.duplicate()
    tuning.gravity = 321.0
    check(ResourceSaver.save(tuning, "user://foundation_tuning.tres") == OK, "Save resource edit")
    var restored: GameTuning = ResourceLoader.load("user://foundation_tuning.tres", "GameTuning", ResourceLoader.CACHE_MODE_IGNORE)
    check(restored.gravity == 321.0, "Resource value survives reload")
    var tiles: TileSet = load("res://resources/terrain/terrain_tileset.tres")
    var atlas: TileSetAtlasSource = tiles.get_source(0)
    check(atlas.get_tiles_count() == 240, "12 by 20 atlas")
    check(atlas.texture_region_size == Vector2i(8, 8), "8 pixel tiles")
    var materials: Array[String] = ["normal", "sticky", "ice", "bouncy"]
    for row: int in range(20):
        for column: int in range(12):
            var tile: TileData = atlas.get_tile_data(Vector2i(column, row), 0)
            check(tile.get_custom_data("surface") == materials[row / 5], "Material row mapping")
    check(atlas.get_tile_data(Vector2i(4, 1), 0).get_collision_polygons_count(0) > 0, "Solid tiles have silhouettes")
    check(session.ball.sprite.texture.get_size() == Vector2(4, 4), "Original four-pixel ball")
    session.free()
    var main: Node2D = load("res://main.tscn").instantiate()
    root.add_child(main)
    var menu: Control = main.get_node("ScreenHost").get_child(0)
    await process_frame
    check(menu.size.x > 0 and menu.size.y > 0, "Menu receives viewport size")
    menu.get_node("CenterContainer/VBoxContainer/InspectButton").pressed.emit()
    await process_frame
    check(main.get_node("ScreenHost").get_child_count() == 0, "Inspection removes menu")
    check(main.get_node("GameHost").get_child_count() == 1, "Inspection instantiates saved session")
    main.free()
    for file: String in ["foundation_roundtrip.tscn", "foundation_tuning.tres"]:
        DirAccess.remove_absolute("user://" + file)
    print("Foundation checks: %s failure(s)" % failures)
    quit(0 if failures == 0 else 1)
