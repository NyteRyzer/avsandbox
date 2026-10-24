class_name World
extends Node3D
## The open world: city, sky, people, props, events, camera, HUD and the
## in-game menus. main.gd creates one World per play session.

signal quit_to_title
signal change_character_requested

var city: City
var day_night: DayNight
var population: Population
var events: Events
var missions: Missions
var char_missions: CharMissions
var loadout_panel: LoadoutPanel
var weapon_wheel: WeaponWheel
var pickups: Pickups
var street_crime: StreetCrime
var side_jobs: SideJobs
var race: Race
var style := StyleMeter.new()
var news: News
var collectibles: Collectibles
var world_map: WorldMap
var photo: PhotoMode
var challenges: Challenges
var survival: Survival
var music: Music
var carrying: Actor = null       # someone you're carrying out of a fire
var waypoint := Vector3.INF
var _last_pos := Vector3.INF
var scanning := false
var _discover_t := 0.0
var helicopter: Helicopter
var actors_root: Node3D
var props_root: Node3D
var fx_root: Node3D
var cam: CameraRig
var hud: Hud
var pause_menu: PauseMenu
var sandbox_menu: SandboxMenu
var travel_menu: TravelMenu
var ship: Waverider
var vehicle: Prop = null         # the car the player is driving
var _saved_layer := 0
var player: Actor
var player_brain: PlayerBrain
var gravity_scale := 1.0
var kos := 0
var _respawn_t := -1.0
var _last_district := ""
var _tips_shown := false
var place_id := "earth1"         # which Earth / era (a Multiverse id)
var inside := ""                 # which interior the player is in ("" outside)
var door: Dictionary = {}        # the door or console the player is next to
var _returns: Dictionary = {}    # interior id -> where to come back out
var breach_portal: BreachPortal  # an open breach waiting for the player to step through
var jump_ship: JumpShip           # the Legends' shuttle, when it's out of the Waverider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	city = City.new()
	city.name = "City"
	add_child(city)
	city.generate()
	day_night = DayNight.new()
	day_night.city = city
	add_child(day_night)
	actors_root = Node3D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	_spawn_parked()
	population = Population.new()
	population.world = self
	add_child(population)
	events = Events.new()
	events.world = self
	add_child(events)
	missions = Missions.new()
	missions.world = self
	add_child(missions)
	char_missions = CharMissions.new()
	char_missions.world = self
	add_child(char_missions)
	pickups = Pickups.new()
	pickups.world = self
	add_child(pickups)
	street_crime = StreetCrime.new()
	street_crime.world = self
	add_child(street_crime)
	side_jobs = SideJobs.new()
	side_jobs.world = self
	add_child(side_jobs)
	weapon_wheel = WeaponWheel.new()
	weapon_wheel.world = self
	add_child(weapon_wheel)
	loadout_panel = LoadoutPanel.new()
	add_child(loadout_panel)
	loadout_panel.closed.connect(func(changed: bool) -> void:
		capture_mouse(true)
		if changed and player and is_instance_valid(player):
			spawn_player(str(player.def["id"]), player.global_position)
			notify("Loadout: " + Loadout.describe(player.def), Color("#c8e8ff")))
	cam = CameraRig.new()
	add_child(cam)
	day_night.follow = cam
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	sandbox_menu = SandboxMenu.new()
	sandbox_menu.world = self
	add_child(sandbox_menu)
	pause_menu = PauseMenu.new()
	pause_menu.world = self
	add_child(pause_menu)
	travel_menu = TravelMenu.new()
	travel_menu.world = self
	add_child(travel_menu)
	ship = Waverider.new()
	ship.world = self
	add_child(ship)
	ship.park(city.waverider_dock)
	Game.notify.connect(notify)
	Game.rank_up.connect(_on_rank_up)
	race = Race.new()
	race.world = self
	add_child(race)
	news = News.new()
	news.world = self
	add_child(news)
	helicopter = Helicopter.new()
	helicopter.world = self
	add_child(helicopter)
	collectibles = Collectibles.new()
	collectibles.world = self
	add_child(collectibles)
	collectibles.build()
	world_map = WorldMap.new()
	world_map.world = self
	add_child(world_map)
	photo = PhotoMode.new()
	photo.world = self
	add_child(photo)
	challenges = Challenges.new()
	challenges.world = self
	add_child(challenges)
	survival = Survival.new()
	survival.world = self
	add_child(survival)
	music = Music.new()
	music.world = self
	add_child(music)
	Game.heat_changed.connect(_on_heat_for_news)


func _apply_rank(a: Actor) -> void:
	var b := Game.rank_bonus() * Game.mastery_bonus(str(a.def.get("id", "")))
	a.max_hp = float(a.def.get("health", 100)) * b
	a.hp = a.max_hp
	a.power = float(a.def.get("power", 1.0)) * b


var _news_heat := 0


func _on_heat_for_news(v: float) -> void:
	var level := int(v)
	if level >= 3 and level > _news_heat:
		news.on_heat(level)
	_news_heat = level


func _on_rank_up(r: int) -> void:
	hud.show_banner("RANK %d: %s" % [r, Game.rank_title(Game.player_side()).to_upper()], Color("#ffd23a"))
	notify("Rank up! +3%% health and power for every character (now +%d%%)." % int((Game.rank_bonus() - 1.0) * 100.0), Color("#ffd23a"))
	Sfx.play("event", null, 2.0)
	if player and is_instance_valid(player):
		var frac := player.hp / maxf(player.max_hp, 1.0)
		_apply_rank(player)
		player.hp = player.max_hp * frac
	Game.save_settings()


func _spawn_parked() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for spot in city.parked:
		var prop := Prop.new()
		prop.build(self, spot["kind"], r)
		props_root.add_child(prop)
		prop.global_transform = spot["xform"]
		prop.sleeping = true


func _exit_tree() -> void:
	if Game.notify.is_connected(notify):
		Game.notify.disconnect(notify)
	if Game.rank_up.is_connected(_on_rank_up):
		Game.rank_up.disconnect(_on_rank_up)
	if Game.heat_changed.is_connected(_on_heat_for_news):
		Game.heat_changed.disconnect(_on_heat_for_news)
	Game.end_slowmo()


## Spawns (or replaces) the player as the given roster character.
func spawn_player(id: String, at = null) -> void:
	if ship and ship.piloted:
		# Changing character at the helm: step back onto the bridge first.
		ship.leave_helm()
	var c := Loadout.apply(Costumes.apply(Game.get_character(id), str(Game.suit_choice.get(id, ""))))
	recent_chars.erase(id)
	recent_chars.push_front(id)
	if recent_chars.size() > 6:
		recent_chars.resize(6)
	var pos: Vector3
	var yaw := cam.yaw
	if at != null:
		pos = at
	elif player and is_instance_valid(player):
		pos = player.global_position
	else:
		pos = spawn_point_for(c)
	var old_heat := Game.heat
	exit_vehicle()
	if player and is_instance_valid(player):
		for a in get_tree().get_nodes_in_group("actors"):
			if a.follow_target == player:
				a.follow_target = null
		player.queue_free()
	player = Actor.new()
	player.world = self
	player.is_player = true
	player.setup(c, c["side"])
	player_brain = PlayerBrain.new()
	player_brain.cam_rig = cam
	player.brain = player_brain
	actors_root.add_child(player)
	player.global_position = pos
	player.died.connect(_on_player_died)
	_apply_rank(player)
	Game.player = player
	Game.selected_id = id
	Game.save_settings()
	cam.target = player
	cam.yaw = yaw
	cam.global_position = player.global_position + Vector3.UP * 1.6
	Game.heat = old_heat if at == null else 0.0
	hud.on_player_changed()
	notify("You are %s" % c["alias"], Color("#ffffff"))
	if str(char_missions.char_id) != id:
		char_missions.set_character(c)
	if c.get("glide", false):
		notify("Hold [Space] while falling to glide on your cape.", Color("#ffe080"))
	if not _tips_shown:
		_tips_shown = true
		notify("Tab: sandbox tools (spawn anyone, time, weather, teleport)", Color("#ffe080"))
		notify("Yellow marker on the minimap = an event to stop (or start)", Color("#ffe080"))
		notify("Esc: pause, change character, settings", Color("#ffe080"))
		notify("G: doors, consoles and travel  ·  R: your ultimate, once it's charged", Color("#ffe080"))
		if not missions.is_complete():
			missions._set_chapter(missions.chapter)


