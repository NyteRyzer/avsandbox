class_name Survival
extends Node
## The Survival Simulator (S.T.A.R. Labs' training program, or anywhere from
## the Tab menu): endless waves of enemies around you, a boss every fifth
## wave, a breather and a heal between waves. Your best wave is saved.

var world
var active := false
var wave := 0
var foes: Array = []
var _break := 0.0


func start() -> void:
	if active:
		return
	active = true
	wave = 0
	_break = 2.0
	world.clear_npcs()
	world.population.enabled = false
	world.events.reset()
	world.hud.show_banner("SURVIVAL SIMULATOR", Color("#5ab8ff"))
	world.notify("Survive as many waves as you can. A boss joins every fifth wave.", Color("#9fd0ff"))


func stop(reason := "") -> void:
	if not active:
		return
	active = false
	for f in foes:
		if is_instance_valid(f):
			f.queue_free()
	foes.clear()
	var best := Game.stat("waves_best")
	if wave - 1 > best:
		Game.record("waves_best", wave - 1 - best)
	world.notify("Simulation over%s: you reached wave %d (best %d)." % [reason, wave, int(maxf(best, wave - 1))], Color("#9fd0ff"))
	Game.add_score(maxi(0, wave - 1) * 60)


func _alive() -> int:
	return foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()


func _process(delta: float) -> void:
	if not active or world.player == null or not is_instance_valid(world.player):
		return
	world.population.enabled = false
	if world.player.dead:
		stop(" (knocked out)")
		return
	if _alive() > 0:
		return
	if _break > 0.0:
		_break -= delta
		return
	if wave > 0:
		world.player.heal(world.player.max_hp * 0.25)
		Game.add_score(40 * wave)
	wave += 1
	_spawn_wave()
	_break = 4.0
	if wave > 1 and Game.stat("waves_best") < wave - 1:
		Game.record("waves_best", wave - 1 - Game.stat("waves_best"))


func _spawn_wave() -> void:
	foes.clear()
	var p: Vector3 = world.player.global_position
	var enemy_side := "villain" if Game.player_side() == 1 else "hero"
	var count := 2 + wave
	for k in count:
		var ang := k * TAU / count + randf() * 0.3
		var pos := p + Vector3(cos(ang), 0, sin(ang)) * randf_range(18.0, 28.0) + Vector3.UP * 0.5
		var a: Actor
		if k < wave / 3:
			a = world.population.spawn_character(Game.random_character(enemy_side), enemy_side, pos)
		else:
			a = world.population.spawn_thug(pos)
		_prep(a)
	if wave % 5 == 0:
		var boss := world.population.spawn_character(Game.random_character(enemy_side), enemy_side, p + Vector3(0, 0.5, -30))
		boss.make_boss(3.0 + wave * 0.2)
		boss.display_name += " (BOSS)"
		_prep(boss)
	world.hud.show_banner("WAVE %d" % wave, Color("#5ab8ff"))
	Sfx.play("event", null, 0.0)


func _prep(a: Actor) -> void:
	a.set_meta("pinned", true)
	a.brain.leash = 0.0
	a.brain.detect = 200.0
	a.grudges[world.player.get_instance_id()] = 9999.0
	FX.portal(world, a.chest(), Color("#5ab8ff"))
	foes.append(a)


func tracker() -> String:
	return "SURVIVAL  ·  wave %d  ·  %d left" % [wave, _alive()] if active else ""
