extends RefCounted
## Offline authoring: hide internal borders where separately editable solids meet.
static func join_edges(course: Node) -> void:
    var occupied: Dictionary = {}
    var maps: Array[TileMapLayer] = []
    for body: Node2D in course.get_node("Terrain").get_children():
        var map: TileMapLayer = body.get_node("Tiles")
        maps.append(map)
        var offset := Vector2i(body.position / 8)
        for cell: Vector2i in map.get_used_cells():
            occupied[cell + offset] = true
    for map: TileMapLayer in maps:
        var offset := Vector2i(map.get_parent().position / 8)
        for cell: Vector2i in map.get_used_cells():
            var at := cell + offset
            var left := not occupied.has(at + Vector2i.LEFT)
            var right := not occupied.has(at + Vector2i.RIGHT)
            var top := not occupied.has(at + Vector2i.UP)
            var bottom := not occupied.has(at + Vector2i.DOWN)
            var uv := Vector2i(4, 1)
            if top:
                uv = Vector2i(2, 2) if left else (Vector2i(3, 2) if right else Vector2i(2, 4))
            elif bottom:
                uv = Vector2i(2, 3) if left else (Vector2i(3, 3) if right else Vector2i(3, 4))
            elif left:
                uv = Vector2i(0, 4)
            elif right:
                uv = Vector2i(1, 4)
            map.set_cell(cell, 1 if uv == Vector2i(4, 1) else 0, Vector2i.ZERO if uv == Vector2i(4, 1) else uv)
        map.rebuild_solid()
