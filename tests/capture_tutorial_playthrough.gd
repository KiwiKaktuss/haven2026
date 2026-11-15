extends SceneTree
## Full ten-lesson proof at 2x: 120 physics ticks/s * time_scale 2 = the
## same 1/60 simulation step as acceptance, with four ticks per movie frame.
var main: Node
var session: TutorialSession
var frame: int = 0
var step_index: int = -1
var step_tick: int = 0
var next_action: int = 0
var rows: Array
var completed_frame: int = -1
var all_complete: bool = false

func _initialize() -> void:
    root.size = Vector2i(960,640)
    Engine.physics_ticks_per_second = 120
    Engine.time_scale = 2.0
    rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/support/tutorial_engine_routes.json"))
    call_deferred("setup")

func setup() -> void:
    main = load("res://main.tscn").instantiate()
    root.add_child(main)
    main._menu_screen._finish_intro()

func _physics_process(_delta: float) -> bool:
    if session == null or session.lesson_done:
        return false
    if step_index != session.step_index:
        step_index = session.step_index
        step_tick = 0
        next_action = 0
        print("CAPTURE LESSON ",step_index+1," frame=",frame)
    step_tick += 1
    if step_index == TutorialSession.CARD_STEP:
        if step_tick in [12,132,252]:
            var card_index: int = 0 if step_tick == 12 else (3 if step_tick == 132 else 9)
            var gallery: Control = session.lesson_ui.get_node("CardLesson")
            var hover := InputEventMouseMotion.new()
            hover.position = gallery.grid.get_child(card_index).get_global_rect().get_center()
            root.push_input(hover,true)
        if step_tick == 372:
            session.lesson_ui.get_node("CardLesson").next_button.pressed.emit()
        return false
    var actions: Array = rows[step_index].actions
    if next_action < actions.size():
        var action: Dictionary = actions[next_action]
        var shot_tick: int = int(action.tick)
        var anchor := Vector2(480,280)
        var drag := Vector2(action.drag[0],action.drag[1])
        # Add a visible pull before release; these inputs do not alter the shot.
        if step_tick == maxi(1,shot_tick-10):
            session.deck.select_slot(int(action.slot))
            session.aim.begin(anchor)
        if step_tick >= shot_tick-10 and step_tick < shot_tick:
            session.aim.move_pointer(anchor + drag * clampf((step_tick-shot_tick+10)/10.0,0,1))
        if step_tick == shot_tick:
            session.deck.select_slot(int(action.slot))
            if not session.aim.aiming:
                session.aim.begin(anchor)
            assert(session.aim.release(anchor+drag), "Capture uses legal releases")
            next_action += 1
    assert(step_tick < 900, "Every captured lesson must complete")
    return false

func _process(_delta: float) -> bool:
    frame += 1
    if frame == 36:
        main._menu_screen.get_node("Center/Content/Tutorial").pressed.emit()
        session = main.session
    if session != null and session.lesson_done:
        if completed_frame < 0:
            completed_frame = frame
            all_complete = true
            print("CAPTURE COMPLETE frame=",frame)
    if frame == 899:
        assert(all_complete, "All ten lessons must finish")
        print("ASSERT PASS: menu, nine real holes, in-place hoverable card lesson, terrain and completion.")
    return false
