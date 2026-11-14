class_name CardView
extends Button
## Layout is authored in card_view.tscn; scripts only bind content/state.
@export var compact: bool = false
var definition: CardDefinition
@onready var content: VBoxContainer = $MarginContainer/VBoxContainer

func bind(card: CardDefinition, selected: bool, affordable: bool = true, key: String = "") -> void:
    definition = card
    content.get_node("Heading/NameSlot/NameLabel").text = card.display_name
    content.get_node("Heading/CostSlot/CostLabel").text = str(card.cost)
    content.get_node("DescriptionSlot/DescriptionLabel").text = card.description
    content.get_node("ArtSlot/TextureRect").texture = card.artwork
    content.get_node("PowerSlot/PowerBar").value = card.power / 285.0 * 100.0
    content.get_node("AccuracySlot/AccuracyBar").value = clampf(100.0 - card.spread_curve.sample(1.0) / 30.0 * 100.0, 0, 100)
    content.get_node("KeySlot/KeyLabel").text = key if affordable else "Need %s elixir" % card.cost
    set_pressed_no_signal(selected)
    tooltip_text = "%s\n%s elixir · %s" % [card.display_name, card.cost, card.description] if compact else ""
    modulate.a = 1.0 if affordable else 0.55
