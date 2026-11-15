class_name HoleLocator
extends Node2D
## Screen-space marker: only the arrow rotates; the flag is an upright sibling.
@export var edge_padding: Vector4 = Vector4(40, 80, 40, 176)
var session: GameSession
@onready var _arrow: Sprite2D = $Arrow

func _process(_delta: float) -> void:
	update_locator()

func update_locator() -> void:
	if session == null or not is_instance_valid(session.course) or not is_instance_valid(session.course.goal_cup):
		hide()
		return
	var cup: GoalCup = session.course.goal_cup
	if not cup.is_visible_in_tree() or session.state not in [GameSession.State.READY, GameSession.State.PLAYING]:
		hide()
		return
	# Use the rendered canvas transform so panning, zoom and camera shake agree
	# with the hole's actual on-screen position, including stretched windows.
	var canvas_to_hud: Transform2D = get_parent().get_global_transform_with_canvas().affine_inverse()
	var target: Vector2 = canvas_to_hud * (cup.get_global_transform_with_canvas() * Vector2(32, 0))
	var screen: Rect2 = canvas_to_hud * get_viewport_rect()
	if screen.has_point(target):
		hide()
		return
	var safe: Rect2 = Rect2(screen.position + Vector2(edge_padding.x, edge_padding.y), screen.size - Vector2(edge_padding.x + edge_padding.z, edge_padding.y + edge_padding.w))
	if not safe.has_area():
		hide()
		return
	var origin: Vector2 = screen.get_center()
	var direction: Vector2 = target - origin
	var along_x: float = INF
	var along_y: float = INF
	if not is_zero_approx(direction.x):
		along_x = ((safe.end.x if direction.x > 0.0 else safe.position.x) - origin.x) / direction.x
	if not is_zero_approx(direction.y):
		along_y = ((safe.end.y if direction.y > 0.0 else safe.position.y) - origin.y) / direction.y
	position = origin + direction * minf(along_x, along_y)
	# The supplied arrow texture points down in its unrotated pose.
	_arrow.rotation = direction.angle() - PI * 0.5
	show()
