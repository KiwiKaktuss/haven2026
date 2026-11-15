class_name TutorialSession
extends GameSession
## Uses production shots, card transactions, cup capture and surface physics.
signal lesson_changed
signal menu_requested
signal begin_playing
var step_index: int = 0
var lesson_done: bool = false
var transitioning: bool = false
var selected_other: bool = false
var used_other: bool = false
var replaced_slot: int = -1
var replacement_seen: bool = false
var touched_surface: bool = false
var stuck_once: bool = false
var left_sticky: bool = false
const CARD_STEP: int = 5
var card_explored: bool = false
var _miss_elapsed: float = 0.0
var _objective_miss_elapsed: float = 0.0
var _transition_left: float = 0.0
var _checkpoint: Vector2 = Vector2.INF
@onready var lesson_ui: Control = $CanvasLayer/TutorialOverlay

func _ready() -> void:
    course_index = step_index
    super._ready()
    ball.contacted.connect(_contact)
    deck.hand_changed.connect(_selection_changed)
    get_viewport().size_changed.connect(_frame_room)
    _prepare_lesson()
    lesson_ui.configure(self)

func _prepare_lesson() -> void:
    lesson_done = false
    transitioning = false
    selected_other = false
    used_other = false
    replaced_slot = -1
    replacement_seen = false
    touched_surface = false
    stuck_once = false
    left_sticky = false
    card_explored = false
    _miss_elapsed = 0.0
    _objective_miss_elapsed = 0.0
    _checkpoint = Vector2.INF
    state = State.READY
    shots = 0
    elapsed_seconds = 0.0
    aim.cancel()
    ball.reset_motion(course.start_marker.global_position)
    course.goal_cup.reset_capture()
    # Ordinary shots only. No effect tutorial or random draw can block a lesson.
    deck.generation += 1
    deck.hand.clear()
    deck.draw_pile.clear()
    deck.discard_pile.clear()
    deck.replacement_remaining.fill(0.0)
    for slot: int in 3:
        deck.hand.append(deck.catalog.find_card(&"sniper" if step_index == 4 or (step_index == 2 and slot == 1) else &"classic"))
    deck.selected_slot = 0
    elixir = 1.2 if step_index == 4 else float(tuning.maximum_elixir)
    random.seed = 2468
    deck.hand_changed.emit()
    elixir_changed.emit(elixir)
    var is_card_lesson: bool = step_index == CARD_STEP
    course.visible = not is_card_lesson
    ball.visible = not is_card_lesson
    ball.simulation_enabled = not is_card_lesson
    aim.enabled = not is_card_lesson
    hud.visible = not is_card_lesson
    hud.get_node("Top").hide()
    hud.get_node("PauseButton").hide()
    for slot: int in 3:
        var view: CardView = hud.get_node("Bottom/Stack/Hand/Card%d" % slot)
        view.show_information = false
    # Keep the whole practical task visible instead of requiring camera controls.
    camera_controller.enabled = false
    _frame_room()
    lesson_changed.emit()

func _frame_room() -> void:
    var viewport: Vector2 = get_viewport_rect().size
    var top: float = 148.0
    var bottom: float = viewport.y - 177.0
    var zoom_value: float = minf((viewport.x - 64.0) / 416.0, (bottom - top) / 176.0)
    zoom_value = maxf(0.6, zoom_value)
    var camera: Camera2D = camera_controller.camera
    camera.zoom = Vector2.ONE * zoom_value
    var screen_center := Vector2(viewport.x * 0.5, (top + bottom) * 0.5)
    camera.global_position = Vector2(144, 40) - (screen_center - viewport * 0.5) / zoom_value
    camera.offset = Vector2.ZERO
    camera.reset_physics_interpolation()

func _selection_changed() -> void:
    if step_index == 2 and deck.selected_slot == 1:
        selected_other = true

func try_shot(drag: Vector2, at: Vector2 = Vector2.INF) -> bool:
    if lesson_done or transitioning or step_index == CARD_STEP:
        return false
    var slot: int = deck.selected_slot
    var other: bool = slot == 1
    var from_sticky: bool = is_instance_valid(ball.attached_body) and ball.attached_body.name == "StickyWall"
    # Reserve a known ordinary replacement; super still owns the atomic cycle.
    if deck.draw_pile.is_empty():
        deck.draw_pile.append(deck.catalog.find_card(&"sniper" if step_index in [3, 4] else &"classic"))
    var committed: bool = super.try_shot(drag, at)
    if committed:
        used_other = used_other or (selected_other and other)
        replaced_slot = slot
        replacement_seen = false
        left_sticky = left_sticky or (stuck_once and from_sticky)
        _miss_elapsed = 0.0
        lesson_changed.emit()
    return committed

