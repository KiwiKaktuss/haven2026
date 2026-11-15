class_name CardView
extends Button
## Pixel tiles in the selector, sprite-only cards in the gameplay hand.
@export var decorated: bool = true
@export var show_information: bool = true
@export var name_only_information: bool = false
@export var selected_lift: float = 6.0
@export var hover_lift: float = 3.0
@export_range(1.0, 1.15, 0.005) var selected_scale: float = 1.05
@export var information_gap: float = 6.0
@export_range(1.0, 30.0) var lift_speed: float = 18.0
@export_range(0.1, 1.0) var unaffordable_opacity: float = 0.48
@export var selected_style: StyleBox = preload("res://resources/ui/pixel/selected.tres")
@export var pending_style: StyleBox = preload("res://resources/ui/pixel/hover.tres")
var definition: CardDefinition
var selected: bool = false
var affordable: bool = true
var pending_choice: bool = false
var _hovered: bool = false
var _information_fit_queued: bool = false
var deal_pending: bool = false
var _lift_target: float = 0.0
var _scale_target: float = 1.0
var _feedback_tween: Tween

func set_deal_pending(value: bool) -> void:
    deal_pending = value
    $Artwork.visible = not value and definition != null
    mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
    if has_node("ReadyMark"):
        $ReadyMark.visible = selected and not value
    if value and has_node("SelectionShadow"):
        $SelectionShadow.hide()
    if value:
        _hide_information()

func _process(delta: float) -> void:
    if not decorated:
        var weight: float = 1.0 - exp(-lift_speed * delta)
        $Artwork.position.y = lerpf($Artwork.position.y, _lift_target, weight)
        var target_scale: Vector2 = Vector2.ONE * _scale_target
        $Artwork.scale = $Artwork.scale.lerp(target_scale, weight)
        if $Artwork.scale.distance_to(target_scale) < 0.0001:
            $Artwork.scale = target_scale
        if has_node("SelectionShadow"):
            var show_shadow: bool = selected and not deal_pending and definition != null
            $SelectionShadow.modulate.a = lerpf($SelectionShadow.modulate.a, 1.0 if show_shadow else 0.0, weight)
            $SelectionShadow.visible = not deal_pending and $SelectionShadow.modulate.a > 0.01

func land() -> void:
    if decorated:
        return
    $Artwork.position.y = -16.0

func reject_play() -> void:
    if decorated:
        return
    if _feedback_tween != null:
        _feedback_tween.kill()
    _feedback_tween = create_tween()
    for offset: float in [-4.0, 4.0, -2.0, 0.0]:
        _feedback_tween.tween_property($Artwork, "position:x", offset, 0.055)

func _ready() -> void:
    mouse_entered.connect(_show_information)
    mouse_exited.connect(_hide_information)
    focus_entered.connect(_show_information)
    focus_exited.connect(_hide_information)
    visibility_changed.connect(_visibility_changed)
    $Information.resized.connect(_position_information)
    $Information.minimum_size_changed.connect(_queue_information_fit)
    $Artwork.resized.connect(_update_artwork_pivot)
    if name_only_information:
        $Information.custom_minimum_size = Vector2.ZERO
        $Information/Margin/Content/Description.hide()
        $Information/Margin/Content/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _update_artwork_pivot()

func _update_artwork_pivot() -> void:
    if not decorated:
        $Artwork.pivot_offset = $Artwork.size * 0.5

func bind(card: CardDefinition, is_selected: bool, can_afford: bool = true, _key: String = "") -> void:
    definition = card
    selected = is_selected
    affordable = can_afford
    $Artwork.texture = card.artwork
    $Artwork.visible = not deal_pending
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
        _lift_target = -selected_lift if selected else (-hover_lift if _hovered else 0.0)
        _scale_target = selected_scale if selected else 1.0
        $Artwork.self_modulate.a = 1.0 if affordable else unaffordable_opacity
        if has_node("ReadyMark"):
            $ReadyMark.visible = selected and not deal_pending

func _show_information() -> void:
    _hovered = true
    _refresh_visuals()
    if show_information and definition != null and not deal_pending:
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
    $Information/Margin/Content/Title.text = definition.display_name if name_only_information else "%s · %s elixir" % [definition.display_name, definition.cost]
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
