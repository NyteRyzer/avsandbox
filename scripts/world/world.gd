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
var actors_root: Node3D
var props_root: Node3D
var fx_root: Node3D
var cam: CameraRig
var hud: Hud
var pause_menu: PauseMenu
var sandbox_menu: SandboxMenu
var travel_menu: TravelMenu
var ship: Waverider
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
	Game.end_slowmo()


## Spawns (or replaces) the player as the given roster character.
func spawn_player(id: String, at = null) -> void:
	var c := Game.get_character(id)
	var pos: Vector3
	var yaw := cam.yaw
	if at != null:
		pos = at
	elif player and is_instance_valid(player):
		pos = player.global_position
	else:
		pos = spawn_point_for(c)
	var old_heat := Game.heat
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
	Game.player = player
	Game.selected_id = id
	Game.save_settings()
	cam.target = player
	cam.yaw = yaw
	cam.global_position = player.global_position + Vector3.UP * 1.6
	Game.heat = old_heat if at == null else 0.0
	hud.on_player_changed()
	notify("You are %s" % c["alias"], Color("#ffffff"))
	if not _tips_shown:
		_tips_shown = true
		notify("Tab: sandbox tools (spawn anyone, time, weather, teleport)", Color("#ffe080"))
		notify("Yellow marker on the minimap = an event to stop (or start)", Color("#ffe080"))
		notify("Esc: pause, change character, settings", Color("#ffe080"))
		notify("G: doors, consoles and travel  ·  R: your ultimate, once it's charged", Color("#ffe080"))
		if not missions.is_complete():
			missions._set_chapter(missions.chapter)


func spawn_point_for(c: Dictionary) -> Vector3:
	var idx := {"star": 0, "central": 1, "national": 2, "freeland": 3, "gotham": 4, "smallville": 5}
	var home: String = c.get("home", "any")
	var center := Vector3(20, 0, 20)
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
	elif event.is_action_pressed("toggle_hud"):
		hud.visible = not hud.visible
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		capture_mouse(true)


func _process(delta: float) -> void:
	if _respawn_t >= 0.0:
		_respawn_t -= delta / maxf(Engine.time_scale, 0.01)
		if _respawn_t < 0.0 and player and is_instance_valid(player):
			player.revive()
			player.global_position = city.nearest_road_point(player.global_position)
			Game.clear_heat()
			hud.show_ko(false)
	if player and is_instance_valid(player):
		inside = Interiors.room_at(player.global_position)
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
	if inside == "" and best.is_empty():
		var bp := ship.boarding_point()
		if Vector2(bp.x - p.x, bp.z - p.z).length() < 6.0 and absf(bp.y - p.y) < 4.0:
			best = {"name": "The Waverider", "pos": bp, "interior": "waverider"}
	return best


## What [G] would do right now, for the HUD prompt ("" if nothing).
func interact_prompt() -> String:
	if ship.piloted:
		return ""
	if not door.is_empty():
		var what: String = door["interior"]
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
	if not door.is_empty():
		use_door(door)
	elif inside == "" and _can_run_between_worlds():
		travel_menu.open("speed")
	elif inside == "" and _can_breach():
		travel_menu.open("breach")


func use_door(d: Dictionary) -> void:
	var what: String = d["interior"]
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
		"helm":
			ship.take_helm()
		"balcony":
			leave_interior("catco", 60.0)
		"exit_speedforce":
			travel_to("earth1", "speed")
		_:
			if what in Interiors.ORDER:
				enter_interior(what)


func enter_interior(id: String, remember := true) -> void:
	if remember and inside == "":
		_returns[id] = player.global_position
	var spot := city.landmark("Inside " + Interiors.NAMES[id])
	var pos: Vector3 = spot["pos"] if not spot.is_empty() else Interiors.origin(id) + Vector3.UP
	_move_player(pos)
	inside = id
	FX.flash(self, player.chest(), Color("#ffffff"), 1.2, 0.3, 0.4)
	notify("Entered " + Interiors.NAMES[id], Color("#bfe8ff"))


## Steps back outside. `lift` raises the exit point (the CatCo balcony).
func leave_interior(id: String, lift := 0.0) -> void:
	var pos := Vector3.ZERO
	if id == "waverider":
		pos = ship.boarding_point()
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


## Rebuilds the world as another Earth, era or the Speed Force. `how` is the
## way you got there (breach, speed, time) and picks the effect.
func travel_to(id: String, how := "breach") -> void:
	if not Multiverse.DESTS.has(id) or player == null:
		return
	var d := Multiverse.dest(id)
	var was_inside := inside
	var rel := player.global_position - Interiors.origin(was_inside) if was_inside != "" else Vector3.ZERO
	events.reset()
	for a in get_tree().get_nodes_in_group("actors"):
		if a != player and not a.is_ally_of_player():
			a.queue_free()
	for p in props_root.get_children():
		p.queue_free()
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
		pos = Interiors.origin(was_inside) + rel
	elif ship.piloted:
		pos = ship.global_position
	elif city.kind == "metro":
		pos = spawn_point_for(player.def)
	else:
		pos = Vector3(0, 0.5, 30)
	if not ship.piloted:
		_move_player(pos)
	inside = was_inside
	_last_district = ""
	missions._spawned_for = -1
	missions._clear_marker()
	missions.on_arrive(id)
	var color := Color("#ffd23a") if how == "speed" else (Color("#a58aff") if how == "time" else Color("#4fa8ff"))
	FX.breach(self, player.chest() + Vector3.UP * 0.5, color, 1.2, 2.2)
	FX.flash(self, player.chest(), color, 3.0, 0.5, 0.6)
	Sfx.play("teleport", null, 0.0)
	var verb := {"speed": "You ran to", "time": "The Waverider arrives in", "breach": "You breached to"}
	notify("%s %s" % [verb.get(how, "Welcome to"), d["name"]], color)
	if city.kind == "speedforce":
		notify("Time Wraiths hunt speedsters here. Find the way home (or press G at the light).", Color("#ffd27a"))
		population.spawn_wraiths(3)
	elif city.kind == "antimatter":
		notify("Shadow Demons swarm the Anti-Matter Universe. The way home is the column of light.", Color("#ff9a9a"))
		population.spawn_wraiths(3)


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
				var pts := 10 if a.def.get("id", "") in ["thug", "police"] else 50
				Game.add_score(pts)
				if pts >= 50:
					notify("You defeated %s!  +%d" % [a.display_name, pts], Color("#ffd23a"))
			else:
				Game.add_heat(0.6)


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
