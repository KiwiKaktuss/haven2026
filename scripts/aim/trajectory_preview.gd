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
@export_range(0.1, 5.0) var horizon_seconds: float = 2.5
@export var line_screen_width: float = 2.0
@export_range(0.05, 1.0) var unaffordable_opacity: float = 0.3
var central: Dictionary = {}
var lower: Dictionary = {}
var upper: Dictionary = {}

func predict(ball: GolfBall, card: CardDefinition, drag: Vector2, angular_offset: float = 0.0) -> Dictionary:
    var at: Vector2 = ShotCalculation.origin(card, ball)
    var speed: Vector2 = ShotCalculation.velocity_after(card, ball, drag, ball.tuning, angular_offset)
    var points: PackedVector2Array = PackedVector2Array([at])
    var ghost_points: PackedVector2Array = PackedVector2Array()
    var gravity_multiplier: float = card.gravity_multiplier
    var armed: bool = card.effect == CardDefinition.Effect.GHOST
    var passing: TerrainObject
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
    var dt: float = 1.0 / Engine.physics_ticks_per_second
    for tick: int in range(ceili(horizon_seconds / dt)):
        speed = BallMotion.accelerate(speed, ball.tuning.gravity * gravity_multiplier, dt)
        var motion: Vector2 = speed * dt
        probe.global_position = at
        var hit: KinematicCollision2D = probe.move_and_collide(motion, true, ball.tuning.collision_margin)
        if armed and hit != null and TerrainQuery.enters(motion, hit.get_normal()):
            passing = hit.get_collider() as TerrainObject
            if passing != null:
                armed = false
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
                gravity_multiplier = 1.0
    for body: PhysicsBody2D in probe.get_collision_exceptions():
        probe.remove_collision_exception_with(body)
    return {"points": points, "ghost_points": ghost_points, "ignored_id": ignored_id, "collider": collided, "hit_step": hit_step, "ghost_entry_step": ghost_entry_step}

func refresh(ball: GolfBall, card: CardDefinition, drag: Vector2, affordable: bool, zoom: float) -> void:
    central = predict(ball, card, drag)
    var spread: float = ShotCalculation.spread(card, ShotCalculation.strength(drag, ball.tuning))
    lower = predict(ball, card, drag, -spread)
    upper = predict(ball, card, drag, spread)
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

func _local_points(world_points: PackedVector2Array) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array()
    for point: Vector2 in world_points:
        result.append(to_local(point))
    return result

func _build_envelope(left: PackedVector2Array, right: PackedVector2Array) -> void:
    # Independent triangles remain drawable when paths turn or terminate on
    # different surfaces. A single closed contour can intersect itself there.
    var vertices: PackedVector2Array = PackedVector2Array()
    var sections: Array[PackedInt32Array] = []
    for index: int in range(1, maxi(left.size(), right.size())):
        var quad: PackedVector2Array = PackedVector2Array([
            to_local(left[mini(index - 1, left.size() - 1)]),
            to_local(left[mini(index, left.size() - 1)]),
            to_local(right[mini(index, right.size() - 1)]),
            to_local(right[mini(index - 1, right.size() - 1)])])
        var base: int = vertices.size()
        vertices.append_array(quad)
        if absf((quad[1] - quad[0]).cross(quad[2] - quad[0])) > 0.000001:
            sections.append(PackedInt32Array([base, base + 1, base + 2]))
        if absf((quad[2] - quad[0]).cross(quad[3] - quad[0])) > 0.000001:
            sections.append(PackedInt32Array([base, base + 2, base + 3]))
    envelope.polygon = vertices
    envelope.polygons = sections
    envelope.visible = not sections.is_empty()
