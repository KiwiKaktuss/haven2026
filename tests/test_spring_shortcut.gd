extends SceneTree
## Find a legal one-card spring bank from spawn, then win through real session
## transactions and independently replay the entire trace on engine ticks.
const Driver = preload("res://tests/support/course_playthrough.gd")
const LiveReplay = preload("res://tests/support/live_playthrough.gd")
var session: GameSession
var driver: RefCounted
var spring_hit: bool = false

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    session = load("res://scenes/game/game_session.tscn").instantiate()
    session.course_index = 2
    session.deck.random.seed = 17
    session.random.seed = 1017
    root.add_child(session)
    driver = Driver.new()
    driver.configure(session)
    session.ball.contacted.connect(func(body: TerrainObject, normal: Vector2) -> void:
        if body.object_id == &"launch_spring" and normal.y < -0.9:
            spring_hit = true)
    await physics_frame
    await process_frame
    for tick: int in 60:
        driver.step()
    var saved: Dictionary = driver.snapshot()
    var found: bool = false
    var target: TerrainObject = session.course.get_node("Terrain/ReturnGallery")
    for slot: int in 3:
        if found: break
        for x: float in [96,100,92,88,84,80]:
            if found: break
            for time_index: int in range(65,115):
                driver.restore(saved)
                spring_hit = false
                var card: CardDefinition = session.deck.hand[slot]
                var time: float = time_index/60.0
                var gravity := session.tuning.gravity*card.gravity_multiplier
                var velocity: Vector2 = (Vector2(x,61.95)-session.ball.global_position)/time-Vector2.DOWN*gravity*(time+1.0/60)*0.5
                if velocity.y+gravity*time < 0 or not driver.shoot(slot,velocity):
                    continue
                if driver.finish_hop(target,false,time+1.3,false) and spring_hit:
                    found = true
                    print("Spring bank reached ReturnGallery with ",card.id," in one legal shot")
                    break
    if not found:
        push_error("No one-card spring bank from spawn reached ReturnGallery")
        quit(1)
        return
    for title: String in ["UpperTerrace","GoalCup"]:
        target = session.course.get_node("GoalCup/Terrain") if title == "GoalCup" else session.course.get_node("Terrain/"+title)
        var reached: bool = false
        for attempt: int in 12:
            if driver.find_hop(target) or driver.find_airborne_hop(target):
                reached = true
                break
            if not driver.cycle_or_position(target,attempt):
                break
        assert(reached,"Spring shortcut must finish through the real cup")
    var row: Dictionary = {"course":"spring_works","deck":session.deck.equipped.duplicate(),"seed":17,"route":"SpringShortcut","won":session.state == GameSession.State.WON,"shots":session.shots,"seconds":session.elapsed_seconds,"end_tick":driver.tick,"actions":driver.actions.duplicate(true),"engine_replay_verified":false,"spring_bank_from_spawn":true}
    session.free()
    var verified: bool = await LiveReplay.new().verify(self,row)
    var file := FileAccess.open("res://screenshots/step_6/playthroughs_spring_shortcut.json",FileAccess.WRITE)
    file.store_string(JSON.stringify([row],"  "))
    print("Spring shortcut: ","PASS" if verified else "FAIL",", ",row.shots," shots; independent engine replay ",verified)
    quit(0 if verified else 1)
