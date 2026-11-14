extends SceneTree
## Exhaustive composition audit, NOT a proof that all hands complete a course.
## Flags decks whose best non-special launch is below the route-test budget.
func _initialize() -> void:
    var catalog: CardCatalog = load('res://resources/cards/catalog.tres')
    var rows: Array = []
    enumerate(catalog, 0, [], rows)
    assert(rows.size() == 210)
    var constrained: int = 0
    for row: Dictionary in rows:
        if row.needs_effect_route_validation: constrained += 1
    DirAccess.make_dir_recursive_absolute('res://screenshots/step_6')
    var file := FileAccess.open('res://screenshots/step_6/deck_audit.json',FileAccess.WRITE)
    file.store_string(JSON.stringify(rows,'  '))
    print('Deck audit: ',rows.size(),' legal decks; ',constrained,' require lower-power / special-effect route validation.')
    print('All 210 still require real hand-cycling and spread playthrough acceptance; this is a composition audit only.')
    quit()
func enumerate(catalog: CardCatalog, start: int, selected: Array, rows: Array) -> void:
    if selected.size() == 6:
        var direct_power: float = 0
        var neutral_launches: Array = []
        var effects: Array = []
        for id: StringName in selected:
            var card := catalog.find_card(id)
            if card.effect in [CardDefinition.Effect.CLASSIC,CardDefinition.Effect.SNIPER,CardDefinition.Effect.DASH,CardDefinition.Effect.FIRE]:
                neutral_launches.append(str(id))
                direct_power = maxf(direct_power,card.power)
            else: effects.append(str(id))
        rows.append({'deck':selected.duplicate(),'ordinary_launches':neutral_launches,'maximum_ordinary_power':direct_power,'effects_to_validate':effects,'needs_effect_route_validation':direct_power < 180.0,'playthrough_verified':false})
        return
    for i in range(start, catalog.cards.size()):
        selected.append(catalog.cards[i].id)
        enumerate(catalog,i+1,selected,rows)
        selected.pop_back()
