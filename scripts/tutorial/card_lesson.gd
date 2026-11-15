extends Control
## Uses the deck selector's real cards and above-card information popovers.
signal card_inspected(card: CardDefinition)
signal continue_requested
var catalog: CardCatalog
var inspected: bool = false
@onready var grid: GridContainer = $Center/Content/Grid
@onready var next_button: Button = $Center/Content/Footer/Continue

func _ready() -> void:
    next_button.pressed.connect(func() -> void:
        if inspected:
            continue_requested.emit())

func configure(value: CardCatalog) -> void:
    catalog = value
    for index: int in catalog.cards.size():
        var view: CardView = grid.get_child(index)
        view.show_information = true
        view.mouse_entered.connect(inspect.bind(index))
        view.focus_entered.connect(inspect.bind(index))
        view.pressed.connect(inspect.bind(index))
    reset_lesson()

func reset_lesson() -> void:
    if catalog == null:
        return
    inspected = false
    next_button.disabled = true
    next_button.text = "Explore a card first"
    for index: int in catalog.cards.size():
        var view: CardView = grid.get_child(index)
        view.show_card(catalog.cards[index])
        view._hide_information()

func inspect(index: int) -> void:
    if catalog == null or not is_visible_in_tree() or not can_process():
        return
    for i: int in catalog.cards.size():
        var view: CardView = grid.get_child(i)
        if i == index:
            view._show_information()
        else:
            view._hide_information()
    inspected = true
    next_button.disabled = false
    next_button.text = "Continue to walls  →"
    card_inspected.emit(catalog.cards[index])
