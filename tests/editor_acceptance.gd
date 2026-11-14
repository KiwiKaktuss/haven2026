@tool
extends EditorPlugin
## Runs only through tools/run_editor_check.py in a real editor process.
func _enter_tree() -> void:
    if OS.get_environment("DECK_GOLF_EDITOR_CHECK") == "1":
        call_deferred("run_check")

func run_check() -> void:
    for frame: int in range(60):
        await get_tree().process_frame
    for path: String in ["res://scenes/ball/ball.tscn", "res://scenes/game/trajectory_preview.tscn", "res://scenes/ui/hud.tscn", "res://scenes/game/game_session.tscn"]:
        EditorInterface.open_scene_from_path(path)
        for frame: int in range(120):
            await get_tree().process_frame
            var current: Node = EditorInterface.get_edited_scene_root()
            if current != null and current.scene_file_path == path:
                break
        var scene: Node = EditorInterface.get_edited_scene_root()
        if scene == null or scene.scene_file_path != path:
            push_error("Editor failed to open " + path)
            get_tree().quit(1)
            return
        print("EDITOR OPEN: ", path, " (", scene.get_child_count(), " authored children)")
    var session: Node = EditorInterface.get_edited_scene_root()
    var original_tuning: GameTuning = load("res://resources/game/default_tuning.tres")
    var tuning: GameTuning = original_tuning.duplicate()
    tuning.gravity = 321.0
    if ResourceSaver.save(tuning, "res://tests/.editor_check/tuning.tres") != OK:
        get_tree().quit(1)
        return
    session.set("tuning", tuning)
    session.get_node("ArtInspection").position = Vector2(17, 23)
    EditorInterface.mark_scene_as_unsaved()
    EditorInterface.save_scene_as("res://tests/.editor_check/session.tscn", false)
    await get_tree().process_frame
    var saved: PackedScene = ResourceLoader.load("res://tests/.editor_check/session.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
    var launched: GameSession = saved.instantiate()
    get_tree().root.add_child(launched)
    var passed: bool = launched.tuning.gravity == 321.0 and launched.get_node("ArtInspection").position == Vector2(17, 23)
    passed = passed and launched.has_node("Ball/CollisionShape2D") and launched.has_node("CanvasLayer/HUD")
    launched.free()
    # Edit actual editor-managed text slots, save copies and verify runtime binding
    # preserves those authored sizes and theme overrides.
    for path: String in ["res://scenes/ui/card_view.tscn", "res://scenes/ui/hud.tscn"]:
        EditorInterface.open_scene_from_path(path)
        for frame: int in range(120):
            await get_tree().process_frame
            var current: Node = EditorInterface.get_edited_scene_root()
            if current != null and current.scene_file_path == path:
                break
        var edited: Node = EditorInterface.get_edited_scene_root()
        var is_card: bool = path.ends_with("card_view.tscn")
        var slot_path: String = "MarginContainer/VBoxContainer/Heading/NameSlot" if is_card else "Top/CourseSlot"
        var slot: Control = edited.get_node(slot_path)
        slot.custom_minimum_size = Vector2(139, 49)
        if is_card:
            edited.get_node("MarginContainer/VBoxContainer/DescriptionSlot").custom_minimum_size = Vector2(0, 83)
            edited.get_node(slot_path + "/NameLabel").add_theme_font_size_override("font_size", 19)
        EditorInterface.mark_scene_as_unsaved()
        var output: String = "res://tests/.editor_check/" + ("card.tscn" if is_card else "hud.tscn")
        EditorInterface.save_scene_as(output, false)
        await get_tree().process_frame
        var copy: PackedScene = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
        var instance: Control = copy.instantiate()
        get_tree().root.add_child(instance)
        passed = passed and instance.get_node(slot_path).custom_minimum_size == Vector2(139, 49)
        instance.free()
    var output: Array = []
    var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_editor_layout.gd", "--log-file", "/tmp/haven2026-editor-layout-runtime.log"], output, true)
    for line: String in output:
        print(line)
    passed = passed and code == 0
    print("EDITOR ACCEPTANCE: ", "PASS" if passed else "FAIL")
    get_tree().quit(0 if passed else 1)
