extends SceneTree
## Render the real deck editor, hover tooltip, swap prompt and in-game dock.
var main: Node2D
var folder: String = "res://screenshots/card_info_fix"
var errors: int = 0

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    while main != null and main._journey_moving:
        await process_frame
    # Native window resizing and text shaping can finish after fast render frames.
    await create_timer(0.3).timeout
    for frame: int in range(12):
        await process_frame

func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder + "/" + label + ".png")

func hover(at: Vector2) -> void:
    var event := InputEventMouseMotion.new()
    event.position = at
    root.push_input(event, true)

func hover_card(card: CardView) -> void:
    # The panel opens immediately; checking next-frame input avoids an unrelated
    # native mouse event replacing the synthetic hover during a one-second wait.
    for attempt: int in range(5):
        hover(card.get_global_rect().get_center())
        await process_frame
        if card.get_node("Information").visible:
            await process_frame
            await process_frame
            var box: Control = card.get_node("Information")
            for text_node: String in ["Title", "Description"]:
                enclosed(box.get_global_rect(), box.get_node("Margin/Content/" + text_node).get_global_rect(), "hover " + text_node)
            if box.get_global_rect().end.y >= card.get_global_rect().position.y:
                errors += 1
                push_error("Description box is not above the card")
            return
    errors += 1
    push_error("Pointer hover did not open the information box")

func enclosed(outer: Rect2, inner: Rect2, label: String) -> void:
    if not outer.grow(1).encloses(inner):
        push_error("Clipped UI: " + label + " " + str(inner) + " outside " + str(outer))
        errors += 1

func run() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    main = load("res://main.tscn").instantiate()
    main.save.path = "user://card_ui_capture.json"
    root.add_child(main)
    await settle()
    await capture("menu")
    for window_size: Vector2i in [Vector2i(800, 640), Vector2i(960, 640), Vector2i(1440, 900)]:
        root.size = window_size
        main._show_deck()
        hover(Vector2(1, 1))
        await settle()
        var editor: Control = main.screen_host.get_child(0)
        for card: Control in editor.get_node("Margin/Content/Grid").get_children():
            enclosed(editor.get_global_rect(), card.get_global_rect(), card.name)
            enclosed(card.get_global_rect().grow(8), card.get_node("Artwork").get_global_rect(), card.name + " content")
        enclosed(editor.get_global_rect(), editor.get_node("Margin/Content/Footer/Back").get_global_rect(), "Back")
        await capture("deck_%s" % window_size.x)
        if window_size.x == 960:
            var view: CardView = editor.get_node("Margin/Content/Grid/Card0")
            await hover_card(view)
            enclosed(editor.get_global_rect(), view.get_node("Information").get_global_rect(), "hover box")
            await capture("deck_hover")
            var equipped: CardView = editor.get_node("Margin/Content/BattleDeck/DeckContent/Hand/Slot0")
            await hover_card(equipped)
            enclosed(editor.get_global_rect(), equipped.get_node("Information").get_global_rect(), "equipped hover box")
            await capture("deck_hover_equipped")
            hover(Vector2(1, 1))
            editor._toggle(&"ghost")
            await settle()
            await capture("deck_swap")
            editor._cancel_swap()
        main._start_course(0)
        main.session.camera_controller.set_zoom(main.session.camera_controller.overview_zoom())
        await settle()
        for card: Control in main.session.hud.get_node("Bottom/Stack/Hand").get_children():
            enclosed(main.session.hud.get_global_rect(), card.get_global_rect(), "hand")
        await capture("hud_%s" % window_size.x)
        if window_size.x == 960:
            main.session.elixir = 2.5
            main.session.set_physics_process(false)
            main.session.hud.refresh()
            await settle()
            await capture("hud_low_elixir")
            var hand_card: Control = main.session.hud.get_node("Bottom/Stack/Hand/Card0")
            hover(hand_card.get_global_rect().get_center())
            await process_frame
            await capture("hud_hover")
            hover(Vector2(1, 1))
        if window_size.x == 960:
            main._pause()
            await settle()
            await capture("pause")
            main._resume()
            main.session.finish_attempt(true)
            await settle()
            await capture("result")
        main._show_menu()
    main.free()
    print("Card UI captures: ", errors, " layout errors")
    quit(0 if errors == 0 else 1)
