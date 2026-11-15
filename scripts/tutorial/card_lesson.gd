extends Control
## An in-place lesson: hovering, keyboard focus or tapping reveals one ability.
signal card_inspected(card: CardDefinition)
signal continue_requested
var catalog: CardCatalog
var inspected: bool = false
@onready var grid: GridContainer = $Center/Panel/Content/Grid
@onready var details: HBoxContainer = $Center/Panel/Content/Details/Row
@onready var next_button: Button = $Center/Panel/Content/Footer/Continue

func _ready() -> void:
    next_button.pressed.connect(func() -> void:
        if inspected:
            continue_requested.emit())

func configure(value: CardCatalog) -> void:
    catalog = value
    for index: int in catalog.cards.size():
        var view: CardView = grid.get_child(index)
        view.show_information = false
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
        grid.get_child(index).show_card(catalog.cards[index])
    details.get_node("Artwork").texture = catalog.find_card(&"classic").artwork
    details.get_node("Text/Heading/Name").text = "Different cards. Different abilities."
    details.get_node("Text/Heading/Cost").text = ""
    details.get_node("Text/Description").text = "Every card changes your shot in its own way. Hover over any card to take a closer look."

func inspect(index: int) -> void:
    if catalog == null or not is_visible_in_tree() or not can_process():
        return
    var card: CardDefinition = catalog.cards[index]
    for i: int in catalog.cards.size():
        grid.get_child(i).show_card(catalog.cards[i], i == index)
    details.get_node("Artwork").texture = card.artwork
    details.get_node("Text/Heading/Name").text = card.display_name
    details.get_node("Text/Heading/Cost").text = "%d elixir" % card.cost
    details.get_node("Text/Description").text = card.description
    inspected = true
    next_button.disabled = false
    next_button.text = "Continue to walls  →"
    card_inspected.emit(card)
