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
	# `-- only=test_name` runs just that (async) test, for quick iteration.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_current = "test_world_smoke"
			await test_world_smoke()
			_current = arg.trim_prefix("only=")
			if _current != "test_world_smoke":
				await call(_current)
			print("\n%d checks passed, %d failed." % [_passed, _failed])
			get_tree().quit(1 if _failed > 0 else 0)
			return
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
	_current = "test_new_powers"
	await test_new_powers()
	_current = "test_ultimates"
	await test_ultimates()
	_current = "test_places"
	await test_places()
	_current = "test_driving"
	await test_driving()
	_current = "test_activities"
	await test_activities()
	_current = "test_identities"
	await test_identities()
	_current = "test_combat_extras"
	await test_combat_extras()
	_current = "test_world_extras"
	await test_world_extras()
	_current = "test_activities_extra"
	await test_activities_extra()
	_current = "test_teams_and_new_heroes"
	await test_teams_and_new_heroes()
	_current = "test_space_glide_missions"
	await test_space_glide_missions()
	_current = "test_loadouts_and_buildings"
	await test_loadouts_and_buildings()
	_current = "test_wheel_powers_streets"
	await test_wheel_powers_streets()
	_current = "test_campaign"
	await test_campaign()
	_current = "test_breach_and_new_features"
	await test_breach_and_new_features()
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
		check(Abilities.ATTACK_DEFAULTS.has(kind) or Powers.ATTACK_DEFAULTS.has(kind), "no defaults for attack " + kind)
	for kind in Game.SPECIAL_KINDS:
		check(Abilities.SPECIAL_DEFAULTS.has(kind) or Powers.SPECIAL_DEFAULTS.has(kind), "no defaults for special " + kind)
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
	check(a.is_water(Vector3(560 + City.LAND + 10, 0, -300)), "beyond the land is water")
	check(a.is_water(Vector3(0, 0, 440)), "the bay between the cities is open water")
	check(not a.is_water(Vector3(560, 0, -560)), "Central City is land")
	check(not a.is_water(Vector3(0, 0, -560)), "the bridge between Star City and Central City is walkable")
	check(a.district_at(Vector3(-2900, 0, -1900)) == "Lian Yu", "Lian Yu is its own island")
	check(a.district_at(Vector3(-1200, 0, -320)) == "The Glades", "the Glades are part of Star City")
	check(a.islands.size() == 6, "six separate city islands")
	check(not a.doors.is_empty(), "landmarks have doors into interiors")
	var road := a.snap_to_road(Vector3(123, 0, 37))
	check(is_zero_approx(fmod(absf(road.x), City.CELL)) or is_zero_approx(fmod(absf(road.z), City.CELL)), "snap_to_road lands on a street")
	check(a.district_at(Vector3(-1500, 0, -600)) == "Star City", "north-west is Star City")
	check(a.district_at(Vector3(300, 0, -300)) == "Central City", "north-east is Central City")
	a.queue_free()
	b.queue_free()


var world: World


func test_world_smoke() -> void:
	world = World.new()
	add_child(world)
	world.char_missions.enabled = false   # only the personal-mission test turns them on
	world.street_crime.enabled = false
	world.side_jobs.enabled = false     # only the side-job test turns them on
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


func test_new_powers() -> void:
	world.clear_npcs()
	world.population.enabled = false
	var seen := {}
	for c in Game.roster:
		var kinds := [c["primary"]["kind"], c["secondary"]["kind"], c["special"]["kind"]]
		var fresh := false
		for k in kinds:
			if (k in Powers.ATTACKS or k in Powers.SPECIALS) and not seen.has(k):
				fresh = true
		var effect := str(c["primary"].get("effect", c["secondary"].get("effect", "")))
		var style := str(c["primary"].get("style", "")) + str(c["secondary"].get("style", ""))
		if not fresh and effect == "" and not ("phase" in style or "momentum" in style):
			continue
		for k in kinds:
			seen[k] = true
		world.clear_npcs()
		await _frames(1)
		world.spawn_player(c["id"], Vector3(560, 0.5, -440))
		world.cam.yaw = 0.0
		world.cam.pitch = 0.0
		var foe: Actor = world.population.spawn_thug(Vector3(560, 0.5, -446))
		foe.make_boss(20.0)
		await _frames(2)
		var p := world.player
		p.aim_point = foe.chest()
		p.face_dir = Vector3.FORWARD
		p.energy = p.max_energy
		for slot in ["primary", "secondary"]:
			var atk: Dictionary = c[slot]
			if is_instance_valid(foe):
				p.aim_point = foe.chest()
			if atk["kind"] in Abilities.HELD_KINDS:
				for i in 20:
					Abilities.held_tick(p, atk, 0.05, slot)
			else:
				Abilities.fire(p, atk)
			await _frames(30)
		p.energy = p.max_energy
		if is_instance_valid(foe):
			p.aim_point = foe.chest()
		var ok := Abilities.special(p, c["special"])
		await _frames(90)
		check(ok, "%s special %s runs" % [c["id"], c["special"]["kind"]])
		check(not is_instance_valid(foe) or foe.hp < foe.max_hp or c["special"]["kind"] in ["shapeshift", "lazarus", "speed_clones", "summon_goons"], "%s's kit hurts a foe in front" % c["id"])
	check(seen.size() > 10, "new powers exercised (%d kinds)" % seen.size())
	world.clear_npcs()


func test_ultimates() -> void:
	world.clear_npcs()
	world.population.enabled = false
	var kinds := {}
	for c in Game.roster:
		var u := Ultimate.for_character(c)
		check(u["kind"] in Ultimate.KINDS, "%s has a known ultimate (%s)" % [c["id"], u["kind"]])
		kinds[u["kind"]] = true
	check(kinds.size() == Ultimate.KINDS.size(), "every ultimate kind is used (%d)" % kinds.size())
	# Run every kind once against a few enemies.
	var by_kind := {}
	for c in Game.roster:
		var k: String = Ultimate.for_character(c)["kind"]
		if not by_kind.has(k):
			by_kind[k] = c["id"]
	for k in by_kind.keys():
		world.clear_npcs()
		await _frames(1)
		world.spawn_player(by_kind[k], Vector3(560, 0.5, -440))
		var foes: Array = []
		for i in 3:
			foes.append(world.population.spawn_thug(Vector3(560 + i * 3.0, 0.5, -432)))
		await _frames(2)
		world.player.ult = 100.0
		world.player.aim_point = Vector3(563, 1, -432)
		world.player.in_ultimate = true
		world.player._abilities(0.016)
		check(world.player.ult_active and world.player.ult == 0.0, "%s ultimate starts" % k)
		await _frames(240)
		Game.end_slowmo()
		var hurt := 0
		for f in foes:
			if not is_instance_valid(f) or f.hp < f.max_hp:
				hurt += 1
		check(hurt > 0 or k == "giant", "%s ultimate hurts enemies" % k)
	world.clear_npcs()
	await _frames(400)
	check(not world.player.ult_active, "ultimates end")
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	var t: Actor = world.population.spawn_thug(Vector3(562, 0.5, -440))
	t.take_damage(30.0, world.player)
	check(world.player.ult > 20.0, "dealing damage charges the ultimate")
	world.clear_npcs()


