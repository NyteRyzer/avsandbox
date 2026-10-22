extends Node
## Renders screenshots of the game for the README and for visual checks.
## Needs a real display (or xvfb):
##   godot --path . res://tools/shots.tscn -- <output dir>

var out_dir := "res://docs/screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	var only := args[1] if args.size() > 1 else ""
	if only == "close":
		await _closeups(args[2].split(","), args[3] if args.size() > 3 else "")
		get_tree().quit()
		return
	if only == "select":
		# One select-screen shot per listed character.
		for id in (args[2].split(",") if args.size() > 2 else ["flash"]):
			var cs := CharacterSelect.new()
			add_child(cs)
			cs._select(id)
			await _snap("select_" + id, 30)
			cs.queue_free()
		get_tree().quit()
		return
	if only == "features":
		var w := World.new()
		add_child(w)
		w.population.enabled = false
		w.char_missions.enabled = false
		w.side_jobs.enabled = false
		w.day_night.frozen = true
		w.day_night.hour = 18.5
		w.events.cooldown = 99999.0
		w.spawn_player("superman", Vector3(560, 0.5, -440))
		for i in 20:
			await get_tree().physics_frame
		w.cam.pitch = -0.12
		w.cam.zoom = 9.0
		w.events.start_random("incursion")
		var inc: Incident = w.events.active["custom"]
		w.player.global_position = inc.center + Vector3(0, 0.5, 12)
		inc._spawn_t = 0.0
		for i in 10:
			await get_tree().physics_frame
		w.cam.yaw = atan2(w.player.global_position.x - inc.center.x, w.player.global_position.z - inc.center.z)
		for i in 50:
			await get_tree().physics_frame
		await _snap("feature_incursion", 2)
		w.events.reset()
		w.clear_npcs()
		w.events.start_random("meteors")
		var met: Incident = w.events.active["custom"]
		w.player.global_position = met.center + Vector3(0, 0.5, 20)
		w.cam.pitch = 0.25
		for i in 200:
			await get_tree().physics_frame
		await _snap("feature_meteors", 2)
		w.events.reset()
		w.cam.pitch = -0.1
		w.cam.zoom = 5.0
		w.side_jobs.toggle_krypto()
		w.side_jobs.krypto.global_position = w.player.global_position + Vector3(1.5, 0.3, 1)
		var crate := w.side_jobs.start_drop()
		crate.global_position = w.player.global_position + Vector3(-3, 6, -6)
		for i in 40:
			await get_tree().physics_frame
		await _snap("feature_krypto_drop", 2)
		get_tree().quit()
		return
	if only == "ship":
		# The Waverider outside (free camera), at the helm, and its rooms.
		var w := World.new()
		add_child(w)
		w.population.enabled = false
		w.events.cooldown = 9999.0
		w.char_missions.enabled = false
		w.day_night.frozen = true
		w.day_night.hour = 16.0
		w.spawn_player("white_canary", Vector3(560, 0.5, -440))
		for i in 10:
			await get_tree().physics_frame
		var c := Camera3D.new()
		w.add_child(c)
		var sp: Vector3 = w.ship.global_position
		for view in [["ship_quarter", Vector3(48, 18, -40)], ["ship_side", Vector3(70, 6, 4)], ["ship_rear", Vector3(-30, 14, 70)]]:
			c.global_position = sp + view[1]
			c.look_at(sp + Vector3(0, 1, 0), Vector3.UP)
			c.current = true
			for i in 6:
				await get_tree().physics_frame
			await _snap(str(view[0]), 3)
		w.cam.camera.current = true
		w.enter_interior("waverider")
		for spot in [["ship_bridge", Vector3(0, 0.5, -6), 0.0], ["ship_bridge_back", Vector3(0, 0.5, -30), PI],
				["ship_corridor", Vector3(0, 0.5, 8), 0.0], ["ship_library", Vector3(-9, 0.5, -3), PI * 0.5],
				["ship_medbay", Vector3(-9, 0.5, 6), PI * 0.5], ["ship_fab", Vector3(9, 0.5, -3), -PI * 0.5],
				["ship_cargo", Vector3(0, 0.5, 33), 0.0]]:
			w.player.global_position = Interiors.to_world("waverider", spot[1])
			w.cam.yaw = spot[2]
			w.cam.pitch = -0.1
			w.cam.zoom = 4.0
			for i in 12:
				await get_tree().physics_frame
			await _snap(str(spot[0]), 3)
		w.call_waverider()
		w.cam.yaw = -0.4
		w.cam.pitch = -0.2
		for i in 90:
			await get_tree().physics_frame
		await _snap("ship_helm_flight", 3)
		get_tree().quit()
		return
	if only == "breach":
		var w := World.new()
		add_child(w)
		w.population.enabled = false
		w.events.cooldown = 9999.0
		w.char_missions.enabled = false
		w.day_night.frozen = true
		w.day_night.hour = 19.5
		w.spawn_player("vibe", Vector3(560, 0.5, -440))
		for i in 20:
			await get_tree().physics_frame
		w.cam.yaw = w.player.model.global_rotation.y + PI + 0.4
		w.cam.pitch = -0.08
		w.cam.zoom = 7.0
		for i in 10:
			await get_tree().physics_frame
		w.open_breach("earth2")
		for i in 12:
			await get_tree().physics_frame
		await _snap("breach_opening", 2)
		for i in 50:
			await get_tree().physics_frame
		await _snap("breach_open", 2)
		w.player.global_position = w.breach_portal.global_position - Vector3.UP * 2.0
		for i in 8:
			await get_tree().physics_frame
		await _snap("breach_arrive", 2)
		get_tree().quit()
		return
	if only == "doors":
		await _doors()
		get_tree().quit()
		return
	if only == "new":
		await _new_places()
		get_tree().quit()
		return
	if only == "wheel":
		await _wheel_shots()
		get_tree().quit()
		return
	if only == "street":
		await _street_shots()
		get_tree().quit()
		return
	if only == "entrances":
		await _entrance_shots()
		get_tree().quit()
		return
	if only == "space":
		await _space_shots()
		get_tree().quit()
		return
	if only == "places":
		await _places()
		get_tree().quit()
		return
	if only == "" or only == "roster":
		await _roster()
	if only == "roster":
		get_tree().quit()
		return
	await _title()
	await _select()
	await _world()
	get_tree().quit()


