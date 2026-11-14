class_name CardCatalog
extends Resource
@export var cards: Array[CardDefinition] = []
@export var default_deck: Array[StringName] = [&"classic", &"sniper", &"fire", &"slow", &"bounce", &"glue"]

func find_card(id: StringName) -> CardDefinition:
    for card: CardDefinition in cards:
        if card.id == id:
            return card
    return null
