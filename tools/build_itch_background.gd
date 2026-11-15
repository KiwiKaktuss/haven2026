extends SceneTree
## Author the editable itch background from gameplay TileSets and sprites.
## Build: Godot --headless --path . --script tools/build_itch_background.gd
## Render: Godot --path . scenes/promo/itch_background.tscn -- --export-cover
const TERRAIN = preload("res://resources/terrain/terrain_tileset.tres")
var artwork: Control

func own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = artwork

func sprite(parent: Node, title: String, path: String, at: Vector2, region: Rect2 = Rect2(), zoom: float = 4.0) -> Sprite2D:
	var item := Sprite2D.new()
	item.name = title
	item.position = at
	item.scale = Vector2.ONE * zoom
	item.texture = load(path)
	item.centered = false
	if region.has_area():
		item.region_enabled = true
		item.region_rect = region
	own(parent, item)
	return item

func detail(parent: Node, title: String, at: Vector2, uv: Vector2i, path: String = "res://art/coast_tiles.svg", zoom: float = 4.0) -> void:
	sprite(parent, title, path, at, Rect2(Vector2(uv * 16), Vector2(16, 16)), zoom)

func platform(parent: Node, title: String, at: Vector2, w: int, h: int, material: int = 0, zoom: float = 4.0) -> void:
	var tiles := TileMapLayer.new()
	tiles.name = title
	tiles.tile_set = TERRAIN
	tiles.position = at
	tiles.scale = Vector2.ONE * zoom
	tiles.collision_enabled = false
	own(parent, tiles)
	for y in h:
		for x in w:
			var uv := Vector2i(4, 1)
			if h == 1:
				uv = Vector2i(0, 1) if x == 0 else (Vector2i(2, 1) if x == w - 1 else Vector2i(0, 2))
			elif y == 0:
				uv = Vector2i(2, 2) if x == 0 else (Vector2i(3, 2) if x == w - 1 else Vector2i(2, 4))
			elif y == h - 1:
				uv = Vector2i(2, 3) if x == 0 else (Vector2i(3, 3) if x == w - 1 else Vector2i(3, 4))
			elif x == 0:
				uv = Vector2i(0, 4)
			elif x == w - 1:
				uv = Vector2i(1, 4)
			if uv == Vector2i(4, 1):
				tiles.set_cell(Vector2i(x, y), 1, Vector2i(material % 2, material / 2))
			else:
				tiles.set_cell(Vector2i(x, y), 0, uv + Vector2i(0, material * 5))

func side(title: String, x: float) -> Control:
	var panel := Control.new()
	panel.name = title
	panel.position.x = x
	panel.size = Vector2(480, 1080)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own(artwork, panel)
	# Only the side columns receive atmosphere; the center is completely plain.
	var atmosphere := TextureRect.new()
	atmosphere.name = "GameplayAtmosphere"
	atmosphere.size = panel.size
	atmosphere.texture = load("res://art/background2.png")
	atmosphere.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	atmosphere.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	atmosphere.modulate = Color(1, 1, 1, 0.06)
	own(panel, atmosphere)
	# Feather the side texture into the reserved center without a visible seam.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform bool right_side = false; void fragment() { vec4 c = texture(TEXTURE, UV); float fade = right_side ? smoothstep(0.0, 0.65, UV.x) : 1.0 - smoothstep(0.35, 1.0, UV.x); COLOR = c * COLOR * vec4(1.0, 1.0, 1.0, fade); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("right_side", x > 0)
	atmosphere.material = material
	return panel

func sea(parent: Node, at: Vector2) -> void:
	# Static atlas regions freeze the water animation for reproducible artwork.
	for y in 4:
		for x in 9:
			var uv := Vector2i(x % 4, 0) if y == 0 else Vector2i(x % 8, mini(5, y + 1))
			sprite(parent, "Water%d_%d" % [x, y], "res://art/coast_tiles.svg", at + Vector2(x * 64, y * 64), Rect2(Vector2(uv * 16), Vector2(16, 16)))

