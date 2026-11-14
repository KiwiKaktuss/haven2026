extends SceneTree
## Seeded legal-action search. Validate its output independently with
## replay_course_playthroughs.gd; a search result alone is not acceptance.
const Driver = preload('res://tests/support/course_playthrough.gd')
const LiveReplay = preload('res://tests/support/live_playthrough.gd')
var catalog: CardCatalog = load('res://resources/cards/catalog.tres')
var courses: CourseCatalog = load('res://resources/levels/catalog.tres')
var failures: int = 0
var rows: Array[Dictionary] = []
var report_name: String = 'default_safe'

func _initialize() -> void:
    call_deferred('run')

func make_session(index: int, deck: Array[StringName], seed_value: int) -> GameSession:
    var session: GameSession = load('res://scenes/game/game_session.tscn').instantiate()
    session.course_index = index
    session.deck.equipped = deck.duplicate()
    session.deck.random.seed = seed_value
    session.random.seed = seed_value + 1000
    root.add_child(session)
    return session

func run() -> void:
    var decks: Array[Array] = [catalog.default_deck]
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var seed_value: int = 17
    var route: String = 'Safe'
    var course_filter: int = -1
    var deck_start: int = 0
    var deck_end: int = 210
    var verify_engine: bool = false
    var retry_runs: Array = []
    var retry_requested: bool = false
    var report_override: String = ''
    for arg: String in args:
        if arg.begins_with('--deck='):
            var ids: Array[StringName] = []
            for id: String in arg.trim_prefix('--deck=').split(','):
                ids.append(StringName(id))
            decks = [ids]
        elif arg.begins_with('--seed='):
            seed_value = int(arg.trim_prefix('--seed='))
        elif arg == '--alternate':
            route = 'Alternate'
            report_name = 'default_alternate'
        elif arg == '--adverse':
            decks.clear()
            enumerate_decks(0, [], decks, true)
            # No precision/braking; high power with wide spread and forced effects.
            decks.append([&'classic', &'heavy', &'bounce', &'dash', &'fire', &'ghost'])
            report_name = 'adverse_safe'
        elif arg == '--all-decks':
            decks.clear()
            enumerate_decks(0, [], decks, false)
            report_name = 'all_decks_safe'
        elif arg.begins_with('--report='):
            report_override = arg.trim_prefix('--report=').validate_filename()
        elif arg.begins_with('--course='):
            course_filter = int(arg.trim_prefix('--course='))
        elif arg.begins_with('--deck-range='):
            var limits: PackedStringArray = arg.trim_prefix('--deck-range=').split(':')
            if limits.size() != 2 or not limits[0].is_valid_int() or not limits[1].is_valid_int():
                push_error('Use --deck-range=START:END with an exclusive end')
                quit(1)
                return
            deck_start = int(limits[0])
            deck_end = int(limits[1])
        elif arg == '--verify':
            verify_engine = true
        elif arg.begins_with('--retry='):
            retry_requested = true
            var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix('--retry=')))
            if not prior is Array:
                push_error('Retry requires a valid replay report')
                quit(1)
                return
            for row: Dictionary in prior:
                if not row.get('engine_replay_verified', false):
                    retry_runs.append(row)
            decks.clear()
            for row: Dictionary in retry_runs:
                if not decks.has(row.deck):
                    decks.append(row.deck)
    if not retry_runs.is_empty():
        report_name = 'retry_seed%s_%s' % [seed_value, route.to_lower()]
    elif retry_requested:
        print('No failed engine replays to retry')
        quit()
        return
    if not report_override.is_empty():
        report_name = report_override
    if course_filter < -1 or course_filter >= courses.courses.size():
        push_error('Course index is outside the catalog')
        quit(1)
        return
    if deck_start < 0 or deck_end <= deck_start or deck_start >= decks.size():
        push_error('Deck range must select at least one available deck')
        quit(1)
        return
    if deck_start != 0 or deck_end != 210:
        report_name += '_%s_%s' % [deck_start, deck_end]
    decks = decks.slice(deck_start, mini(deck_end, decks.size()))
    for raw_ids: Array in decks:
        var ids: Array[StringName] = []
        ids.assign(raw_ids)
        var validator := DeckModel.new()
        validator.catalog = catalog
        var valid: bool = validator.valid_deck(ids)
        validator.free()
        if not valid:
            push_error('Playthrough requires five unique catalog card IDs')
            quit(1)
            return
        for index: int in courses.courses.size():
            if args.has('--first-only') and index > 0:
                break
            if course_filter >= 0 and index != course_filter:
                continue
            if not retry_runs.is_empty() and not retry_runs.any(func(row: Dictionary) -> bool: return same_deck(row.deck, ids) and row.course == str(courses.courses[index].id)):
                continue
            var session: GameSession = make_session(index, ids, seed_value)
            var driver = Driver.new()
            driver.configure(session)
            await physics_frame
            await process_frame
            var won: bool = driver.solve(route)
            var trace: Array[Dictionary] = driver.actions.duplicate(true)
            var end_tick: int = driver.tick
            var row: Dictionary = {'course': str(courses.courses[index].id), 'deck': ids,
                'seed': seed_value, 'route': route, 'won': won, 'failure': driver.failure,
                'shots': session.shots, 'seconds': session.elapsed_seconds,
                'rejected_branches': driver.rejected, 'end_tick': end_tick, 'actions': trace,
                'engine_replay_verified': false, 'mover_clearance': 'entire_swept_envelope'}
            session.free()
            var accepted: bool = won
            if won and verify_engine:
                accepted = await LiveReplay.new().verify(self, row)
            if not accepted:
                failures += 1
            rows.append(row)
            print('%s %s/%s: %s shots, %.2fs, %s rejected branches; %s' % [
                ('PASS' if verify_engine else 'CANDIDATE') if accepted else 'FAIL', row.course, route, row.shots,
                row.seconds, row.rejected_branches, row.failure])
            write_report()
    if rows.is_empty():
        push_error('No course/deck pair matched the requested filters')
        failures += 1
    print('Course playthroughs: %s run(s), %s failure(s); engine replay %s' % [rows.size(), failures, 'checked' if verify_engine else 'required'])
    quit(0 if failures == 0 else 1)

func write_report() -> void:
    DirAccess.make_dir_recursive_absolute('res://screenshots/step_6')
    var file := FileAccess.open('res://screenshots/step_6/playthroughs_%s.json' % report_name, FileAccess.WRITE)
    file.store_string(JSON.stringify(rows, '  '))

func enumerate_decks(start: int, selected: Array[StringName], decks: Array[Array], constrained_only: bool) -> void:
    if selected.size() == CardCatalog.DECK_SIZE:
        if not constrained_only or not selected.any(func(id: StringName) -> bool: return id in [&'classic', &'dash', &'fire']):
            decks.append(selected.duplicate())
        return
    for index: int in range(start, catalog.cards.size()):
        selected.append(catalog.cards[index].id)
        enumerate_decks(index + 1, selected, decks, constrained_only)
        selected.pop_back()

func same_deck(a: Array, b: Array) -> bool:
    if a.size() != b.size():
        return false
    for index: int in a.size():
        if str(a[index]) != str(b[index]):
            return false
    return true
