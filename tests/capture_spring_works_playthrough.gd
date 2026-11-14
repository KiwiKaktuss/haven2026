extends SceneTree
## 30 fps proof: spring bank from spawn, complete baseline win (only stationary
## resource waits cut), then explicit lift/shuttle boarding-and-launch fixtures.
const Driver = preload("res://tests/support/course_playthrough.gd")
var session: GameSession
var driver: RefCounted
var phase: String = "overview"
var phase_frame: int = 0
var frame: int = 0
var row: Dictionary
var trace: Array
var action_index: int = 0
var waiting_frames: int = 0
var landed_frames: int = 0
var safe_won: bool = false
var bank_landed: bool = false
var lift_landed: bool = false
var shuttle_landed: bool = false

func _initialize() -> void:
    root.size = Vector2i(960,640)
    call_deferred("setup")

func make_session(data: Dictionary = {}) -> void:
    if session != null:
        session.free()
    session = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 2
    session.deck.random.seed = int(data.get("seed",17))
    session.random.seed = int(data.get("seed",17))+1000
    if data.has("deck"):
        session.deck.equipped.assign(data.deck)
    root.add_child(session)
    session.aim.enabled = false
    session.camera_controller.set_process(false)

func setup() -> void:
    make_session()
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.hud.hide()
    session.camera_controller.camera.position = Vector2(120,32)
    session.camera_controller.camera.zoom = Vector2.ONE*1.25

func prepare_trace(report: String, title: String) -> void:
    row = JSON.parse_string(FileAccess.get_file_as_string("res://screenshots/step_6/playthroughs_"+report+".json"))[0]
    assert(row.won and row.engine_replay_verified)
    make_session(row)
    driver = Driver.new()
    driver.configure(session)
    # The proven baseline avoids both full swept envelopes, so movers may run
    # visibly on engine ticks while the ball trace advances at two 60 Hz steps.
    for mover: MovingPlatform in session.course.get_node("MovingPlatforms").get_children():
        mover.set_physics_process(true)
    trace = row.actions
    action_index = 0
    # Cut only the stationary pre-shot wait; the real ball still settles at spawn.
    for tick: int in int(trace[0].tick):
        driver.step()
    waiting_frames = 0
    landed_frames = 0
    phase = title
    phase_frame = 0
    session.camera_controller.set_zoom(2.25)
    session.camera_controller.recenter(true)
    print("Proof begins ",phase," at frame ",frame)

func trace_tick() -> void:
    while action_index < trace.size() and int(trace[action_index].tick) == driver.tick:
        var action: Dictionary = trace[action_index]
        session.deck.select_slot(int(action.slot))
        assert(str(session.deck.selected_card().id) == action.card)
        assert(session.try_shot(Vector2(action.drag[0],action.drag[1]),Vector2(480,280)))
        action_index += 1
    driver.step()

func follow_ball() -> void:
    var cam := session.camera_controller
    cam.camera.position = cam.camera.position.lerp(cam.clamped(session.ball.global_position+Vector2(0,20)),0.16)

func prepare_ride(title: String) -> void:
    make_session()
    session.set_physics_process(false)
    session.hud.hide()
    session.ball.simulation_enabled = true
    var mover: MovingPlatform = session.course.get_node("MovingPlatforms/"+title)
    session.ball.reset_motion(mover.to_global(Vector2(28,-2.02)))
    session.ball.velocity = mover.surface_velocity
    session.camera_controller.set_zoom(2.5)
    session.camera_controller.recenter(true)
    phase = title
    phase_frame = 0
    landed_frames = 0
    print("Explicit boarding/launch fixture ",title," at frame ",frame)

func launch_from_ride() -> void:
    var destination := Vector2(344,53.95) if phase == "Lift" else Vector2(0,-82.05)
    var time: float = 0.8 if phase == "Lift" else 0.7
    var velocity := (destination-session.ball.global_position)/time-Vector2.DOWN*session.tuning.gravity*(time+1.0/60)*0.5
    var slot: int = -1
    for effect: int in [CardDefinition.Effect.FIRE,CardDefinition.Effect.CLASSIC,CardDefinition.Effect.SNIPER]:
        for i: int in session.deck.hand.size():
            if session.deck.hand[i].effect == effect:
                slot = i
    assert(slot >= 0)
    session.deck.select_slot(slot)
    var impulse := velocity-session.ball.world_velocity()
    var card := session.deck.selected_card()
    var drag := -impulse/(card.power*session.tuning.shot_power_multiplier)*session.tuning.maximum_drag
    assert(session.try_shot(drag,Vector2(480,280)))
    print("Launched from ",phase," at frame ",frame)

func _process(_delta: float) -> bool:
    if session == null:
        return false
    frame += 1
    phase_frame += 1
    if phase == "overview":
        if phase_frame == 24:
            prepare_trace("spring_shortcut","bank")
    elif phase in ["bank","safe"]:
        for substep: int in 2:
            if phase != "bank" or action_index == 0:
                trace_tick()
            else:
                driver.step()
        follow_ball()
        assert(session.state != GameSession.State.LOST,"Proof replay must stay above the water")
        if phase == "bank":
            if session.ball.contact_body == session.course.get_node("Terrain/ReturnGallery") and session.ball.world_velocity().length() < 1:
                landed_frames += 1
            else:
                landed_frames = 0
            if landed_frames > 12:
                bank_landed = true
                print("Spring bank lands in ReturnGallery at frame ",frame)
                prepare_trace("spring_final_alternate29","safe")
        else:
            if session.ball.world_velocity().length() < 0.1 and session.ball.contact_body != null:
                waiting_frames += 1
            else:
                waiting_frames = 0
            if waiting_frames > 6 and action_index < trace.size() and int(trace[action_index].tick)-driver.tick > 45:
                while driver.tick < int(trace[action_index].tick)-15:
                    trace_tick()
                waiting_frames = 0
            if session.state == GameSession.State.WON:
                assert(action_index == trace.size())
                safe_won = true
                print("Complete baseline win at frame ",frame)
                prepare_ride("Lift")
    elif phase in ["Lift","Shuttle"]:
        follow_ball()
        if phase_frame == 60:
            assert(session.ball.support_body == session.course.get_node("MovingPlatforms/"+phase))
            launch_from_ride()
        if phase_frame > 60:
            var target := session.course.get_node("Terrain/EastGallery" if phase == "Lift" else "Terrain/UpperTerrace")
            if session.ball.contact_body == target and session.ball.world_velocity().length() < 1:
                landed_frames += 1
            else:
                landed_frames = 0
            if landed_frames > 6:
                if phase == "Lift":
                    lift_landed = true
                    prepare_ride("Shuttle")
                else:
                    shuttle_landed = true
                    phase = "finish"
                    phase_frame = 0
                    session.ball.simulation_enabled = false
                    session.hud.hide()
                    print("Both mover launches land at frame ",frame)
    else:
        var t: float = clampf(float(phase_frame)/maxf(1.0,900-frame+phase_frame),0,1)
        session.camera_controller.camera.position = Vector2(-80,-80).lerp(Vector2(120,32),smoothstep(0,1,t))
        session.camera_controller.camera.zoom = Vector2.ONE*lerpf(2.3,1.25,smoothstep(0,1,t))
    if frame == 899:
        assert(bank_landed and safe_won and lift_landed and shuttle_landed,"All four proof sequences must complete")
        print("Spring Works proof: full baseline win, spring bank, lift and shuttle launches PASS")
    RenderingServer.force_draw()
    return false