## Waits for whole rendered frames (process, not just physics, has run).
func _idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_places() -> void:
	world.clear_npcs()
	world.population.enabled = false
	for id in Interiors.ORDER:
		check(not world.city.landmark("Inside " + Interiors.NAMES[id]).is_empty(), "interior %s is built" % id)
	var built_in := 0
	for id in Interiors.ORDER:
		if not Interiors.is_remote(id):
			built_in += 1
	check(built_in == 14, "fourteen rooms are inside their real buildings (%d)" % built_in)
	check(Interiors.is_remote("waverider"), "the Waverider is bigger on the inside")
	check(world.city.islands.size() >= 6, "six city islands (with Gotham and Smallville)")
	check(world.city.district_at(Vector3(-1440, 1, 3440)) == "Gotham City", "Gotham is south of National City")
	check(world.city.district_at(Vector3(2560, 1, 1440)) == "Smallville", "Smallville is east of Freeland")
	check(not world.city.is_water(Vector3(-1440, 0, 2440)), "a bridge reaches Gotham")
	check(not world.city.is_water(Vector3(1560, 0, 1440)), "a bridge reaches Smallville")
	check(not world.city.landmark("Wayne Tower").is_empty() and not world.city.landmark("Kent Farm").is_empty(), "Wayne Tower and Kent Farm")
	# Walk in through the front doors of S.T.A.R. Labs, Jitters and Verdant.
	for room in ["star_labs", "jitters", "bunker"]:
		var start: Vector3 = Interiors.origin(room) + Vector3(0, 0.5, -(Interiors.SIZES[room].z * 0.5 + (14.0 if room == "star_labs" else 4.0)))
		world.spawn_player("vibe", start)
		world.cam.yaw = PI
		world.cam.pitch = -0.1
		await _frames(3)
		check(world.inside == "", "%s: starting on the street" % room)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var got_in := false
		for i in 260:
			await get_tree().physics_frame
			if world.inside == room:
				got_in = true
				break
		Input.action_release("move_forward")
		Input.action_release("sprint")
		check(got_in, "walked in through the %s entrance (ended at %s)" % [room, world.player.global_position])
	await get_tree().process_frame
	check(world.place_name(world.player.global_position) == "The Arrow Bunker", "HUD names the room")
	check(world.day_night.indoors, "lighting switches to indoors")
	world.leave_interior("bunker")
	await _frames(3)
	check(world.inside == "" and world.player.global_position.distance_to(Interiors.outside_point("bunker")) < 2.0, "leaving puts you on the street outside")
	check(world.player.global_position.y > -1.0 and world.player.global_position.y < 3.0, "at street level")
	# Suit up from a display case in the Bunker.
	world.enter_interior("bunker")
	await _frames(3)
	var suit: Dictionary = {}
	for d in world.city.doors:
		if d["interior"] == "suit" and d["data"] == "black_canary":
			suit = d
	world.use_door(suit)
	check(world.player.def["id"] == "black_canary", "suit up from the display case")
	world.leave_interior("bunker")
	# Board the Waverider, fly it, and come back to the bridge.
	world.teleport_player(world.ship.boarding_point())
	await _frames(3)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("interior", "") == "waverider", "the ship's ramp is a door (%s)" % str(world.door))
	world.interact()
	await _frames(3)
	check(world.inside == "waverider", "boarded the Waverider")
	world.ship.take_helm()
	var start := world.ship.global_position
	world.cam.yaw = 0.0
	world.cam.pitch = 0.4
	await _hold("move_forward", 90)
	check(world.ship.global_position.distance_to(start) > 40.0, "the Waverider flies (%.0f m)" % world.ship.global_position.distance_to(start))
	check(world.ship.global_position.y > start.y + 5.0, "and climbs")
	check(world.player.global_position.distance_to(world.ship.global_position) < 9.0, "the pilot rides along")
	world.cam.pitch = -0.2
	world.interact()
	await _frames(3)
	check(not world.ship.piloted and world.inside == "waverider", "leaving the helm returns to the bridge")
	# Time travel from the bridge keeps you aboard.
	world.travel_to("2046", "time")
	await _frames(5)
	check(world.place_id == "2046" and world.city.spec.get("ruined", false), "time jump to 2046")
	check(world.inside == "waverider", "still aboard after the jump")
	world.leave_interior("waverider")
	await _frames(5)
	check(world.inside == "" and world.player.global_position.y > -2.0, "step off the ship in 2046")
	for id in ["old_west", "earthx", "speedforce", "antimatter", "argo", "vanishing_point", "earth90", "earth1"]:
		world.travel_to(id, "breach")
		await _frames(5)
		check(world.place_id == id and world.city.islands.size() > 0, "travelled to " + id)
		check(world.player.global_position.y > -2.0, "landed on the ground in " + id)
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	world.travel_to("speedforce", "speed")
	world.population.enabled = true
	world.population._tick = 0.0
	await _frames(3)
	check(get_tree().get_nodes_in_group("wraiths").size() >= 3, "Time Wraiths hunt in the Speed Force")
	var home: Dictionary = {}
	for d in world.city.doors:
		if d["interior"] == "exit_speedforce":
			home = d
	world.use_door(home)
	await _frames(3)
	check(world.place_id == "earth1" and world.city.kind == "metro", "the way home leads back to Earth-1")
	world.travel_menu.open("speed")
	check(world.travel_menu._list.get_child_count() == Multiverse.EARTHS.size() + 1, "speedster travel menu lists the Speed Force and every Earth")
	world.travel_menu.close()


func test_driving() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	var car := Prop.new()
	car.build(world, "car")
	world.props_root.add_child(car)
	car.global_position = Vector3(562, 0.3, -440)
	car.rotation.y = 0.0
	await _frames(4)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("interior", "") == "car", "standing by a car offers to drive it")
	world.interact()
	check(world.vehicle == car and car.player_driven, "G gets behind the wheel")
	var start := car.global_position
	await _hold("move_forward", 90)
	check(car.global_position.distance_to(start) > 15.0, "the car drives (%.0f m)" % car.global_position.distance_to(start))
	check(car.speed_kmh() > 40.0, "and picks up speed (%.0f km/h)" % car.speed_kmh())
	check(world.player.global_position.distance_to(car.global_position) < 2.0, "the driver rides along")
	var victim: Actor = world.population.spawn_thug(car.global_position + car.heading * 6.0)
	await _hold("move_forward", 20)
	check(victim.hp < victim.max_hp, "running into people hurts them")
	world.interact()
	await _frames(2)
	check(world.vehicle == null and world.player.visible and not car.player_driven, "G gets out")
	world.clear_npcs()


