extends Node2D
## Small animated flame tongues, drawn in the meter's screen-sized coordinates.
var _time: float = 0.0

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()

func _draw() -> void:
	for index: int in range(5):
		var phase: float = _time * 7.0 + index * 2.3
		var x: float = 7.0 + index * 6.5
		var height: float = 2.0 + (sin(phase) * 0.5 + 0.5) * 2.5
		var sway: float = sin(phase * 0.7) * 0.6
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 1.6, 1.0), Vector2(x - 1.1, -height * 0.35),
			Vector2(x + sway, -height), Vector2(x + 1.2, -height * 0.25),
			Vector2(x + 1.6, 1.0)]), Color(0.89, 0.42, 0.19, 0.65))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 0.7, 0.5), Vector2(x + sway * 0.5, -height * 0.45),
			Vector2(x + 0.7, 0.5)]), Color(0.96, 0.7, 0.34, 0.75))
