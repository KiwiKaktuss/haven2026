extends Node2D
## Pixel-sized fire, animated on twos to match the course artwork.
const FRAME_COUNT: int = 12
const FRAME_RATE: float = 12.0
const FRAME_SIZE: Vector2i = Vector2i(40, 18)
const BASELINE: int = 17
const OUTLINE := Color("783b40")
const RED := Color("c65b3f")
const ORANGE := Color("ed8b45")
const GOLD := Color("f6c56b")
const CORE := Color("fff0bc")
var _time: float = 0.0
var _frame: int = 0
var _frames: Array[ImageTexture] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index: int in range(FRAME_COUNT):
		_frames.append(_make_frame(index))
	visibility_changed.connect(_restart)

func _restart() -> void:
	if is_visible_in_tree():
		_time = 0.0
		_frame = 0
		queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time = fmod(_time + delta, FRAME_COUNT / FRAME_RATE)
	var next_frame: int = int(_time * FRAME_RATE) % FRAME_COUNT
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()

func _draw() -> void:
	if not _frames.is_empty():
		draw_texture(_frames[_frame], Vector2(0, -BASELINE))

func _make_frame(index: int) -> ImageTexture:
	var mask := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	# Connected, asymmetric tongues. Integer rows keep every contour crisp.
	for x: int in range(3, 37):
		for y: int in range(BASELINE - 2, BASELINE + 1):
			mask.set_pixel(x, y, Color.WHITE)
	for tongue: int in range(5):
		var phase: float = TAU * float(index) / FRAME_COUNT + tongue * 1.9
		var height: int = 7 + roundi(sin(phase) * 2.0) + (2 if tongue == 2 else 0)
		var center: int = 6 + tongue * 7
		for rise: int in range(height):
			var taper: float = float(rise) / height
			var half_width: int = maxi(0, 3 - int(taper * 4.0))
			var sway: int = roundi(sin(phase + taper * 2.5) * taper * 2.0)
			for x: int in range(center + sway - half_width, center + sway + half_width + 1):
				mask.set_pixel(x, BASELINE - rise, Color.WHITE)
	var art := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in range(1, FRAME_SIZE.y):
		for x: int in range(1, FRAME_SIZE.x - 1):
			if mask.get_pixel(x, y).a == 0.0:
				continue
			var edge: bool = mask.get_pixel(x - 1, y).a == 0.0 or mask.get_pixel(x + 1, y).a == 0.0 or mask.get_pixel(x, y - 1).a == 0.0
			var rise: int = BASELINE - y
			var color: Color = RED if edge else ORANGE
			if edge and mask.get_pixel(x, y - 1).a > 0.0:
				color = OUTLINE
			elif not edge and rise <= 4:
				color = GOLD
				if rise <= 1 or (rise <= 3 and (x + index / 3) % 7 < 3):
					color = CORE
			art.set_pixel(x, y, color)
	# Two staggered embers peel away, then dim as they rise.
	for ember: int in range(2):
		var age: int = (index + ember * 6) % FRAME_COUNT
		if age >= 8:
			continue
		var x: int = 12 + ember * 15 + (1 if age >= 4 else 0)
		var y: int = 6 - age / 2
		art.set_pixel(x, y, GOLD if age < 4 else RED)
	return ImageTexture.create_from_image(art)
