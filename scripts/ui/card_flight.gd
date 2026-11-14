class_name CardFlight
extends Node2D
## An editor-authored sprite, burst and dissolve track; motion is screen-space.
signal arrived
@export var back_texture: Texture2D
@export var arc_height: float = 72.0
@export var flip_turn: float = 0.3
var destination: Vector2
var _origin: Vector2
var _front: Texture2D
var _card_size: Vector2
var _duration: float
var _elapsed: float = 0.0
var _drawing: bool = false
var _finished: bool = false

func begin(card: CardDefinition, from: Vector2, to: Vector2, card_size: Vector2, seconds: float, drawing: bool) -> void:
    _front = card.artwork
    _origin = from
    destination = to
    _card_size = card_size
    _duration = maxf(seconds, 0.01)
    _drawing = drawing
    position = from
    _render(0.0)

func _set_texture(texture: Texture2D) -> void:
    $Card.texture = texture
    $Card.scale = _card_size / texture.get_size()

func _render(t: float) -> void:
    var eased: float = 1.0 - pow(1.0 - t, 3.0) if not _drawing else t * t * (3.0 - 2.0 * t)
    position = _origin.lerp(destination, eased) + Vector2.UP * sin(PI * t) * arc_height
    _set_texture(back_texture if _drawing and t < 0.5 else _front)
    if _drawing:
        $Card.scale.x *= maxf(0.025, absf(cos(t * PI)))
        rotation = sin(t * PI) * flip_turn
        scale = Vector2.ONE * (0.78 + 0.22 * t + sin(t * PI) * 0.12)
    else:
        rotation = sin(t * PI) * -flip_turn
        scale = Vector2.ONE * lerpf(1.0, 0.66, eased)
    $Shadow.position = Vector2(5, 10)
    $Shadow.texture = $Card.texture
    $Shadow.scale = $Card.scale

func _process(delta: float) -> void:
    if _finished or _duration <= 0.0:
        return
    _elapsed += delta
    var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
    _render(t)
    if t >= 1.0:
        _finished = true
        arrived.emit()
        if _drawing:
            queue_free()
        else:
            $Shadow.hide()
            $Sparkles.restart()
            $Sparkles.emitting = true
            $AnimationPlayer.play(&"dissolve")
            $AnimationPlayer.animation_finished.connect(func(_name: StringName) -> void: queue_free(), CONNECT_ONE_SHOT)
