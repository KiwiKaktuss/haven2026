class_name DeckModel
extends Node
## Owns piles; the session publishes hand_changed after a complete transaction.
signal hand_changed
@export var catalog: CardCatalog
var equipped: Array[StringName] = []
var hand: Array[CardDefinition] = []
var draw_pile: Array[CardDefinition] = []
var discard_pile: Array[CardDefinition] = []
var selected_slot: int = 0
var random: RandomNumberGenerator = RandomNumberGenerator.new()
## The replacement is reserved atomically, but cannot be played until dealt.
var replacement_remaining: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
var generation: int = 0

func slot_ready(slot: int) -> bool:
	return slot >= 0 and slot < hand.size() and replacement_remaining[slot] <= 0.0

func advance_deal(delta: float) -> void:
	for slot: int in range(replacement_remaining.size()):
		replacement_remaining[slot] = maxf(0.0, replacement_remaining[slot] - delta)

func valid_deck(ids: Array[StringName]) -> bool:
	if catalog == null or ids.size() != CardCatalog.DECK_SIZE:
		return false
	var seen: Array[StringName] = []
	for id: StringName in ids:
		if seen.has(id) or catalog.find_card(id) == null:
			return false
		seen.append(id)
	return true

func start_attempt(ids: Array[StringName] = []) -> bool:
	var chosen: Array[StringName] = ids
	if chosen.is_empty():
		chosen = equipped if valid_deck(equipped) else catalog.default_deck
	if not valid_deck(chosen):
		return false
	equipped = chosen.duplicate()
	generation += 1
	replacement_remaining.fill(0.0)
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	for id: StringName in equipped:
		draw_pile.append(catalog.find_card(id))
	_shuffle(draw_pile)
	for slot: int in range(3):
		hand.append(draw_pile.pop_back())
	selected_slot = 0
	hand_changed.emit()
	return true

func _shuffle(pile: Array[CardDefinition]) -> void:
	for index: int in range(pile.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var card: CardDefinition = pile[index]
		pile[index] = pile[other]
		pile[other] = card

func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= hand.size():
		return false
	selected_slot = slot
	hand_changed.emit()
	return true

func selected_card() -> CardDefinition:
	return hand[selected_slot] if selected_slot >= 0 and selected_slot < hand.size() else null

func cycle_selected(notify: bool = true) -> void:
	discard_pile.append(hand[selected_slot])
	if draw_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		_shuffle(draw_pile)
	hand[selected_slot] = draw_pile.pop_back()
	if notify:
		hand_changed.emit()
