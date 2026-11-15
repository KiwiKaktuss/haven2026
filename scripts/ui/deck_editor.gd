extends Control
signal done_requested(ids: Array[StringName])
@export var catalog: CardCatalog = preload("res://resources/cards/catalog.tres")
@export var preview_mode: bool = false
var selected: Array[StringName] = []
var pending_swap: StringName = &""
var _saved_selection: Array[StringName] = []

func _ready() -> void:
    for index: int in range(catalog.cards.size()):
        get_node("Margin/Content/Grid/Card%s" % index).pressed.connect(_toggle.bind(catalog.cards[index].id))
    for index: int in range(CardCatalog.DECK_SIZE):
        get_node("Margin/Content/BattleDeck/DeckContent/Hand/Slot%s" % index).pressed.connect(_deck_slot_clicked.bind(index))
    $Margin/Content/Footer/Back.pressed.connect(_done)
    refresh()

func configure(ids: Array[StringName]) -> void:
    selected.clear()
    for id: StringName in ids:
        if catalog.find_card(id) != null and not selected.has(id) and selected.size() < CardCatalog.DECK_SIZE:
            selected.append(id)
    pending_swap = &""
    _saved_selection = selected.duplicate()
    refresh()
    if preview_mode:
        _toggle(&"classic")

func _toggle(id: StringName) -> void:
    if catalog.find_card(id) == null:
        return
    if preview_mode:
        var card: CardDefinition = catalog.find_card(id)
        $Margin/Content/CardExplanation.text = "%s · %d elixir\n%s" % [card.display_name, card.cost, card.description]
        for index: int in catalog.cards.size():
            get_node("Margin/Content/Grid/Card%d" % index).show_card(catalog.cards[index], catalog.cards[index].id == id)
        return
    if selected.has(id):
        selected.erase(id)
        pending_swap = &""
    elif selected.size() < CardCatalog.DECK_SIZE:
        selected.append(id)
        pending_swap = &""
    else:
        pending_swap = &"" if pending_swap == id else id
    refresh()

func _deck_slot_clicked(index: int) -> void:
    if preview_mode:
        return
    if index < 0 or index >= selected.size():
        return
    if not pending_swap.is_empty():
        selected[index] = pending_swap
        pending_swap = &""
    else:
        selected.remove_at(index)
    refresh()

func _cancel_swap() -> void:
    pending_swap = &""
    refresh()

func refresh() -> void:
    for index: int in range(catalog.cards.size()):
        var card: CardDefinition = catalog.cards[index]
        var view: CardView = get_node("Margin/Content/Grid/Card%s" % index)
        view.show_card(card, selected.has(card.id) or pending_swap == card.id)
        view.set_pending(pending_swap == card.id)
    for index: int in range(CardCatalog.DECK_SIZE):
        var view: CardView = get_node("Margin/Content/BattleDeck/DeckContent/Hand/Slot%s" % index)
        if index < selected.size():
            var card: CardDefinition = catalog.find_card(selected[index])
            view.show_card(card)
            view.set_pending(false)
        else:
            view.show_empty(index)
    $Margin/Content/Header/Count.text = "OPTIONAL GUIDE" if preview_mode else "%s / %s cards" % [selected.size(), CardCatalog.DECK_SIZE]
    if not pending_swap.is_empty():
        $Margin/Content/BattleDeck/DeckContent/Summary/Tip.text = "Replace a deck card with %s, or click it again to cancel." % catalog.find_card(pending_swap).display_name
    else:
        $Margin/Content/BattleDeck/DeckContent/Summary/Tip.text = "Five cards · Three in hand" if selected.size() == CardCatalog.DECK_SIZE else "Choose %s more card%s to complete your deck." % [CardCatalog.DECK_SIZE - selected.size(), "" if selected.size() == CardCatalog.DECK_SIZE - 1 else "s"]

func show_save_error() -> void:
    $Margin/Content/BattleDeck/DeckContent/Summary/Tip.text = "Could not save your deck. Press Back to try again."

func _done() -> void:
    _cancel_swap()
    # Back always navigates. An unfinished edit cannot overwrite a valid deck.
    var ids: Array[StringName] = selected if selected.size() == CardCatalog.DECK_SIZE else _saved_selection
    done_requested.emit(ids.duplicate())
