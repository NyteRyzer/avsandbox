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
	await _title()
	await _select()
	await _world()
	get_tree().quit()


func _snap(name: String, frames := 20) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s  draw calls %d  objects %d  fps %d" % [name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		Engine.get_frames_per_second()])


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