func _snap(name: String, frames := 20) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.86)
	print("saved %s  draw calls %d  objects %d  fps %d" % [name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		Engine.get_frames_per_second()])


func _roster() -> void:
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.5, 0)
	root.add_child(light)
	var per_row := 10
	for side in ["hero", "villain"]:
		var list: Array = Game.heroes() if side == "hero" else Game.villains()
		for i in list.size():
			var c: Dictionary = list[i]
			var m := CharacterModel.new()
			root.add_child(m)
			m.build(c["look"])
			var s := float(c["look"].get("scale", 1.0))
			m.scale = Vector3.ONE * minf(1.0, 1.3 / s) * s / s
			var row := i / per_row
			var col := i % per_row
			var y := -row * 3.0 - (0.0 if side == "hero" else 12.5)
			m.position = Vector3(col * 1.6, y, 0)
			m.rotation.y = PI + 0.35
			var l := Label3D.new()
			l.text = c["alias"]
			l.font_size = 40
			l.pixel_size = 0.006
			l.outline_size = 8
			l.modulate = UITheme.side_color(side).lightened(0.4)
			l.position = m.position + Vector3(0, -0.25, 0.5)
			root.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 24.0
	cam.position = Vector3(7.2, -10.0, 20)
	cam.current = true
	root.add_child(cam)
	get_window().size = Vector2i(1600, 1700)
	await _snap("roster", 10)
	get_window().size = Vector2i(1600, 900)
	root.queue_free()
	await get_tree().process_frame


