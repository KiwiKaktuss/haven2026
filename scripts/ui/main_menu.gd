extends Control
signal play_requested
signal deck_requested
signal inspect_requested
signal lab_requested
signal cards_requested

# Measured from sound/mainmenu.mp3 at 100 Hz. Rebuild if the track changes.
const MOTION = preload("res://resources/audio/menu_motion.json")
@onready var logo: TextureRect = $Center/Content/LogoSlot/Logo
@onready var panel: Panel = $Center/MenuPanel
@onready var play: Button = $Center/Content/Play
@onready var deck: Button = $Center/Content/Deck
@onready var credits: Label = $Center/Content/Credits
@onready var audio: Node = get_node("/root/GameAudio")
var _intro: bool = false
var _intro_time: float = 0.0
var _flight_layer: Control

func _ready() -> void:
    _intro = not audio.menu_intro_seen
    audio.menu_intro_seen = true
    _flight_layer = Control.new()
    _flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flight_layer)
    _flight_layer.draw.connect(_draw_flight)
    play.pressed.connect(func() -> void: play_requested.emit())
    deck.pressed.connect(func() -> void: deck_requested.emit())
    $CenterContainer/VBoxContainer/InspectButton.pressed.connect(func() -> void: inspect_requested.emit())
    $CenterContainer/VBoxContainer/PhysicsLabButton.pressed.connect(func() -> void: lab_requested.emit())
    $CenterContainer/VBoxContainer/CardLabButton.pressed.connect(func() -> void: cards_requested.emit())
    _process(0.0)

func _input(event: InputEvent) -> void:
    if not _intro:
        return
    if event is InputEventMouseButton:
        for button: Button in [play, deck]:
            if not button.disabled and button.get_global_rect().has_point(event.position):
                _finish_intro()
                return
    if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
        _finish_intro()
        get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
    var time: float = audio.menu_music_time()
    var data: Dictionary = MOTION.data
    var samples: Array = data.envelope
    var sample: float = clampf(time / float(data.sample_step), 0.0, samples.size() - 1.0)
    var index: int = int(sample)
    var strength: float = lerpf(float(samples[index]), float(samples[mini(index + 1, samples.size() - 1)]), sample - index)
    # Two percent travel: a quiet musical accent, with no free-running tween.
    var idle_scale: float = 1.0 + strength * 0.02
    if not _intro:
        logo.scale = Vector2.ONE * idle_scale
        return
    # Ignore tiny audio-clock regressions within a mix buffer during the reveal.
    _intro_time = maxf(_intro_time, time)
    var impact: float = float(data.impact_time)
    var reveal: float = _ease((_intro_time - impact) / 0.16)
    logo.modulate.a = reveal
    var settle: float = maxf(0.0, _intro_time - impact)
    var bounce: float = sin(settle * 22.0) * exp(-settle * 9.0) * 0.065
    logo.scale = Vector2(idle_scale + bounce, idle_scale - bounce * 0.65) * lerpf(0.94, 1.0, reveal)
    _reveal_control(panel, float(data.panel_time), 0.40)
    _reveal_control(play, float(data.panel_time), 0.32)
    _reveal_control(deck, float(data.deck_time), 0.30)
    credits.modulate.a = _ease((_intro_time - 2.70) / 0.30)
    _flight_layer.queue_redraw()
    if _intro_time >= float(data.end_time):
        _finish_intro()

func _ease(value: float) -> float:
    return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)

func _reveal_control(control: Control, start: float, duration: float) -> void:
    var progress: float = _ease((_intro_time - start) / duration)
    control.modulate.a = progress
    # Container-owned layout stays intact, including when the window resizes.
    control.offset_transform_enabled = true
    control.offset_transform_position = Vector2(0.0, 12.0 * (1.0 - progress))
    if control is Button:
        control.disabled = progress < 0.15

func _finish_intro() -> void:
    _intro = false
    logo.modulate.a = 1.0
    for control: Control in [panel, play, deck]:
        control.modulate.a = 1.0
        control.offset_transform_position = Vector2.ZERO
    play.disabled = false
    deck.disabled = false
    credits.modulate.a = 1.0
    _flight_layer.queue_redraw()

func _ball_position(progress: float) -> Vector2:
    var target: Vector2 = logo.get_global_rect().get_center() - global_position
    var start := Vector2(-16.0, target.y + 115.0)
    var point: Vector2 = start.lerp(target, progress)
    point.y -= sin(progress * PI) * minf(110.0, size.y * 0.17)
    return point

func _draw_flight() -> void:
    if not _intro:
        return
    var impact: float = float(MOTION.data.impact_time)
    var progress: float = clampf(_intro_time / impact, 0.0, 1.0)
    var fade: float = 1.0 - _ease((_intro_time - impact) / 0.14)
    if fade <= 0.0:
        return
    # A short, restrained dotted trail; no particles or screen shake.
    for dot: int in range(1, 7):
        var trail_progress: float = progress - dot * 0.035
        if trail_progress > 0.0:
            _flight_layer.draw_circle(_ball_position(trail_progress), 1.5, Color(1.0, 1.0, 1.0, (0.38 - dot * 0.045) * fade), true, -1, true)
    var ball: Vector2 = _ball_position(progress)
    _flight_layer.draw_circle(ball + Vector2(0, 1.5), 5.0, Color(0.13, 0.23, 0.26, 0.18 * fade), true, -1, true)
    _flight_layer.draw_circle(ball, 4.5, Color(1.0, 1.0, 0.96, fade), true, -1, true)
