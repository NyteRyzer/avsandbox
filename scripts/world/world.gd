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
var actors_root: Node3D
var props_root: Node3D
var fx_root: Node3D
var cam: CameraRig
var hud: Hud
var pause_menu: PauseMenu
var sandbox_menu: SandboxMenu
var player: Actor
var player_brain: PlayerBrain
var gravity_scale := 1.0
var kos := 0
var _respawn_t := -1.0
var _last_district := ""
var _tips_shown := false


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
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for spot in city.parked:
		var prop := Prop.new()
		prop.build(self, spot["kind"], r)
		props_root.add_child(prop)
		prop.global_transform = spot["xform"]
		prop.sleeping = true
	population = Population.new()
	population.world = self
	add_child(population)
	events = Events.new()
	events.world = self
	add_child(events)
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
	Game.notify.connect(notify)


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


func spawn_point_for(c: Dictionary) -> Vector3:
	var idx := {"star": 0, "central": 1, "national": 2, "freeland": 3}
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
		var d := city.district_at(player.global_position)
		if d != _last_district:
			_last_district = d
			hud.show_district(d)


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
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.flying = false
	cam.global_position = pos + Vector3.UP * 1.6
	FX.portal(self, player.chest(), Color("#4fa8ff"))
