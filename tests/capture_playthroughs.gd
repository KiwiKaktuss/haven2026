extends SceneTree
## 15-second montage: two Ghost replacement fixtures, then the final approach
## of each verified default-deck trace. Earlier actions are replayed from spawn
## during preroll; no ball placement is used in the four production courses.
const Driver = preload('res://tests/support/course_playthrough.gd')
var frame: int = 0
var lab: Node2D
var main: Node2D
var driver: RefCounted
var rows: Array
var trace: Array
var next_action: int = 0
var replacement: StringName
var replaced: bool = false

func _initialize() -> void:
    call_deferred('setup')

func setup() -> void:
    rows = JSON.parse_string(FileAccess.get_file_as_string('res://screenshots/step_6/playthroughs_default_safe.json'))
    assert(rows.size() == 4)
    lab = load('res://tests/scenes/card_lab.tscn').instantiate()
    root.add_child(lab)
    lab.session.set_physics_process(false)
    lab.session.ball.simulation_enabled = false
    lab.aim.enabled = false
    prepare_ghost(false)

func select(id: StringName) -> void:
    for slot: int in lab.session.deck.hand.size():
        if lab.session.deck.hand[slot].id == id:
            lab.session.deck.select_slot(slot)
            return
    assert(false, 'Expected fixture card in the opening hand')

func prepare_ghost(sticky: bool) -> void:
    replacement = &'glue' if sticky else &'heavy'
    var ids: Array[StringName] = [&'ghost', replacement, &'classic', &'dash', &'rewind', &'sniper']
    for seed_value: int in 100:
        lab.session.deck.random.seed = seed_value
        lab.session.deck.start_attempt(ids)
        var names: Array = lab.session.deck.hand.map(func(card: CardDefinition) -> StringName: return card.id)
        if names.has(&'ghost') and names.has(replacement):
            break
    lab.session.elixir = 10
    lab.session.state = GameSession.State.READY
    lab.session.shots = 0
    lab.session.elapsed_seconds = 0
    var body: TerrainObject = lab.get_node('Terrain/Sticky' if sticky else 'Terrain/Normal')
    lab.session.ball.reset_motion(body.to_global(Vector2(32, -6)))
    lab.camera_controller.set_zoom(8.0)
    lab.camera_controller.recenter(true)
    lab.get_node('CanvasLayer/Instructions').text = 'GHOST REPLACEMENT FIXTURE\nGhost -> %s inside a solid; the passage stays open until the full ball exits.' % str(replacement).capitalize()
    replaced = false
    select(&'ghost')
    assert(lab.session.try_shot(Vector2(0, -60)))

func prepare_course(index: int) -> void:
    print('Capture approach ', index, ' at frame ', frame)
    if lab != null:
        lab.free()
        lab = null
    if main != null:
        main.free()
    main = load('res://main.tscn').instantiate()
    main.save.path = 'user://playthrough_capture.json'
    root.add_child(main)
    var row: Dictionary = rows[index]
    var session: GameSession = main.game_scene.instantiate()
    main._clear_screens()
    main.session = session
    main.course_index = index
    session.course_index = index
    session.deck.equipped.assign(row.deck)
    session.deck.random.seed = int(row.seed)
    session.random.seed = int(row.seed) + 1000
    session.attempt_finished.connect(main._result)
    main.game_host.add_child(session)
    driver = Driver.new()
    driver.configure(session)
    trace = row.actions
    next_action = 0
    var preroll: int = maxi(0, int(trace[-1].tick) - 30)
    while driver.tick < preroll:
        advance_trace()
    session.camera_controller.set_zoom(4.0)
    session.camera_controller.recenter(true)

func advance_trace() -> void:
    while next_action < trace.size() and int(trace[next_action].tick) == driver.tick:
        var action: Dictionary = trace[next_action]
        main.session.deck.select_slot(int(action.slot))
        assert(str(main.session.deck.selected_card().id) == action.card)
        assert(main.session.try_shot(Vector2(action.drag[0], action.drag[1])))
        next_action += 1
    driver.step()

func _process(_delta: float) -> bool:
    frame += 1
    if lab == null and main == null:
        return false
    if frame < 90:
        if frame == 45:
            prepare_ghost(true)
        for substep: int in 2:
            var ball: GolfBall = lab.session.ball
            if not replaced and ball.ghost_state == GolfBall.GhostState.PASSING:
                select(replacement)
                assert(lab.session.try_shot(Vector2(0, 160)))
                replaced = true
            ball.step_motion(1.0 / 60.0)
            lab.session.advance_clock(1.0 / 60.0)
        RenderingServer.force_draw()
        return false
    if (frame - 90) % 90 == 0 and frame < 450:
        prepare_course((frame - 90) / 90)
    if main != null:
        for substep: int in 2:
            advance_trace()
        if (frame - 90) % 90 == 89:
            assert(main.session.state == GameSession.State.WON, 'The montage approach must finish through actual cup dwell')
    if frame == 449:
        print('Capture complete: ', frame, ' frames; final state ', main.session.state)
        DirAccess.remove_absolute('user://playthrough_capture.json')
    RenderingServer.force_draw()
    return false