func test_activities() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	for kind in ["dominators", "jailbreak"]:
		world.events.start_random(kind)
		check(world.events.active.get("kind", "") == kind and world.events.active["actors"].size() >= 6, kind + " event spawns enemies")
		world.events._expire()
	world.clear_npcs()
	world.race.start(false)
	check(world.race.active and world.race.points.size() == Race.RINGS, "a race lays out its checkpoints")
	var score_before := Game.score
	for k in Race.RINGS:
		world.teleport_player(world.race.points[k] - Vector3.UP * 2.0)
		await get_tree().process_frame
		await get_tree().process_frame
	check(not world.race.active and Game.score > score_before, "finishing the race pays out")
	var xp_before := int(Game.settings["xp"])
	Game.settings["xp"] = 0
	var rank_before := Game.rank()
	Game.add_score(Game.xp_for(rank_before + 1) + 1)
	check(Game.rank() == rank_before + 1, "earning points raises your rank")
	check(world.player.max_hp > float(world.player.def["health"]), "rank boosts health")
	Game.settings["xp"] = xp_before


func test_identities() -> void:
	world.clear_npcs()
	world.population.enabled = false
	var with_id := 0
	for c in Game.roster:
		if c.has("civilian"):
			with_id += 1
			check(c.has("transform") and str(c["transform"]["style"]) != "", c["id"] + " has a transformation")
	check(with_id >= 60, "most characters have a secret identity (%d)" % with_id)
	var styles := {}
	for c in Game.roster:
		if c.has("transform"):
			styles[c["transform"]["style"]] = true
	check(styles.size() >= 20, "%d different transformation styles" % styles.size())
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	var p := world.player
	check(Suitup.toggle(p), "the Flash can change into civilian clothes")
	await _frames(80)
	await get_tree().process_frame
	check(p.civilian and not p.changing, "now Barry Allen in street clothes")
	check(p.display_name == "Barry Allen" and p.movement == "run", "no super speed as Barry (%s, %s)" % [p.display_name, p.movement])
	p.energy = p.max_energy
	var before := p.energy
	p.in_special = true
	p._abilities(0.016)
	p.in_special = false
	check(Game.slowmo_left <= 0.0 and p.energy == before, "no powers in civilian clothes")
	var thug: Actor = world.population.spawn_thug(p.global_position + Vector3(0, 0, -6))
	await _frames(2)
	check(not thug.is_hostile_to(p), "villains don't recognise a hero in street clothes")
	check(Suitup.toggle(p), "suit back up")
	await _frames(80)
	check(not p.civilian and p.movement == "speed" and p.display_name == "The Flash", "the Flash again")
	world.spawn_player("superman", Vector3(560, 0.5, -440))
	Suitup.toggle(world.player)
	await _frames(80)
	check(world.player.civilian and world.player.def["look"]["extras"].has("glasses"), "Clark Kent wears glasses")
	check(not world.player.flying and world.player.movement == "run", "Clark can't fly")
	world.spawn_player("grodd", Vector3(560, 0.5, -440))
	check(not Suitup.toggle(world.player), "Grodd has no secret identity")
	world.clear_npcs()


func test_combat_extras() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	var p := world.player
	world.cam.yaw = 0.0
	world.cam.pitch = 0.0
	var foe: Actor = world.population.spawn_thug(Vector3(560, 0.5, -446))
	await _frames(3)
	# Lock-on
	p.lock_target = world.player_brain._pick_lock(p)
	check(p.lock_target == foe, "lock-on picks the enemy in front")
	# Block: a blocked hit does much less damage
	p.face_dir = Vector3(0, 0, -1)
	p.rotation.y = 0.0
	p.blocking = true
	p._block_start = -100.0
	var hp0 := p.hp
	p.take_damage(40.0, foe)
	var blocked := hp0 - p.hp
	p.blocking = false
	p.hp = p.max_hp
	p.take_damage(40.0, foe)
	var full := p.max_hp - p.hp
	check(blocked < full * 0.5, "blocking soaks most of a hit (%.0f vs %.0f)" % [blocked, full])
	# Parry
	p.hp = p.max_hp
	p.blocking = true
	p._block_start = Time.get_ticks_msec() / 1000.0
	p.take_damage(40.0, foe)
	p.blocking = false
	check(p.hp == p.max_hp and foe.stun_t > 1.0, "a perfect parry takes no damage and staggers the attacker")
	# Style
	var before := world.style.points
	p.style_kind = "melee"
	p.combo_hit(3)
	p.style_kind = "arrow"
	p.combo_hit(3)
	check(world.style.points > before + 10.0 and world.style.rank() >= 1, "fighting raises the style rank (%s)" % world.style.label())
	# Takedown
	foe.hp = foe.max_hp * 0.15
	p.global_position = foe.global_position + Vector3(0, 0, 2.0)
	await _frames(2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("interior", "") == "takedown", "a beaten enemy offers a takedown")
	world.interact()
	await _frames(5)
	Game.end_slowmo()
	check(not is_instance_valid(foe) or foe.dead, "the takedown finishes them")
	# Dive slam
	world.spawn_player("batwoman", Vector3(560, 18.0, -440))
	p = world.player
	var t2: Actor = world.population.spawn_thug(Vector3(560, 0.5, -440))
	t2.make_boss(5.0)
	p.global_position = Vector3(560, 18.0, -440)
	p.velocity = Vector3(0, -3.0, 0)
	await _frames(2)
	p.in_primary = true
	p._abilities(0.016)
	p.in_primary = false
	check(p.slam_pending, "attacking while falling starts a dive slam")
	await _frames(60)
	check(t2.hp < t2.max_hp, "the dive slam hits the enemy below")
	await get_tree().process_frame
	check(world.hud.boss_panel.visible or t2.grudges.is_empty(), "boss health bar shows for a boss fight")
	world.clear_npcs()


