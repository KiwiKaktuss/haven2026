extends SceneTree

const RESULT = preload("res://scripts/ui/result_screen.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func run() -> void:
    for sample: Array in [[0.0, 3], [19.999, 3], [20.0, 2], [39.999, 2], [40.0, 1], [69.999, 1], [70.0, 0], [125.0, 0]]:
        check(RESULT.stars_for_time(sample[0]) == sample[1], "Star threshold at %s seconds" % sample[0])
    var screen: Control = load("res://scenes/ui/result_screen.tscn").instantiate()
    root.add_child(screen)
    var stars: TextureRect = screen.get_node("Center/Content/StarSpace/Stars")
    var stats: Label = screen.get_node("Center/Content/Stats")
    for count: int in [3, 2, 1]:
        screen.configure(true, [50.0, 30.0, 10.0][count - 1], 7, 13.8, false, false)
        check(stars.texture.resource_path == "res://art/%sstars.png" % count, "Winning result uses matching star artwork")
        check(stars.get_parent().visible, "Earned stars are visible")
    screen.configure(true, 13.8, 1, 13.8, true, true)
    check(stats.text == "0:13.80  ·  1 shot  ·  New best 0:13.80", "All three stats share one line, preserving new records and singular shots")
    check(screen.get_node("Center/Content/Next").text == "Choose a course", "Final course navigation remains available")
    screen._star_tween.custom_step(1.0)
    var initial_y: float = stars.position.y
    screen._star_tween.custom_step(1.8)
    check(stars.position.y < initial_y - 5.0, "Stars slowly float after their entrance")
    screen._star_tween.custom_step(1.8)
    check(is_equal_approx(stars.position.y, initial_y), "Idle animation returns smoothly")
    for viewport_size: Vector2i in [Vector2i(800, 640), Vector2i(1440, 900)]:
        root.size = viewport_size
        for frame: int in range(4):
            await process_frame
        var panel: Rect2 = screen.get_node("Center/MenuPanel").get_global_rect().grow(-24.0)
        for path: String in ["StarSpace", "Title", "Stats", "Next", "Restart", "Menu"]:
            check(panel.encloses(screen.get_node("Center/Content/" + path).get_global_rect()), "%s fits inside the result panel at %s" % [path, viewport_size])
    if "--capture" in OS.get_cmdline_user_args():
        root.size = Vector2i(960, 640)
        screen.configure(true, 32.89, 7, 13.8, false, false)
        await create_timer(1.0).timeout
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://screenshots/result_stars.png")
    screen.configure(true, 70.0, 7, 13.8, false, false)
    check(not stars.get_parent().visible, "70 seconds earns no stars")
    screen.configure(false, 10.0, 2, 13.8, false, false)
    check(not stars.get_parent().visible and not screen.get_node("Center/Content/Next").visible, "Defeat never awards stars or offers Next")
    screen.configure(false, 10.0, 2, 0.0, false, false)
    check(stats.text == "0:10.00  ·  2 shots", "Absent records leave no trailing separator")
    screen.free()
    print("Result stars: %s checks, %s failure(s)" % [checks, failures])
    quit(0 if failures == 0 else 1)