## Renders characters large, four to an image, for checking model detail.
## An optional pose plays on every model (e.g. "punch", "bow", "two_hands").
func _closeups(ids: Array, pose: String) -> void:
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.5, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	root.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(2.4, 1.15, 4.6)
	cam.fov = 38
	cam.current = true
	root.add_child(cam)
	var spacing := 0.5
	if pose == "face":
		cam.position = Vector3(2.4, 1.62, 1.9)
		cam.fov = 26
		pose = ""
	elif pose == "torso":
		# Chest-up, straight on: for judging shoulders and torsos.
		spacing = 0.8
		cam.position = Vector3(1.65 + 1.5 * spacing, 1.38, 3.2)
		cam.fov = 28
		pose = ""
	var batch := 0
	while batch * 4 < ids.size():
		var models: Array = []
		for i in 4:
			var idx := batch * 4 + i
			if idx >= ids.size():
				break
			var c := Game.get_character(ids[idx])
			if str(ids[idx]).begins_with("npc_"):
				var pop := Population.new()
				pop.rng.seed = idx * 7919 + batch
				match str(ids[idx]).trim_prefix("npc_").rstrip("0123456789"):
					"police":
						c = pop.police_def()
					"thug":
						c = pop.thug_def(idx % 4)
					_:
						c = pop.civilian_def()
				pop.free()
			var m := CharacterModel.new()
			root.add_child(m)
			m.build(c["look"])
			var s := float(c["look"].get("scale", 1.0))
			m.scale = Vector3.ONE * minf(1.0, 1.25 / s)
			m.position = Vector3(i * 1.6, 0, 0) if cam.fov > 30 else Vector3(1.65 + i * spacing, 0, 0)
			m.rotation.y = PI + 0.5 if not pose in ["run", "sprint", "fly", "cruise"] else PI * 0.5 + 0.35
			if spacing > 0.5:
				m.rotation.y = PI + 0.15
			if pose in ["fly", "cruise"]:
				m.position.y = 0.6
			models.append(m)
		var motion := {"run": [9.0, true, false], "sprint": [40.0, true, false], "fly": [2.0, false, true], "cruise": [30.0, false, true], "idle": [0.0, true, false]}
		for f in (34 if motion.has(pose) else 30):
			for m in models:
				if motion.has(pose):
					var mv: Array = motion[pose]
					m.animate(1.0 / 60.0, mv[0], mv[1], mv[2], 0.0, false)
					continue
				if pose != "" and f % 12 == 0:
					m.play(pose, 0.8, f / 12)
				m.animate(1.0 / 60.0, 0.0, true, false, 0.0, false)
			await get_tree().process_frame
		await _snap("close_%d" % batch, 2)
		for m in models:
			m.queue_free()
		batch += 1
	root.queue_free()


func _title() -> void:
	var t := TitleScreen.new()
	add_child(t)
	await _snap("title", 40)
	t.queue_free()


func _select() -> void:
	var cs := CharacterSelect.new()
	add_child(cs)
	cs._select("flash")
	await _snap("character_select", 30)
	cs.queue_free()


func _world() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = true
	w.events.cooldown = 9999.0
	w.day_night.frozen = true
	w.day_night.hour = 16.5
	w.spawn_player("flash", Vector3(720, 0.5, -840))
	w.cam.yaw = 0.6
	w.cam.pitch = -0.15
	for i in 120:
		await get_tree().physics_frame
	await _snap("central_city", 10)

	w.spawn_player("supergirl", Vector3(-420, 90, 760))
	w.player.flying = true
	w.cam.yaw = 2.4
	w.cam.pitch = -0.25
	await _snap("national_city_flight", 30)

	w.spawn_player("green_arrow", Vector3(-560, 0.5, -640))
	w.day_night.hour = 21.5
	w.cam.yaw = -0.4
	w.cam.pitch = 0.1
	for k in 4:
		w.population.spawn_thug(Vector3(-560 + k * 2.0, 0.5, -650))
	await _snap("star_city_night", 40)
	w.player.aim_point = w.player.global_position + Vector3(0, 1, -12)
	w.player.in_primary = true
	Abilities.fire(w.player, w.player.def["primary"])
	Abilities.fire(w.player, w.player.def["secondary"])
	await _snap("combat", 6)

	w.day_night.hour = 12.0
	w.spawn_player("grodd", Vector3(520, 0.5, -500))
	w.cam.yaw = 0.0
	w.cam.pitch = -0.1
	for c in ["reverse_flash", "zoom", "deathstroke", "killer_frost"]:
		w.spawn_npc_character(c, false)
	await _snap("unity_park", 30)
	Abilities.special(w.player, w.player.def["special"])
	await _snap("ground_slam", 4)
	w.sandbox_menu.open()
	await _snap("sandbox_menu", 10)
	w.sandbox_menu.close()

	# Action: a speedster at full tilt, heat vision.
	w.clear_npcs()
	w.day_night.hour = 17.8
	w.spawn_player("reverse_flash", Vector3(-160, 0.5, -560))
	w.cam.yaw = PI * 0.5 + 0.35
	w.cam.pitch = -0.12
	w.player.face_dir = Vector3.RIGHT
	for i in 50:
		w.player.velocity = Vector3(55, 0, 0)
		w.player.global_position += Vector3(55.0 / 60.0, 0, 0)
		w.player._speed_trail(1.0 / 60.0, 55.0)
		await get_tree().physics_frame
	await _snap("speedster", 1)
	w.spawn_player("superman", Vector3(560, 30, 560))
	w.player.flying = true
	w.cam.yaw = 0.3
	w.cam.pitch = -0.35
	var target := w.population.spawn_character(Game.get_character("reign"), "villain", Vector3(556, 18, 530))
	target.flying = true
	for i in 30:
		w.player.aim_point = target.chest()
		Abilities.held_tick(w.player, w.player.def["secondary"], 1.0 / 60.0, "secondary")
		await get_tree().process_frame
	await _snap("heat_vision", 1)


