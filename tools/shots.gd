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
	if pose == "face":
		cam.position = Vector3(2.4, 1.62, 1.9)
		cam.fov = 26
		pose = ""
	var batch := 0
	while batch * 4 < ids.size():
		var models: Array = []
		for i in 4:
			var idx := batch * 4 + i
			if idx >= ids.size():
				break
			var c := Game.get_character(ids[idx])
			var m := CharacterModel.new()
			root.add_child(m)
			m.build(c["look"])
			var s := float(c["look"].get("scale", 1.0))
			m.scale = Vector3.ONE * minf(1.0, 1.25 / s)
			m.position = Vector3(i * 1.6, 0, 0) if cam.fov > 30 else Vector3(1.65 + i * 0.5, 0, 0)
			m.rotation.y = PI + 0.5
			models.append(m)
		for f in 30:
			for m in models:
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
	w.spawn_player("flash", Vector3(280, 0.5, -240))
	w.cam.yaw = 0.6
	w.cam.pitch = -0.15
	for i in 120:
		await get_tree().physics_frame
	await _snap("central_city", 10)

	w.spawn_player("supergirl", Vector3(-250, 90, 200))
	w.player.flying = true
	w.cam.yaw = 2.4
	w.cam.pitch = -0.25
	await _snap("national_city_flight", 30)

	w.spawn_player("green_arrow", Vector3(-280, 0.5, -320))
	w.day_night.hour = 21.5
	w.cam.yaw = -0.4
	w.cam.pitch = 0.1
	for k in 4:
		w.population.spawn_thug(Vector3(-280 + k * 2.0, 0.5, -330))
	await _snap("star_city_night", 40)
	w.player.aim_point = w.player.global_position + Vector3(0, 1, -12)
	w.player.in_primary = true
	Abilities.fire(w.player, w.player.def["primary"])
	Abilities.fire(w.player, w.player.def["secondary"])
	await _snap("combat", 6)

	w.day_night.hour = 12.0
	w.spawn_player("grodd", Vector3(20, 0.5, 30))
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
	w.spawn_player("reverse_flash", Vector3(-560, 0.5, 0))
	w.cam.yaw = PI * 0.5 + 0.35
	w.cam.pitch = -0.12
	w.player.face_dir = Vector3.RIGHT
	for i in 50:
		w.player.velocity = Vector3(55, 0, 0)
		w.player.global_position += Vector3(55.0 / 60.0, 0, 0)
		w.player._speed_trail(1.0 / 60.0, 55.0)
		await get_tree().physics_frame
	await _snap("speedster", 1)
	w.spawn_player("superman", Vector3(300, 30, 300))
	w.player.flying = true
	w.cam.yaw = 0.3
	w.cam.pitch = -0.35
	var target := w.population.spawn_character(Game.get_character("reign"), "villain", Vector3(296, 18, 270))
	target.flying = true
	for i in 30:
		w.player.aim_point = target.chest()
		Abilities.held_tick(w.player, w.player.def["secondary"], 1.0 / 60.0, "secondary")
		await get_tree().process_frame
	await _snap("heat_vision", 1)
