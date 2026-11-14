class_name DeckModel
extends Node
## Pile mutation and conservation rules are implemented in plan step 3.
signal hand_changed
@export var catalog: CardCatalog
var hand: Array[CardDefinition] = []
var draw_pile: Array[CardDefinition] = []
var discard_pile: Array[CardDefinition] = []