func _contact(body: TerrainObject, normal: Vector2) -> void:
    if shots == 0:
        return
    if step_index == 6 and body.name == "BankWall" and absf(normal.x) > 0.7:
        touched_surface = true
    elif step_index == 8 and body.name == "Ice":
        touched_surface = true
    elif step_index == 9 and body.name == "Spring":
        touched_surface = true

func objective_met() -> bool:
    if step_index == CARD_STEP:
        return card_explored
    if shots == 0:
        return false
    match step_index:
        2: return used_other
        3: return replacement_seen
        6, 8, 9: return touched_surface
        7: return stuck_once and left_sticky
    return true

func advance_clock(delta: float) -> void:
    # Leave the real meter and deal timers running; no time or score pressure.
    if step_index == CARD_STEP:
        return
    super.advance_clock(delta)
    elapsed_seconds = 0.0

func check_course_end(delta: float) -> void:
    if course == null or lesson_done or step_index == CARD_STEP:
        return
    if transitioning:
        _transition_left -= delta
        if _transition_left <= 0.0:
            _advance_step()
        return
    if state not in [State.READY, State.PLAYING]:
        return
    if replaced_slot >= 0 and deck.slot_ready(replaced_slot):
        replacement_seen = true
    if step_index == 7 and is_instance_valid(ball.attached_body) and ball.attached_body.name == "StickyWall":
        stuck_once = true
        _checkpoint = ball.global_position
    if ball.global_position.y >= course.void_boundary.global_position.y or ball.global_position.x < -72.0 or ball.global_position.x > 370.0:
        _reset_miss()
        return
    # A missed landing can be retried immediately; only this room is affected.
    var speed: float = ball.world_velocity().length()
    if shots > 0 and speed < 0.8 and ball.global_position.distance_to(course.goal_cup.to_global(Vector2(32, 0))) > 38.0 and ball.attached_body == null:
        _miss_elapsed += delta
        if _miss_elapsed > 1.4:
            _reset_miss()
            return
    else:
        _miss_elapsed = 0.0
    if objective_met():
        if course.goal_cup.advance_capture(ball, tuning, delta):
            aim.cancel()
            transitioning = true
            _transition_left = 0.9
            lesson_changed.emit()
    else:
        course.goal_cup.reset_capture()
        # Reaching the hole without the demonstrated mechanic offers a clean retry.
        if course.goal_cup.capture_shape.global_position.distance_to(ball.global_position) < 6.0 and speed < tuning.capture_speed:
            _objective_miss_elapsed += delta
            if _objective_miss_elapsed > 1.4:
                _reset_miss()
        else:
            _objective_miss_elapsed = 0.0

func _reset_miss() -> void:
    # Sticky departure keeps the successful attachment as a local checkpoint.
    if step_index == 7 and _checkpoint.is_finite():
        aim.cancel()
        ball.reset_motion(_checkpoint)
        var wall: TerrainObject = course.get_node("Terrain/StickyWall")
        ball.attached_body = wall
        ball.local_anchor = wall.to_local(_checkpoint)
        left_sticky = false
        elixir = float(tuning.maximum_elixir)
        _miss_elapsed = 0.0
        lesson_changed.emit()
    else:
        retry_step()

func retry_step() -> void:
    if lesson_done:
        return
    var old: GolfCourse = course
    course_host.remove_child(old)
    old.queue_free()
    course = courses.courses[step_index].scene.instantiate() as GolfCourse
    course_host.add_child(course)
    _prepare_lesson()

func _advance_step() -> void:
    if step_index == 9:
        transitioning = false
        lesson_done = true
        aim.enabled = false
        ball.simulation_enabled = false
        hud.hide()
        lesson_ui.show_complete()
        return
    step_index += 1
    course_index = step_index
    retry_step()

func finish_attempt(_won: bool) -> void:
    # Tutorial failures never open the scored result screen.
    _reset_miss()

func inspect_card(_card: CardDefinition) -> void:
    if step_index == CARD_STEP:
        card_explored = true

func complete_card_lesson() -> void:
    if step_index == CARD_STEP and card_explored and state in [State.READY, State.PLAYING]:
        _advance_step()

func resume_attempt() -> void:
    super.resume_attempt()
    if step_index == CARD_STEP:
        hud.hide()
