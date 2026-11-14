class_name CardView
extends Button
## Pixel tiles in the selector, sprite-only cards in the gameplay hand.
@export var decorated: bool = true
@export var show_information: bool = true
@export var selected_lift: float = 6.0
@export var hover_lift: float = 3.0
@export var information_gap: float = 6.0
@export var selected_style: StyleBox = preload("res://resources/ui/pixel/selected.tres")
@export var pending_style: StyleBox = preload("res://resources/ui/pixel/hover.tres")
var definition: CardDefinition
var selected: bool = false
var affordable: bool = true
var pending_choice: bool = false
var _hovered: bool = false
var _information_fit_queued: bool = false

func _ready() -> void:
    mouse_entered.connect(_show_information)
    mouse_exited.connect(_hide_information)
    focus_entered.connect(_show_information)
    focus_exited.connect(_hide_information)
    visibility_changed.connect(_visibility_changed)
    $Information.resized.connect(_position_information)
    $Information.minimum_size_changed.connect(_queue_information_fit)

func bind(card: CardDefinition, is_selected: bool, can_afford: bool = true, _key: String = "") -> void:
    definition = card
    selected = is_selected
    affordable = can_afford
    $Artwork.texture = card.artwork
    $Artwork.show()
    $EmptySymbol.hide()
    $Caption.text = card.display_name
    set_pressed_no_signal(selected)
    _refresh_visuals()
    if $Information.visible:
        _update_information()

func show_empty(_slot: int) -> void:
    definition = null
    selected = false
    pending_choice = false
    $Artwork.texture = null
    $Artwork.hide()
    $Information.hide()
    $Marker.hide()
    $EmptySymbol.visible = decorated
    $Caption.text = "EMPTY"
    set_pressed_no_signal(false)

func show_card(card: CardDefinition, is_selected: bool = false) -> void:
    bind(card, is_selected)

func set_pending(value: bool) -> void:
    pending_choice = value
    _refresh_visuals()

func _refresh_visuals() -> void:
    if decorated:
        var style: StyleBox = pending_style if pending_choice else selected_style
        add_theme_stylebox_override("pressed", style)
        add_theme_stylebox_override("hover_pressed", style)
        $Marker.visible = selected and definition != null
        $Marker.text = "↔" if pending_choice else "✓"
    else:
        $Artwork.position.y = -selected_lift if selected else (-hover_lift if _hovered else 0.0)

func _show_information() -> void:
    _hovered = true
    _refresh_visuals()
    if show_information and definition != null:
        _update_information()
        $Information.show()

func _hide_information() -> void:
    _hovered = false
    _refresh_visuals()
    $Information.hide()

func _visibility_changed() -> void:
    if not is_visible_in_tree():
        _hide_information()

func _update_information() -> void:
    $Information/Margin/Content/Title.text = "%s · %s elixir" % [definition.display_name, definition.cost]
    $Information/Margin/Content/Description.text = definition.description
    _queue_information_fit()

func _queue_information_fit() -> void:
    if _information_fit_queued:
        return
    _information_fit_queued = true
    call_deferred("_fit_information")

func _fit_information() -> void:
    _information_fit_queued = false
    if definition == null or not is_inside_tree():
        return
    # Wrapping updates minimum height after containers assign the text width.
    # Fit again when that minimum changes, so the panel can shrink as well as grow.
    $Information.reset_size()
    $Information.queue_sort()
    _position_information()

func _position_information() -> void:
    if definition == null or not is_inside_tree():
        return
    var popup: Control = $Information
    var card_rect: Rect2 = get_global_rect()
    var viewport_size: Vector2 = get_viewport_rect().size
    popup.global_position = Vector2(
        clampf(card_rect.get_center().x - popup.size.x * 0.5, 6.0, maxf(6.0, viewport_size.x - popup.size.x - 6.0)),
        maxf(6.0, card_rect.position.y - popup.size.y - information_gap)).floor()
