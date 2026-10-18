extends Node
## Headless test suite: roster data, city generation, factions, combat, and
## a smoke test that plays every character in the live world.
## Run from the project folder:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 when every check passes, 1 otherwise.

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	for test in ["test_roster_is_valid", "test_roster_has_both_sides", "test_ability_defaults_cover_roster",
			"test_factions", "test_city_is_deterministic"]:
		_current = test
		call(test)
	_current = "test_world_smoke"
	await test_world_smoke()
	_current = "test_combat"
	await test_combat()
	_current = "test_player_input"
	await test_player_input()
	_current = "test_ui_smoke"
	await test_ui_smoke()
	print("\n%d checks passed, %d failed." % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL [%s] %s" % [_current, message])


func test_roster_is_valid() -> void:
	check(Game.roster_errors.is_empty(), "roster errors: " + "; ".join(Game.roster_errors))
	check(Game.roster.size() >= 50, "expected at least 50 characters, got %d" % Game.roster.size())


func test_roster_has_both_sides() -> void:
	check(Game.heroes().size() >= 20, "need at least 20 heroes")
	check(Game.villains().size() >= 20, "need at least 20 villains")
	for m in Game.MOVEMENTS:
		check(Game.roster.any(func(c): return c["movement"] == m), "no character uses movement " + m)


func test_ability_defaults_cover_roster() -> void:
	for kind in Game.ATTACK_KINDS:
		check(Abilities.ATTACK_DEFAULTS.has(kind), "no defaults for attack " + kind)
	for kind in Game.SPECIAL_KINDS:
		check(Abilities.SPECIAL_DEFAULTS.has(kind), "no defaults for special " + kind)
	for c in Game.roster:
		check(Abilities.cooldown(c["primary"]) >= 0.0, c["id"] + " primary cooldown")
		check(Abilities.special_cost(c["special"]) > 0.0, c["id"] + " special cost")


func test_factions() -> void:
	check(Game.side_of("hero") == 1 and Game.side_of("police") == 1, "heroes and police are lawful")
	check(Game.side_of("villain") == -1 and Game.side_of("thug") == -1, "villains and thugs are criminal")
	check(Game.side_of("civilian") == 0, "civilians are neutral")


func test_city_is_deterministic() -> void:
	var a := City.new()
	add_child(a)
	a.generate(99)
	var b := City.new()
	add_child(b)
	b.generate(99)
	check(a.buildings.size() > 300, "city should have hundreds of buildings, got %d" % a.buildings.size())
	check(a.buildings.size() == b.buildings.size(), "same seed should give the same city")
	check(a.landmarks.size() >= 12, "expected landmarks, got %d" % a.landmarks.size())
	for name in ["S.T.A.R. Labs", "Queen Consolidated", "CatCo Worldwide", "Iron Heights", "The Waverider", "Jitters"]:
		check(not a.landmark(name).is_empty(), "missing landmark " + name)
	check(a.is_water(Vector3(City.LAND + 10, 0, 0)), "beyond the land is water")
	check(a.is_water(Vector3(0, 0, 0)), "the bay between the cities is open water")
	check(not a.is_water(Vector3(560, 0, -560)), "Central City is land")
	check(not a.is_water(Vector3(0, 0, -560)), "the bridge between Star City and Central City is walkable")
	check(a.district_at(Vector3(-1560, 0, -1400)) == "Lian Yu", "Lian Yu is its own island")
	check(a.district_at(Vector3(-330, 0, -330)) == "The Glades", "the Glades are part of Star City")
	check(a.islands.size() == 4, "four separate city islands")
	check(not a.doors.is_empty(), "landmarks have doors into interiors")
	var road := a.snap_to_road(Vector3(123, 0, 37))
	check(is_zero_approx(fmod(absf(road.x), City.CELL)) or is_zero_approx(fmod(absf(road.z), City.CELL)), "snap_to_road lands on a street")
	check(a.district_at(Vector3(-700, 0, -700)) == "Star City", "north-west is Star City")
	check(a.district_at(Vector3(300, 0, -300)) == "Central City", "north-east is Central City")
	a.queue_free()
	b.queue_free()


var world: World


func test_world_smoke() -> void:
	world = World.new()
	add_child(world)
	world.spawn_player("flash")
	check(world.player != null and world.player.is_player, "player spawned")
	check(world.city.parked.size() > 50, "props were placed")
	for i in 30:
		await get_tree().physics_frame
	check(world.player.global_position.y > -5.0, "player rests on the ground")
	# Population fills the streets.
	for i in 90:
		await get_tree().process_frame
	var civs := get_tree().get_nodes_in_group("civilians").size()
	check(civs > 0, "civilians spawned")
	# Every character can be played and use every ability without errors.
	for c in Game.roster:
		world.spawn_player(c["id"], Vector3(560, 0.5, -520))
		var p := world.player
		await get_tree().physics_frame
		p.energy = p.max_energy
		p.aim_point = p.global_position + Vector3(0, 1, -20)
		Abilities.fire(p, c["primary"])
		Abilities.fire(p, c["secondary"])
		if c["primary"]["kind"] == "beam":
			Abilities.held_tick(p, c["primary"], 0.1, "primary")
		Abilities.special(p, c["special"])
		Game.end_slowmo()
		await get_tree().physics_frame
		check(not p.dead and is_instance_valid(p), c["id"] + " survived using its own powers")
	# And every character works as an AI.
	var enemies: Array = []
	for c in Game.roster:
		enemies.append(world.population.spawn_character(c, "villain" if c["side"] == "hero" else "hero", Vector3(560 + randf_range(-30, 30), 0.5, -560 + randf_range(20, 60))))
	for i in 120:
		await get_tree().physics_frame
	check(true, "AI brawl ran")
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	for kind in Events.HERO_EVENTS + Events.VILLAIN_EVENTS:
		world.events.start_random(kind)
		check(not world.events.active.is_empty(), "event " + kind + " started")
		await get_tree().physics_frame
	world.events._expire()


func test_combat() -> void:
	world.spawn_player("green_arrow", Vector3(640, 0.5, -560))
	Game.cheats["god_mode"] = false
	var p := world.player
	var enemy: Actor = world.population.spawn_character(Game.get_character("deathstroke"), "villain", Vector3(80, 0.5, -3))
	var civ: Actor = world.population.spawn_civilian(Vector3(644, 0.5, -560))
	await get_tree().physics_frame
	check(enemy.is_hostile_to(p), "villain is hostile to a hero player")
	check(not civ.is_hostile_to(p), "civilians are not hostile")
	var before := enemy.hp
	enemy.take_damage(20.0, p)
	check(enemy.hp < before, "damage lowers health")
	check(enemy.grudges.has(p.get_instance_id()), "being hit creates a grudge")
	enemy.take_damage(9999.0, p)
	check(enemy.dead, "lethal damage knocks out")
	var score_after_ko := Game.score
	check(score_after_ko > 0, "knocking out a villain scores")
	Game.clear_heat()
	civ.take_damage(5.0, p)
	check(Game.heat > 0.0, "hitting civilians adds heat")
	Game.clear_heat()
	# Freezing
	var e2: Actor = world.population.spawn_character(Game.get_character("zoom"), "villain", Vector3(80, 0.5, -6))
	await get_tree().physics_frame
	e2.take_damage(1.0, p, "ice")
	check(e2.frozen_t > 0.0 and not e2.can_act(), "ice freezes")
	# Allies don't fight each other or the player.
	var ally: Actor = world.spawn_npc_character("spartan", true)
	check(not ally.is_hostile_to(p) and not p.can_hurt(ally), "allies are friendly")
	# Props
	var car := Prop.new()
	car.build(world, "car")
	world.props_root.add_child(car)
	car.global_position = Vector3(650, 1, -560)
	car.hit(500.0, Vector3.ZERO, p)
	check(car.exploded, "cars explode when wrecked")
	# Traffic drives along the street, then becomes a physics car when hit.
	var t: Prop = world.population.spawn_traffic(Vector3(560, 0, -440))
	var t_start := t.global_position
	for i in 60:
		await get_tree().physics_frame
	check(t.global_position.distance_to(t_start) > 5.0, "traffic drives (moved %.1f m)" % t.global_position.distance_to(t_start))
	check(absf(fmod(absf(t.global_position.x), City.CELL) - Prop.LANE) < 1.0 or absf(fmod(absf(t.global_position.z), City.CELL) - Prop.LANE) < 1.0 \
		or absf(fmod(absf(t.global_position.x), City.CELL) - (City.CELL - Prop.LANE)) < 1.0 or absf(fmod(absf(t.global_position.z), City.CELL) - (City.CELL - Prop.LANE)) < 1.0, "traffic keeps to a lane")
	t.hit(5.0, Vector3.ZERO, p)
	check(not t.driving and not t.freeze, "hit traffic becomes a physics car")
	world.spawn_player("supergirl", Vector3(650, 0.5, -556))
	var crate := Prop.new()
	crate.build(world, "crate")
	world.props_root.add_child(crate)
	crate.global_position = Vector3(650, 0.5, -554)
	await get_tree().physics_frame
	Abilities.pick_up(world.player)
	check(world.player.held_prop != null, "strong characters lift props")
	Abilities.throw_prop(world.player)
	check(world.player.held_prop == null and crate.thrown_t > 0.0, "props can be thrown")


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
	Input.action_release(action)


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func test_player_input() -> void:
	world.clear_npcs()
	world.population.enabled = false
	# Super speed covers a lot of ground. Run down a street (x = 0 is a road).
	world.spawn_player("flash", Vector3(560, 0.5, -360))
	world.cam.yaw = 0.0
	await get_tree().physics_frame
	var start := world.player.global_position
	Input.action_press("sprint")
	await _hold("move_forward", 90)
	Input.action_release("sprint")
	var ran := world.player.global_position.distance_to(start)
	check(ran > 40.0, "the Flash sprinted %.0f m in 1.5 s" % ran)
	# Walking is much slower.
	world.spawn_player("spartan", Vector3(560, 0.5, -360))
	await get_tree().physics_frame
	start = world.player.global_position
	await _hold("move_forward", 60)
	var walked := world.player.global_position.distance_to(start)
	check(walked > 3.0 and walked < 12.0, "Spartan walked %.1f m in 1 s" % walked)
	# Jumping leaves the ground.
	await _tap("jump")
	for i in 10:
		await get_tree().physics_frame
	check(world.player.global_position.y > 0.8, "jump leaves the ground")
	# Flyers take off and climb.
	world.spawn_player("supergirl", Vector3(560, 0.5, -360))
	await get_tree().physics_frame
	await _tap("fly")
	check(world.player.flying, "F toggles flight")
	await _hold("jump", 90)
	check(world.player.global_position.y > 8.0, "flying climbs (y=%.1f)" % world.player.global_position.y)
	# Heat vision fires a beam while held.
	world.cam.pitch = -0.3
	await _hold("secondary", 20)
	check(world.player.beams.size() >= 2, "holding RMB fires twin heat-vision beams from the eyes")
	await _tap("fly")
	check(not world.player.flying, "F again stops flying")
	# Super jumpers jump high.
	world.spawn_player("grodd", Vector3(560, 0.5, -360))
	for i in 40:
		await get_tree().physics_frame
	await _tap("jump")
	var peak := 0.0
	for i in 40:
		await get_tree().physics_frame
		peak = maxf(peak, world.player.global_position.y)
	check(peak > 6.0, "Grodd super-jumps (peak %.1f m)" % peak)
	# Grappling line pulls you to a wall.
	world.spawn_player("green_arrow", Vector3(552, 0.5, -360))
	await get_tree().physics_frame
	world.player.aim_point = world.player.global_position + Vector3(-30, 12, 0)
	Abilities.fire_grapple(world.player)
	check(world.player.grapple_point != null, "grapple attaches to a building")
	# Primary attacks spawn projectiles.
	world.player._release_grapple()
	var before := Projectile.spawned
	await _hold("attack", 4)
	check(Projectile.spawned > before, "LMB fires an arrow")
	# Slow-mo special
	world.spawn_player("flash", Vector3(560, 0.5, -360))
	world.player.energy = 100.0
	await get_tree().physics_frame
	await _tap("special")
	check(Engine.time_scale < 1.0, "Q starts speed-force slow motion")
	Game.end_slowmo()
	world.population.enabled = true


func test_ui_smoke() -> void:
	var cs := CharacterSelect.new()
	add_child(cs)
	await get_tree().process_frame
	cs._set_filter("villain")
	check(cs._grid.get_child_count() > 0, "villain filter lists characters")
	cs._select("supergirl")
	check(cs._play.text.contains("SUPERGIRL"), "selecting updates the play button")
	cs.queue_free()
	var ts := TitleScreen.new()
	add_child(ts)
	await get_tree().process_frame
	ts.queue_free()
	world.sandbox_menu.open()
	world.sandbox_menu._spawn_random(false, 2)
	world.sandbox_menu.close()
	world.pause_menu.open()
	world.pause_menu.close()
	world.day_night.set_weather("storm")
	world.day_night.hour = 23.0
	for i in 10:
		await get_tree().process_frame
	check(world.day_night.is_night(), "night time")
	world.queue_free()
	await get_tree().process_frame
	check(true, "world freed cleanly")
