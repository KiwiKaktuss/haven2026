class_name GameHUD
extends Control
signal pause_requested
var session: GameSession

static func format_time(seconds: float) -> String:
    var centiseconds: int = floori(seconds * 100)
    return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func configure(value: GameSession, title: String) -> void:
    session = value
    $Top/CourseSlot/CourseLabel.text = title
    $Top/Pause.pressed.connect(func() -> void: pause_requested.emit())
    for slot: int in range(3):
        get_node("Bottom/Stack/Hand/Card%s" % slot).pressed.connect(session.deck.select_slot.bind(slot))
    $AimFeedback.aim = session.aim
    $AimFeedback.connect_aim()
    refresh()

func _process(_delta: float) -> void:
    if session != null:
        refresh()

func refresh() -> void:
    $Top/TimerSlot/TimerLabel.text = "%d:%02d" % [floori(session.elapsed_seconds) / 60, floori(session.elapsed_seconds) % 60]
    $Top/ShotsSlot/ShotsLabel.text = "%s shot%s" % [session.shots, "" if session.shots == 1 else "s"]
    $Bottom/Stack/Elixir/ElixirLabel.text = "Elixir %s / %s" % [floori(session.elixir), session.tuning.maximum_elixir]
    $Bottom/Stack/Elixir/ElixirBar.max_value = session.tuning.maximum_elixir
    $Bottom/Stack/Elixir/ElixirBar.value = session.elixir
    $Bottom/Stack/Meta/DrawLabel.text = "Draw · %s" % session.deck.draw_pile.size()
    $Bottom/Stack/Meta/EffectLabel.text = "Active · " + String(CardDefinition.Effect.keys()[session.ball.active_effect]).capitalize()
    $HintSlot/HintLabel.text = "Drag back · release to shoot · right-click cancel · 1–3 cards" if session.shots == 0 else "WASD move view · scroll zoom · Space follow ball"
    for slot: int in range(session.deck.hand.size()):
        var card: CardDefinition = session.deck.hand[slot]
        get_node("Bottom/Stack/Hand/Card%s" % slot).bind(card, session.deck.selected_slot == slot, session.elixir >= card.cost, str(slot + 1))