func test_world_extras() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("superman", Vector3(560, 0.5, -440))
	var p := world.player
	# Street furniture can be thrown
	var kinds := {}
	for spot in world.city.parked:
		kinds[spot["kind"]] = true
	check(kinds.has("bench") and kinds.has("hydrant") and kinds.has("bike"), "the streets have benches, hydrants and motorcycles (%s)" % str(kinds.keys()))
	var bench := Prop.new()
	bench.build(world, "hydrant")
	world.props_root.add_child(bench)
	bench.global_position = p.global_position + Vector3(0, 0.2, -2)
	await _frames(2)
	Abilities.pick_up(p)
	check(p.held_prop == bench, "Superman can lift a fire hydrant")
	Abilities.throw_prop(p)
	# News, helicopter, weather, difficulty
	world.news.queue.clear()
	world.news.on_boss("Reverse-Flash")
	world.news._t = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.news.current.contains("Reverse-Flash"), "the news reports what happened")
	Game.heat = 3.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.helicopter.active, "a news helicopter arrives when the heat is up")
	Game.clear_heat()
	world.day_night.set_weather("snow")
	check(world.day_night.snow.emitting, "it can snow")
	world.day_night.set_weather("clear")
	Game.settings["difficulty"] = 2.0
	var hard := Game.damage_to_player()
	Game.settings["difficulty"] = 1.0
	check(hard > Game.damage_to_player(), "hard difficulty hurts more")
	# Collectibles, map, discovery, scan, photo mode
	check(world.collectibles.spots.size() == Collectibles.TOTAL, "40 Crisis Fragments are hidden on Earth-1")
	var left := world.collectibles.remaining()
	if not left.is_empty():
		var before: int = world.collectibles.found_count()
		world.teleport_player(left[0]["pos"] - Vector3.UP * 1.0)
		await _frames(2)
		await get_tree().process_frame
		check(world.collectibles.found_count() == before + 1, "walking into a fragment collects it")
	var star: Dictionary = world.city.landmark("CCPD")
	world.teleport_player(star["pos"])
	world._discover_t = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.progress["discovered"].has("CCPD"), "visiting a landmark discovers it")
	world.world_map.open()
	world.world_map._pick(star)
	check(world.waypoint != Vector3.INF, "the map sets a waypoint")
	world.world_map.close()
	world.photo.open()
	check(world.photo.active and get_tree().paused, "photo mode freezes the world")
	world.photo.close()
	check(not get_tree().paused, "and lets it go again")
	world.waypoint = Vector3.INF
	# Alternate suits
	Game.progress["suits"].append("flash:Season 1 Suit")
	Game.suit_choice["flash"] = "Season 1 Suit"
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	check(world.player.def["look"]["suit"] == "#5a0a0e", "the Flash wears his Season 1 suit")
	Game.suit_choice.erase("flash")
	# Achievements and challenges
	Game.record("kos")
	check(Game.progress["achievements"].has("first_blood"), "achievements unlock from stats")
	check(world.challenges.active.size() == 3, "three challenges are on offer")
	world.clear_npcs()


func test_activities_extra() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("killer_frost", Vector3(560, 0.5, -440))
	world.events.start_random("fire")
	var act = world.events.active.get("custom", null)
	check(act != null and act.trapped.size() == 4, "a building fire traps four people")
	if act:
		for c in act.trapped.duplicate():
			world.teleport_player(c.global_position + Vector3(0, 0, -1.5))
			await _frames(2)
			await get_tree().process_frame
			await get_tree().process_frame
			if world.door.get("interior", "") == "rescue":
				world.interact()
			check(world.carrying == c, "pick up a trapped civilian")
			world.teleport_player(act.ambulance + Vector3(2, 0.5, 0))
			await _frames(3)
		await _frames(3)
		await get_tree().process_frame
		check(world.events.active.is_empty(), "rescuing everyone completes the fire event")
	world.events.start_random("chase")
	act = world.events.active.get("custom", null)
	check(act != null and is_instance_valid(act.car) and act.car.getaway, "a getaway car speeds off")
	if act:
		var start: Vector3 = act.car.global_position
		await _frames(60)
		check(act.car.global_position.distance_to(start) > 10.0, "and it drives")
		act.car.hit(500.0, Vector3.ZERO, world.player)
		await _frames(5)
		check(act.robbers.size() == 2, "wreck it and the robbers bail out")
		for r in act.robbers:
			r.take_damage(9999.0, world.player)
		await _frames(5)
		await get_tree().process_frame
		check(world.events.active.is_empty(), "beat the robbers to finish the chase")
	# Survival
	world.survival.start()
	await _frames(200)
	check(world.survival.wave >= 1 and world.survival.foes.size() >= 3, "survival waves spawn")
	for f in world.survival.foes:
		if is_instance_valid(f):
			f.take_damage(99999.0, world.player)
	await _frames(400)
	check(world.survival.wave >= 2, "clearing a wave brings the next (%d)" % world.survival.wave)
	world.survival.stop()
	world.clear_npcs()
	# Recruit and swap
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	var ally: Actor = world.population.spawn_character(Game.get_character("vibe"), "hero", Vector3(561.5, 0.5, -440))
	await _frames(2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("interior", "") == "recruit", "a nearby hero can be recruited")
	world.interact()
	check(ally.follow_target == world.player, "Vibe joins the team")
	var old := world.player
	world.swap_to_next_ally()
	check(world.player == ally and ally.is_player and old.follow_target == ally, "Y switches control to the ally")
	# Bike and emotes
	var bike := Prop.new()
	bike.build(world, "bike")
	world.props_root.add_child(bike)
	bike.global_position = world.player.global_position + Vector3(2, 0.3, 0)
	await _frames(3)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("name", "").contains("motorcycle"), "motorcycles can be ridden")
	for k in 60:
		if world.player.is_on_floor():
			break
		await get_tree().physics_frame
	Emotes.play(world.player, 3)
	check(Game.stat("emotes") >= 1.0, "emotes play")
	world.clear_npcs()


