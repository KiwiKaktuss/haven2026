@tool
extends Control
## Sprite-0011 is an atlas: hills, mountains, clouds, then sky.
## Speeds are atlas pixels per second; lower atlas rows drift more slowly.

const ATLAS: Texture2D = preload("res://art/Sprite-0011.png")
const STRIP_WIDTH: float = 512.0
const STRIP_HEIGHT: float = 128.0
const HILLS_COLOR: Color = Color8(50, 132, 100)
const MOUNTAINS_COLOR: Color = Color8(43, 78, 149)

@export_range(0.0, 20.0, 0.1) var hills_speed: float = 6.0
@export_range(0.0, 20.0, 0.1) var mountains_speed: float = 3.0
@export_range(0.0, 20.0, 0.1) var clouds_speed: float = 1.4
@export_range(0.0, 20.0, 0.1) var sky_speed: float = 0.35

var _offsets: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    clip_contents = true
    resized.connect(queue_redraw)
    set_process(not Engine.is_editor_hint())
    queue_redraw()

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    var speeds: PackedFloat64Array = PackedFloat64Array([
        sky_speed, clouds_speed, mountains_speed, hills_speed,
    ])
    for layer: int in range(_offsets.size()):
        # Wrap each layer separately to keep long-running menus stable.
        _offsets[layer] = fposmod(_offsets[layer] + speeds[layer] * delta, STRIP_WIDTH)
    queue_redraw()

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    # One shared scale keeps the landscape proportional on tall and wide windows.
    var art_scale: float = maxf(2.0, size.y / 256.0)
    var strip_height: float = STRIP_HEIGHT * art_scale
    _draw_strip(0, Rect2(0, 384, STRIP_WIDTH, 138), 0.0, size.y, art_scale)
    # Soften the atlas's high-contrast sky dithering behind the menu.
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.91, 0.93, 1.0, 0.78))
    _draw_strip(1, Rect2(0, 256, STRIP_WIDTH, STRIP_HEIGHT), size.y * 0.18, strip_height, art_scale)
    var mountain_bottom: float = size.y * 0.74
    draw_rect(Rect2(0, mountain_bottom, size.x, size.y - mountain_bottom), MOUNTAINS_COLOR)
    _draw_strip(2, Rect2(0, 128, STRIP_WIDTH, STRIP_HEIGHT), mountain_bottom - strip_height, strip_height, art_scale)
    var hills_bottom: float = size.y * 0.88
    draw_rect(Rect2(0, hills_bottom, size.x, size.y - hills_bottom), HILLS_COLOR)
    _draw_strip(3, Rect2(0, 0, STRIP_WIDTH, STRIP_HEIGHT), hills_bottom - strip_height, strip_height, art_scale)

func _draw_strip(layer: int, source: Rect2, top: float, height: float, art_scale: float) -> void:
    var tile_width: float = STRIP_WIDTH * art_scale
    var left: float = -_offsets[layer] * art_scale
    while left < size.x:
        # Adjacent copies share an edge, so wrapping never exposes an empty gap.
        draw_texture_rect_region(ATLAS, Rect2(left, top, tile_width, height), source)
        left += tile_width
