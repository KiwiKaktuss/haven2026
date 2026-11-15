extends SceneTree
## Offline cover authoring: save real, editor-editable TileMapLayers.
const COVER := "res://scenes/promo/game_cover.tscn"
const TILESET := preload("res://resources/terrain/terrain_tileset.tres")

func _initialize() -> void:
	var scene: Control = load(COVER).instantiate()
	for title: String in ["LaunchPlatform", "StickyPlatform"]:
		var previous := scene.get_node_or_null(title)
		if previous != null:
			scene.remove_child(previous)
			previous.free()
	platform(scene, "LaunchPlatform", Vector2(-24, 366), 9, 3, 0)
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed, COVER)
	scene.free()
	quit(result)

func platform(scene: Control, title: String, at: Vector2, width: int, height: int, band: int) -> void:
	var layer := TileMapLayer.new()
	layer.name = title
	layer.position = at
	layer.scale = Vector2(3, 3)
	layer.tile_set = TILESET
	layer.collision_enabled = false
	scene.add_child(layer)
	layer.owner = scene
	# Behind the cards, above the background.
	scene.move_child(layer, 1)
	for y: int in range(height):
		for x: int in range(width):
			# Identical edge/corner mapping to tools/build_first_fairway.gd.
			var uv := Vector2i(4, 1)
			if y == 0:
				uv = Vector2i(2, 2) if x == 0 else (Vector2i(3, 2) if x == width - 1 else Vector2i(2, 4))
			elif y == height - 1:
				uv = Vector2i(2, 3) if x == 0 else (Vector2i(3, 3) if x == width - 1 else Vector2i(3, 4))
			elif x == 0:
				uv = Vector2i(0, 4)
			elif x == width - 1:
				uv = Vector2i(1, 4)
			# Solid interiors use the game's full-fill atlas, just like the course.
			if uv == Vector2i(4, 1):
				layer.set_cell(Vector2i(x, y), 1, Vector2i((band / 5) % 2, (band / 5) / 2))
			else:
				layer.set_cell(Vector2i(x, y), 0, uv + Vector2i(0, band))
