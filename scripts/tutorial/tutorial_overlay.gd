extends Control
const TITLES: Array[String] = ["Aiming and shooting", "Shot power", "Selecting a card", "Card replacement", "Elixir", "Card abilities", "Normal walls", "Sticky walls", "Ice", "Bouncy surfaces"]
const INSTRUCTIONS: Array[String] = [
    "Drag back, then release to shoot into the nearby hole.",
    "Drag farther for more power. Reach the distant hole.",
    "Select the middle card, then shoot into the hole.",
    "Shoot once, watch its replacement arrive, then reach the hole.",
    "Wait for 2 elixir, then spend it on a shot to the hole.",
    "Hover over a card to discover what it does.",
    "Bounce off the right wall and return to the hole.",
    "Shoot onto the sticky wall, then shoot away into the hole.",
    "Slide across the ice with a gentle shot to the hole.",
    "Hit the spring below, then land at the elevated hole."
]
var session: TutorialSession
var time: float = 0.0
const INK := Color(0.20, 0.24, 0.30)
const GOLD := Color(0.89, 0.56, 0.19)
@onready var explanation: Label = $Lesson/Content/Explanation

func configure(value: TutorialSession) -> void:
    session = value
    $PauseButton.pressed.connect(func() -> void: session.pause_requested.emit())
    $Complete/Center/Panel/Content/Begin.pressed.connect(func() -> void: session.begin_playing.emit())
    $CardLesson.card_inspected.connect(session.inspect_card)
    $CardLesson.continue_requested.connect(session.complete_card_lesson)
    $CardLesson.configure(session.deck.catalog)
    session.lesson_changed.connect(refresh)
    refresh()

func refresh() -> void:
    if session == null:
        return
    $Lesson/Content/Count.text = "%d / 10" % (session.step_index + 1)
    $Lesson/Content/Title.text = TITLES[session.step_index]
    $Lesson/Content/Instruction.text = INSTRUCTIONS[session.step_index]
    var showing_cards: bool = session.step_index == TutorialSession.CARD_STEP
    $CardLesson.visible = showing_cards
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
    explanation.text = ""
    if session.transitioning:
        explanation.text = "✓  Hole reached!"
    else:
        match session.step_index:
            0: explanation.text = "Pull opposite the direction you want the ball to travel."
            1: explanation.text = "Watch the power bar above the ball as you drag."
            2: explanation.text = "Selected ≠ played. The card changes your shot only when you release." if not session.used_other else "Card played! Now reach the hole."
            3:
                explanation.text = "Played cards leave the hand. A new card fills the same slot."
                if session.replaced_slot >= 0:
                    explanation.text = "Replacement arrived! Finish at the hole." if session.replacement_seen else "Watch the empty slot — your replacement is on its way."
            4: explanation.text = "ELIXIR  ·  %.1f / 2 needed. It refills automatically." % session.elixir if session.elixir < 2.0 and session.shots == 0 else "Each Snipe card costs 2 elixir. Shooting spends it; it refills."
            6: explanation.text = "Ordinary walls redirect the ball." if not session.touched_surface else "Wall bounce done! Finish at the hole."
            7: explanation.text = "The + pattern marks sticky terrain. Stay attached until your next shot." if session.stuck_once else "Aim at the wall with the + pattern."
            8: explanation.text = "The slashed surface has low friction. A short drag keeps you sliding."
            9: explanation.text = "The chevron surface launches the ball upward."
    explanation.visible = not explanation.text.is_empty()
    queue_redraw()

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
    if session.step_index in [2, 3]:
        var slot: int = 1 if session.step_index == 2 else maxi(session.replaced_slot, 0)
        var view: Control = session.hud.get_node("Bottom/Stack/Hand/Card%d" % slot)
        highlight(view.get_global_rect())
    if session.step_index == 4:
        highlight(session.hud.get_node("Bottom/Stack/Elixir").get_global_rect())
        var card: Control = session.hud.get_node("Bottom/Stack/Hand/Card0")
        var rect: Rect2 = card.get_global_rect()
        highlight(Rect2(rect.position, Vector2(rect.size.x, 24)))
    match session.step_index:
        6:
            if not session.touched_surface:
                route(PackedVector2Array([Vector2(0, 70), Vector2(48, -12), Vector2(132, -22), Vector2(180, 8), Vector2(150, 48), hole]))
        7:
            # A second non-colour cue on the wall itself.
            for y: int in range(-16, 72, 16):
                var at: Vector2 = world(Vector2(192, y))
                draw_line(at - Vector2(4, 0), at + Vector2(4, 0), INK, 2)
                draw_line(at - Vector2(0, 4), at + Vector2(0, 4), INK, 2)
            if not session.stuck_once:
                route(PackedVector2Array([Vector2(0, 70), Vector2(80, 10), Vector2(180, 24)]))
        8:
            for x: int in range(32, 160, 16):
                draw_line(world(Vector2(x, 78)), world(Vector2(x + 5, 82)), INK, 1)
        9:
            for x: int in range(56, 160, 16):
                var at: Vector2 = world(Vector2(x, 92))
                draw_polyline(PackedVector2Array([at + Vector2(-4, 4), at, at + Vector2(4, 4)]), INK, 2)
            if not session.touched_surface:
                route(PackedVector2Array([Vector2(0, 22), Vector2(72, 84), Vector2(144, -4), hole]))

func show_complete() -> void:
    $Lesson.hide()
    $PauseButton.hide()
    $Complete.show()
    $Complete/Center/Panel/Content/Begin.grab_focus()
