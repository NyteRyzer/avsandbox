extends Node
## Soak test: plays the game with random inputs for a while and reports any
## script errors (they show up in the log). Run headless:
##   godot --headless --path . res://tools/soak.tscn

var world: World
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 7
	world = World.new()
	add_child(world)
	world.population.enabled = true
	var places := ["earth1", "earth2", "argo", "speedforce", "earthx", "1942", "antimatter", "vanishing_point", "old_west", "earth1"]
	var ids: Array = Game.roster.map(func(c) -> String: return str(c["id"]))
	for round in 60:
		var id: String = ids[rng.randi() % ids.size()]
		world.spawn_player(id)
		print("SOAK round %d as %s in %s" % [round, id, world.place_id])
		if round % 6 == 5:
			world.travel_to(places[(round / 6) % places.size()], "breach")
		if round % 4 == 0:
			world.events.start_random()
		if round % 7 == 3:
			world.street_crime.start()
		# Story Mode: jump into random missions, boss fights and crises.
		if round % 5 == 1:
			Game.mode = "story"
			world.missions._set_chapter(rng.randi() % Missions.MISSIONS.size())
		if round % 5 == 3 and world.player:
			var villains := Game.roster.filter(func(c) -> bool: return c["side"] == "villain")
			var b: Actor = world.missions._spawn(str(villains[rng.randi() % villains.size()]["id"]), world.player.global_position + Vector3(6, 0.5, 6))
			b.make_boss(2.0)
			world.boss_fight.begin(b, true, {"escape": rng.randf() < 0.3})
		if round % 8 == 4 and world.place_id == "earth1":
			world.crisis.start_crisis()
		if round == 40:
			Game.mode = "sandbox"
		if round % 9 == 2 and world.city.kind == "metro":
			var room: String = Interiors.ORDER[rng.randi() % Interiors.ORDER.size()]
			world.enter_interior(room)
		var p: Actor = world.player
		for step in 240:
			if not is_instance_valid(world.player):
				break
			p = world.player
			p.in_move = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).limit_length(1.0)
			p.in_primary = rng.randf() < 0.3
			p.in_secondary = rng.randf() < 0.2
			p.in_special = rng.randf() < 0.03
			p.in_ability = rng.randf() < 0.03
			p.in_ultimate = rng.randf() < 0.01
			p.in_jump = rng.randf() < 0.05
			p.in_up = rng.randf() < 0.3
			p.in_sprint = rng.randf() < 0.4
			if rng.randf() < 0.01:
				p.ult = 100.0
			if rng.randf() < 0.01:
				world.interact()
			p.in_dodge = rng.randf() < 0.02
			p.in_down = rng.randf() < 0.05
			if world.qte.active and rng.randf() < 0.25:
				world.qte.press(["attack", "interact", "jump", "dodge", "block", "ability"][rng.randi() % 6])
			if world.cutscene.active and rng.randf() < 0.02:
				world.cutscene.skip()
			if world.boss_fight.active() and rng.randf() < 0.01:
				world.boss_fight.boss.take_damage(world.boss_fight.boss.max_hp * 0.2, p)
			if rng.randf() < 0.004 and world.city.kind == "metro":
				world.teleport_player(world.city.random_road_point(p.global_position, 20.0, 300.0) + Vector3.UP)
			await get_tree().physics_frame
		if world.inside != "":
			world.leave_interior(world.inside)
	print("SOAK DONE")
	get_tree().quit()
