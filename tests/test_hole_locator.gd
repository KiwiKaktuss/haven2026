extends SceneTree
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in 3:
		await process_frame

func frame_target(session: GameSession, screen_position: Vector2) -> void:
	var camera: Camera2D = session.camera_controller.camera
	camera.global_position = session.course.goal_cup.to_global(Vector2(32, 0)) - (screen_position - root.get_visible_rect().get_center()) / camera.zoom
	camera.force_update_scroll()

func run() -> void:
	if capture:
		DirAccess.make_dir_recursive_absolute("res://screenshots/hole_locator")
	for index: int in 4:
		var session: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
		session.course_index = index
		root.add_child(session)
		session.set_physics_process(false)
		session.ball.simulation_enabled = false
		session.camera_controller.enabled = false
		await settle()
		var locator: HoleLocator = session.hud.get_node("HoleLocator")
		var arrow: Sprite2D = locator.get_node("Arrow")
		var flag: Sprite2D = locator.get_node("Flag")
		var viewport: Vector2 = root.get_visible_rect().size
		var center: Vector2 = viewport * 0.5
		if capture:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://screenshots/hole_locator/course_%d.png" % index)
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()]:
			frame_target(session, center + direction * viewport.length() * 2.0)
			await settle()
			check(locator.visible, "Course %d: offscreen hole shows locator" % index)
			check(arrow.transform.y.normalized().is_equal_approx(direction), "Arrow points toward hole in direction %s" % direction)
			check(is_zero_approx(flag.global_rotation) and flag.global_position.is_equal_approx(locator.global_position + Vector2(0, 3)), "Flag stays upright and slightly below the arrow center")
			check(absf((locator.position - center).normalized().cross(direction)) < 0.001, "Edge position follows the bearing to the hole")
			check(Rect2(Vector2(34, 34), viewport - Vector2(68, 68)).has_point(locator.position), "Rotated arrow remains inside screen")
			if capture and index == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://screenshots/hole_locator/direction_%d.png" % roundi(fposmod(direction.angle(), TAU) * 100))
		for target: Vector2 in [center, Vector2(1, 1), viewport - Vector2.ONE]:
			frame_target(session, target)
			await settle()
			check(not locator.visible, "Course %d: visible hole hides locator" % index)
		# Zoom changes the projected visibility even without a pan.
		var camera: Camera2D = session.camera_controller.camera
		camera.zoom = Vector2.ONE
		frame_target(session, center + Vector2(viewport.x * 0.4, 0))
		await settle()
		check(not locator.visible, "Hole inside view before zoom")
		camera.zoom = Vector2(4, 4)
		camera.force_update_scroll()
		await settle()
		check(locator.visible, "Zooming in reveals edge locator")
		session.course.goal_cup.hide()
		await settle()
		check(not locator.visible, "Hidden course target has no locator")
		session.course.goal_cup.show()
		await settle()
		session.finish_attempt(true)
		check(not locator.is_visible_in_tree(), "Result hides locator with HUD")
		session.free()
		await settle()
	# A wide window uses its current viewport rather than fixed design dimensions.
	root.size = Vector2i(1280, 720)
	var wide: GameSession = load("res://scenes/game/game_session.tscn").instantiate()
	root.add_child(wide)
	wide.set_physics_process(false)
	wide.ball.simulation_enabled = false
	wide.camera_controller.enabled = false
	await settle()
	frame_target(wide, Vector2(2200, 360))
	await settle()
	var wide_locator: HoleLocator = wide.hud.get_node("HoleLocator")
	check(wide_locator.visible and is_equal_approx(wide_locator.position.x, root.get_visible_rect().end.x - wide_locator.edge_padding.z), "Resize moves locator to current right edge")
	wide.free()
	root.get_node("GameAudio/Music").stop()
	await settle()
	print("Hole locator: %d checks, %d failure(s)" % [checks, failures])
	quit(0 if failures == 0 else 1)