func _places() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = false
	w.events.cooldown = 9999.0
	w.day_night.frozen = true
	w.day_night.hour = 15.0
	w.spawn_player("flash", Vector3(560, 0.5, -440))
	for id in Interiors.ORDER:
		w.enter_interior(id)
		w.cam.yaw = 0.0
		w.cam.pitch = -0.12
		w.cam.zoom = 7.0
		for i in 20:
			await get_tree().physics_frame
		await _snap("inside_" + id, 5)
	w.leave_interior("waverider")
	w.cam.yaw = 0.5
	w.cam.pitch = -0.2
	w.cam.zoom = 14.0
	for i in 20:
		await get_tree().physics_frame
	await _snap("waverider_pad", 5)
	w.ship.take_helm()
	w.ship.global_position = Vector3(500, 120, -300)
	w.ship.yaw = -0.6
	w.cam.yaw = -0.4
	w.cam.pitch = -0.25
	for i in 30:
		await get_tree().physics_frame
	await _snap("waverider_flight", 5)
	w.ship.leave_helm()
	w.leave_interior("waverider")
	for id in ["earthx", "2046", "3030", "earth2", "old_west", "speedforce"]:
		w.travel_to(id, "breach")
		w.cam.yaw = 0.6
		w.cam.pitch = -0.1
		w.cam.zoom = 6.0
		if w.city.kind == "metro":
			w.teleport_player(w.city.district_center(1) + Vector3(0, 0.5, 0))
		for i in 60:
			await get_tree().physics_frame
		await _snap("place_" + id, 10)


func _new_places() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = true
	w.events.cooldown = 9999.0
	w.day_night.frozen = true
	w.day_night.hour = 15.0
	var spots := [["gotham", Vector3(-1480, 0.5, 3360), 0.3], ["gotham_air", Vector3(-1440, 160, 3120), 0.0],
		["smallville", Vector3(2480, 0.5, 1400), 0.8], ["kent_farm", Vector3(2440, 0.5, 1470), 0.0]]
	for sp in spots:
		w.spawn_player("batwoman" if str(sp[0]).begins_with("gotham") else "superman", sp[1])
		if sp[1].y > 5.0:
			w.player.flying = true
		w.cam.yaw = sp[2]
		w.cam.pitch = -0.12 if sp[1].y < 5.0 else -0.35
		for i in 60:
			await get_tree().physics_frame
		await _snap("new_" + str(sp[0]), 10)
	w.population.enabled = false
	for id in ["batcave", "kent_barn"]:
		w.enter_interior(id)
		w.cam.yaw = 0.0
		w.cam.pitch = -0.12
		w.cam.zoom = 7.0
		for i in 20:
			await get_tree().physics_frame
		await _snap("new_inside_" + id, 5)
	w.leave_interior("kent_barn")
	for id in ["antimatter", "argo", "vanishing_point", "earth90", "earth99"]:
		w.travel_to(id, "breach")
		w.cam.yaw = 0.6 if id != "antimatter" else 0.0
		w.cam.pitch = -0.05
		w.cam.zoom = 6.0
		if w.city.kind == "metro":
			w.teleport_player(w.city.district_center(1) + Vector3(0, 0.5, 0))
		for i in 60:
			await get_tree().physics_frame
		await _snap("new_" + id, 10)
	# An ultimate in action
	w.travel_to("earth1", "breach")
	w.population.enabled = false
	w.clear_npcs()
	w.spawn_player("black_lightning", Vector3(560, 0.5, -440))
	for i in 5:
		w.population.spawn_thug(Vector3(556 + i * 2.5, 0.5, -455))
	w.cam.yaw = 0.0
	w.cam.pitch = -0.05
	w.player.ult = 100.0
	w.player.in_ultimate = true
	w.player._abilities(0.016)
	for i in 50:
		await get_tree().physics_frame
	await _snap("new_ultimate", 1)


