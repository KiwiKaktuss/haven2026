extends SceneTree
## Acceptance: genuine engine physics, aim press/release, no ball teleports.
var session: TutorialSession
var failures: int = 0
var rows: Array = []
var actions: Array = []
var tick: int = 0
var step_tick: int = 0

func _initialize() -> void:
    call_deferred("run")

func wait_ticks(count: int) -> void:
    for i: int in count:
        await physics_frame
        await process_frame
        tick += 1
        step_tick += 1

func shoot(drag: Vector2) -> void:
    session.aim.begin(Vector2(480,280))
    session.aim.move_pointer(Vector2(480,280)+drag)
    var committed: bool = session.aim.release(Vector2(480,280)+drag)
    if not committed:
        failures += 1
        push_error("Shot rejected at lesson %d" % (session.step_index+1))
    actions.append({"tick":step_tick,"slot":session.deck.selected_slot,"drag":[drag.x,drag.y]})

func run() -> void:
    session = load("res://scenes/tutorial/tutorial_session.tscn").instantiate()
    root.add_child(session)
    var discovered: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/support/tutorial_routes.json"))
    for index: int in 10:
        if session.step_index != index:
            push_error("Expected lesson %d, got %d" % [index+1,session.step_index+1])
            failures += 1
            break
        step_tick = 0
        actions = []
        await wait_ticks(12)
        if index == 2:
            session.hud._select(1)
        if index == 4:
            await wait_ticks(150)
        if index == TutorialSession.CARD_STEP:
            var cards: Control = session.lesson_ui.get_node("CardLesson")
            for card_index: int in session.deck.catalog.cards.size():
                cards.inspect(card_index)
                var description: Label = cards.details.get_node("Text/Description")
                if description.text != session.deck.catalog.cards[card_index].description:
                    failures += 1
            cards.next_button.pressed.emit()
            rows.append({"step":index,"actions":[],"ticks":step_tick,"completed":session.step_index == 6})
            print("ENGINE LESSON 6 completed=",session.step_index == 6," card overview")
            continue
        if index == 7:
            var angle: float = 35.0
            var length: float = 160.0
            shoot(-Vector2.from_angle(deg_to_rad(-angle))*length)
            var attached: bool = false
            for i: int in 300:
                await wait_ticks(1)
                attached = session.stuck_once
                if attached and session.deck.slot_ready(0):
                    break
            if not attached:
                failures += 1
                push_error("Lesson %d failed its surface task, ball %s" % [index+1,session.ball.position])
                break
            var destination: Vector2 = session.course.goal_cup.to_global(Vector2(32,-2))
            var flight: float = 0.7
            var wanted: Vector2 = (destination-session.ball.global_position)/flight - Vector2.DOWN*session.tuning.gravity*(flight+1.0/60)*0.5
            var impulse: Vector2 = wanted - session.ball.world_velocity()
            var card: CardDefinition = session.deck.selected_card()
            shoot(-impulse/(card.power*session.tuning.shot_power_multiplier)*session.tuning.maximum_drag)
        else:
            for row: Dictionary in discovered:
                if int(row.step) == index:
                    shoot(Vector2(row.drag[0],row.drag[1]))
                    break
        var completed: bool = false
        for i: int in 900:
            await wait_ticks(1)
            if session.step_index > index or session.lesson_done:
                completed = true
                break
        print("ENGINE LESSON ",index+1," completed=",completed," shots=",actions.size()," ticks=",step_tick," position=",session.ball.position)
        rows.append({"step":index,"actions":actions.duplicate(true),"ticks":step_tick,"completed":completed})
        if not completed:
            failures += 1
            break
    if not session.lesson_done:
        failures += 1
        push_error("Tutorial must finish all ten lessons")
    var file := FileAccess.open("res://screenshots/tutorial/engine_routes.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(rows,"  "))
    print("Tutorial engine playthrough: ", "PASS" if failures == 0 else "FAIL", " (",failures," failures)")
    session.free()
    await process_frame
    quit(1 if failures else 0)
