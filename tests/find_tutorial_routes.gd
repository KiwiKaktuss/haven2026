extends SceneTree
## Offline route discovery; acceptance replays these through ordinary engine ticks.
var session: TutorialSession
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    session = load("res://scenes/tutorial/tutorial_session.tscn").instantiate()
    root.add_child(session)
    session.set_physics_process(false)
    session.ball.simulation_enabled = false
    session.hud.set_process(false)
    session.lesson_ui.set_process(false)
    var report: Array = []
    for index: int in [0,1,2,3,4,6,8,9]:
        session.step_index = index
        session.retry_step()
        await physics_frame
        var found: bool = false
        for angle: int in range(5, 86, 5):
            if found: break
            for power_int: int in range(2, 11):
                session._prepare_lesson()
                if index == 2:
                    session.deck.select_slot(1)
                if index == 4:
                    session.advance_clock(2.5)
                for tick: int in 12:
                    session.ball.step_motion(1.0/60)
                var drag := -Vector2.from_angle(deg_to_rad(-angle)) * power_int * 16.0
                if not session.try_shot(drag):
                    continue
                for tick: int in 720:
                    session.advance_clock(1.0/60)
                    session.ball.step_motion(1.0/60)
                    if session.replaced_slot >= 0 and session.deck.slot_ready(session.replaced_slot):
                        session.replacement_seen = true
                    if session.objective_met() and session.course.goal_cup.advance_capture(session.ball,session.tuning,1.0/60):
                        found = true
                        report.append({"step":index,"drag":[drag.x,drag.y],"ticks":tick+1})
                        print("FOUND ",index+1," angle ",angle," power ",power_int," ticks ",tick)
                        break
                    if session.ball.position.y > 136 or session.ball.position.x < -72 or session.ball.position.x > 370:
                        break
                    if tick > 150 and session.ball.world_velocity().length() < 0.1 and session.ball.global_position.distance_to(session.course.goal_cup.capture_shape.global_position) > 8.0:
                        break
                if found: break
        if not found:
            print("NO ROUTE ",index+1)
    DirAccess.make_dir_recursive_absolute("res://screenshots/tutorial")
    var file := FileAccess.open("res://tests/support/tutorial_routes.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    session.free()
    quit()
