class_name BallMotion
extends RefCounted
## Shared pure calculations for live motion and the future trajectory preview.
static func accelerate(current: Vector2, gravity: float, delta: float) -> Vector2:
    return current + Vector2.DOWN * gravity * delta

static func impact(relative_velocity: Vector2, normal: Vector2, surface: SurfaceDefinition, tuning: GameTuning, retention: float = -1.0) -> Vector2:
    var inward: float = relative_velocity.dot(normal)
    if inward >= 0.0:
        return relative_velocity
    var tangent: Vector2 = relative_velocity - normal * inward
    var bounce: float = surface.bounce if retention < 0.0 else retention
    var outward: float = -inward * bounce
    if -inward < tuning.bounce_threshold:
        outward = 0.0
    if surface.material == SurfaceDefinition.SurfaceMaterial.BOUNCY:
        outward = maxf(outward * surface.launch_multiplier, surface.minimum_launch_speed)
    return tangent + normal * outward

static func friction(relative_velocity: Vector2, normal: Vector2, rate: float, delta: float, stop_speed: float) -> Vector2:
    var tangent: Vector2 = relative_velocity.slide(normal) * exp(-rate * delta)
    if tangent.length() < stop_speed:
        tangent = Vector2.ZERO
    return tangent + normal * maxf(0.0, relative_velocity.dot(normal))
