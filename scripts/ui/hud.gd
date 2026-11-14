class_name GameHUD
extends Control
signal pause_requested
@export var flight_scene: PackedScene
@export_range(0.1, 0.8) var played_flight_seconds: float = 0.38
var session: GameSession
var _pending: Dictionary = {}
var _generation: int = -1

static func format_time(seconds: float) -> String:
	var centiseconds: int = floori(seconds * 100)
	return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func configure(value: GameSession, _title: String) -> void:
	session = value
	for slot: int in range(3):
		get_node("Bottom/Stack/Hand/Card%s" % slot).pressed.connect(_select.bind(slot))
	session.card_presented.connect(_play_card)
	session.shot_rejected.connect(_reject)
	refresh()

func _select(slot: int) -> void:
	if session.deck.slot_ready(slot):
		session.deck.select_slot(slot)
	else:
		_reject(slot)

func _reject(slot: int) -> void:
	get_node("Bottom/Stack/Hand/Card%s" % slot).reject_play()
	$Bottom/Stack/Elixir/AnimationPlayer.play(&"reject")

func _play_card(card: CardDefinition, slot: int, at: Vector2) -> void:
	# A reset and a shot can occur before the next rendered frame.
	refresh()
	var view: CardView = get_node("Bottom/Stack/Hand/Card%s" % slot)
	var artwork: Control = view.get_node("Artwork")
	var flight: CardFlight = flight_scene.instantiate()
	$Flights.add_child(flight)
	# The release position is in viewport coordinates, matching this canvas.
	flight.begin(card, artwork.get_global_rect().get_center(), at, artwork.get_global_rect().size, played_flight_seconds, false)
	_pending[slot] = {"dealing": false}
	view.set_deal_pending(true)
	$Bottom/Stack/Elixir/AnimationPlayer.play(&"spend")
	refresh()

func _process(_delta: float) -> void:
	if session != null:
		refresh()

func refresh() -> void:
	if _generation != session.deck.generation:
		_generation = session.deck.generation
		_pending.clear()
		for child: Node in $Flights.get_children():
			child.queue_free()
	$Top/TimerSlot/TimerLabel.text = "%d:%02d" % [floori(session.elapsed_seconds) / 60, floori(session.elapsed_seconds) % 60]
	$Bottom/Stack/Elixir/ElixirBar.max_value = session.tuning.maximum_elixir
	$Bottom/Stack/Elixir/ElixirBar.value = session.elixir
	for slot: int in range(session.deck.hand.size()):
		var card: CardDefinition = session.deck.hand[slot]
		var view: CardView = get_node("Bottom/Stack/Hand/Card%s" % slot)
		var ready: bool = session.deck.slot_ready(slot)
		view.bind(card, session.deck.selected_slot == slot, session.elixir >= card.cost)
		view.set_deal_pending(not ready)
		if _pending.has(slot):
			if _pending[slot].has("flight") and is_instance_valid(_pending[slot].flight):
				_pending[slot].flight.destination = view.get_node("Artwork").get_global_rect().get_center()
			if ready:
				_pending.erase(slot)
				view.land()
			elif not _pending[slot].dealing and session.deck.replacement_remaining[slot] <= session.tuning.card_deal_seconds:
				_pending[slot].dealing = true
				var artwork: Control = view.get_node("Artwork")
				var flight: CardFlight = flight_scene.instantiate()
				$Flights.add_child(flight)
				_pending[slot].flight = flight
				flight.begin(card, $Bottom/Stack/DeckPile.get_global_rect().get_center(), artwork.get_global_rect().get_center(), artwork.get_global_rect().size, session.deck.replacement_remaining[slot], true)
				$Bottom/Stack/DeckPile/AnimationPlayer.play(&"deal")
