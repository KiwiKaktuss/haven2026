extends SceneTree
## Deterministic live-physics route search. Uses actual saved solids and card
## impulses, never teleports between successful route hops. Candidate retries
## restore the last successful resting state, not the target platform.
var failures: int = 0
var course: GolfCourse
var ball: GolfBall
var card: CardDefinition = load('res://resources/cards/classic.tres')
var report: Array = []
var last_hit: TerrainObject
var last_normal: Vector2
func _initialize() -> void:
    call_deferred('run')
func run() -> void:
    ball = load('res://scenes/ball/ball.tscn').instantiate()
    ball.simulation_enabled = false
    root.add_child(ball)
    ball.contacted.connect(func(body: TerrainObject, normal: Vector2) -> void: last_hit = body; last_normal = normal)
    for id: String in ['first_fairway','cold_snap','spring_works','final_ascent']:
        course = load('res://scenes/levels/%s.tscn'%id).instantiate()
        root.add_child(course)
        for mover: MovingPlatform in course.get_node('MovingPlatforms').get_children():
            mover.motion_enabled = false
        await physics_frame
        await process_frame
        for route: Node in course.get_node('Routes').get_children():
            ball.reset_motion(course.start_marker.global_position)
            for tick in 60: ball.step_motion(1.0/60)
            var sequence: Array = []
            for stop: Marker2D in route.get_children().slice(1):
                var name_text: String = stop.get_meta('support')
                var target: TerrainObject = course.get_node('GoalCup/Terrain') if name_text == 'GoalCup' else course.get_node('Terrain/'+name_text)
                var result := find_shot(target, name_text == 'GoalCup')
                for reposition in 6:
                    if not result.is_empty(): break
                    var support: TerrainObject = ball.contact_body
                    if support == null: support = ball.support_body
                    if support == null: break
                    var before := ball.global_position
                    var dx: float = signf(target.global_position.x+24-before.x)
                    var impulse := Vector2(dx*45,-40)-ball.world_velocity()
                    ball.play_card(card,impulse,false)
                    var reposition_brakes: Array = []
                    for tick in 180:
                        ball.step_motion(1.0/60)
                        if support.surface.material == SurfaceDefinition.SurfaceMaterial.ICE and absf(ball.position.x-before.x) > 24 and absf(ball.world_velocity().x) > 9:
                            var brake := Vector2(-ball.world_velocity().x,0)
                            reposition_brakes.append({'at':[ball.position.x,ball.position.y],'impulse':[brake.x,brake.y]})
                            ball.play_card(card,brake,false)
                    if ball.contact_body != support: break
                    sequence.append({'target':str(support.name),'origin':[before.x,before.y],'impulse':[impulse.x,impulse.y],'landing':[ball.position.x,ball.position.y],'braking':reposition_brakes})
                    result = find_shot(target,name_text == 'GoalCup')
                if result.is_empty():
                    failures += 1
                    print('FAIL ',id,'/',route.name,' -> ',name_text, ' from ',ball.position)
                    break
                sequence.append(result)
                print('PASS ',id,'/',route.name,' -> ',name_text,' landed ',ball.position)
            report.append({'course':id,'route':str(route.name),'shots':sequence})
        course.free()
    DirAccess.make_dir_recursive_absolute('res://screenshots/step_6')
    var file := FileAccess.open('res://screenshots/step_6/routes.json',FileAccess.WRITE)
    file.store_string(JSON.stringify(report,'  '))
    ball.free()
    print('Route physics: ',failures,' failure(s)')
    quit(0 if failures == 0 else 1)

func find_shot(target: TerrainObject, cup: bool) -> Dictionary:
    var origin := ball.global_position
    var original_support := ball.support_body
    var original_contact := ball.contact_body
    var original_attached := ball.attached_body
    var original_anchor := ball.local_anchor
    var incoming := ball.world_velocity()
    var bounds: Rect2i = target.get_node('Tiles').get_used_rect()
    var tile_size: Vector2i = target.get_node('Tiles').tile_set.tile_size
    var width: float = bounds.size.x * tile_size.x
    var target_y: float = target.global_position.y - 2.05 + (8.0 if cup else 0.0)
    var low: float = 22.0 if cup else 8.0
    var high: float = 42.0 if cup else width-8.0
    for height in [0.0, 12.0, 24.0]:
        for x_index in 9:
            var target_x: float = target.global_position.x + lerpf(low,high,x_index/8.0)
            for time_index in range(20,91,2):
                var t: float = time_index/60.0
                var velocity := Vector2((target_x-origin.x)/t,(target_y-origin.y)/t-130.0*t)
                velocity.y -= height
                if velocity.y + 260.0*t < 0: continue
                var impulse := velocity-incoming
                if impulse.length() > card.power or impulse.length() < 10: continue
                ball.reset_motion(origin)
                ball.velocity = incoming
                ball.play_card(card,impulse,false)
                var dwell: float = 0.0
                var braking: Array = []
                for tick in 240:
                    last_hit = null
                    ball.step_motion(1.0/60)
                    if target.surface.material == SurfaceDefinition.SurfaceMaterial.BOUNCY and last_hit == target and last_normal.y < -0.95 and ball.position.x > target.position.x + 6 and ball.position.x < target.position.x + width - 6:
                        return {'target':str(target.name),'origin':[origin.x,origin.y],'impulse':[impulse.x,impulse.y],'landing':[ball.global_position.x,ball.global_position.y],'braking':braking}
                    if ball.global_position.y > course.void_boundary.position.y: break
                    var on_target: bool = ball.contact_body == target or ball.attached_body == target
                    if on_target and target.surface.material == SurfaceDefinition.SurfaceMaterial.ICE and absf(ball.world_velocity().x) > 9.0:
                        var brake := Vector2(-ball.world_velocity().x, 0)
                        if brake.length() <= card.power:
                            braking.append({'at':[ball.position.x,ball.position.y],'impulse':[brake.x,brake.y]})
                            ball.play_card(card,brake,false)
                    if cup:
                        on_target = on_target and ball.global_position.x > target.global_position.x+18 and ball.global_position.x < target.global_position.x+46 and ball.global_position.y > target.global_position.y
                    if on_target and ball.world_velocity().length() < 8.0:
                        dwell += 1.0/60
                        if dwell > 0.65:
                            return {'target':str(target.name),'origin':[origin.x,origin.y],'impulse':[impulse.x,impulse.y],'landing':[ball.global_position.x,ball.global_position.y],'braking':braking}
                    else: dwell = 0.0
    ball.reset_motion(origin)
    ball.velocity = incoming
    ball.support_body = original_support
    ball.contact_body = original_contact
    ball.attached_body = original_attached
    ball.local_anchor = original_anchor
    if original_support != null: ball.support_transform = original_support.global_transform
    return {}
