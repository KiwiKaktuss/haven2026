class_name TrajectoryPreview
extends Node2D
## The saved, invisible probe performs the same swept circle query as live motion.
## Geometry is sampled at its CURRENT transform; future platform motion is uncertain.
@export var probe: CharacterBody2D
@export var probe_shape: CollisionShape2D
@export var central_line: Line2D
@export var envelope: Polygon2D
@export var origin_marker: Line2D
@export var ghost_marker: Line2D
## Includes a full-strength vertical Fireball's ascent and return.
@export_range(0.1, 5.0) var horizon_seconds: float = 4.0
@export var line_screen_width: float = 2.0
## Allow imprecise cards to show meaningful spread without covering the course.
@export var maximum_spread_screen_width: float = 96.0
@export_range(0.05, 1.0) var unaffordable_opacity: float = 0.3
var central: Dictionary = {}
var lower: Dictionary = {}
var upper: Dictionary = {}
var _screen_scale: float = 1.0
var _last_query_frame: int = -1
var _last_query_key: Array = []

func _ready() -> void:
	central_line.antialiased = true
	central_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	central_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var fade := Gradient.new()
	fade.set_color(0, Color(0.18, 0.43, 0.32, 0.95))
	fade.set_color(1, Color(0.18, 0.43, 0.32, 0.4))
	central_line.gradient = fade
	ghost_marker.antialiased = true

func _draw() -> void:
	if central.is_empty() or central.points.size() < 2:
		return
	var endpoint: Vector2 = to_local(central.points[-1])
	var color := Color(0.18, 0.43, 0.32, 0.85)
	if central.hit_step >= 0:
		draw_circle(endpoint, 3.5 * _screen_scale, Color(0.94, 1.0, 0.95, 0.9))
		draw_arc(endpoint, 3.5 * _screen_scale, 0, TAU, 24, color, 1.3 * _screen_scale, true)
	else:
		draw_circle(endpoint, 1.8 * _screen_scale, Color(0.18, 0.43, 0.32, 0.4))

func predict(ball: GolfBall, card: CardDefinition, drag: Vector2, angular_offset: float = 0.0, max_steps: int = -1) -> Dictionary:
	var at: Vector2 = ShotCalculation.origin(card, ball)
	var speed: Vector2 = ShotCalculation.velocity_after(card, ball, drag, ball.tuning, angular_offset)
	var points: PackedVector2Array = PackedVector2Array([at])
	var ghost_points: PackedVector2Array = PackedVector2Array()
	var gravity_multiplier: float = card.gravity_multiplier
	var armed: bool = card.effect == CardDefinition.Effect.GHOST
	var passing: TerrainObject
	var passage_expires_effect: bool = false
	var ignored_id: StringName
	var collided: TerrainObject
	var hit_step: int = -1
	var ghost_entry_step: int = -1
	probe.global_transform = ball.global_transform
	probe_shape.shape = ball.collision_shape.shape
	probe_shape.transform = ball.collision_shape.transform
	probe.collision_mask = ball.collision_mask
	for body: PhysicsBody2D in probe.get_collision_exceptions():
		probe.remove_collision_exception_with(body)
	probe.global_position = at
	if ball.ghost_state == GolfBall.GhostState.PASSING and is_instance_valid(ball.ghost_body) and TerrainQuery.overlaps(probe_shape.shape, probe_shape.global_transform, ball.ghost_body):
		passing = ball.ghost_body
		ignored_id = passing.object_id
		ghost_entry_step = 0
		ghost_points.append(at)
		probe.add_collision_exception_with(passing)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var steps: int = ceili(horizon_seconds / dt)
	if max_steps >= 0:
		steps = mini(steps, max_steps)
	for tick: int in range(steps):
		if not armed and passing == null:
			for cup: GoalCup in get_tree().get_nodes_in_group(&"goal_cups"):
				speed = cup.attract_velocity(at, speed, dt)
		speed = BallMotion.accelerate(speed, ball.tuning.gravity * gravity_multiplier, dt)
		var motion: Vector2 = speed * dt
		probe.global_position = at
		var hit: KinematicCollision2D = probe.move_and_collide(motion, true, ball.tuning.collision_margin)
		if armed and passing == null and hit != null and TerrainQuery.enters(motion, hit.get_normal()):
			passing = hit.get_collider() as TerrainObject
			if passing != null:
				armed = false
				passage_expires_effect = true
				ghost_entry_step = tick
				ignored_id = passing.object_id
				probe.add_collision_exception_with(passing)
				ghost_points.append(at + hit.get_travel())
				hit = probe.move_and_collide(motion, true, ball.tuning.collision_margin)
		if hit != null:
			at += hit.get_travel()
			points.append(at)
			collided = hit.get_collider() as TerrainObject
			hit_step = tick
			if passing != null:
				ghost_points.append(at)
			break
		at += motion
		points.append(at)
		if passing != null:
			ghost_points.append(at)
			probe.global_position = at
			if not TerrainQuery.overlaps(probe_shape.shape, probe_shape.global_transform, passing):
				probe.remove_collision_exception_with(passing)
				passing = null
				if passage_expires_effect:
					gravity_multiplier = 1.0
	for body: PhysicsBody2D in probe.get_collision_exceptions():
		probe.remove_collision_exception_with(body)
	return {"points": points, "ghost_points": ghost_points, "ignored_id": ignored_id, "collider": collided, "hit_step": hit_step, "ghost_entry_step": ghost_entry_step}

