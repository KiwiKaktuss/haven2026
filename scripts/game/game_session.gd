class_name GameSession
extends Node2D
## Owns attempt state; never constructs terrain or HUD hierarchies.
signal shot_committed(card: CardDefinition)
signal elixir_changed(amount: int)
signal attempt_finished(won: bool)
enum State { READY, PLAYING, PAUSED, WON, LOST }
@export var tuning: GameTuning
@export var courses: CourseCatalog
@export var course_host: Node2D
@export var ball: GolfBall
@export var deck: DeckModel
@export var hud: Control
@export var course_index: int = 0
var state: State = State.READY

func _ready() -> void:
    if courses == null or courses.courses.is_empty():
        return
    var definition: CourseDefinition = courses.courses[clampi(course_index, 0, courses.courses.size() - 1)]
    var course: GolfCourse = definition.scene.instantiate() as GolfCourse
    course_host.add_child(course)
    ball.global_position = course.start_marker.global_position
    ball.safe_position = ball.global_position
