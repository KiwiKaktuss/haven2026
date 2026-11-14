class_name AimFeedback
extends Control
@export var aim: AimController
@export var power: ProgressBar
@export var label: Label

func _ready() -> void:
    connect_aim()

func connect_aim() -> void:
    if aim != null and not aim.aim_changed.is_connected(refresh):
        aim.aim_changed.connect(refresh)
    refresh()

func refresh() -> void:
    visible = aim != null and aim.aiming
    if not visible:
        return
    var card: CardDefinition = aim.session.deck.selected_card()
    var amount: float = ShotCalculation.strength(aim.drag_vector(), aim.session.tuning)
    power.value = amount * 100.0
    label.text = "Power %s%% · %s" % [roundi(amount * 100), "Release to shoot" if aim.session.elixir >= card.cost else "Need %s elixir" % card.cost]
