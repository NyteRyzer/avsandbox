extends Node
## Renders aerial views of the map for checking the layout.
##   godot --path . res://tools/overview.tscn -- <output dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_window().size = Vector2i(1600, 900)
	var w := World.new()
	add_child(w)
	w.events.cooldown = 9999.0
	w.day_night.frozen = true
	w.day_night.hour = 15.0
	w.spawn_player("supergirl", Vector3(0, 700, 1300))
	w.player.flying = true
	w.player.set_physics_process(false)
	var shots := [
		["bay", Vector3(0, 900, 1500), Vector3(0, 0, -100)],
		["star_city", Vector3(-250, 260, -150), Vector3(-560, 40, -560)],
		["central_city", Vector3(900, 200, -250), Vector3(620, 30, -700)],
		["national_city", Vector3(-250, 160, 1000), Vector3(-560, 40, 600)],
		["freeland", Vector3(850, 120, 900), Vector3(560, 10, 560)],
		["lian_yu", Vector3(-1250, 140, -1100), Vector3(-1560, 10, -1400)],
	]
	for s in shots:
		var cam := Camera3D.new()
		cam.far = 5000.0
		add_child(cam)
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.current = true
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_jpg(out.path_join(s[0] + ".jpg"), 0.85)
		print("saved ", s[0])
		cam.queue_free()
	get_tree().quit()
