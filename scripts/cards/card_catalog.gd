class_name CardCatalog
extends Resource
const DECK_SIZE: int = 5

@export var cards: Array[CardDefinition] = []
@export var default_deck: Array[StringName] = [&"classic", &"sniper", &"fire", &"slow", &"bounce"]

# The Gravity card retains the legacy "rewind" ID for saved decks.
func find_card(id: StringName) -> CardDefinition:
	for card: CardDefinition in cards:
		if card.id == id:
			return card
	return null