func test_teams_and_new_heroes() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.events.enabled = false
	check(Game.roster.size() >= 130, "the roster has 130 characters (%d)" % Game.roster.size())
	for id in ["rip_hunter", "wildcat", "hourman", "dr_fate", "green_lantern", "icicle", "solomon_grundy", "the_shade", "doomsday", "black_flash"]:
		check(Game.by_id.has(id), "%s is playable" % id)
	var bad := []
	for t in Teams.TEAMS:
		for id in Teams.TEAMS[t]["members"]:
			if not Game.by_id.has(id):
				bad.append(id)
	for h in Teams.NEMESIS:
		if not Game.by_id.has(h) or not Game.by_id.has(Teams.NEMESIS[h]):
			bad.append(h)
	check(bad.is_empty(), "every team member and nemesis exists (%s)" % str(bad))
	check(Teams.share_team("stargirl", "wildcat") == "Justice Society", "Stargirl and Wildcat are both JSA")
	check(Teams.nemesis("flash") == "reverse_flash" and Teams.nemesis("reverse_flash") == "flash", "the Flash and the Reverse-Flash are nemeses")
	# The new powers all work.
	var specials := {"green_lantern": "construct", "hourman": "miraclo", "the_shade": "shadows", "dr_fate": "ankh",
		"johnny_thunder": "thunderbolt", "atom_smasher": "grow"}
	for id in specials:
		world.spawn_player(id, Vector3(560, 0.5, -440))
		var p: Actor = world.player
		var foe: Actor = world.population.spawn_thug(p.global_position + Vector3(0, 0.3, -5))
		foe.set_meta("pinned", true)
		await _frames(3)
		p.aim_point = foe.chest()
		check(p.def["special"]["kind"] == specials[id], "%s has %s" % [id, specials[id]])
		p.energy = p.max_energy
		var ok: bool = Abilities.special(p, p.def["special"])
		await _frames(30)
		check(ok and (foe.hp < foe.max_hp or foe.dead or id == "hourman" or id == "atom_smasher"), "%s's %s works" % [id, specials[id]])
		if id == "atom_smasher":
			check(p.size > 1.5, "Atom Smasher grows")
		if id == "hourman":
			check(p.rage_t > 0.0, "Miraclo powers Hourman up")
		world.clear_npcs()
	# Every new character can spawn and fight.
	for id in ["rip_hunter", "ava_sharpe", "stripe", "huntress", "spooner", "batwing", "icicle", "bizarro", "doomsday", "hush", "black_mask"]:
		world.spawn_player(id, Vector3(560, 0.5, -440))
		await _frames(2)
		world.player.in_primary = true
		world.player._abilities(0.016)
		world.player.in_primary = false
		check(is_instance_valid(world.player) and not world.player.dead, "%s spawns and attacks" % id)
	# Team-up bonus
	world.spawn_player("stargirl", Vector3(560, 0.5, -440))
	var ally: Actor = world.population.spawn_character(Game.get_character("wildcat"), "hero", Vector3(562, 0.5, -440), world.player)
	world._update_team_bonus()
	check(world.team_bonus == "Justice Society", "fighting beside a teammate gives a team-up bonus")
	ally.queue_free()
	await get_tree().process_frame
	world._update_team_bonus()
	check(world.team_bonus == "", "and it ends when they're gone")
	# Mastery
	var before := Game.mastery_level("stargirl")
	Game.progress["mastery"]["stargirl"] = float(Game.MASTERY_XP[1]) - 1.0
	check(Game.add_mastery("stargirl", 5.0) == 2, "mastery levels up")
	check(Game.mastery_bonus("stargirl") > 1.0, "mastery makes you stronger")
	Game.progress["mastery"]["stargirl"] = 0.0
	# Team and nemesis events
	world.events.start_random("team_attack")
	check(world.events.active.get("actors", []).size() == 3, "a villain team attacks together")
	world.events.reset()
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	world.events.start_random("nemesis")
	var acts: Array = world.events.active.get("actors", [])
	check(acts.size() == 1 and acts[0].def["id"] == "reverse_flash" and acts[0].boss, "the Reverse-Flash hunts the Flash")
	world.events.reset()
	world.clear_npcs()
	# JSA Headquarters
	check(Interiors.ORDER.has("jsa_hq") and world.city.landmark("JSA Headquarters").size() > 0, "the JSA has a headquarters in Smallville")
	world.jsa_rollcall()
	var jsa := 0
	for a in get_tree().get_nodes_in_group("actors"):
		if a.follow_target == world.player and Teams.TEAMS["Justice Society"]["members"].has(a.def.get("id", "")):
			jsa += 1
	check(jsa == 3, "the round table calls three JSA members")
	world.clear_npcs()
	world.events.enabled = true


func test_space_glide_missions() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.events.enabled = false
	# Bigger cities, further apart.
	check(City.N == 14 and world.city.islands.size() == 6, "islands are 14 blocks across")
	var c0: Vector2 = City.ISLAND_CENTERS[0]
	var c1: Vector2 = City.ISLAND_CENTERS[1]
	check(c0.distance_to(c1) >= 2000.0, "the cities are 2 km apart")
	check(world.city.bridges.size() >= 7, "long bridges join them")
	# Batwoman glides.
	world.spawn_player("batwoman", Vector3(560, 60.0, -440))
	var p: Actor = world.player
	check(p.def.get("glide", false), "Batwoman can glide")
	p.velocity = Vector3(0, -5.0, 0)
	world.player_brain = null
	p.brain = null
	var y0 := p.global_position.y
	for k in 40:
		p.in_up = true
		p.in_move = p.forward()
		await get_tree().physics_frame
	check(p.gliding or p.model.gliding, "holding jump while falling glides")
	var fallen := y0 - p.global_position.y
	check(fallen < 12.0, "gliding falls slowly (%.1f m)" % fallen)
	check(Vector3(p.velocity.x, 0, p.velocity.z).length() > 8.0, "and sails forward")
	p.in_up = false
	# Fly to space: Argo City.
	world.spawn_player("supergirl", Vector3(560, 0.5, -440))
	p = world.player
	p.flying = true
	p.global_position = Vector3(560, 720.0, -440)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.place_id == "argo", "flying high enough leaves Earth for Argo City")
	check(not world.city.landmark("Hall of Elders").is_empty(), "Argo City has the Hall of Elders")
	var kryptonians := 0
	for a in get_tree().get_nodes_in_group("actors"):
		if a.display_name == "Kryptonian":
			kryptonians += 1
	check(kryptonians >= 8, "Kryptonians live in Argo City")
	p = world.player
	p.global_position = Vector3(0, -150.0, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.place_id == "earth1" and world.player.global_position.y > 100.0, "diving off Argo City falls back to Earth")
	# The Speed Force.
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	world.travel_to("speedforce", "speed")
	await get_tree().process_frame
	check(world.city.get_node_or_null("SpeedForceFX") != null, "the Speed Force crackles with lightning and drifting memories")
	world.player.energy = 0.0
	world.use_door({"interior": "speedforce_talk"})
	check(world.player.energy >= world.player.max_energy - 0.1, "the Speed Force charges a speedster")
	world.travel_to("earth1", "speed")
	await get_tree().process_frame
	world.clear_npcs()
	# Personal missions
	world.char_missions.enabled = true
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	Game.progress["char_missions"].erase("flash")
	world.char_missions.set_character(world.player.def)
	check(world.char_missions.current().get("title", "") == "Lightning Strikes Twice", "the Flash has his own story")
	check(world.char_missions.tracker().begins_with("PERSONAL"), "personal missions show on the HUD")
	var gen := CharMissions.story_for(Game.get_character("wildcat"))
	check(gen.size() == 3 and str(gen[2]["title"]).contains("Tigress"), "everyone else gets missions from their team and nemesis")
	var tgt: Vector3 = world.city.landmark("Central City Downtown")["pos"]
	world.teleport_player(tgt)
	await _frames(3)
	check(world.char_missions.foes.size() == 3, "reaching the mission spawns the fight")
	for f in world.char_missions.foes.duplicate():
		if is_instance_valid(f):
			f.blocking = false
			f.in_block = false
			f.invuln_t = 0.0
			f.take_damage(99999.0, world.player)
	for k in 30:
		await get_tree().process_frame
		if world.char_missions.index == 1:
			break
	check(world.char_missions.index == 1, "beating them advances the story (%d)" % world.char_missions.index)
	Game.progress["char_missions"].erase("flash")
	world.char_missions.set_character(world.player.def)
	world.char_missions.enabled = false
	# Powers look like moves.
	var sp: Dictionary = {"kind": "ground_slam"}
	world.player.energy = world.player.max_energy
	Abilities.special(world.player, sp)
	check(world.player.model._action == "ground_pound", "a ground slam plays its own animation")
	world.clear_npcs()
	world.events.enabled = true


