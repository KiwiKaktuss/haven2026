extends Control
const TITLES: Array[String] = ["Aiming and shooting", "Shot power", "Selecting a card", "Card abilities", "Normal walls", "Sticky walls", "Ice", "Bouncy surfaces"]
var session: TutorialSession
var time: float = 0.0
var zoom_learned: bool = false
const INK := Color(0.20, 0.24, 0.30)
const GOLD := Color(0.89, 0.56, 0.19)
@onready var description: Label = $Lesson/Content/Description

func configure(value: TutorialSession) -> void:
    session = value
    $PauseButton.pressed.connect(func() -> void: session.pause_requested.emit())
    $Complete/Center/Panel/Content/MainMenu.pressed.connect(func() -> void: session.menu_requested.emit())
    session.camera_controller.zoom_used.connect(_on_zoom_used)
    $CardLesson.card_inspected.connect(session.inspect_card)
    $CardLesson.continue_requested.connect(session.complete_card_lesson)
    $CardLesson.configure(session.deck.catalog)
    session.lesson_changed.connect(refresh)
    refresh()

func refresh() -> void:
    if session == null:
        return
    $Lesson/Content/Title.text = "%s  %d / %d" % [TITLES[session.step_index], session.step_index + 1, TITLES.size()]
    description.text = _description()
    var showing_cards: bool = session.step_index == TutorialSession.CARD_STEP
    $CardLesson.visible = showing_cards
    $ZoomHint.visible = not zoom_learned and not showing_cards and not session.lesson_done
    if showing_cards:
        $CardLesson.reset_lesson()

func _unhandled_input(event: InputEvent) -> void:
    if session != null and session.step_index == TutorialSession.CARD_STEP and event.is_action_pressed(&"pause") and not event.is_echo():
        get_viewport().set_input_as_handled()
        session.pause_requested.emit()

func _process(delta: float) -> void:
    time += delta
    if session == null:
        return
    description.text = _description()
    queue_redraw()

func _description() -> String:
    if session.transitioning:
        return "Hole reached!"
    match session.step_index:
        0:
            return "Pull opposite the shot direction, then release." if session.aim.aiming else "Drag back, then release to shoot into the hole."
        1:
            return "Watch the power bar as you drag farther." if session.aim.aiming else "Drag farther for a stronger shot to the distant hole."
        2:
            if session.used_other:
                return "Card played! Now reach the hole."
            if session.selected_other and session.deck.selected_slot == 1:
                return "Selection only readies a card; shoot to use it."
            return "Select the middle card, then shoot to use it."
        3:
            return "Hover over a card for its ability and cost above it."
        4:
            return "Wall bounce done! Finish at the hole." if session.touched_surface else "Bounce off the right wall to reach the hole."
        5:
            if session.left_sticky:
                return "Shoot away from the sticky wall into the hole."
            return "You stay attached until you shoot again. Aim for the hole." if session.stuck_once else "Shoot onto the wall marked + to stick to it."
        6:
            return "Use a gentle shot; ice keeps the ball sliding toward the hole."
        7:
            return "Bounce onto the upper platform and reach the hole." if session.touched_surface else "Hit the chevron surface to bounce up toward the hole."
    return ""

func world(at: Vector2) -> Vector2:
    return session.get_canvas_transform() * at

func highlight(rect: Rect2) -> void:
    var pulse: float = 0.7 + 0.3 * sin(time * 5.0)
    var tint := Color(GOLD, pulse)
    draw_rect(rect.grow(5), tint, false, 2.0)
    for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
        draw_circle(corner, 3, tint)

func route(points: PackedVector2Array) -> void:
    for i: int in range(points.size() - 1):
        var start: Vector2 = world(points[i])
        var end: Vector2 = world(points[i + 1])
        var length: float = start.distance_to(end)
        for dot: int in range(int(length / 12.0)):
            draw_circle(start.lerp(end, dot * 12.0 / maxf(length, 1)), 2.0, Color(INK, 0.38))

func _draw() -> void:
    if session == null or session.lesson_done or session.step_index == TutorialSession.CARD_STEP:
        return
    var hole: Vector2 = session.course.goal_cup.to_global(Vector2(32, 0))
    if session.step_index == 1 and session.aim.aiming:
        var meter: Control = session.aim.get_node("BallPowerBar")
        highlight(Rect2(world(meter.global_position), meter.size))
    if session.step_index == 2:
        var view: Control = session.hud.get_node("Bottom/Stack/Hand/Card1")
        highlight(view.get_global_rect())
    match session.step_index:
        4:
            if not session.touched_surface:
                route(PackedVector2Array([Vector2(0, 70), Vector2(48, -12), Vector2(132, -22), Vector2(180, 8), Vector2(150, 48), hole]))
        5:
            # A second non-colour cue on the wall itself.
            for y: int in range(-16, 72, 16):
                var at: Vector2 = world(Vector2(192, y))
                draw_line(at - Vector2(4, 0), at + Vector2(4, 0), INK, 2)
                draw_line(at - Vector2(0, 4), at + Vector2(0, 4), INK, 2)
            if not session.stuck_once:
                route(PackedVector2Array([Vector2(0, 70), Vector2(80, 10), Vector2(180, 24)]))
        6:
            for x: int in range(32, 160, 16):
                draw_line(world(Vector2(x, 78)), world(Vector2(x + 5, 82)), INK, 1)
        7:
            for x: int in range(56, 160, 16):
                var at: Vector2 = world(Vector2(x, 92))
                draw_polyline(PackedVector2Array([at + Vector2(-4, 4), at, at + Vector2(4, 4)]), INK, 2)
            if not session.touched_surface:
                route(PackedVector2Array([Vector2(0, 22), Vector2(72, 84), Vector2(144, -4), hole]))

func _on_zoom_used() -> void:
    zoom_learned = true
    $ZoomHint.hide()

func show_complete() -> void:
    $Lesson.hide()
    $ZoomHint.hide()
    $Complete/Center/Panel/Content/Count.text = "%d / %d   ·   ALL LESSONS COMPLETE" % [TITLES.size(), TITLES.size()]
    $PauseButton.hide()
    $Complete.show()
    $Complete/Center/Panel/Content/MainMenu.grab_focus()
