class_name StreetCrime
extends Node
## Small crimes between the big events: a mugger chasing someone down the
## street. Heroes have 45 seconds to stop it; there's a reward and a thank-you,
## and the news hears about it.

var world
var enabled := true
var mugger: Actor
var victim: Actor
var time_left := 0.0
var _cooldown := 60.0


func _process(delta: float) -> void:
	if not enabled or world == null or world.player == null or not is_instance_valid(world.player):
		return
	if mugger:
		_tick(delta)
		return
	if world.inside != "" or world.city.kind != "metro" or Game.player_side() != 1 or not world.events.active.is_empty():
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = randf_range(70.0, 120.0)
		start()


func start() -> bool:
	var p: Vector3 = world.player.global_position
	var pos: Vector3 = world.city.random_road_point(p, 35.0, 70.0, null, true)
	victim = world.population.spawn_civilian(pos + Vector3.UP * 0.5)
	victim.set_meta("pinned", true)
	victim.display_name = "Victim"
	mugger = world.population.spawn_thug(pos + Vector3(3, 0.5, 0))
	mugger.display_name = "Mugger"
	mugger.set_meta("pinned", true)
	mugger.grudges[victim.get_instance_id()] = 60.0
	time_left = 45.0
	world.notify("\"Help! Somebody stop him!\" A mugging nearby.", Color("#ffb070"))
	Sfx.play("event", null, -6.0)
	return true


func _tick(delta: float) -> void:
	time_left -= delta
	if not is_instance_valid(mugger) or mugger.dead:
		if is_instance_valid(victim) and not victim.dead:
			world.notify("\"Thank you!\" Mugging stopped.  +40", Color("#60ff90"))
			Game.add_score(40)
			Game.record("muggings_stopped")
			if world.news:
				world.news.report("A mugging in %s was stopped by %s." % [world.city.district_at(victim.global_position), world.player.def.get("alias", "a hero")])
		stop()
		return
	if time_left <= 0.0 or not is_instance_valid(victim) or victim.dead:
		world.notify("The mugger got away.", Color("#ff8060"))
		if is_instance_valid(mugger):
			mugger.queue_free()
		stop()


## Where the minimap marks the crime.
func target_pos() -> Vector3:
	return mugger.global_position if mugger and is_instance_valid(mugger) else Vector3.INF


func stop() -> void:
	mugger = null
	if is_instance_valid(victim):
		victim.remove_meta("pinned")
	victim = null
	time_left = 0.0