func test_loadouts_and_buildings() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.events.enabled = false
	# Loadouts
	var flash: Dictionary = Game.get_character("flash")
	var prim := Loadout.options(flash, "primary")
	check(prim.size() > 6 and prim[0]["name"] == flash["primary"]["name"], "the Flash has a list of primaries, his own first")
	var names := prim.map(func(o) -> String: return str(o["name"]))
	check(names.has("Mach Kicks") and names.has("Cold Gun"), "speedster powers and armory weapons are on offer")
	for id in ["green_arrow", "supergirl", "constantine", "atom", "batwoman", "grodd", "flash"]:
		var d: Dictionary = Game.get_character(id)
		for slot in Loadout.SLOTS:
			for o in Loadout.options(d, slot):
				if not Loadout._valid(slot, o):
					check(false, "%s has a bad %s option %s" % [id, slot, o.get("name", "")])
	var ci := names.find("Cold Gun")
	Loadout.choose("flash", "primary", ci)
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	check(world.player.def["primary"]["name"] == "Cold Gun", "a chosen weapon is equipped")
	check(world.player.def["look"]["gear"].get("right", "") == "cold_gun", "and it's in his hand")
	world.player.in_primary = true
	for k in 4:
		await get_tree().physics_frame
	world.player.in_primary = false
	Loadout.reset("flash")
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	check(world.player.def["primary"]["name"] == flash["primary"]["name"], "resetting brings back the signature kit")
	check(Game.get_character("flash")["primary"]["name"] == flash["primary"]["name"], "the roster itself is untouched")
	world.loadout_panel.open("supergirl")
	check(world.loadout_panel.visible and world.loadout_panel._rows.get_child_count() == 4, "the loadout screen has four slots")
	world.loadout_panel.close()
	# Telekinesis
	check(Game.get_character("grodd").get("telekinetic", false) and Game.get_character("thinker").get("telekinetic", false), "canon telekinetics are marked")
	world.spawn_player("damien_darhk", Vector3(560, 0.5, -440))
	var p: Actor = world.player
	var car := Prop.new()
	car.build(world, "car")
	world.props_root.add_child(car)
	car.global_position = p.global_position + Vector3(0, 0.6, -14)
	await _frames(3)
	p.aim_point = car.global_position
	p.rotation.y = 0.0
	check(p.tk_grab(), "a telekinetic lifts a car from 14 m away")
	await _frames(20)
	check(car.global_position.y > p.global_position.y + 1.0, "it floats in the air")
	p.tk_release(true)
	await _frames(5)
	check(not p.tk_hold and car.linear_velocity.length() > 10.0, "and is thrown")
	var foe: Actor = world.population.spawn_thug(p.global_position + Vector3(0, 0.3, -8))
	await _frames(3)
	p.aim_point = foe.chest()
	check(p.tk_grab() and p.tk_actor == foe, "telekinesis can lift a person")
	await _frames(15)
	check(foe.global_position.y > p.global_position.y + 0.5, "they hang helpless in the air")
	p.tk_release(true)
	check(foe.hp < foe.max_hp, "and get thrown")
	world.clear_npcs()
	# Walk-in entrances
	for room in ["star_labs", "queen_consolidated", "ccpd", "l_corp", "iron_heights", "arkham", "garfield"]:
		check(world.city.interior_slots.has(room), "%s has a front entrance you walk through" % Interiors.NAMES[room])
	var front := Interiors.outside_point("iron_heights")
	world.spawn_player("superman", front)
	world.inside = ""
	var into := Interiors.to_world("iron_heights", Vector3(0, 0.5, 8))
	world.player.global_position = into
	await _frames(3)
	world._process(0.016)
	check(Interiors.room_at(world.player.global_position) == "iron_heights", "Iron Heights' cell block is inside the prison")
	# Elevators
	world.enter_interior("queen_consolidated")
	world.use_door({"interior": "elevator", "data": "queen_consolidated"})
	check(world.player.global_position.y > 150.0, "the Queen Consolidated elevator goes to the roof")
	# Arrests and jailbreaks
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	var crook: Actor = world.population.spawn_thug(world.player.global_position + Vector3(1.5, 0.3, 0))
	await _frames(2)
	crook.take_damage(99999.0, world.player)
	await _frames(2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.door.get("interior", "") == "arrest", "a knocked-out crook can be arrested")
	world.interact()
	check(world.carrying == crook, "you carry them")
	var before := Game.stat("arrests")
	world.enter_interior("ccpd")
	world.interact()
	check(Game.stat("arrests") == before + 1.0, "dropping them at the CCPD books them")
	world.spawn_player("captain_cold", Vector3(560, 0.5, -440))
	world.enter_interior("iron_heights")
	check(world.inmates.size() >= 8, "Iron Heights is full of inmates")
	world.use_door({"interior": "cell", "data": "0"})
	var freed := 0
	for a in get_tree().get_nodes_in_group("actors"):
		if a.follow_target == world.player:
			freed += 1
	check(freed == 1, "a villain can break an inmate out")
	world.leave_interior("iron_heights")
	world.clear_npcs()
	world.inmates.clear()
	Game.clear_heat()
	# Med bay
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	world.player.hp = 10.0
	world.use_door({"interior": "medbay"})
	check(world.player.hp == world.player.max_hp, "the med bay patches you up")
	# Weapon pickups
	world.pickups.spawn(world.player.global_position + Vector3(0, 0.6, 0), "Shotgun", 3)
	await _frames(3)
	check(world.player.pickup_ammo == 3 and world.player.def["primary"]["name"] == "Shotgun", "walking over a dropped shotgun picks it up")
	for k in 3:
		world.player.cooldowns["primary"] = 0.0
		world.player.in_primary = true
		world.player._abilities(0.016)
	world.player.in_primary = false
	check(world.player.pickup_ammo == 0 and world.player.def["primary"]["name"] == flash["primary"]["name"], "out of ammo, back to your own powers")
	# Superhero landing
	world.spawn_player("superman", Vector3(560, 40.0, -440))
	world.player.velocity = Vector3(0, -45.0, 0)
	var landed := false
	for k in 90:
		await get_tree().physics_frame
		if world.player.model._action == "hero_land":
			landed = true
			break
	check(landed, "dropping from a height makes a superhero landing")
	# Boss rage
	var boss: Actor = world.population.spawn_character(Game.get_character("zoom"), "villain", Vector3(570, 0.5, -440))
	boss.make_boss(2.0)
	boss.blocking = false
	boss.take_damage(boss.max_hp * 0.6, world.player)
	check(boss.has_meta("enraged") and boss.rage_t > 0.0, "a boss at half health is enraged")
	world.clear_npcs()
	# Muggings and weather powers
	world.street_crime.enabled = true
	world.street_crime.start()
	check(is_instance_valid(world.street_crime.mugger), "a mugging can break out")
	world.street_crime.mugger.blocking = false   # a fresh block would parry the hit
	world.street_crime.mugger.take_damage(99999.0, world.player)
	for i in 3:
		await get_tree().process_frame
	check(world.street_crime.mugger == null, "stopping the mugger ends it")
	world.street_crime.enabled = false
	world.power_weather("storm", 1.0)
	check(world.day_night.weather == "storm", "Weather Wizard's storm changes the weather")
	world._tick_power_weather(2.0)
	check(world.day_night.weather != "storm", "and it clears up again")
	world.clear_npcs()
	world.events.enabled = true


