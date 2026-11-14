class_name GolfBall
extends CharacterBody2D
signal effect_changed(effect: CardDefinition.Effect)
signal contacted(body: TerrainObject, normal: Vector2)
@export var tuning: GameTuning
@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var effect_animation: AnimationPlayer
@export var simulation_enabled: bool = true
var active_effect: CardDefinition.Effect = CardDefinition.Effect.CLASSIC
var safe_position: Vector2
var contact_body: TerrainObject
var contact_normal: Vector2 = Vector2.UP
var attached_body: TerrainObject
var local_anchor: Vector2
# velocity is relative to support while resting/rolling; world-space in flight.
var support_body: TerrainObject
var support_transform: Transform2D
var safe_contact_elapsed: float = 0.0
var departing_body: TerrainObject
var departure_normal: Vector2
var gravity_multiplier: float = 1.0
var bounce_retention: float = -1.0
var glue_enabled: bool = false

func _ready() -> void:
    safe_position = global_position

func world_velocity() -> Vector2:
    if is_instance_valid(attached_body):
        return attached_body.surface_velocity
    if is_instance_valid(support_body):
        return velocity + support_body.surface_velocity
    return velocity

## A caller must validate the action first. Failed actions never call this method.
func launch(impulse: Vector2, clear_momentum: bool = false) -> void:
    var momentum: Vector2 = Vector2.ZERO if clear_momentum else world_velocity()
    departing_body = contact_body
    departure_normal = contact_normal
    attached_body = null
    support_body = null
    contact_body = null
    safe_contact_elapsed = 0.0
    velocity = momentum + impulse

func reset_motion(at_position: Vector2) -> void:
    global_position = at_position
    velocity = Vector2.ZERO
    attached_body = null
    support_body = null
    contact_body = null
    departing_body = null
    safe_position = at_position
    safe_contact_elapsed = 0.0
    reset_physics_interpolation()

func _physics_process(delta: float) -> void:
    if simulation_enabled:
        step_motion(delta)

func step_motion(delta: float) -> void:
    if is_instance_valid(attached_body):
        global_position = attached_body.to_global(local_anchor)
        velocity = Vector2.ZERO
        _track_safe(delta)
        return
    var previous_support: TerrainObject = support_body if is_instance_valid(support_body) else null
    var carrier_velocity: Vector2 = Vector2.ZERO
    if previous_support != null:
        # Move with the support transform once; rolling uses relative velocity below.
        global_position = previous_support.global_transform * (support_transform.affine_inverse() * global_position)
        carrier_velocity = previous_support.surface_velocity
    support_body = null
    contact_body = null
    velocity = BallMotion.accelerate(velocity, tuning.gravity * gravity_multiplier, delta)
    var remaining: float = delta
    var friction_applied: bool = false
    for iteration: int in range(tuning.maximum_contacts_per_step):
        if remaining <= 0.000001 or velocity.length_squared() < 0.000001:
            break
        var motion: Vector2 = velocity * remaining
        var hit: KinematicCollision2D = move_and_collide(motion, false, tuning.collision_margin)
        if hit == null:
            break
        remaining *= clampf(hit.get_remainder().length() / maxf(motion.length(), 0.000001), 0.0, 1.0)
        var body: TerrainObject = hit.get_collider() as TerrainObject
        var normal: Vector2 = hit.get_normal()
        if body == null or body.surface == null:
            velocity = velocity.slide(normal)
            continue
        contact_body = body
        contact_normal = normal
        var relative: Vector2 = velocity + carrier_velocity - body.surface_velocity
        var incoming: float = relative.dot(normal)
        var leaving_old: bool = body == departing_body and relative.dot(departure_normal) >= -tuning.reattach_inward_speed
        if body != departing_body or incoming < -tuning.reattach_inward_speed:
            departing_body = null
            leaving_old = false
        contacted.emit(body, normal)
        if (glue_enabled or body.surface.attaches_on_contact) and not leaving_old:
            attached_body = body
            local_anchor = body.to_local(global_position)
            velocity = Vector2.ZERO
            _track_safe(delta)
            return
        relative = BallMotion.impact(relative, normal, body.surface, tuning, bounce_retention)
        var supports_gravity: bool = normal.dot(Vector2.UP) > tuning.minimum_support_dot
        var resting_contact: bool = supports_gravity and relative.dot(normal) < tuning.rest_speed
        if resting_contact:
            relative = relative.slide(normal)
            if not friction_applied:
                relative = BallMotion.friction(relative, normal, body.surface.friction, delta, tuning.rolling_stop_speed)
                friction_applied = true
            support_body = body
            support_transform = body.global_transform
            velocity = relative
            carrier_velocity = body.surface_velocity
        else:
            support_body = null
            # Once airborne, carry momentum is part of world velocity, exactly once.
            velocity = relative + body.surface_velocity
            carrier_velocity = Vector2.ZERO
        if hit.get_travel().length_squared() < 0.000001 and incoming >= 0.0:
            break
    if support_body == null and previous_support != null:
        velocity += carrier_velocity
    if is_instance_valid(departing_body):
        var touching: KinematicCollision2D = move_and_collide(-departure_normal * tuning.contact_probe, true, tuning.collision_margin)
        if touching == null or touching.get_collider() != departing_body:
            departing_body = null
    if support_body == null:
        contact_body = null
    _track_safe(delta)

func _track_safe(delta: float) -> void:
    if is_instance_valid(contact_body) and not contact_body.is_moving_surface():
        safe_contact_elapsed += delta
        if safe_contact_elapsed >= tuning.safe_contact_seconds:
            safe_position = global_position + contact_normal * tuning.safe_position_clearance
    else:
        safe_contact_elapsed = 0.0
