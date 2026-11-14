@tool
extends TileMapLayer
## Paint cells in the editor; the parent remains one whole Ghost-able object.
## Collision polygons are saved in the scene, never constructed during play.
@export var update_collision_in_editor: bool = true
@export_tool_button("Update solid from painted tiles") var update_solid: Callable = rebuild_solid
var _pending: bool = false

func _ready() -> void:
    if Engine.is_editor_hint():
        changed.connect(_queue_rebuild)

func _queue_rebuild() -> void:
    if not update_collision_in_editor or _pending:
        return
    _pending = true
    call_deferred("_finish_rebuild")

func _finish_rebuild() -> void:
    _pending = false
    if Engine.is_editor_hint() and is_inside_tree():
        rebuild_solid()

func rebuild_solid() -> void:
    if tile_set == null or not get_parent() is PhysicsBody2D:
        return
    var body := get_parent()
    var bounds := get_used_rect()
    for child: Node in body.get_children():
        if child is CollisionPolygon2D and str(child.name).begins_with("Solid"):
            body.remove_child(child)
            child.free()
    if bounds.size == Vector2i.ZERO:
        return
    var size := tile_set.tile_size
    var mask_image := Image.create(bounds.size.x * size.x, bounds.size.y * size.y, false, Image.FORMAT_RGBA8)
    var images: Dictionary = {}
    for cell: Vector2i in get_used_cells():
        var source_id := get_cell_source_id(cell)
        var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
        if atlas == null:
            continue
        if not images.has(source_id):
            images[source_id] = atlas.texture.get_image()
        var region := atlas.get_tile_texture_region(get_cell_atlas_coords(cell))
        mask_image.blit_rect(images[source_id], region, (cell - bounds.position) * size)
    var mask := BitMap.new()
    mask.create_from_image_alpha(mask_image, 0.5)
    var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask_image.get_size()), 0.0)
    for index: int in polygons.size():
        var shape := CollisionPolygon2D.new()
        shape.name = "SolidSilhouette" if index == 0 else "Solid%d" % index
        var polygon: PackedVector2Array = polygons[index]
        for point: int in polygon.size():
            polygon[point] = transform * (polygon[point] + Vector2(bounds.position * size))
        shape.polygon = polygon
        body.add_child(shape)
        shape.owner = owner
