extends SceneTree
## Replay both independently engine-verified traces from spawn. Only stationary
## regeneration waits are cut; no ball placement/checkpoint restoration is used.
## 30 fps, two 60 Hz physics steps per rendered frame. Art tour fills the finish.
const Driver = preload("res://tests/support/course_playthrough.gd")
var session: GameSession
var driver: RefCounted
var rows: Array = []
var trace: Array
var action_index: int = 0
var course_run: int = -1
var frame: int = 0
var completed_frame: int = -1
var waiting_frames: int = 0

func _initialize() -> void:
    root.size = Vector2i(960,640)
    call_deferred("setup")

func setup() -> void:
    for title: String in ["safe", "alternate"]:
        var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://screenshots/step_6/playthroughs_cold_rework_%s.json" % title))[0]
        assert(row.engine_replay_verified and row.won)
        rows.append(row)
    prepare_run(0)
    session.hud.hide()
    session.camera_controller.camera.position = Vector2(112,32)
    session.camera_controller.camera.zoom = Vector2.ONE * 1.35

func prepare_run(index: int) -> void:
    if session != null:
        session.free()
    course_run = index
    var row: Dictionary = rows[index]
    session = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 1
    session.deck.equipped.assign(row.deck)
    session.deck.random.seed = int(row.seed)
    session.random.seed = int(row.seed) + 1000
    root.add_child(session)
    session.camera_controller.set_process(false)
    driver = Driver.new()
    driver.configure(session)
    trace = row.actions
    action_index = 0
    waiting_frames = 0
    session.camera_controller.set_zoom(2.4)
    session.camera_controller.recenter(true)
    print("Capture route ", row.route, " begins at frame ", frame)

func step_trace() -> void:
    while action_index < trace.size() and int(trace[action_index].tick) == driver.tick:
        var action: Dictionary = trace[action_index]
        session.deck.select_slot(int(action.slot))
        assert(str(session.deck.selected_card().id) == action.card)
        assert(session.try_shot(Vector2(action.drag[0],action.drag[1]), Vector2(480,280)))
        action_index += 1
        waiting_frames = 0
    driver.step()

func follow_ball() -> void:
    var cam := session.camera_controller
    var destination := cam.clamped(session.ball.global_position + Vector2(0,20))
    cam.camera.position = cam.camera.position.lerp(destination, 0.12)

func _process(_delta: float) -> bool:
    if session == null:
        return false
    frame += 1
    if frame <= 30:
        RenderingServer.force_draw()
        return false
    if frame == 31:
        session.hud.show()
        session.camera_controller.set_zoom(2.4)
        session.camera_controller.recenter(true)
    if completed_frame < 0:
        for substep: int in 2:
            step_trace()
        # Show a landing before cutting the resource wait to the next action.
        if session.ball.world_velocity().length() < 0.1 and session.ball.contact_body != null:
            waiting_frames += 1
        else:
            waiting_frames = 0
        if waiting_frames > 6 and action_index < trace.size() and int(trace[action_index].tick) - driver.tick > 45:
            while driver.tick < int(trace[action_index].tick) - 15:
                step_trace()
            print("Cut stationary resource wait before action ", action_index, " at frame ", frame)
            waiting_frames = 0
        follow_ball()
        assert(session.state != GameSession.State.LOST, "Rendered replay must not fall into the sea")
        if session.state == GameSession.State.WON:
            assert(action_index == trace.size())
            print("Capture won ", rows[course_run].route, " at frame ", frame)
            if course_run == 0:
                prepare_run(1)
            else:
                completed_frame = frame
                session.hud.hide()
    else:
        # Final inspection moves from the ice catch banks up to the goal.
        var t: float = clampf(float(frame-completed_frame)/maxf(1.0,900-completed_frame),0,1)
        var points := PackedVector2Array([Vector2(192,128),Vector2(248,0),Vector2(80,-56),Vector2(224,-112),Vector2(112,32)])
        var segment: float = t * (points.size()-1)
        var index: int = mini(int(segment),points.size()-2)
        session.camera_controller.camera.position = points[index].lerp(points[index+1],smoothstep(0,1,segment-index))
        session.camera_controller.camera.zoom = Vector2.ONE * lerpf(2.5,1.35,smoothstep(0.7,1.0,t))
    if frame == 899:
        assert(completed_frame > 0, "Both routes must finish within the proof clip")
        print("Cold Snap proof: both complete traces replayed, final frame ", frame)
    RenderingServer.force_draw()
    return false
