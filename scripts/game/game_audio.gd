extends Node
## Shared playback survives screen changes and keeps presentation out of physics.
@export var menu_music: AudioStream
@export var level_music: AudioStream
@export var impact_cooldown_ms: int = 80
@onready var music: AudioStreamPlayer = $Music
@onready var click: AudioStreamPlayer = $Click
@onready var hover: AudioStreamPlayer = $Hover
@onready var golfball_hit: AudioStreamPlayer = $GolfballHit
@onready var wallhit: AudioStreamPlayer = $WallHit
@onready var winhole: AudioStreamPlayer = $WinHole
var _last_impacts: Dictionary[int, int] = {}
var _hover_queued: bool = false
var menu_intro_seen: bool = false

func menu_music_time() -> float:
    if music.stream != menu_music or not music.playing:
        return 0.0
    # Follow the audible sample position, rather than accumulating frame time.
    return maxf(0.0, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _ready() -> void:
    get_tree().node_added.connect(_watch_node)
    get_tree().node_removed.connect(_forget_node)
    _watch_branch(get_tree().root)

func play_menu_music() -> void:
    _play_music(menu_music)

func play_level_music() -> void:
    _play_music(level_music)

func _play_music(stream: AudioStream) -> void:
    # Restarting or moving to another course keeps the same loop uninterrupted.
    if music.stream == stream and music.playing:
        return
    music.stream = stream
    music.play()

func _watch_branch(node: Node) -> void:
    _watch_node(node)
    for child: Node in node.get_children():
        _watch_branch(child)

func _watch_node(node: Node) -> void:
    if node is GoalCup:
        if not node.captured.is_connected(_on_hole_captured):
            node.captured.connect(_on_hole_captured)
    if node is Control:
        if not node.mouse_entered.is_connected(_queue_hover):
            node.mouse_entered.connect(_queue_hover)
        if node is BaseButton:
            if not node.pressed.is_connected(_on_button_pressed):
                node.pressed.connect(_on_button_pressed)
    if node is GolfBall:
        if not node.launched.is_connected(_on_ball_launched):
            node.launched.connect(_on_ball_launched)
        var impact_callback: Callable = _on_ball_struck.bind(node)
        if not node.struck.is_connected(impact_callback):
            node.struck.connect(impact_callback)

func _forget_node(node: Node) -> void:
    _last_impacts.erase(node.get_instance_id())

func _on_button_pressed() -> void:
    # A scene's earlier signal listener may already have removed the button.
    click.play()

func _queue_hover() -> void:
    if not _hover_queued:
        _hover_queued = true
        _play_hover.call_deferred()

func _play_hover() -> void:
    _hover_queued = false
    # Nested controls can enter together; sound only the final element once.
    var control: Control = get_viewport().gui_get_hovered_control()
    if control == null or not control.is_visible_in_tree() or not control.can_process():
        return
    if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
        return
    if control is Container or control.get_class() == "Control":
        return
    if control is BaseButton and control.disabled:
        return
    hover.play()

func _on_ball_launched(_card: CardDefinition, _impulse: Vector2, _from_position: Vector2) -> void:
    golfball_hit.play()

func _on_hole_captured() -> void:
    winhole.play()

func _on_ball_struck(_body: TerrainObject, _normal: Vector2, speed: float, ball: GolfBall) -> void:
    var now: int = Time.get_ticks_msec()
    var id: int = ball.get_instance_id()
    if now - _last_impacts.get(id, -impact_cooldown_ms) < impact_cooldown_ms:
        return
    _last_impacts[id] = now
    wallhit.volume_db = linear_to_db(clampf(speed / 180.0, 0.25, 1.0)) - 5.0
    wallhit.play()
