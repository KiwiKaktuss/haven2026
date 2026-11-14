class_name GameSession
extends Node2D
## Owns attempt state; never constructs terrain or HUD hierarchies.
signal shot_committed(card: CardDefinition)
signal card_presented(card: CardDefinition, slot: int, screen_position: Vector2)
signal shot_rejected(slot: int)
signal elixir_changed(amount: float)
signal pause_requested
signal follow_requested
signal attempt_finished(won: bool)
enum State { READY, PLAYING, PAUSED, WON, LOST }
@export var tuning: GameTuning
@export var courses: CourseCatalog
@export var course_host: Node2D
@export var ball: GolfBall
@export var deck: DeckModel
@export var hud: Control
@export var aim: AimController
@export var camera_controller: CourseCamera
@export var course_index: int = 0
var state: State = State.READY
var elixir: float = 10.0
var shots: int = 0
var elapsed_seconds: float = 0.0
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var _committing: bool = false
var course: GolfCourse
var _resume_state: State = State.READY
@export var inspection_mode: bool = false

func _ready() -> void:
    get_node("/root/GameAudio").play_level_music()
    start_attempt()
    if has_node("Backdrop"):
        $Backdrop.configure(course_index)
    if courses == null or courses.courses.is_empty():
        return
    var definition: CourseDefinition = courses.courses[clampi(course_index, 0, courses.courses.size() - 1)]
    course = definition.scene.instantiate() as GolfCourse
    course_host.add_child(course)
    ball.reset_motion(course.start_marker.global_position)
    $ArtInspection.visible = inspection_mode
    if inspection_mode:
        ball.simulation_enabled = false
        aim.enabled = false
        camera_controller.enabled = false
        hud.hide()
        course.hide()
    else:
        camera_controller.configure(course)
        if hud is GameHUD:
            hud.configure(self, definition.title)
            hud.pause_requested.connect(func() -> void: pause_requested.emit())

func pause_attempt() -> bool:
    if state not in [State.READY, State.PLAYING]:
        return false
    _resume_state = state
    state = State.PAUSED
    if aim != null:
        aim.cancel()
    process_mode = Node.PROCESS_MODE_DISABLED
    return true

func resume_attempt() -> void:
    if state != State.PAUSED:
        return
    state = _resume_state
    process_mode = Node.PROCESS_MODE_INHERIT
    if hud != null:
        hud.show()

func finish_attempt(won: bool) -> void:
    if state not in [State.READY, State.PLAYING]:
        return
    state = State.WON if won else State.LOST
    if aim != null:
        aim.cancel()
    if hud != null:
        hud.hide()
    process_mode = Node.PROCESS_MODE_DISABLED
    attempt_finished.emit(won)

func check_course_end(delta: float) -> void:
    if course == null or inspection_mode or state not in [State.READY, State.PLAYING]:
        return
    var lowest_point: float = ball.global_position.y + (tuning.ball_radius if course.void_detects_ball_edge else 0.0)
    if course.void_boundary != null and lowest_point >= course.void_boundary.global_position.y:
        finish_attempt(false)
    elif course.goal_cup != null and course.goal_cup.advance_capture(ball, tuning, delta):
        finish_attempt(true)

func start_attempt() -> void:
    if aim != null:
        aim.cancel()
    state = State.READY
    elixir = float(tuning.maximum_elixir)
    shots = 0
    elapsed_seconds = 0.0
    ball.reset_motion(ball.global_position)
    deck.start_attempt()
    elixir_changed.emit(elixir)

func _physics_process(delta: float) -> void:
    advance_clock(delta)
    check_course_end(delta)

func advance_clock(delta: float) -> void:
    if state not in [State.READY, State.PLAYING] or delta <= 0.0:
        return
    if state == State.PLAYING:
        elapsed_seconds += delta
    deck.advance_deal(delta)
    var next: float = minf(float(tuning.maximum_elixir), elixir + delta / maxf(tuning.regeneration_seconds, 0.001))
    if next != elixir:
        elixir = next
        elixir_changed.emit(elixir)

## drag is current pointer minus fixed mouse-down anchor in screen pixels.
## All failure paths precede RNG use, detachment, pile changes and success signals.
func try_shot(drag: Vector2, screen_position: Vector2 = Vector2.INF) -> bool:
    if _committing or state not in [State.READY, State.PLAYING]:
        return false
    var card: CardDefinition = deck.selected_card()
    if card == null or not deck.slot_ready(deck.selected_slot) or not ShotCalculation.valid_drag(drag, tuning) or elixir < card.cost:
        if card != null and ShotCalculation.valid_drag(drag, tuning):
            shot_rejected.emit(deck.selected_slot)
        return false
    _committing = true
    var half_spread: float = ShotCalculation.spread(card, ShotCalculation.strength(drag, tuning))
    var impulse: Vector2 = ShotCalculation.impulse(card, drag, tuning, random.randf_range(-half_spread, half_spread))
    elixir -= card.cost
    ball.play_card(card, impulse, false)
    shots += 1
    state = State.PLAYING
    var played_slot: int = deck.selected_slot
    deck.cycle_selected(false)
    deck.replacement_remaining[played_slot] = tuning.card_redraw_delay + tuning.card_deal_seconds
    # Publish only after every authoritative field is consistent. Reentrant
    # signal listeners cannot initiate a nested transaction.
    ball.effect_changed.emit(ball.active_effect)
    deck.hand_changed.emit()
    elixir_changed.emit(elixir)
    card_presented.emit(card, played_slot, screen_position if screen_position.is_finite() else get_viewport().get_mouse_position())
    shot_committed.emit(card)
    follow_requested.emit()
    _committing = false
    return true
