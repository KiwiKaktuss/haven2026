@tool
extends "res://scripts/promo/game_cover.gd"
## Let the actual itch page background show through around the logo.
func _ready() -> void:
	get_node("Background").hide()
	super._ready()
