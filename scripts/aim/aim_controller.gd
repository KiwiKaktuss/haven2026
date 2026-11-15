class_name AimController
extends Node2D
signal aim_changed
@export var session: GameSession
@export var preview: TrajectoryPreview
@export var camera: Camera2D
@export var enabled: bool = true
var aiming: bool = false
var anchor: Vector2
var pointer: Vector2
var left_held: bool = false
var _fresh_press: bool = false

func _ready() -> void:
	# Query after live ball/platform motion, avoiding a one-tick trailing origin.
	process_physics_priority = 100
	session.deck.hand_changed.connect(update_preview)
	session.elixir_changed.connect(func(_amount: float) -> void: update_preview())

func active_attempt() -> bool:
	return enabled and session.state in [GameSession.State.READY, GameSession.State.PLAYING]

func drag_vector() -> Vector2:
	return pointer - anchor

func begin(at: Vector2) -> void:
	if not active_attempt():
		return
	anchor = at
	pointer = at
	aiming = true
	update_preview()

func move_pointer(at: Vector2) -> void:
	pointer = at

func cancel() -> void:
	aiming = false
	preview.visible = false
	aim_changed.emit()

func release(at: Vector2, over_ui: bool = false) -> bool:
	if not aiming:
		return false
	pointer = at
	var drag: Vector2 = drag_vector()
	cancel()
	return session.try_shot(drag, at) if active_attempt() and not over_ui else false

func _input(event: InputEvent) -> void:
	if not enabled or event.is_echo():
		return
	if event is InputEventMouseMotion:
		move_pointer(event.position)
	if event.is_action_pressed(&"aim"):
		_fresh_press = not left_held
		left_held = true
	elif event.is_action_released(&"aim"):
		left_held = false
		if aiming:
			release(event.position, _over_ui())
			get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"cancel_aim"):
		cancel()
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		cancel()
		session.pause_requested.emit()
	for slot: int in range(3):
		if event.is_action_pressed(StringName("card_slot_%s" % (slot + 1))) and active_attempt():
			session.deck.select_slot(slot)
			update_preview()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed(&"aim") and _fresh_press and not _over_ui():
		begin(event.position)
		get_viewport().set_input_as_handled()

func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(preview):
		left_held = false
		cancel()

func _physics_process(_delta: float) -> void:
	if not active_attempt():
		if aiming:
			cancel()
		return
	update_preview()

func update_preview() -> void:
	var card: CardDefinition = session.deck.selected_card()
	if aiming and card != null and session.deck.slot_ready(session.deck.selected_slot) and ShotCalculation.valid_drag(drag_vector(), session.tuning):
		preview.refresh(session.ball, card, drag_vector(), session.elixir >= card.cost, camera.zoom.x)
	else:
		preview.visible = false
	aim_changed.emit()
