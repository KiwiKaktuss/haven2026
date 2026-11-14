extends SceneTree
## The menu and editor share a continuous surface-to-underground camera journey.
var main: Node2D
var checks: int = 0
var failures: int = 0
var capture_enabled: bool = false
const SAVE_PATH: String = "user://menu_journey_test.json"

func _initialize() -> void:
    capture_enabled = "--capture" in OS.get_cmdline_user_args()
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func frames() -> void:
    for frame: int in range(4):
        await process_frame

func capture(label: String) -> void:
    if capture_enabled:
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://screenshots/menu_journey/" + label + ".png")

func click(button: Button) -> void:
    var at: Vector2 = button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion, true)
    for down: bool in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        root.push_input(event, true)

func finish_travel() -> void:
    main._journey_tween.custom_step(10.0)
    await frames()

func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://screenshots/menu_journey")
    DirAccess.remove_absolute(SAVE_PATH)
    root.size = Vector2i(960, 640)
    main = load("res://main.tscn").instantiate()
    main.save.path = SAVE_PATH
    root.add_child(main)
    await frames()
    var original_menu: Control = main._menu_screen
    await capture("01_menu")
    click(original_menu.get_node("Center/Content/Deck"))
    check(main._journey_moving and main.screen_host.get_child_count() == 2, "Edit deck starts a continuous journey with both rooms present")
    main._journey_tween.pause()
    main._show_deck()
    main._show_menu()
    check(main.screen_host.get_child_count() == 2, "Repeated navigation during travel cannot create extra screens")
    var editor: Control = main._deck_screen
    main._journey_tween.custom_step(main.MENU_TRAVEL_SECONDS * 0.5)
    await frames()
    check(original_menu.position.y < 0.0 and editor.position.y > 0.0, "Descending moves the surface upward as the editor rises into view")
    check(is_equal_approx(original_menu.get_global_rect().end.y, editor.position.y), "Surface and underground meet without an empty seam")
    check(not editor.can_process() and not original_menu.can_process(), "Both screens ignore input during travel")
    var selected_before: Array[StringName] = editor.selected.duplicate()
    click(editor.get_node("Margin/Content/Grid/Card0"))
    check(editor.selected == selected_before, "Real clicks cannot modify cards during travel")
    await capture("02_descending")
    root.size = Vector2i(800, 700)
    await frames()
    check(is_equal_approx(original_menu.get_global_rect().end.y, editor.position.y), "Resizing mid-journey keeps the rooms joined")
    await finish_travel()
    check(editor.position.y == 0.0 and editor.can_process() and not original_menu.visible, "Arrival enables only the editor")
    var back: Button = editor.get_node("Margin/Content/Footer/Back")
    check(editor.get_node("Margin/Content/Footer").get_child_count() == 1, "Footer contains only Back")
    check(absf(back.get_global_rect().get_center().x - editor.size.x * 0.5) < 1.0, "Back is centered at the minimum window width")
    check(editor.get_node("Background").texture.resource_path == "res://art/green.png", "Underground uses the supplied green background")
    root.size = Vector2i(960, 640)
    await frames()
    await capture("03_editor")
    var replacement: StringName
    for card: CardDefinition in editor.catalog.cards:
        if not editor.selected.has(card.id):
            replacement = card.id
            break
    editor._toggle(replacement)
    editor._deck_slot_clicked(0)
    var edited: Array[StringName] = editor.selected.duplicate()
    click(back)
    check(main._journey_moving, "Back starts the return journey")
    main._journey_tween.pause()
    main._journey_tween.custom_step(main.MENU_TRAVEL_SECONDS * 0.5)
    await frames()
    await capture("04_ascending")
    await finish_travel()
    check(main._menu_screen == original_menu and original_menu.position.y == 0.0 and original_menu.can_process(), "Return restores the original living menu")
    var restored := SaveStore.new()
    restored.path = SAVE_PATH
    restored.read_save(main.cards, main.courses)
    check(restored.equipped == edited, "Back persists a complete edited deck")
    await capture("05_returned")
    click(original_menu.get_node("Center/Content/Deck"))
    await finish_travel()
    editor._deck_slot_clicked(0)
    click(back)
    await finish_travel()
    check(main.save.equipped == edited, "Back from an incomplete edit keeps the previous valid loadout")
    click(original_menu.get_node("Center/Content/Deck"))
    await finish_travel()
    main.save.path = "user://missing_menu_journey_directory/save.json"
    click(back)
    check(not main._journey_moving and editor.can_process() and editor.visible, "Save failure keeps the editor usable for retry")
    check(editor.get_node("Margin/Content/BattleDeck/DeckContent/Summary/Tip").text.contains("Could not save"), "Save failure appears beside the deck")
    main.save.path = SAVE_PATH
    click(back)
    await finish_travel()
    click(original_menu.get_node("Center/Content/Deck"))
    main._show_levels()
    await frames()
    check(main.screen_host.get_child_count() == 1 and not main._journey_moving, "Leaving the menu flow cancels travel without orphaned screens")
    main.free()
    DirAccess.remove_absolute(SAVE_PATH)
    print("Menu journey: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
