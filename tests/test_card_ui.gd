extends SceneTree
## Card art mapping, six-card editing, swaps, and HUD resource feedback.
var checks: int = 0
var failures: int = 0
var catalog: CardCatalog = load("res://resources/cards/catalog.tres")

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func run() -> void:
    var order: Array[StringName] = [&"fire", &"sniper", &"classic", &"slow", &"heavy", &"bounce", &"glue", &"dash", &"ghost", &"rewind"]
    for index: int in range(order.size()):
        var card: CardDefinition = catalog.cards[index]
        check(card.id == order[index], "Collection follows the supplied sprite order")
        var art: AtlasTexture = card.artwork as AtlasTexture
        check(art != null and art.region == Rect2((index % 5) * 22, (index / 5) * 31, 22, 31), "Correct 22 × 31 art for " + String(card.id))
    var editor: Control = load("res://scenes/ui/deck_editor.tscn").instantiate()
    root.add_child(editor)
    editor.configure(catalog.default_deck)
    check(editor.selected.size() == 6, "Default deck has six cards")
    var slot: CardView = editor.get_node("Margin/Content/BattleDeck/DeckContent/Hand/Slot0")
    check(slot.definition.id == catalog.default_deck[0], "Battle Deck shows the equipped order")
    var collection: CardView = editor.get_node("Margin/Content/Grid/Card0")
    check(not collection.get_node("Information").visible and collection.tooltip_text.is_empty(), "Descriptions stay hidden outside hover")
    for frame: int in range(3):
        await process_frame
    collection._show_information()
    for frame: int in range(4):
        await process_frame
    var popup: Control = collection.get_node("Information")
    check(popup.visible and popup.get_node("Margin/Content/Description").text == collection.definition.description, "Hover reveals the card description")
    check(popup.get_global_rect().end.y < collection.get_global_rect().position.y, "Hover box appears above the card")
    collection._hide_information()
    check(not popup.visible, "Leaving the card hides its description")
    check(collection.get_theme_stylebox("normal") is StyleBoxTexture and collection.get_node("Caption").text == "Fireball", "Selector shows a pixel tile and readable card name")
    check(not collection.has_node("Cost") and not collection.has_node("Status"), "Cards have no added cost badge or action label")
    check(not editor.has_node("Margin/Content/BattleDeck/DeckContent/Summary/Average"), "No purple average-elixir label remains")
    var long_card: CardDefinition = catalog.cards[0].duplicate()
    long_card.description = "A long description must wrap inside its frame without escaping into the collection. ".repeat(4)
    collection.bind(long_card, true)
    collection._show_information()
    for frame: int in range(6):
        await process_frame
    var wrapped: Label = popup.get_node("Margin/Content/Description")
    check(popup is PanelContainer and wrapped.get_line_count() > 1 and popup.get_global_rect().encloses(wrapped.get_global_rect()), "Wrapped descriptions resize their containing frame")
    check(popup.get_global_rect().end.y < collection.get_global_rect().position.y, "Expanded description remains above the collection card")
    collection.bind(catalog.cards[0], true)
    for frame: int in range(3):
        await process_frame
    collection._update_information()
    collection._hide_information()
    slot._show_information()
    for frame: int in range(4):
        await process_frame
    check(slot.get_node("Information").get_global_rect().end.y < slot.get_global_rect().position.y, "Equipped card description also appears above the card")
    slot._hide_information()
    for window_size: Vector2i in [Vector2i(800, 640), Vector2i(960, 640), Vector2i(961, 641), Vector2i(1440, 900), Vector2i(1600, 1280)]:
        root.size = window_size
        for frame: int in range(3):
            await process_frame
        var grid_aligned: bool = true
        for tile: CardView in editor.get_node("Margin/Content/Grid").get_children():
            var art_rect: Rect2 = tile.get_node("Artwork").get_global_rect()
            var art_scale: Vector2 = tile.get_node("Artwork").get_screen_transform().get_scale()
            grid_aligned = grid_aligned and art_rect.position.is_equal_approx(art_rect.position.round()) and art_rect.size == Vector2(66, 93)
            grid_aligned = grid_aligned and art_scale.is_equal_approx(art_scale.round())
        check(grid_aligned, "Original card pixels stay integer-aligned at " + str(window_size))
    root.size = Vector2i(960, 640)
    var original: Array[StringName] = editor.selected.duplicate()
    editor._toggle(&"heavy")
    check(editor.pending_swap == &"heavy" and editor.selected == original, "Choosing seventh card stages a swap")
    check(editor.get_node("Margin/Content/Footer/Done").disabled, "Pending swap must be resolved before saving")
    var pending_tile: CardView = editor.get_node("Margin/Content/Grid/Card4")
    check(pending_tile.pending_choice and pending_tile.get_node("Marker").text == "↔", "Pending replacement has its own visible state")
    editor._deck_slot_clicked(2)
    check(editor.selected[2] == &"heavy" and editor.selected.size() == 6 and editor.pending_swap.is_empty(), "Slot click completes six-card replacement")
    editor._toggle(&"dash")
    editor._cancel_swap()
    check(not editor.selected.has(&"dash") and editor.pending_swap.is_empty(), "Cancel preserves the equipped deck")
    editor._deck_slot_clicked(0)
    check(editor.selected.size() == 5 and editor.get_node("Margin/Content/Footer/Done").disabled, "Removing card disables saving")
    editor._toggle(&"dash")
    check(editor.selected.size() == 6 and editor.selected.has(&"dash"), "Collection fills an empty deck slot")
    for id: StringName in editor.selected.duplicate():
        editor._toggle(id)
    check(editor.selected.is_empty() and slot.definition == null and slot.get_node("Artwork").texture == null, "Empty slots never retain stale artwork")
    editor._toggle(&"fire")
    check(slot.definition.id == &"fire" and slot.get_node("Artwork").visible, "Empty slot can be filled again")
    editor.free()
    var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.elixir = 0
    session.hud.refresh()
    var hand: CardView = session.hud.get_node("Bottom/Stack/Hand/Card0")
    check(not hand.affordable and hand.get_node("Artwork").modulate == Color.WHITE, "Affordability leaves the original sprite unchanged")
    hand._show_information()
    check(not hand.get_node("Information").visible, "Gameplay hand stays graphics only on hover")
    session.elixir = 10
    session.hud.refresh()
    check(hand.affordable, "Affordability updates after regeneration")
    check(session.hud.get_node("Bottom/Stack/Elixir/ElixirBar").value == 10, "Elixir meter follows session")
    check(session.hud.get_node("Bottom/Stack/Dock").texture.resource_path == "res://art/dock.png", "Hand uses supplied dock")
    var visible_labels: Array[Node] = []
    for node: Node in session.hud.find_children("*", "Label", true, false):
        if node.is_visible_in_tree():
            visible_labels.append(node)
    check(visible_labels.size() == 1 and visible_labels[0].name == &"TimerLabel", "Timer is the only visible gameplay text")
    check(not session.course.get_node("Hints").visible, "World instruction text is hidden")
    var frame_style: StyleBoxTexture = load("res://resources/ui/frame.tres")
    var frame_texture: CanvasTexture = frame_style.texture as CanvasTexture
    check(frame_texture.diffuse_texture.resource_path == "res://art/ui/panel.svg" and frame_style.texture_margin_left == 12, "Shared style uses a three-pixel stepped frame")
    check(hand.get_theme_stylebox("normal") is StyleBoxEmpty and not hand.get_node("Caption").is_visible_in_tree(), "Gameplay cards retain the sprite-only presentation")
    check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "Window scaling preserves integer sprite pixels")
    session.free()
    print("Card UI: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
