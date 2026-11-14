extends SceneTree
## Offline tool only. Rebuild explicitly; never runs at game startup.
## Alpha-derived silhouettes are saved as editable TileSet polygons.
func _initialize() -> void:
    var texture: Texture2D = load("res://art/all_tiles2.png")
    var image: Image = texture.get_image()
    var atlas := TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = Vector2i(8, 8)
    var tiles := TileSet.new()
    tiles.tile_size = Vector2i(8, 8)
    tiles.add_physics_layer()
    tiles.set_physics_layer_collision_layer(0, 1)
    tiles.set_physics_layer_collision_mask(0, 0)
    tiles.add_custom_data_layer()
    tiles.set_custom_data_layer_name(0, "surface")
    tiles.set_custom_data_layer_type(0, TYPE_STRING)
    tiles.add_source(atlas, 0)
    var surfaces: Array[String] = ["normal", "sticky", "ice", "bouncy"]
    for y: int in range(20):
        for x: int in range(12):
            var coords := Vector2i(x, y)
            atlas.create_tile(coords)
            var data: TileData = atlas.get_tile_data(coords, 0)
            data.set_custom_data("surface", surfaces[y / 5])
            var cell: Image = image.get_region(Rect2i(x * 8, y * 8, 8, 8))
            var bitmap := BitMap.new()
            bitmap.create_from_image_alpha(cell, 0.5)
            var polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(Rect2i(0, 0, 8, 8), 0.0)
            data.set_collision_polygons_count(0, polygons.size())
            for index: int in range(polygons.size()):
                var polygon: PackedVector2Array = polygons[index]
                for point: int in range(polygon.size()):
                    polygon[point] -= Vector2(4, 4)
                data.set_collision_polygon_points(0, index, polygon)
    var result: Error = ResourceSaver.save(tiles, "res://resources/terrain/terrain_tileset.tres")
    if result != OK:
        push_error("Atlas save failed: %s" % result)
    else:
        print("Saved 240 editable tiles with material metadata and alpha silhouettes.")
    quit(result)
