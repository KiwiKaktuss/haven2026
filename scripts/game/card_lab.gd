extends "res://scripts/game/physics_lab.gd"
## Physics/card/aim verification fixture. Reset/deck selectors are debug controls.
@export var aim: AimController
@export var camera_controller: CourseCamera
@export var session: GameSession
@export var hand_buttons: Array[Button] = []
@export var status: Label
@export var fixture_selector: OptionButton
@export var deck_selector: OptionButton
@export var trial_starts: Array[Vector2] = [Vector2(48, 70), Vector2(160, 70), Vector2(272, 70), Vector2(384, 70), Vector2(496, 250)]
@export var debug_drag: Vector2 = Vector2(-36, 80)
@export var alternate_deck: Array[StringName] = [&"classic", &"heavy", &"dash", &"ghost", &"rewind", &"glue"]

func _ready() -> void:
    super._ready()
    for demo: GolfBall in balls:
        demo.simulation_enabled = demo == session.ball
        demo.visible = demo == session.ball
    for slot: int in range(hand_buttons.size()):
        hand_buttons[slot].pressed.connect(session.deck.select_slot.bind(slot))
    session.deck.hand_changed.connect(_refresh)
    session.elixir_changed.connect(func(_amount: float) -> void: _refresh())
    fixture_selector.item_selected.connect(func(_index: int) -> void: reset_lab())
    deck_selector.item_selected.connect(func(_index: int) -> void: reset_lab())
    reset_lab()

func reset_lab() -> void:
    aim.cancel()
    session.ball.reset_motion(trial_starts[fixture_selector.selected])
    session.deck.equipped = session.deck.catalog.default_deck.duplicate() if deck_selector.selected == 0 else alternate_deck.duplicate()
    session.start_attempt()
    camera_controller.recenter(true)
    _refresh()

func launch_all() -> void:
    session.try_shot(debug_drag)
    _refresh()

func _process(_delta: float) -> void:
    _refresh()

func _refresh() -> void:
    for slot: int in range(hand_buttons.size()):
        var card: CardDefinition = session.deck.hand[slot]
        hand_buttons[slot].text = "%s%s · %s" % ["> " if session.deck.selected_slot == slot else "", card.display_name, card.cost]
    status.text = "Elixir %.1f / %s   Shots %s   Time %.1fs   Active: %s\nDraw %s   |   %s" % [session.elixir, session.tuning.maximum_elixir, session.shots, session.elapsed_seconds, CardDefinition.Effect.keys()[session.ball.active_effect], session.deck.draw_pile.size(), session.deck.selected_card().description]

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"lab_reset"):
        reset_lab()
        get_viewport().set_input_as_handled()

func _on_exit_pressed() -> void:
    aim.cancel()
    super._on_exit_pressed()