func _initialize() -> void:
	artwork = Control.new()
	artwork.name = "ItchBackground"
	artwork.size = Vector2(1920, 1080)
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.clip_contents = true
	artwork.set_script(load("res://scripts/promo/game_cover.gd"))
	artwork.set("artwork_size", Vector2i(1920, 1080))
	artwork.set("output_path", "res://art/promo/deck_golf_itch_background_1920x1080.png")
	artwork.set_meta("center_safe_area", Rect2i(480, 0, 960, 1080))
	var sky := ColorRect.new()
	sky.name = "PlainSky"
	sky.size = artwork.size
	sky.color = Color(0.95, 0.98, 0.95, 1)
	own(artwork, sky)
	var left := side("LeftCoastalCourse", 0)
	var right := side("RightSummitCourse", 1440)
	# Distant clouds and scenery use the very same coast sprites as the courses.
	detail(left, "HighCloud", Vector2(252, 64), Vector2i(11, 2), "res://art/coast_tiles.svg", 5)
	detail(left, "LowCloud", Vector2(-32, 448), Vector2i(11, 2), "res://art/coast_tiles.svg", 6)
	detail(right, "HighCloud", Vector2(28, 100), Vector2i(11, 2), "res://art/coast_tiles.svg", 5)
	detail(right, "LowCloud", Vector2(300, 452), Vector2i(11, 2), "res://art/coast_tiles.svg", 6)
	sea(left, Vector2(-80, 1008))
	sea(right, Vector2(-16, 1024))
	platform(left, "HighFairway", Vector2(-48, 280), 11, 3)
	detail(left, "FairwayGrass", Vector2(4, 216), Vector2i(8, 0))
	detail(left, "FairwayFlowers", Vector2(196, 216), Vector2i(9, 0))
	detail(left, "FairwayVines", Vector2(164, 376), Vector2i(12, 0))
	sprite(left, "BallOnTee", "res://art/ball.png", Vector2(120, 264))
	platform(left, "SteppingStone", Vector2(260, 520), 5, 2)
	detail(left, "DirectionSign", Vector2(292, 456), Vector2i(5, 0), "res://art/spring_works_scenery.svg")
	platform(left, "LowerCoast", Vector2(-64, 784), 12, 4)
	detail(left, "CoastalReeds", Vector2(20, 720), Vector2i(11, 0))
	detail(left, "CoastalFlowers", Vector2(232, 720), Vector2i(3, 0), "res://art/spring_works_scenery.svg")
	detail(left, "CoastalVines", Vector2(112, 912), Vector2i(12, 0))
	platform(left, "LowSteppingStone", Vector2(352, 948), 3, 1)
	# The summit beacon and frosted trees are original Final Ascent / Cold Snap art.
	platform(right, "Summit", Vector2(208, 300), 11, 3)
	sprite(right, "SummitBeacon", "res://art/final_ascent_scenery.svg", Vector2(244, 108))
	detail(right, "SummitFlowers", Vector2(400, 236), Vector2i(3, 0), "res://art/spring_works_scenery.svg")
	platform(right, "IceLanding", Vector2(48, 548), 7, 3, 2)
	detail(right, "FrostPine", Vector2(76, 484), Vector2i(0, 0), "res://art/cold_snap_scenery.svg")
	detail(right, "FrostCrystals", Vector2(204, 484), Vector2i(1, 0), "res://art/cold_snap_scenery.svg")
	detail(right, "Icicles", Vector2(140, 644), Vector2i(2, 0), "res://art/cold_snap_scenery.svg")
	platform(right, "SpringStep", Vector2(324, 716), 5, 2, 3)
	# Reuse the exact in-game cup geometry and flag, with no gameplay scripts.
	var cup: Node = load("res://scenes/terrain/cup_terrain.tscn").instantiate()
	var cup_art := Node2D.new()
	cup_art.name = "GoalCup"
	cup_art.position = Vector2(160, 924)
	cup_art.scale = Vector2(4, 4)
	own(right, cup_art)
	for title in ["Tiles", "HoleSprite", "FlagSprite"]:
		var node: Node = cup.get_node(title).duplicate()
		# A negative gameplay z-index would put the flag behind this artwork's sky.
		node.z_index = 0
		own(cup_art, node)
	cup.free()
	# A pair of cards quietly connects the scenery to Deck Golf's central mechanic.
	var classic := sprite(left, "ClassicCard", "res://art/cards2.png", Vector2(24, 966), Rect2(44, 0, 22, 31), 3)
	classic.rotation = -0.18
	var bounce := sprite(right, "BounceCard", "res://art/cards2.png", Vector2(402, 968), Rect2(0, 31, 22, 31), 3)
	bounce.rotation = 0.18
	var packed := PackedScene.new()
	assert(packed.pack(artwork) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/promo/itch_background.tscn") == OK)
	artwork.free()
	print("Saved itch background: 1920 x 1080; blank center x=480..1439.")
	quit()
