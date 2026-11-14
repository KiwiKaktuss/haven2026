extends Control
signal done_requested(ids: Array[StringName])
@export var catalog: CardCatalog = preload("res://resources/cards/catalog.tres")
var selected: Array[StringName] = []

func _ready() -> void:
    for index: int in range(catalog.cards.size()):
        get_node("Margin/Content/Grid/Card%s" % index).pressed.connect(_toggle.bind(catalog.cards[index].id))
    $Margin/Content/Footer/Done.pressed.connect(_done)

func configure(ids: Array[StringName]) -> void:
    selected = ids.duplicate()
    refresh()

func _toggle(id: StringName) -> void:
    if selected.has(id):
        selected.erase(id)
    elif selected.size() < 6:
        selected.append(id)
    refresh()

func refresh() -> void:
    for index: int in range(catalog.cards.size()):
        var card: CardDefinition = catalog.cards[index]
        get_node("Margin/Content/Grid/Card%s" % index).bind(card, selected.has(card.id))
    $Margin/Content/Header/Count.text = "%s / 6 selected" % selected.size()
    $Margin/Content/Footer/Done.disabled = selected.size() != 6
    $Margin/Content/Footer/Hint.text = "Remove a card to choose another." if selected.size() == 6 else "Choose %s more. Numbers show elixir cost." % (6 - selected.size())

func _done() -> void:
    if selected.size() == 6:
        done_requested.emit(selected.duplicate())
