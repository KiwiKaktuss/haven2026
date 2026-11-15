extends Control
signal next_requested
signal restart_requested
signal menu_requested

const STAR_TEXTURES: Array[Texture2D] = [
    preload("res://art/1stars.png"),
    preload("res://art/2stars.png"),
    preload("res://art/3stars.png"),
]

var _star_tween: Tween
@onready var _stars: TextureRect = $Center/Content/StarSpace/Stars

func _ready() -> void:
    $Center/Content/Next.pressed.connect(func() -> void: next_requested.emit())
    $Center/Content/Restart.pressed.connect(func() -> void: restart_requested.emit())
    $Center/Content/Menu.pressed.connect(func() -> void: menu_requested.emit())

func configure(won: bool, elapsed: float, shots: int, best: float, new_record: bool, last_course: bool) -> void:
    $Center/Content/Title.text = "Course complete" if won else "Into the void"
    var stats: String = "%s  ·  %s shot%s" % [GameHUD.format_time(elapsed), shots, "" if shots == 1 else "s"]
    if best > 0:
        stats += "  ·  %s %s" % ["New best" if new_record else "Best", GameHUD.format_time(best)]
    $Center/Content/Stats.text = stats
    $Center/Content/Next.visible = won and not last_course
    $Center/Content/Next.text = "Next level"
    var stars: int = stars_for_time(elapsed) if won else 0
    $Center/Content/StarSpace.visible = stars > 0
    $Center/MenuPanel.custom_minimum_size.y = 478.0 if stars > 0 else 380.0
    if _star_tween:
        _star_tween.kill()
    if stars > 0:
        _stars.texture = STAR_TEXTURES[stars - 1]
        _stars.tooltip_text = "%s star%s earned" % [stars, "" if stars == 1 else "s"]
        _stars.position.y = 9.0
        _stars.scale = Vector2.ONE * 0.85
        _stars.modulate = Color(1, 1, 1, 0)
        _star_tween = create_tween().set_parallel(true)
        _star_tween.tween_property(_stars, "modulate:a", 1.0, 0.45).set_delay(0.15)
        _star_tween.tween_property(_stars, "scale", Vector2.ONE, 0.65).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _star_tween.tween_property(_stars, "position:y", 4.0, 0.65).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        _star_tween.chain().tween_callback(_start_star_idle)

static func stars_for_time(elapsed: float) -> int:
    if elapsed < 20.0:
        return 3
    if elapsed < 40.0:
        return 2
    if elapsed < 70.0:
        return 1
    return 0

func _start_star_idle() -> void:
    _star_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _star_tween.tween_property(_stars, "position:y", -2.0, 1.8)
    _star_tween.tween_property(_stars, "position:y", 4.0, 1.8)
