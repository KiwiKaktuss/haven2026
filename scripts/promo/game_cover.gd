@tool
extends Control
## Standalone promotional artwork using the original gameplay background, cards, and logo.
## Run this scene with -- --export-cover to save the exact-size PNG.
@export var artwork_size: Vector2i = Vector2i(630, 500)
@export_file("*.png") var output_path: String = "res://art/promo/deck_golf_630x500.png"
@export var transparent_background: bool = false
var _rendering_only: bool = false

func _ready() -> void:
	if Engine.is_editor_hint() or _rendering_only:
		return
	var window := get_window()
	window.min_size = artwork_size
	window.content_scale_size = artwork_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.size = artwork_size
	if "--export-cover" in OS.get_cmdline_user_args():
		_export_cover.call_deferred()

func _export_cover() -> void:
	# Render separately so the output is independent of window size / screen DPI.
	var viewport := SubViewport.new()
	viewport.size = artwork_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = transparent_background
	add_child(viewport)
	var artwork: Control = load(scene_file_path).instantiate()
	artwork.set("_rendering_only", true)
	viewport.add_child(artwork)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output := output_path
	DirAccess.make_dir_recursive_absolute("res://art/promo")
	var result := viewport.get_texture().get_image().save_png(output)
	if result != OK:
		push_error("Cover export failed: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("Cover exported: %s (%d x %d)" % [ProjectSettings.globalize_path(output), artwork_size.x, artwork_size.y])
	get_tree().quit()