func _doors() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = false
	w.events.cooldown = 9999.0
	w.day_night.frozen = true
	w.day_night.hour = 17.0
	for room in ["star_labs", "jitters", "bunker", "catco", "batcave", "kent_barn"]:
		var o := Interiors.origin(room)
		var out := o + Vector3(0, 0.5, -(Interiors.SIZES[room].z * 0.5 + (16.0 if room == "star_labs" else 9.0)))
		w.spawn_player("flash", out)
		w.cam.yaw = PI
		w.cam.pitch = -0.05
		w.cam.zoom = 7.0
		for i in 40:
			await get_tree().physics_frame
		await _snap("door_" + room, 5)
	# Inside, looking back out through the doorway
	w.spawn_player("flash", Interiors.origin("jitters") + Vector3(0, 0.5, 2))
	w.cam.yaw = 0.0
	w.cam.zoom = 5.0
	for i in 30:
		await get_tree().physics_frame
	await _snap("door_inside_jitters", 5)
	# Transformations, mid-change
	var who := ["flash", "superman", "killer_frost", "vibe", "black_lightning", "stargirl"]
	for k in who.size():
		w.spawn_player(who[k], Vector3(560, 0.5, -440))
		w.cam.yaw = 0.4
		w.cam.pitch = -0.1
		w.cam.zoom = 5.0
		for i in 20:
			await get_tree().physics_frame
		Suitup.toggle(w.player)
		for i in 75:
			await get_tree().physics_frame
		Suitup.toggle(w.player)
		for i in 28:
			await get_tree().physics_frame
		await _snap("suit_" + who[k], 1)


func _space_shots() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = false
	w.events.cooldown = 9999.0
	w.char_missions.enabled = false
	w.day_night.frozen = true
	w.day_night.hour = 14.0
	w.spawn_player("supergirl", Vector3(560, 0.5, -440))
	# Argo City from above the dome, and from the plaza.
	w.travel_to("argo", "space")
	for shot in [["argo_approach", Vector3(0, 140, 520), 0.0, -0.25, 30.0], ["argo_plaza", Vector3(0, 0.5, 60), 0.0, 0.05, 9.0],
			["argo_earth", Vector3(0, 40, 330), PI, -0.5, 14.0]]:
		w.player.global_position = shot[1]
		w.player.flying = shot[1].y > 5.0
		w.cam.yaw = shot[2]
		w.cam.pitch = shot[3]
		w.cam.zoom = shot[4]
		for i in 30:
			await get_tree().physics_frame
		await _snap(str(shot[0]), 6)
	# The Speed Force
	w.spawn_player("flash", Vector3(0, 0.5, 30))
	w.travel_to("speedforce", "speed")
	for shot in [["speedforce_road", Vector3(0, 0.5, -20), 0.0, -0.05, 9.0], ["speedforce_heart", Vector3(0, 0.5, 6), 0.0, -0.05, 7.0],
			["speedforce_memories", Vector3(0, 30, 40), 2.2, -0.15, 12.0]]:
		w.player.global_position = shot[1]
		w.player.flying = false
		w.cam.yaw = shot[2]
		w.cam.pitch = shot[3]
		w.cam.zoom = shot[4]
		for i in 30:
			await get_tree().physics_frame
		await _snap(str(shot[0]), 6)
	# Batwoman gliding over Gotham
	w.travel_to("earth1", "breach")
	w.spawn_player("batwoman", Vector3(-1440, 90, 3300))
	w.player.brain = null
	for i in 40:
		w.player.in_up = true
		w.player.in_move = Vector3(0, 0, -1)
		await get_tree().physics_frame
	w.cam.yaw = 2.5
	w.cam.pitch = -0.1
	w.cam.zoom = 6.0
	await _snap("batwoman_glide", 3)
	# A cast pose
	w.spawn_player("superman", Vector3(560, 0.5, -440))
	w.cam.yaw = 0.6
	w.cam.zoom = 7.0
	for i in 20:
		await get_tree().physics_frame
	Abilities.special(w.player, {"kind": "ground_slam"})
	for i in 14:
		await get_tree().physics_frame
	await _snap("ground_pound", 2)