func refresh(ball: GolfBall, card: CardDefinition, drag: Vector2, affordable: bool, zoom: float) -> void:
	# Signals can request the identical query several times in one physics frame.
	# Never cache across ticks: moving terrain and the ball must stay current.
	var key: Array = [ball, card, drag, ball.global_position, ball.world_velocity(), ball.safe_position]
	var frame: int = Engine.get_physics_frames()
	if frame != _last_query_frame or key != _last_query_key:
		central = predict(ball, card, drag)
		var spread: float = ShotCalculation.spread(card, ShotCalculation.strength(drag, ball.tuning))
		lower = predict(ball, card, drag, -spread, central.points.size() - 1) if spread > 0.00001 else central
		upper = predict(ball, card, drag, spread, central.points.size() - 1) if spread > 0.00001 else central
		_last_query_frame = frame
		_last_query_key = key
	_screen_scale = 1.0 / maxf(zoom, 0.001)
	central_line.points = _local_points(central.points)
	_build_envelope(lower.points, upper.points)
	ghost_marker.points = _local_points(central.ghost_points)
	origin_marker.position = to_local(ShotCalculation.origin(card, ball))
	var scale_factor: float = 1.0 / maxf(zoom, 0.001)
	central_line.width = line_screen_width * scale_factor
	ghost_marker.width = line_screen_width * 2.0 * scale_factor
	origin_marker.scale = Vector2.ONE * scale_factor
	modulate.a = 1.0 if affordable else unaffordable_opacity
	visible = true
	queue_redraw()

func _local_points(world_points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in world_points:
		result.append(to_local(point))
	return result

func _build_envelope(left: PackedVector2Array, right: PackedVector2Array) -> void:
	# A bounded ribbon follows only the shared, collision-free part of the
	# predictions. Never join a stopped endpoint to a still-flying boundary.
	var count: int = mini(central.points.size(), mini(left.size(), right.size()))
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var sections: Array[PackedInt32Array] = []
	for index: int in range(count):
		var center: Vector2 = central.points[index]
		var before: Vector2 = central.points[maxi(0, index - 1)]
		var after: Vector2 = central.points[mini(central.points.size() - 1, index + 1)]
		var normal: Vector2 = (after - before).normalized().orthogonal()
		var half_width: float = minf(left[index].distance_to(right[index]) * 0.5, maximum_spread_screen_width * 0.5 * _screen_scale)
		var progress: float = float(index) / maxf(count - 1, 1)
		# Taper both ends so the spread never ends with a blunt cut.
		half_width *= minf(1.0, (1.0 - progress) * 8.0)
		vertices.append(to_local(center + normal * half_width))
		vertices.append(to_local(center - normal * half_width))
		var tint := Color(0.42, 0.73, 0.53, 0.22 * (1.0 - progress * 0.7))
		colors.append(tint)
		colors.append(tint)
		if index == 0:
			continue
		var base: int = index * 2
		for triangle: PackedInt32Array in [PackedInt32Array([base - 2, base, base + 1]), PackedInt32Array([base - 2, base + 1, base - 1])]:
			if absf((vertices[triangle[1]] - vertices[triangle[0]]).cross(vertices[triangle[2]] - vertices[triangle[0]])) > 0.000001:
				sections.append(triangle)
	envelope.color = Color.WHITE
	envelope.polygon = vertices
	envelope.vertex_colors = colors
	envelope.polygons = sections
	envelope.visible = not sections.is_empty()