func test_wheel_powers_streets() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.events.enabled = false
	# Every character has three extra powers.
	var short := []
	for c in Game.roster:
		var pw := Loadout.extra_powers(c)
		if pw.size() < 3:
			short.append(c["id"])
		for o in pw:
			if o["kind"] == c["special"]["kind"]:
				short.append(c["id"] + " repeats Q")
	check(short.is_empty(), "every character has three extra powers (%s)" % str(short))
	world.spawn_player("flash", Vector3(560, 0.5, -440))
	var p: Actor = world.player
	var foe: Actor = world.population.spawn_thug(p.global_position + Vector3(0, 0.3, -6))
	await _frames(3)
	p.aim_point = foe.chest()
	for i in 3:
		p.energy = p.max_energy
		p.in_power = [i == 0, i == 1, i == 2]
		p._abilities(0.016)
		p.in_power = [false, false, false]
		check(p.cooldowns["power%d" % (i + 1)] > 0.0, "power %d (%s) fires" % [i + 1, p.powers[i]["name"]])
		await _frames(10)
	world.clear_npcs()
	# Weapon wheel
	world.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	p = world.player
	world.weapon_wheel.open()
	check(world.weapon_wheel.visible and Engine.time_scale < 0.5, "the weapon wheel opens and slows time")
	check(world.weapon_wheel.options.size() >= 6, "it offers a ring of weapons")
	var target := world.weapon_wheel.options.size() / 2
	var ang := float(target) * TAU / world.weapon_wheel.options.size()
	world.weapon_wheel._aim = Vector2(sin(ang), -cos(ang)) * 120.0
	world.weapon_wheel._pick()
	var want: String = world.weapon_wheel.options[target]["name"]
	world.weapon_wheel.close(true)
	check(not world.weapon_wheel.visible and Engine.time_scale > 0.9, "letting go closes it")
	check(p.def["primary"]["name"] == want, "and equips what you pointed at (%s)" % want)
	world.weapon_wheel.ring = 2
	world.weapon_wheel.open()
	world.weapon_wheel.ring = 2
	world.weapon_wheel._load_ring()
	world.weapon_wheel._aim = Vector2(0, -120)
	world.weapon_wheel._pick()
	world.weapon_wheel.close(true)
	Loadout.reset("green_arrow")
	world.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	# Streets: subways, food carts, ATMs, phone booths, hoops, fountains
	var kinds := {}
	for pt in world.city.points:
		kinds[pt["kind"]] = true
	check(world.city.subways.size() >= 6, "there are subway stations (%d)" % world.city.subways.size())
	for k in ["food_cart", "vending", "atm", "phone_booth"]:
		check(kinds.has(k), "the streets have a %s" % k)
	var st: Dictionary = world.city.subways[0]
	var other: Dictionary = world.city.subways[world.city.subways.size() - 1]
	world.use_door({"interior": "subway", "data": st["name"]})
	check(world.world_map.visible and world.world_map.subway_from == st["name"], "the subway opens a list of stations")
	world.world_map._ride(other)
	check(world.player.global_position.distance_to(other["pos"]) < 3.0, "and rides you across the map")
	p = world.player
	p.hp = 10.0
	world.use_door({"interior": "food_cart"})
	check(p.hp > 10.0, "a hot dog heals")
	p.energy = 0.0
	world.use_door({"interior": "vending"})
	check(p.energy == p.max_energy, "an energy drink refills energy")
	world.use_door({"interior": "phone_booth"})
	var allies := get_tree().get_nodes_in_group("actors").filter(func(a) -> bool: return a.follow_target == p)
	check(allies.size() == 1, "a phone booth calls a teammate")
	world.use_door({"interior": "hoop"})
	world.use_door({"interior": "fountain"})
	world.spawn_player("captain_cold", Vector3(560, 0.5, -440))
	var heat := Game.heat
	world.use_door({"interior": "atm"})
	check(Game.heat > heat, "a villain can crack an ATM (and the police come)")
	Game.clear_heat()
	world.clear_npcs()
	# The map
	world.world_map.open()
	world.world_map._zoom_at(Vector2(100, 100), 2.0)
	check(world.world_map._zoom > 1.5, "the map zooms")
	world.world_map.close()
	world.events.enabled = true


func test_campaign() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.spawn_player("vibe", Vector3(560, 0.5, -440))
	world.missions.restart()
	check(world.missions.tracker().contains("S.T.A.R. Labs"), "chapter 1 points to S.T.A.R. Labs")
	check(world.missions.target_pos() != Vector3.INF, "the minimap marks the objective")
	world.enter_interior("star_labs")
	await _frames(4)
	await get_tree().process_frame
	check(world.missions.chapter == 1, "entering S.T.A.R. Labs completes chapter 1")
	world.leave_interior("star_labs")
	var guard := 0
	while not world.missions.is_complete() and guard < 8:
		guard += 1
		var c := world.missions.current()
		var place: String = c.get("place", "earth1")
		if world.place_id != place:
			world.travel_to(place, "breach")
		await _frames(3)
		await get_tree().process_frame
		await get_tree().process_frame
		if str(c["kind"]) == "defeat":
			check(world.missions.foes.size() == c["foes"].size(), "chapter %d spawns its foes" % (world.missions.chapter + 1))
			if c.get("boss", false):
				check(world.missions.foes[0].boss, "chapter %d has a boss" % (world.missions.chapter + 1))
			for f in world.missions.foes:
				if is_instance_valid(f):
					f.take_damage(999999.0, world.player)
			await _frames(3)
			await get_tree().process_frame
	check(world.missions.is_complete(), "the whole Crisis campaign can be finished")
	check(world.place_id == "earth1", "and it ends back home")
	world.missions.restart()
	world.travel_to("earth2", "breach")
	world.missions._set_chapter(0)
	await _frames(3)
	var zooms := get_tree().get_nodes_in_group("actors").filter(func(a) -> bool: return a.def.get("id", "") == "zoom")
	check(zooms.size() >= 1, "Earth-2's Zoom is waiting even outside the campaign")
	world.travel_to("earth1", "breach")
	world.clear_npcs()