func _entrance_shots() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = false
	w.events.cooldown = 9999.0
	w.char_missions.enabled = false
	w.street_crime.enabled = false
	w.day_night.frozen = true
	w.day_night.hour = 15.0
	w.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	for room in ["queen_consolidated", "ccpd", "iron_heights", "arkham"]:
		var out := Interiors.outside_point(room)
		var d: Dictionary = Interiors.placed[room]
		var back: Vector3 = (out - d["origin"]).normalized()
		w.inside = ""
		w.player.global_position = out + back * 8.0
		w.cam.yaw = atan2(back.x, back.z)
		w.cam.pitch = 0.05
		w.cam.zoom = 6.0
		for i in 30:
			await get_tree().physics_frame
		await _snap("entrance_" + room, 6)
		w.enter_interior(room)
		w.cam.yaw = 0.0
		w.cam.pitch = -0.15
		w.cam.zoom = 7.0
		for i in 30:
			await get_tree().physics_frame
		await _snap("inside_" + room, 6)
		w.leave_interior(room)
	w.loadout_panel.open("flash")
	await _snap("loadout_screen", 6)
	w.loadout_panel.close()


func _street_shots() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = true
	w.events.cooldown = 9999.0
	w.char_missions.enabled = false
	w.street_crime.enabled = false
	w.day_night.frozen = true
	w.day_night.hour = 16.0
	w.spawn_player("flash", Vector3(560, 0.5, -440))
	for i in 120:
		await get_tree().physics_frame
	for shot in [["street_central", Vector3(560, 0.5, -440), 0.0, 0.02, 9.0], ["street_star", Vector3(-1440, 0.5, -440), 0.8, 0.0, 9.0],
			["street_national", Vector3(-1440, 0.5, 1560), 2.0, 0.05, 9.0], ["street_aerial", Vector3(560, 60.0, -300), 0.4, -0.45, 20.0]]:
		w.player.global_position = shot[1]
		w.player.flying = shot[1].y > 5.0
		w.cam.yaw = shot[2]
		w.cam.pitch = shot[3]
		w.cam.zoom = shot[4]
		for i in 90:
			await get_tree().physics_frame
		await _snap(str(shot[0]), 6)
	# A line-up of every car style
	var x := 560.0 - 14.0
	for st in ["sedan", "hatch", "suv", "van", "sports", "pickup", "taxi", "police"]:
		var car := Prop.new()
		car.style = st
		car.build(w, "car")
		w.props_root.add_child(car)
		car.global_position = Vector3(x, 0.6, -470)
		car.rotation.y = PI * 0.5
		x += 4.0
	var bike := Prop.new()
	bike.build(w, "bike")
	w.props_root.add_child(bike)
	bike.global_position = Vector3(x, 0.4, -470)
	w.player.global_position = Vector3(560, 0.5, -462)
	w.player.flying = false
	w.cam.yaw = 0.0
	w.cam.pitch = -0.12
	w.cam.zoom = 16.0
	for i in 60:
		await get_tree().physics_frame
	await _snap("cars_lineup", 6)


func _wheel_shots() -> void:
	var w := World.new()
	add_child(w)
	w.population.enabled = true
	w.events.cooldown = 9999.0
	w.char_missions.enabled = false
	w.street_crime.enabled = false
	w.day_night.frozen = true
	w.day_night.hour = 15.0
	w.spawn_player("green_arrow", Vector3(560, 0.5, -440))
	for i in 60:
		await get_tree().physics_frame
	w.weapon_wheel.auto_close = false
	w.weapon_wheel.open()
	w.weapon_wheel._aim = Vector2(80, -80)
	w.weapon_wheel._pick()
	await _snap("weapon_wheel", 4)
	w.weapon_wheel.close(false)
	for pt in w.city.points:
		if pt["kind"] == "fountain":
			w.player.global_position = pt["pos"] + Vector3(0, 30, 30)
			w.player.flying = false
			break
	w.cam.yaw = 0.0
	w.cam.pitch = -0.6
	w.cam.zoom = 30.0
	for i in 40:
		await get_tree().physics_frame
	await _snap("plaza_aerial", 4)
	w.world_map.open()
	await _snap("world_map", 6)
	w.world_map._zoom_at(w.world_map._map.size * 0.5, 3.0)
	await _snap("world_map_zoom", 6)
	w.world_map.close()
