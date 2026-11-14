class_name TerrainQuery
extends RefCounted
## Shared whole-body overlap rule for live Ghost and trajectory simulation.
static func overlaps(shape: Shape2D, transform: Transform2D, body: TerrainObject) -> bool:
    if not is_instance_valid(body):
        return false
    for owner_id: int in body.get_shape_owners():
        if body.is_shape_owner_disabled(owner_id):
            continue
        var solid_transform: Transform2D = body.global_transform * body.shape_owner_get_transform(owner_id)
        for index: int in range(body.shape_owner_get_shape_count(owner_id)):
            if shape.collide(transform, body.shape_owner_get_shape(owner_id, index), solid_transform):
                return true
    return false

static func enters(motion: Vector2, normal: Vector2) -> bool:
    return motion.dot(normal) < -0.000001
