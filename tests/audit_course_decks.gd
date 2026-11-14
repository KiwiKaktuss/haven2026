extends SceneTree
## Composition audit plus optional seeded engine-replay evidence. Pass report
## paths after --. Never promotes a search-only result to verified gameplay.
var evidence: Dictionary = {}
func _initialize() -> void:
    for path: String in OS.get_cmdline_user_args():
        var runs: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not runs is Array:
            push_error('Invalid playthrough report: ' + path)
            quit(1)
            return
        for run: Dictionary in runs:
            if not run.get('engine_replay_verified', false):
                continue
            var key: String = deck_key(run.deck)
            if not evidence.has(key):
                evidence[key] = {}
            evidence[key][run.course] = {'seed': run.seed, 'route': run.route, 'report': path}
    var catalog: CardCatalog = load('res://resources/cards/catalog.tres')
    var rows: Array = []
    enumerate(catalog, 0, [], rows)
    assert(rows.size() == 210)
    var constrained: int = 0
    var verified: int = 0
    for row: Dictionary in rows:
        if row.needs_effect_route_validation: constrained += 1
        if row.playthrough_verified: verified += 1
    DirAccess.make_dir_recursive_absolute('res://screenshots/step_6')
    var file := FileAccess.open('res://screenshots/step_6/deck_audit.json',FileAccess.WRITE)
    file.store_string(JSON.stringify(rows,'  '))
    print('Deck audit: ',rows.size(),' legal decks; ',constrained,' require lower-power / special-effect route validation.')
    print(verified, ' / 210 decks have successful seeded engine replays on all four courses.')
    print('This does not prove every shuffle/spread outcome or human difficulty; search-only results are excluded.')
    quit()
func enumerate(catalog: CardCatalog, start: int, selected: Array, rows: Array) -> void:
    if selected.size() == CardCatalog.DECK_SIZE:
        var direct_power: float = 0
        var neutral_launches: Array = []
        var effects: Array = []
        for id: StringName in selected:
            var card := catalog.find_card(id)
            if card.effect in [CardDefinition.Effect.CLASSIC,CardDefinition.Effect.SNIPER,CardDefinition.Effect.DASH,CardDefinition.Effect.FIRE]:
                neutral_launches.append(str(id))
                direct_power = maxf(direct_power,card.power)
            else: effects.append(str(id))
        var verified_courses: Dictionary = evidence.get(deck_key(selected), {})
        rows.append({'deck':selected.duplicate(),'ordinary_launches':neutral_launches,'maximum_ordinary_power':direct_power,'effects_to_validate':effects,'needs_effect_route_validation':direct_power < 180.0,'playthrough_verified':verified_courses.size() == 4,'seeded_course_evidence':verified_courses})
        return
    for i in range(start, catalog.cards.size()):
        selected.append(catalog.cards[i].id)
        enumerate(catalog,i+1,selected,rows)
        selected.pop_back()

func deck_key(ids: Array) -> String:
    var names: Array[String] = []
    for id: Variant in ids:
        names.append(str(id))
    names.sort()
    return ','.join(names)