func test_breach_and_new_features() -> void:
	world.clear_npcs()
	world.population.enabled = false
	world.events.enabled = true
	world.events.cooldown = 99999.0
	world.side_jobs.enabled = false
	if world.place_id != "earth1":
		world.travel_to("earth1", "speed")
	# Breaching opens a portal; nothing happens until you walk into it.
	world.spawn_player("vibe", Vector3(560, 0.5, -440))
	await _idle(3)
	world.open_breach("earth2")
	check(is_instance_valid(world.breach_portal), "breaching opens a portal")
	await _idle(70)
	check(world.place_id == "earth1", "the breach doesn't teleport you on its own")
	world.player.global_position = world.breach_portal.global_position - Vector3.UP * 2.0
	await _idle(4)
	check(world.place_id == "earth2", "walking into the breach takes you through")
	var exits := 0
	for c in world.get_children():
		if c is BreachPortal and c.exit_only:
			exits += 1
	check(exits == 1, "you step out of an exit breach on the other side")
	world.travel_to("earth1", "speed")
	world.spawn_player("superman", Vector3(560, 0.5, -440))
	var p: Actor = world.player
	await _idle(3)
	# Breach incursion: the breach keeps sending people until you smash it.
	world.events.start_random("incursion")
	var inc: Incident = world.events.active.get("custom")
	check(inc != null and is_instance_valid(inc.breach_body), "a breach incursion opens a hostile breach")
	inc._spawn_t = 0.0
	await _idle(3)
	check(inc.invaders.size() == 1, "doppelgangers come through the breach")
	inc.breach_body.hit(99999.0, Vector3.ZERO, p)
	for a in inc.invaders:
		a.take_damage(99999.0, p)
	await _idle(4)
	check(world.events.active.is_empty() and Game.stat("breaches_closed") >= 1.0, "smashing the breach and its invaders ends the incursion")
	# Meteors: anything that hits them breaks them.
	world.events.start_random("meteors")
	var met: Incident = world.events.active.get("custom")
	await _idle(3)
	check(met.meteors.size() == 1, "a meteor shower starts dropping meteors")
	var rock: HitTarget = met.meteors[0]["body"]
	Abilities.explode(world, rock.global_position, 3.0, 200.0, p)
	await _idle(2)
	check(met.smashed == 1, "an explosion smashes a meteor")
	var thug: Actor = world.population.spawn_thug(p.global_position + Vector3(0, 0.5, 8))
	met._spawn_meteor()
	var rock2: HitTarget = met.meteors[-1]["body"]
	rock2.hit(500.0, Vector3.ZERO, thug)
	check(not rock2.dead, "enemies can't break meteors for you")
	thug.queue_free()
	world.events.reset()
	# Falling civilians: catch them.
	world.events.start_random("falling")
	var fall: Incident = world.events.active.get("custom")
	if fall != null and fall.kind == "falling":
		fall._next_fall = 0.0
		await _idle(2)
		var who: Actor = fall.fallers[0]["actor"]
		p.global_position = who.global_position - Vector3.UP * 1.2
		await _idle(2)
		check(fall.caught == 1, "flying into a falling civilian catches them")
	else:
		check(false, "a falling-civilian event starts in the city")
	world.events.reset()
	# Runaway car: stand in front of it and it grinds to a halt.
	world.events.start_random("runaway")
	var run: Incident = world.events.active.get("custom")
	check(run != null and is_instance_valid(run.runaway_car), "a runaway car event starts")
	var stopped0 := Game.stat("runaways_stopped")
	for k in 300:
		if not is_instance_valid(run) or run.done or run.failed:
			break
		p.global_position = run.runaway_car.global_position + run.runaway_car.heading * 3.0
		await _idle(1)
	check(Game.stat("runaways_stopped") > stopped0, "a strong hero stops the runaway car")
	world.events.reset()
	# Most Wanted.
	var b: Actor = world.side_jobs.start_bounty()
	check(world.side_jobs.bounty_pos() != Vector3.INF, "a Most Wanted bounty appears on the map")
	var before_score := Game.score
	b.take_damage(999999.0, p)
	await _idle(2)
	check(world.side_jobs.bounty == null and Game.score > before_score, "taking down the bounty pays out")
	# Supply drop.
	var crate: Node3D = world.side_jobs.start_drop()
	crate.global_position.y = 0.6
	await _idle(2)
	p.hp = 10.0
	p.global_position = crate.global_position
	await _idle(2)
	check(world.side_jobs.drop == null and p.hp == p.max_hp, "opening a supply drop heals you")
	world.clear_npcs()
	# Help request: fetch the cat from the roof.
	var owner_npc: Actor = world.side_jobs.start_help()
	p.global_position = owner_npc.global_position + Vector3(1, 0, 0)
	await _idle(2)
	check(world._nearest_door().get("interior", "") == "help", "you can talk to someone asking for help")
	world.side_jobs.accept_help(owner_npc)
	check(is_instance_valid(world.side_jobs.cat), "their cat is stuck on a roof")
	p.global_position = world.side_jobs.cat.global_position - Vector3.UP * 1.2
	await _idle(2)
	check(world.side_jobs.cat_carried, "you can grab the cat")
	p.global_position = owner_npc.global_position + Vector3(1, 0, 0)
	await _idle(2)
	check(world.side_jobs.owner_npc == null and Game.stat("cats_rescued") >= 1.0, "bringing the cat back finishes the job")
	# Fans and selfies.
	var fan: Actor = world.population.spawn_civilian(p.global_position + Vector3(6, 0.5, 0))
	world.side_jobs.enabled = true
	world.side_jobs._fan_t = 0.0
	await _idle(2)
	world.side_jobs.enabled = false
	check(fan.has_meta("fan"), "civilians recognise a hero and ask for a selfie")
	world.side_jobs.selfie(fan)
	check(not fan.has_meta("fan") and Game.stat("selfies") >= 1.0, "taking the selfie")
	# Krypto.
	world.side_jobs.toggle_krypto()
	check(is_instance_valid(world.side_jobs.krypto), "Superman can whistle for Krypto")
	var foe: Actor = world.population.spawn_thug(p.global_position + Vector3(4, 0.5, 0))
	var hp0 := foe.hp
	for k in 90:
		await _idle(1)
		if foe.hp < hp0:
			break
	check(foe.hp < hp0, "Krypto bites the bad guys")
	world.spawn_player("flash", p.global_position)
	await _idle(2)
	check(world.side_jobs.krypto == null, "Krypto leaves when you aren't a Kryptonian")
	world.clear_npcs()
	# Target drill.
	world.side_jobs.start_drill()
	check(world.side_jobs.drones.size() == 4, "the target drill puts up drones")
	var d0: HitTarget = world.side_jobs.drones[0]
	d0.hit(5.0, Vector3.ZERO, world.player)
	check(world.side_jobs.drill_score == 1 and world.side_jobs.drones.size() == 4, "smashing a drone scores and another appears")
	world.side_jobs.drill_time = 0.01
	await _idle(2)
	check(world.side_jobs.drones.is_empty() and Game.stat("drill_best_flash") >= 1.0, "the drill ends and records your best")
	world.side_jobs.enabled = true
	world.events.enabled = true


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