func spawn_point_for(c: Dictionary) -> Vector3:
	var idx := {"star": 0, "central": 1, "national": 2, "freeland": 3, "gotham": 4, "smallville": 5, "keystone": 6, "metropolis": 7,
		"blue_valley": 8}
	var home: String = c.get("home", "any")
	var center := Vector3(20, 0, 20)
	if city.kind == "metro":
		center = city.district_center(1)
	if idx.has(home):
		center = city.district_center(idx[home])
	return city.snap_to_road(center + Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))) + Vector3.UP * 0.5


func capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if sandbox_menu.visible:
			sandbox_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sandbox_menu"):
		sandbox_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		world_map.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo"):
		photo.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("wheel"):
		weapon_wheel.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("wheel"):
		weapon_wheel.close(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("emote_1") or event.is_action_pressed("emote_2") or event.is_action_pressed("emote_3") or event.is_action_pressed("emote_4"):
		for k in 4:
			if event.is_action_pressed("emote_%d" % (k + 1)) and player and is_instance_valid(player):
				Emotes.play(player, k + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("waverider"):
		if player and is_instance_valid(player):
			call_waverider()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump_ship"):
		if player and is_instance_valid(player):
			call_jump_ship()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("companion"):
		if player and is_instance_valid(player):
			side_jobs.toggle_krypto()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("swap"):
		swap_to_next_ally()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("suit"):
		if player and is_instance_valid(player) and vehicle == null and not ship.piloted:
			Suitup.toggle(player)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_hud"):
		hud.visible = not hud.visible
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		capture_mouse(true)


func _process(delta: float) -> void:
	style.tick(delta / maxf(Engine.time_scale, 0.01))
	if player and is_instance_valid(player):
		scanning = Input.is_action_pressed("scan") and not player.civilian and not player.dead
		_space_check()
		_tick_power_weather(delta)
		_team_t -= delta
		if _team_t <= 0.0:
			_team_t = 0.5
			_update_team_bonus()
		_discover_t -= delta
		if _discover_t <= 0.0:
			_discover_t = 1.0
			_discover()
			var pp := player.global_position
			if _last_pos != Vector3.INF and vehicle == null and not ship.piloted:
				var moved := Vector2(pp.x - _last_pos.x, pp.z - _last_pos.z).length()
				if moved > 0.5 and moved < 120.0:
					Game.record("distance", moved)
			_last_pos = pp
		if waypoint != Vector3.INF and Vector2(waypoint.x - player.global_position.x, waypoint.z - player.global_position.z).length() < 15.0:
			waypoint = Vector3.INF
			notify("Waypoint reached.", Color("#3affd0"))
	if _respawn_t >= 0.0:
		_respawn_t -= delta / maxf(Engine.time_scale, 0.01)
		if _respawn_t < 0.0 and player and is_instance_valid(player):
			player.revive()
			player.global_position = city.nearest_road_point(player.global_position)
			Game.clear_heat()
			hud.show_ko(false)
	if player and is_instance_valid(player):
		var was_in := inside
		inside = Interiors.room_at(player.global_position)
		if inside != was_in and inside != "":
			# Walk-in rooms (Iron Heights, Arkham) have no door to do this.
			_on_enter_room(inside)
		day_night.indoors = inside != ""
		population.enabled = inside == "" and not ship.piloted
		events.enabled = inside == "" and city.kind in ["metro", "western"]
		door = _nearest_door()
		var storm := "#ffe48a" if city.kind == "speedforce" else ("#ff3a4a" if city.kind == "antimatter" or city.spec.get("antimatter_storm", false) else "")
		if storm != "" and inside == "" and randf() < delta * 1.5:
			var c := player.global_position
			var a := c + Vector3(randf_range(-80, 80), randf_range(40, 90), randf_range(-80, 80))
			FX.lightning(self, a, a + Vector3(randf_range(-40, 40), randf_range(-30, 10), randf_range(-40, 40)), Color(storm), 0.25, 3.0, 8, 2)
		var d := place_name(player.global_position)
		if d != _last_district:
			_last_district = d
			hud.show_district(d)


## Walking near a landmark marks it on the map (and allows fast travel).
func _discover() -> void:
	if place_id != "earth1" or inside != "":
		return
	var found: Array = Game.progress["discovered"]
	var p := player.global_position
	for l in city.landmarks:
		if l.get("interior", false) or found.has(l["name"]):
			continue
		var lp: Vector3 = l["pos"]
		if Vector2(lp.x - p.x, lp.z - p.z).length() < 45.0:
			found.append(l["name"])
			notify("Discovered: %s  (fast travel from the map, M)" % l["name"], Color("#bfe8ff"))
			Game.add_score(10)
			Game.record("discovered")


## "Central City", or "Earth-2 · Central City" away from home.
func place_name(p: Vector3) -> String:
	var d := city.district_at(p)
	if place_id == "earth1" or Interiors.room_at(p) != "" or city.kind != "metro":
		return d
	return "%s · %s" % [Multiverse.dest(place_id)["name"], d]


# --- Doors, interiors and travel ---------------------------------------------

func _nearest_door() -> Dictionary:
	if ship.piloted or player.dead:
		return {}
	var p := player.global_position
	var best: Dictionary = {}
	var best_d := 3.2
	for dr in city.doors:
		var dp: Vector3 = dr["pos"]
		var dd := Vector2(dp.x - p.x, dp.z - p.z).length()
		if dd < best_d and absf(dp.y - p.y) < 3.0:
			best_d = dd
			best = dr
	if inside == "" and best.is_empty() and is_instance_valid(jump_ship) and jump_ship.state == "landed" \
			and jump_ship.global_position.distance_to(p) < 8.0:
		best = {"name": "Board the Jump Ship (fly to the Waverider)", "pos": jump_ship.global_position, "interior": "jump_ship"}
	if inside == "" and best.is_empty() and ship.near(p, 25.0):
		best = {"name": "The Waverider", "pos": ship.global_position, "interior": "waverider"}
	# People trapped in a fire, and heroes who might join you.
	if best.is_empty() and carrying == null:
		for o in get_tree().get_nodes_in_group("actors"):
			if o == player or o.global_position.distance_to(p) > 2.8:
				continue
			if o.dead:
				if Game.player_side() == 1 and o.team in ["villain", "thug"] and not o.has_meta("inmate") and not player.civilian:
					best = {"name": "Arrest %s (carry them to a cell)" % o.display_name, "pos": o.global_position, "interior": "arrest", "actor": o}
					break
				continue
			if o.has_meta("trapped"):
				best = {"name": "Carry %s to safety" % o.display_name, "pos": o.global_position, "interior": "rescue", "actor": o}
				break
			if o.has_meta("help_request"):
				best = {"name": "Ask what's wrong", "pos": o.global_position, "interior": "help", "actor": o}
				break
			if o.has_meta("fan") and not player.civilian:
				best = {"name": "Take a selfie with your fan", "pos": o.global_position, "interior": "selfie", "actor": o}
				break
			if not player.civilian and o.follow_target == null and not o.is_hostile_to(player) and not player.is_hostile_to(o) \
					and o.side() == player.side() and o.def.get("id", "") not in ["civilian", "police", "thug"] and not o.has_meta("summon"):
				best = {"name": "Recruit %s" % o.display_name, "pos": o.global_position, "interior": "recruit", "actor": o}
				break
	# Takedowns: finish off a beaten enemy up close.
	if best.is_empty() and not player.civilian:
		for o in get_tree().get_nodes_in_group("actors"):
			if o == player or o.dead or o.team == "civilian" or not (o.is_hostile_to(player) or o.grudges.has(player.get_instance_id())):
				continue
			var low: bool = o.hp < o.max_hp * (0.1 if o.boss else 0.22) or (o.stun_t > 0.0 and o.hp < o.max_hp * 0.35 and not o.boss) \
				or o.staggered_t > 0.0
			if low and o.global_position.distance_to(p) < 3.5:
				best = {"name": "Takedown " + o.display_name, "pos": o.global_position, "interior": "takedown", "actor": o}
				break
	if inside == "" and best.is_empty() and vehicle == null and not player.flying:
		var best_car: Prop = null
		var car_d := 3.6
		for prop in get_tree().get_nodes_in_group("props"):
			if prop.is_vehicle() and not prop.exploded and prop.holder == null:
				var cd: float = prop.global_position.distance_to(p)
				if cd < car_d:
					car_d = cd
					best_car = prop
		if best_car:
			var what := "motorcycle" if best_car.kind == "bike" else "car"
			best = {"name": ("Ride the " if best_car.kind == "bike" else "Drive the ") + what if not best_car.driving else "Carjack the " + what, "pos": best_car.global_position, "interior": "car", "prop": best_car}
	return best


## What [G] would do right now, for the HUD prompt ("" if nothing).
func interact_prompt() -> String:
	if ship.piloted:
		return ""
	if vehicle:
		return "%d km/h   ·   W/S drive  ·  A/D steer  ·  Space handbrake  ·  Shift nitro  ·  G get out" % int(vehicle.speed_kmh())
	if not door.is_empty():
		var what: String = door["interior"]
		if what == "waverider":
			return "[G]  Board the Waverider   ·   [U]  Take off in it"
		if what == "helm":
			return "[G]  Take the helm   ·   [U]  works from anywhere"
		if what in Interiors.ORDER:
			return "[G]  Enter " + str(door["name"])
		return "[G]  " + str(door["name"])
	if inside == "" and _can_run_between_worlds():
		return "[G]  Run into the Speed Force / to another Earth"
	if inside == "" and _can_breach():
		return "[G]  Open a breach to another Earth"
	return ""


func _can_run_between_worlds() -> bool:
	return player.movement == "speed" and player.in_sprint and Vector3(player.velocity.x, 0, player.velocity.z).length() > 30.0


func _can_breach() -> bool:
	return player.def.get("id", "") == "vibe"


func interact() -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if ship.piloted:
		ship.leave_helm()
		return
	if vehicle:
		exit_vehicle()
		return
	if carrying:
		_drop_carried()
		return
	if not door.is_empty():
		use_door(door)
	elif inside == "" and _can_run_between_worlds():
		travel_menu.open("speed")
	elif inside == "" and _can_breach():
		travel_menu.open("breach")


func use_door(d: Dictionary) -> void:
	var what: String = d["interior"]
	if what == "waverider" and not ship.piloted:
		# Gideon beams you aboard: a column of light, and you're in the cargo bay.
		FX.flash(self, player.chest(), Color("#bfe8ff"), 2.0, 0.4, 0.6)
		FX.lightning(self, player.chest(), ship.global_position, Color("#9ad8ff"), 0.6, 0.5, 6, 0)
		Sfx.play("teleport", player.global_position, -2.0)
	match what:
		"exit":
			leave_interior(str(d.get("outside", inside)))
		"suit":
			FX.flash(self, player.chest(), Color("#ffffff"), 1.4)
			spawn_player(str(d["data"]), player.global_position)
		"speedforce":
			if player.movement == "speed":
				travel_to("speedforce", "speed")
			else:
				notify("Only a speedster can run fast enough to reach the Speed Force.", Color("#ffd27a"))
		"breach_room":
			travel_menu.open("breach")
		"time_console":
			travel_menu.open("time")
		"nav_console":
			set_ship_course()
		"helm":
			ship.take_helm()
		"car":
			enter_vehicle(d["prop"])
		"takedown":
			takedown(d["actor"])
		"rescue":
			carrying = d["actor"]
			carrying.collision_layer = 0
			notify("Carry them to the ambulance. [G] puts them down.", Color("#60ff90"))
		"recruit":
			recruit(d["actor"])
		"jump_ship":
			_jump_ship_up()
		"jump_ship_out":
			_jump_ship_down()
		"help":
			side_jobs.accept_help(d["actor"])
		"selfie":
			side_jobs.selfie(d["actor"])
		"drill":
			side_jobs.start_drill()
		"training":
			survival.start()
		"jsa_rollcall":
			jsa_rollcall()
		"cell":
			_cell(d)
		"arrest":
			carrying = d["actor"]
			carrying.collision_layer = 0
			carrying.set_meta("pinned", true)
			notify("Carry them to Iron Heights, Arkham or the CCPD holding cell. [G] at a cell locks them up.", Color("#9fc8ff"))
		"elevator":
			var room := str(d.get("data", inside))
			if city.roofs.has(room):
				_move_player(city.roofs[room])
				inside = ""
				_last_district = ""
				notify("The elevator opens onto the roof.", Color("#ffe8a0"))
			else:
				notify("The elevator's out of order on this Earth.", Color("#ffe8a0"))
		"subway", "food_cart", "vending", "atm", "phone_booth", "hoop", "fountain":
			_street_interact(d)
		"armory":
			capture_mouse(false)
			loadout_panel.open(str(player.def["id"]))
		"medbay":
			player.heal(player.max_hp)
			player.energy = player.max_energy
			for a in get_tree().get_nodes_in_group("actors"):
				if a.is_ally_of_player():
					a.heal(a.max_hp)
			FX.flash(self, player.chest(), Color("#60ff90"), 2.0, 0.4, 0.5)
			notify("Patched up: full health and energy.", Color("#60ff90"))
			Game.record("medbay")
		"balcony":
			leave_interior("catco", 60.0)
		"exit_speedforce":
			travel_to("earth1", "speed")
		"speedforce_talk":
			_speed_force_talk()
		_:
			if what in Interiors.ORDER:
				enter_interior(what)


## The Speed Force speaks through a familiar face, and charges up a speedster.
const SPEED_FORCE_LINES := [
	"\"You can't outrun this, Barry. But you don't have to run alone.\"",
	"\"I am the Speed Force. I have always been with you.\"",
	"\"Every moment you've ever lived is here. Stop running from them.\"",
	"\"Your mother's death is not your fault. Let it go, and run.\"",
	"\"The Speed Force is in everything that moves. Even you.\"",
]


func _speed_force_talk() -> void:
	var line: String = SPEED_FORCE_LINES[randi() % SPEED_FORCE_LINES.size()]
	notify("The Speed Force: " + line, Color("#ffe8a0"))
	FX.flash(self, player.chest(), Color("#ffe8a0"), 4.0, 0.6, 0.6)
	if player.movement == "speed":
		player.energy = player.max_energy
		player.add_ult(100.0)
		player.heal(player.max_hp)
		player.rage_t = maxf(player.rage_t, 20.0)
		FX.aura(player, Color("#ffd23a"), player.size, 20.0)
		notify("You are charged with the Speed Force: full energy, full ultimate.", Color("#ffd23a"))
		Game.record("speed_force_charges")
	else:
		notify("\"You are not a speedster. But you are welcome here.\"", Color("#ffe8a0"))


## Weather powers: a storm called down, a deep freeze. The sky changes for a
## while, then goes back to what it was.
var _power_weather_t := 0.0
var _weather_before := ""


func power_weather(w: String, seconds := 30.0) -> void:
	if inside != "" or city.kind != "metro":
		return
	if _power_weather_t <= 0.0:
		_weather_before = day_night.weather
	_power_weather_t = seconds
	if day_night.weather != w:
		day_night.set_weather(w)
		notify("The sky answers: %s rolls in." % ("a storm" if w == "storm" else ("snow" if w == "snow" else w)), Color("#c8e0ff"))


func _tick_power_weather(delta: float) -> void:
	if _power_weather_t <= 0.0:
		return
	_power_weather_t -= delta
	if _power_weather_t <= 0.0:
		day_night.set_weather(_weather_before if _weather_before != "" else "clear")


# --- Street interactables -----------------------------------------------------

var _phone_t := 0.0
var _coin_t := 0.0


func _street_interact(d: Dictionary) -> void:
	var p := player
	match str(d["interior"]):
		"subway":
			world_map.open_subway(str(d.get("data", "")))
		"food_cart":
			p.heal(p.max_hp * 0.4)
			FX.sparks(self, p.chest(), Color("#ffd27a"), 8, 2.0, 0.4)
			notify("A Central City hot dog. +40% health.", Color("#ffd27a"))
			Game.record("hot_dogs")
		"vending":
			p.energy = p.max_energy
			notify("An energy drink. Energy full.", Color("#6ad0ff"))
		"atm":
			if Game.player_side() == -1 and not p.civilian:
				Game.add_score(100)
				Game.add_heat(1.0)
				FX.sparks(self, p.chest() + p.forward(), Color("#6ad0ff"), 14, 4.0, 0.5)
				notify("You crack the ATM.  +100  (the police are on their way)", Color("#ff9a6a"))
				for k in 2:
					var cop: Actor = population.spawn_police(city.random_road_point(p.global_position, 25.0, 45.0))
					cop.grudges[p.get_instance_id()] = 40.0
				Game.record("atms_cracked")
			else:
				notify("Balance: one hero's salary. Not much.", Color("#bcd4ff"))
		"phone_booth":
			if _phone_t > Time.get_ticks_msec() / 1000.0:
				notify("Nobody's picking up. Try again in a bit.", Color("#bcd4ff"))
				return
			var team := Teams.main_team(str(p.def.get("id", "")))
			var ids: Array = Teams.members(team).filter(func(id) -> bool: return id != str(p.def.get("id", "")))
			if ids.is_empty():
				notify("You call... but you work alone.", Color("#bcd4ff"))
				return
			var who: String = ids[randi() % ids.size()]
			var a: Actor = population.spawn_character(Game.get_character(who), p.team, p.global_position + Vector3(2, 0.3, 2), p)
			a.set_meta("pinned", true)
			FX.breach(self, a.chest(), Teams.color(team), 0.8, 1.2)
			notify("%s answers the call and joins you." % a.display_name, Teams.color(team))
			_phone_t = Time.get_ticks_msec() / 1000.0 + 60.0
		"hoop":
			p.model.play("throw", 0.4)
			if randf() < 0.5 + (0.3 if p.movement == "speed" else 0.0):
				Game.add_score(10)
				notify("Swish!  +10", Color("#ffb070"))
				Game.record("hoops")
			else:
				notify("Off the rim.", Color("#c8c8c8"))
		"fountain":
			if _coin_t > Time.get_ticks_msec() / 1000.0:
				notify("Your pockets are empty for now.", Color("#c8e8ff"))
				return
			_coin_t = Time.get_ticks_msec() / 1000.0 + 90.0
			var luck := randi() % 3
			match luck:
				0:
					p.rage_t = maxf(p.rage_t, 20.0)
					notify("Lucky coin: your hits land harder for a while.", Color("#ffd23a"))
				1:
					p.add_ult(40.0)
					notify("Lucky coin: ultimate +40.", Color("#ffd23a"))
				_:
					Game.add_score(25)
					notify("You make a wish.  +25", Color("#ffd23a"))
			FX.sparks(self, p.chest() + p.forward() * 2.0, Color("#ffd23a"), 6, 3.0, 0.4)


## The JSA brownstone's round table: three members of the Justice Society
## join you (if they aren't you already).
func jsa_rollcall() -> void:
	var ids: Array = Teams.members("Justice Society").filter(func(id) -> bool: return id != str(player.def.get("id", "")))
	ids.shuffle()
	var names := []
	for id in ids.slice(0, 3):
		var a: Actor = population.spawn_character(Game.get_character(id), player.team, player.global_position + Vector3(randf_range(-3, 3), 0.3, randf_range(2, 4)), player)
		a.set_meta("pinned", true)
		names.append(str(a.def["alias"]))
	notify("The Justice Society answers: " + ", ".join(names), Color("#ffd23a"))
	Game.record("recruits", names.size())


## The last enemy (or a boss) goes down in slow motion.
func final_blow(a: Actor) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Game.start_slowmo(0.9)
	shake_at(a.global_position, 0.4)
	FX.flash(self, a.chest(), Color.WHITE, 1.4, 0.3, 0.5)


## The bridge's navigation console: each use sets a course for the next
## city round the map. Gideon flies there and hovers over its shore.
func set_ship_course(index := -1) -> void:
	if city.kind != "metro":
		notify("Gideon: \"There's nowhere to fly to here, Captain. Try a time jump.\"", Color("#ffb04a"))
		return
	if index < 0:
		var here := city.district_index(ship.global_position)
		if ship.course != Vector3.INF:
			here = City.DISTRICTS.find(ship.course_name)
		index = (here + 1) % City.DISTRICTS.size()
	var c: Vector2 = City.ISLAND_CENTERS[index]
	# Hover above the north shore strip, lengthwise along it, so the ramp
	# comes down on open ground.
	var spot := Vector3(c.x, 34.0, c.y - City.HALF - City.ROAD * 0.5 - 24.0)
	ship.set_course(spot, PI * 0.5, City.DISTRICTS[index])
	if not ship.course_done.is_connected(_on_course_done):
		ship.course_done.connect(_on_course_done)
	notify("Gideon: \"Course laid in for %s.\"  (use the console again for the next city)" % City.DISTRICTS[index], Color("#ffb04a"))
	Game.record("ship_courses")


func _on_course_done(name: String) -> void:
	notify("Gideon: \"We've arrived over %s.\" Step off the ramp in the cargo bay." % name, Color("#ffb04a"))


## A cinematic finisher on a beaten enemy.
func takedown(o: Actor) -> void:
	if not is_instance_valid(o) or o.dead:
		return
	var to := o.global_position - player.global_position
	to.y = 0
	player.face_dir = to.normalized()
	player.global_position = o.global_position - to.normalized() * 1.4
	player.velocity = Vector3.ZERO
	o.stun_t = 2.0
	o.staggered_t = 0.0
	if o._stagger_label:
		o._stagger_label.queue_free()
		o._stagger_label = null
	var moves := ["uppercut", "spin_kick", "heavy", "kick"]
	player.model.play(moves[randi() % moves.size()], 0.5)
	Game.start_slowmo(0.7)
	shake_at(o.global_position, 0.5)
	var color := Color(str(player.def["look"].get("trail", player.def["look"].get("accent", "#ffffff"))))
	FX.flash(self, o.chest(), color, 1.5, 0.3, 0.7)
	FX.ring(self, o.chest(), color, 3.0, 0.4, to.normalized())
	# A reeling boss loses a fifth of its health; anyone else goes down.
	var dmg := o.max_hp * 0.2 if o.boss and o.hp > o.max_hp * 0.1 else o.hp + 50.0
	o.take_damage(dmg, player, "", to.normalized() * 14.0 + Vector3.UP * 10.0)
	o.model.tumble(16.0)
	style.add(10, "takedown")
	Game.add_score(25)
	Game.record("takedowns")
	hud.show_banner("TAKEDOWN", color)
	Sfx.play("slam", o.global_position, 4.0)


func enter_vehicle(car: Prop) -> void:
	if car.driving and Game.player_side() == 1:
		Game.add_heat(0.6)
		notify("Carjacking! Heroes borrow cars, they don't steal them.", Color("#ff9070"))
	elif car.driving:
		Game.add_heat(0.3)
		Game.add_score(5)
	if car.getaway:
		# Hijacking a getaway car ends the getaway: the robbers bail out.
		car.getaway = false
	vehicle = car
	car.take_wheel(player)
	Game.record("drives")
	_saved_layer = player.collision_layer
	player.collision_layer = 0
	player.velocity = Vector3.ZERO
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cam.zoom = 9.0
	cam.spring.add_excluded_object(car.get_rid())
	Sfx.play("click", null, 0.0)


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var car := vehicle
	vehicle = null
	var side := car.global_basis.x * -2.4
	if is_instance_valid(car):
		car.leave_wheel()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.collision_layer = _saved_layer
	player.global_position = car.global_position + side + Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	cam.zoom = 5.5


func _drop_carried() -> void:
	if carrying and is_instance_valid(carrying) and carrying.dead and (inside in Interiors.PRISONS or inside == "ccpd"):
		var key := ""
		if inside in Interiors.PRISONS:
			var pts := Interiors.cell_points(inside)
			var best := 0
			var bd := INF
			for k in pts.size():
				var dd: float = Interiors.to_world(inside, pts[k]).distance_to(player.global_position)
				if dd < bd:
					bd = dd
					best = k
			key = "%s:%d" % [inside, best]
		_lock_up(key)
		return
	var c := carrying
	carrying = null
	if not is_instance_valid(c):
		return
	c.collision_layer = Game.LAYER_ACTORS
	c.global_position = player.global_position + player.forward() * 1.2
	var act = events.active.get("custom", null)
	if act and is_instance_valid(act) and act.kind == "fire":
		act.carried_drop(c)


func recruit(o: Actor) -> void:
	var allies := get_tree().get_nodes_in_group("actors").filter(func(a) -> bool: return a.follow_target == player)
	if allies.size() >= 3:
		notify("You already have three allies.", Color("#ffd27a"))
		return
	o.follow_target = player
	o.set_meta("pinned", true)
	o.team = player.team
	FX.flash(self, o.chest(), Color("#5fa8ff"), 1.2, 0.3)
	notify("%s joins your team. [Y] switches to them." % o.display_name, Color("#a0d0ff"))
	Game.record("recruits")


## Tag team: take control of one of your allies; you become their backup.
var recent_chars: Array[String] = []   # most recently played first


## [Y] with no allies around: flip back to the character you played before,
## right where you stand. Tap again to flip back.
func quick_swap() -> void:
	if recent_chars.size() < 2:
		notify("No allies to switch to. Recruit heroes with [G], spawn some from the Tab menu, or pick another hero to flip between them with [Y].", Color("#ffd27a"))
		return
	var prev: String = recent_chars[1]
	var at := player.global_position
	FX.flash(self, player.chest(), Color("#ffffff"), 2.0, 0.3, 0.4)
	spawn_player(prev, at)
	player.velocity = Vector3.ZERO
	notify("Swapped to %s. [Y] to swap back." % str(player.def.get("name", prev)), Color("#bfe8ff"))
	Game.record("quick_swaps")


func swap_to_next_ally() -> void:
	if player == null or not is_instance_valid(player) or player.dead or vehicle or ship.piloted or player.changing or carrying:
		return
	# Clones and summons vanish after a while, so you can't take them over.
	var allies := get_tree().get_nodes_in_group("actors").filter(func(a) -> bool:
		return a.follow_target == player and not a.dead and not a.has_meta("temporary"))
	if allies.is_empty():
		quick_swap()
		return
	var a: Actor = allies[0]
	var old := player
	old.is_player = false
	old.lock_target = null
	var brain := AIBrain.new()
	brain.role = "fighter"
	brain.home = old.global_position
	brain.leash = 0.0
	brain.detect = 55.0
	old.brain = brain
	old.follow_target = a
	if old.died.is_connected(_on_player_died):
		old.died.disconnect(_on_player_died)
	a.follow_target = null
	a.is_player = true
	a.brain = player_brain
	a.grudges.clear()
	a.died.connect(_on_player_died)
	for other in allies:
		if other != a:
			other.follow_target = a
	player = a
	Game.player = a
	cam.target = a
	for m in a.model.meshes:
		m.visibility_range_end = 0.0
	hud.on_player_changed()
	FX.flash(self, a.chest(), Color("#5fa8ff"), 1.0, 0.25)
	notify("You are now %s." % a.display_name, Color("#a0d0ff"))


func _physics_process(_delta: float) -> void:
	if carrying and is_instance_valid(carrying) and player and is_instance_valid(player):
		carrying.dead_time = 0.0
		carrying.global_position = player.global_position + Vector3.UP * 1.1 * player.size - player.forward() * 0.3
		carrying.velocity = Vector3.ZERO
		carrying.rotation.y = player.rotation.y
		var act = events.active.get("custom", null)
		if act and is_instance_valid(act) and act.kind == "fire" and carrying.global_position.distance_to(act.ambulance) < 7.0:
			_drop_carried()
	elif carrying:
		carrying = null
	if vehicle and is_instance_valid(vehicle) and player and is_instance_valid(player):
		player.global_position = vehicle.global_position + Vector3.UP * 1.0
		player.invuln_t = 0.5
	elif vehicle:
		exit_vehicle()


func enter_interior(id: String, remember := true) -> void:
	if remember and inside == "":
		_returns[id] = player.global_position
	var spot := city.landmark("Inside " + Interiors.NAMES[id])
	var pos: Vector3 = spot["pos"] if not spot.is_empty() else Interiors.origin(id) + Vector3.UP
	_move_player(pos)
	inside = id
	FX.flash(self, player.chest(), Color("#ffffff"), 1.2, 0.3, 0.4)
	notify("Entered " + Interiors.NAMES[id], Color("#bfe8ff"))
	_on_enter_room(id)


# --- Prisons: inmates, arrests and jailbreaks ---------------------------------

var inmates: Dictionary = {}       # "room:cell" -> Actor
var _jailed: Dictionary = {}       # "room:cell" -> character id (who's locked up where)

const INMATES := {"iron_heights": ["captain_cold", "heat_wave", "weather_wizard", "mirror_master", "golden_glider", "pied_piper",
	"trickster", "king_shark", "atom_smasher", "livewire"],
	"arkham": ["alice", "poison_ivy", "hush", "black_mask", "count_vertigo", "deadshot", "solomon_grundy", "eclipso", "dragon_king", "tigress"]}


## Walking into a prison: its inmates sit behind the bars.
func _on_enter_room(id: String) -> void:
	if not id in Interiors.PRISONS:
		return
	var pts := Interiors.cell_points(id)
	for k in pts.size():
		var key := "%s:%d" % [id, k]
		if inmates.has(key) and is_instance_valid(inmates[key]):
			continue
		var who: String = _jailed.get(key, INMATES[id][k % INMATES[id].size()])
		if who == "" or not Game.by_id.has(who):
			continue
		var a: Actor = population.spawn_character(Game.get_character(who), "villain", Interiors.to_world(id, pts[k]) + Vector3(0, 0.3, 0))
		a.brain = null
		a.set_meta("pinned", true)
		a.set_meta("inmate", key)
		a.collision_layer = 0
		inmates[key] = a


func _cell(d: Dictionary) -> void:
	var key := "%s:%s" % [inside, str(d.get("data", "0"))]
	var a = inmates.get(key, null)
	if carrying and is_instance_valid(carrying) and carrying.dead:
		_lock_up(key)
		return
	if a == null or not is_instance_valid(a):
		notify("The cell is empty. Knock out a villain and carry them here (G).", Color("#bcd4ff"))
		return
	if Game.player_side() == 1:
		notify("%s glares at you through the bars." % a.display_name, Color("#bcd4ff"))
		return
	# Jailbreak: the inmate walks free and joins you.
	inmates.erase(key)
	_jailed[key] = ""
	a.remove_meta("inmate")
	a.collision_layer = Game.LAYER_ACTORS
	a.brain = AIBrain.new()
	a.brain.role = "fighter"
	a.brain.home = a.global_position
	a.brain.detect = 55.0
	a.follow_target = player
	a.team = player.team
	a.global_position = player.global_position + player.forward() * 2.0
	FX.flash(self, a.chest(), Color("#ff6a4a"), 1.4, 0.3)
	notify("JAILBREAK: %s is free and on your side!" % a.display_name, Color("#ff9a6a"))
	Game.record("jailbreaks")
	Game.add_heat(1.0)
	Game.add_score(60)


## Arrests: a knocked-out villain carried into a cell (or CCPD's holding cell).
func _lock_up(key := "") -> void:
	var c := carrying
	carrying = null
	if not is_instance_valid(c):
		return
	var who := str(c.def.get("id", ""))
	if key != "" and Game.by_id.has(who):
		_jailed[key] = who
		if inmates.has(key) and is_instance_valid(inmates[key]):
			inmates[key].queue_free()
		inmates.erase(key)
	FX.flash(self, c.chest(), Color("#4f8aff"), 1.2, 0.3)
	notify("ARRESTED: %s is behind bars.  +75" % c.display_name, Color("#9fc8ff"))
	c.queue_free()
	Game.record("arrests")
	Game.add_score(75)
	if key != "":
		_on_enter_room(inside)


## Steps back outside. `lift` raises the exit point (the CatCo balcony).
func leave_interior(id: String, lift := 0.0) -> void:
	var pos := Vector3.ZERO
	if id == "waverider":
		pos = ship.boarding_point()
	elif not Interiors.is_remote(id):
		pos = Interiors.outside_point(id)
	elif _returns.has(id):
		pos = _returns[id]
	else:
		pos = spawn_point_for(player.def)
		for dr in city.doors:
			if dr["interior"] == id:
				pos = dr["pos"]
				break
	_returns.erase(id)
	if lift > 0.0:
		pos += Vector3.UP * lift
	_move_player(pos)
	inside = ""
	_last_district = ""


func _move_player(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.flying = false
	cam.global_position = pos + Vector3.UP * 1.6
	for a in get_tree().get_nodes_in_group("actors"):
		if a != player and a.is_ally_of_player():
			a.global_position = pos + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3))
			a.velocity = Vector3.ZERO


## [U]: Gideon flies the Waverider to you and puts you at the helm (or, if
## you're already flying it, drops you out underneath). Inside the ship it
## just takes you to the helm.
func call_waverider() -> void:
	if ship.piloted:
		ship.bail_out()
		return
	if player.dead or vehicle or player.changing or carrying:
		return
	if inside == "waverider":
		ship.take_helm()
		return
	if inside != "":
		notify("Gideon can't bring the ship indoors. Step outside first.", Color("#ffd27a"))
		return
	# It jumps in through time, right overhead, facing where you're looking.
	var above := player.global_position + Vector3(0, 28.0, 0)
	above.y = maxf(above.y, 30.0)
	ship.yaw = cam.yaw
	ship.global_position = above
	ship.rotation = Vector3(0, ship.yaw, 0)
	FX.breach(self, above, Color("#a58aff"), 1.4, 9.0)
	FX.flash(self, above, Color("#d8c8ff"), 14.0, 0.5, 0.7)
	Sfx.play("teleport", above, 2.0)
	ship.take_helm()
	notify("Gideon brings the Waverider to you.  [U] bail out  ·  [G] walk to the bridge", Color("#bfe8ff"))
	Game.record("waverider_calls")


## The Legends' Jump Ship ------------------------------------------------------

static func is_legend(id: String) -> bool:
	return Teams.TEAMS.get("Legends", {}).get("members", []).has(id)


## [J] for a Legend: the Jump Ship flies down from the Waverider and lands
## in front of you. Board it (G) to fly up to the ship.
func call_jump_ship() -> void:
	if not is_legend(str(player.def.get("id", ""))):
		notify("Only the Legends have a Jump Ship. (Anyone can call the Waverider with U.)", Color("#a0a0a0"))
		return
	if inside != "" or ship.piloted or vehicle or player.dead:
		notify("Step outside to call the Jump Ship.", Color("#ffd27a"))
		return
	if is_instance_valid(jump_ship):
		jump_ship.queue_free()
	var fwd := player.forward()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var spot := player.global_position + fwd * 9.0
	var ground := spot.y - 0.5
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 30.0, spot + Vector3.DOWN * 60.0, Game.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		ground = float(hit["position"].y)
	jump_ship = JumpShip.new().setup(self)
	add_child(jump_ship)
	jump_ship.arrive(Vector3(spot.x, ground + 1.65, spot.z))
	notify("Gideon sends the Jump Ship down for you. [G] to board it.", Color("#ffb04a"))
	Game.record("jump_ship_calls")


func _jump_ship_up() -> void:
	if not is_instance_valid(jump_ship):
		return
	_returns["waverider"] = player.global_position
	var dock := ship.global_position - ship.forward() * 26.0 + Vector3.UP * 2.0
	jump_ship.carry_player_to(dock, func() -> void:
		jump_ship.release_player(Interiors.to_world("waverider", Vector3(-6.5, 0.6, 25.0)))
		inside = "waverider"
		notify("The Jump Ship docks in the Waverider's cargo bay.", Color("#ffb04a"))
		jump_ship.queue_free()
		jump_ship = null)
	notify("Flying to the Waverider...", Color("#ffb04a"))


## From the cargo bay: the Jump Ship takes you back down to where you were.
func _jump_ship_down() -> void:
	var dest: Vector3 = _returns.get("waverider", ship.boarding_point())
	if is_instance_valid(jump_ship):
		jump_ship.queue_free()
	jump_ship = JumpShip.new().setup(self)
	add_child(jump_ship)
	var start := ship.global_position - ship.forward() * 26.0 + Vector3.UP * 2.0
	jump_ship.global_position = start
	_move_player(start)
	inside = ""
	var land := Vector3(dest.x + 4.0, dest.y + 1.1, dest.z)
	jump_ship.carry_player_to(land, func() -> void:
		jump_ship.release_player(Vector3(dest.x, dest.y + 0.3, dest.z))
		notify("The Jump Ship sets you down. [J] calls it again.", Color("#ffb04a"))
		jump_ship.leave())
	notify("The Jump Ship drops out of the cargo bay...", Color("#ffb04a"))


## Tears a breach open a few steps ahead of the player; walking into it
## travels to `id`. Opening another replaces it.
func open_breach(id: String) -> void:
	if not Multiverse.DESTS.has(id) or player == null or not is_instance_valid(player):
		return
	if is_instance_valid(breach_portal):
		breach_portal.close()
	# Open it where the player is looking.
	var fwd := player.forward()
	var view := get_viewport().get_camera_3d()
	if view:
		fwd = -view.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var base := player.global_position + fwd * 4.0
	var portal := BreachPortal.new().setup(self, id, BREACH_COLOR, str(Multiverse.dest(id)["name"]))
	add_child(portal)
	portal.global_position = Vector3(base.x, player.global_position.y + 2.0, base.z)
	portal.look_at(Vector3(player.global_position.x, portal.global_position.y, player.global_position.z), Vector3.UP)
	portal.entered.connect(func() -> void: _step_through_breach(id))
	breach_portal = portal
	Sfx.play("teleport", portal.global_position, 0.0, 0.0)
	FX.flash(self, portal.global_position, BREACH_COLOR, 2.5, 0.4, 0.5)
	if player.model:
		player.model.play("palm_push", 0.6)
	notify("A breach tears open to %s. Step through it." % Multiverse.dest(id)["name"], BREACH_COLOR)


const BREACH_COLOR := Color("#4fa8ff")


func _step_through_breach(id: String) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	FX.flash(self, player.chest(), BREACH_COLOR, 2.2, 0.35, 0.45)
	travel_to(id, "breach")


## Before the fx root is cleared on travel: finish ultimates and costume
## changes in progress (they live there) and make actors drop their effect
## nodes, so nobody is left holding a freed beam or a half-done ultimate.
func _detach_fx() -> void:
	for f in fx_root.get_children():
		if f is Ultimate:
			f._end()
		elif f is Suitup:
			var su: Suitup = f
			if is_instance_valid(su.actor):
				if not su._swapped:
					su.actor.set_civilian(su.to_civilian)
				su.actor.changing = false
				if is_instance_valid(su.actor.model):
					su.actor.model.rotation = Vector3.ZERO
					su.actor.model.scale = Vector3.ONE * su.actor._cur_scale()
	for a in get_tree().get_nodes_in_group("actors"):
		a.drop_fx_refs()
	_power_weather_t = 0.0
	_weather_before = ""
	if survival.active:
		survival.stop(" (you left this Earth)")


## Rebuilds the world as another Earth, era or the Speed Force. `how` is the
## way you got there (breach, speed, time) and picks the effect.
func travel_to(id: String, how := "breach") -> void:
	if not Multiverse.DESTS.has(id) or player == null:
		return
	var d := Multiverse.dest(id)
	exit_vehicle()
	race.stop()
	var was_inside := inside
	# Where we stand in the room, in the room's own frame (rooms can be turned).
	var rel := Vector3.ZERO
	if was_inside != "":
		rel = (player.global_position - Interiors.origin(was_inside)).rotated(Vector3.UP, -float(Interiors.placed[was_inside]["yaw"]))
	events.reset()
	for a in get_tree().get_nodes_in_group("actors"):
		if a != player and not a.is_ally_of_player():
			a.queue_free()
	for p in props_root.get_children():
		p.queue_free()
	_detach_fx()
	for f in fx_root.get_children():
		f.queue_free()
	remove_child(city)
	city.queue_free()
	city = City.new()
	city.name = "City"
	add_child(city)
	move_child(city, 0)
	city.generate(1987, d["spec"])
	day_night.city = city
	_spawn_parked()
	place_id = id
	_returns.clear()
	if ship.piloted:
		ship.global_position.y = maxf(ship.global_position.y, 80.0)
	else:
		ship.park(city.waverider_dock)
	var pos: Vector3
	if was_inside != "":
		pos = Interiors.origin(was_inside) + rel.rotated(Vector3.UP, float(Interiors.placed[was_inside]["yaw"]))
	elif ship.piloted:
		pos = ship.global_position
	elif city.kind == "metro":
		pos = spawn_point_for(player.def)
	else:
		pos = Vector3(0, 0.5, 30)
	if how == "space":
		pos = Vector3(0, 140, 520)
		if ship.piloted:
			ship.global_position = pos + Vector3(0, 20, 30)
	elif how == "reentry":
		var back := _space_return
		pos = city.snap_to_road(Vector3(back.x, 0, back.z)) + Vector3.UP * 0.5
		if player.movement == "flight" or ship.piloted:
			pos = Vector3(back.x, 420.0, back.z)
		if ship.piloted:
			ship.global_position = pos + Vector3(0, 10, 20)
	if not ship.piloted:
		_move_player(pos)
		if (how == "space" or (how == "reentry" and pos.y > 100.0)) and player.movement == "flight":
			player.flying = true
	inside = was_inside
	_last_district = ""
	missions._spawned_for = -1
	Game.record("travels")
	missions._clear_marker()
	char_missions._cleanup()
	pickups.clear()
	street_crime.stop()
	side_jobs.reset()
	if is_instance_valid(jump_ship):
		if jump_ship.carrying:
			jump_ship.release_player(player.global_position)
		jump_ship.queue_free()
	jump_ship = null
	inmates.clear()
	missions.on_arrive(id)
	collectibles.build()
	waypoint = Vector3.INF
	day_night.set_weather(str(d["spec"].get("weather", "clear")))
	var color := Color("#ffd23a") if how == "speed" else (Color("#a58aff") if how == "time" else BREACH_COLOR)
	if how == "breach" and not ship.piloted:
		# Step out of a breach that seals behind you.
		var fwd := player.forward()
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
		var exit := BreachPortal.new().setup(self, id, BREACH_COLOR, "", true)
		add_child(exit)
		exit.global_position = player.global_position - fwd * 1.0 + Vector3.UP * 2.0
		exit.look_at(exit.global_position + fwd, Vector3.UP)
		player.velocity = fwd * 6.0 + Vector3.UP * 1.5
	else:
		FX.breach(self, player.chest() + Vector3.UP * 0.5, color, 1.2, 2.2)
	FX.flash(self, player.chest(), color, 3.0, 0.5, 0.6)
	Sfx.play("teleport", null, 0.0)
	if how == "space":
		color = Color("#bfe8ff")
	elif how == "reentry":
		color = Color("#ff8a3a")
		FX.flash(self, player.chest(), Color("#ff6a1a"), 6.0, 0.8, 0.7)
	var verb := {"speed": "You ran to", "time": "The Waverider arrives in", "breach": "You breached to",
		"space": "You leave Earth's atmosphere. Ahead:", "reentry": "Re-entering the atmosphere over"}
	notify("%s %s" % [verb.get(how, "Welcome to"), d["name"]], color)
	if city.kind == "speedforce":
		notify("Time Wraiths hunt speedsters here. Find the way home (or press G at the light).", Color("#ffd27a"))
		population.spawn_wraiths(3)
	elif city.kind == "antimatter":
		notify("Shadow Demons swarm the Anti-Matter Universe. The way home is the column of light.", Color("#ff9a9a"))
		population.spawn_wraiths(3)
	elif city.kind == "argo":
		notify("Argo City, the last city of Krypton. Dive off the edge to fall back to Earth.", Color("#bfe8ff"))
		population.spawn_kryptonians(12)
		Game.record("argo_visits")


func notify(text: String, color := Color.WHITE) -> void:
	if hud:
		hud.notify(text, color)


func shake_at(pos: Vector3, amount: float) -> void:
	if cam == null:
		return
	var d := cam.global_position.distance_to(pos)
	if d < 70.0:
		cam.shake(amount * (1.0 - d / 70.0))


func on_actor_ko(a: Actor, source: Actor) -> void:
	if a == player:
		return
	if source == null or not is_instance_valid(source) or not source.is_player:
		return
	kos += 1
	Game.record("kos")
	pickups.drop_from(a)
	_gain_mastery(a)
	if a.boss:
		Game.record("bosses")
		news.on_boss(a.display_name)
		final_blow(a)
	if a.def.get("id", "") not in ["civilian", "police", "thug"]:
		Game.record("supers_defeated")
	var ps := Game.player_side()
	match a.team:
		"civilian":
			Game.add_heat(1.0)
			if ps == 1:
				Game.add_score(-25)
				notify("Civilian knocked out! Heroes don't do that.", Color("#ff6060"))
			else:
				Game.add_score(5)
		"police":
			if ps == 1:
				Game.add_heat(1.0)
				Game.add_score(-15)
			else:
				Game.add_heat(0.5)
				Game.add_score(15)
		_:
			if a.side() != ps:
				var pts := int((10 if a.def.get("id", "") in ["thug", "police"] else 50) * style.multiplier())
				Game.add_score(pts)
				if pts >= 50:
					notify("You defeated %s!  +%d" % [a.display_name, pts], Color("#ffd23a"))
			else:
				Game.add_heat(0.6)


## Mastery XP for the character you're playing.
func _gain_mastery(a: Actor) -> void:
	if a.team == "civilian" or a.side() == Game.player_side():
		return
	var id := str(player.def.get("id", ""))
	var xp := 80.0 if a.boss else (30.0 if a.def.get("id", "") not in ["thug", "police"] else 10.0)
	if team_bonus != "":
		xp *= 1.25
	var lvl := Game.add_mastery(id, xp)
	if lvl > 0:
		var ratio := player.hp / maxf(player.max_hp, 1.0)
		_apply_rank(player)
		player.hp = player.max_hp * ratio
		hud.show_banner("%s  MASTERY %d" % [str(player.def["alias"]).to_upper(), lvl], Color("#ffd23a"))
		notify("Mastery level %d: +%d%% health and power" % [lvl, int(round((Game.mastery_bonus(id) - 1.0) * 100.0))], Color("#ffd23a"))


## Flying high enough leaves the atmosphere for Argo City; falling off Argo
## City (or flying far away from it) brings you back down to Earth.
const SPACE_ALTITUDE := 700.0
var _space_return := Vector3(560, 0, -440)
var _space_from := "earth1"
var _space_hint := false


func _space_check() -> void:
	var p: Vector3 = ship.global_position if ship.piloted else player.global_position
	if city.kind == "metro" and inside == "":
		if p.y > 450.0 and not _space_hint and (player.flying or ship.piloted):
			_space_hint = true
			notify("The sky is turning black... keep climbing to reach space.", Color("#bfe8ff"))
		if p.y > SPACE_ALTITUDE and (player.flying or ship.piloted):
			_space_return = p
			_space_from = place_id
			_space_hint = false
			travel_to("argo", "space")
	elif city.kind == "argo" and inside == "":
		# (Rooms like the Waverider's bridge sit far away from the city.)
		if p.y < -140.0 or Vector2(p.x, p.z).length() > 1700.0:
			travel_to(_space_from if Multiverse.DESTS.has(_space_from) else "earth1", "reentry")


## Team-up: fighting next to a recruited teammate hits harder.
var team_bonus := ""
var _team_t := 0.0


func _update_team_bonus() -> void:
	var was := team_bonus
	team_bonus = ""
	if player == null or not is_instance_valid(player) or player.civilian:
		return
	var pid := str(player.def.get("id", ""))
	for a in get_tree().get_nodes_in_group("actors"):
		if a.follow_target == player and not a.dead and a.global_position.distance_to(player.global_position) < 30.0:
			var t := Teams.share_team(pid, str(a.def.get("id", "")))
			if t != "":
				team_bonus = t
				break
	if team_bonus != "" and team_bonus != was:
		notify("TEAM-UP: %s! Your attacks hit harder." % team_bonus, Teams.color(team_bonus))


func _on_player_died(_a: Actor, source: Actor) -> void:
	Game.end_slowmo()
	_respawn_t = 3.5
	var by := ""
	if source and is_instance_valid(source):
		by = " by " + source.display_name
	hud.show_ko(true, "KNOCKED OUT" + by)


# --- Sandbox helpers --------------------------------------------------------

func spawn_npc_character(id: String, as_ally: bool) -> Actor:
	var c := Game.get_character(id)
	var forward := -cam.global_basis.z
	forward.y = 0
	var pos := player.global_position + forward.normalized() * 10.0
	pos.y = maxf(player.global_position.y, 0.2)
	var team: String = player.team if as_ally else ("villain" if Game.player_side() == 1 else "hero")
	var a := population.spawn_character(c, team, pos, player if as_ally else null)
	a.set_meta("pinned", true)
	a.brain.leash = 0.0
	a.brain.detect = 70.0
	if not as_ally:
		a.grudges[player.get_instance_id()] = 30.0
		if c["side"] == "hero" and Game.player_side() == 1:
			a.display_name = "Evil " + c["alias"]
		elif c["side"] == "villain" and Game.player_side() == -1:
			a.display_name = "Rival " + c["alias"]
	FX.portal(self, a.chest(), Color("#4fa8ff"))
	notify("%s %s" % [a.display_name, "joins you" if as_ally else "appears!"], Color("#a0d0ff") if as_ally else Color("#ff9080"))
	return a


func spawn_prop_here(kind: String) -> void:
	var forward := -cam.global_basis.z
	forward.y = 0
	var prop := Prop.new()
	prop.build(self, kind)
	props_root.add_child(prop)
	prop.global_position = player.global_position + forward.normalized() * 7.0 + Vector3.UP * 3.0
	prop.rotation.y = cam.yaw


func clear_npcs() -> void:
	for a in get_tree().get_nodes_in_group("actors"):
		if a != player:
			a.queue_free()


func teleport_player(pos: Vector3) -> void:
	inside = Interiors.room_at(pos)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.flying = false
	cam.global_position = pos + Vector3.UP * 1.6
	FX.portal(self, player.chest(), Color("#4fa8ff"))
