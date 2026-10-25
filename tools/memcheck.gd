extends Node
## Prints memory use while building the world, travelling and spawning, to
## spot leaks:  godot --headless --path . res://tools/memcheck.tscn

func _mem(label: String) -> void:
	print("MEM %-28s static %6.0f MB  objects %7d  nodes %6d  resources %6d" % [label,
		OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])


func _ready() -> void:
	_mem("start")
	if OS.get_cmdline_user_args().has("city"):
		var c := City.new()
		add_child(c)
		c.generate()
		_mem("city generated")
		print("parked: %d" % c.parked.size())
		var r2 := RandomNumberGenerator.new()
		var n := 0
		for spot in c.parked:
			var prop := Prop.new()
			prop.build(self, spot["kind"], r2)
			add_child(prop)
			prop.global_transform = spot["xform"]
			n += 1
			if n % 500 == 0:
				_mem("%d parked" % n)
		_mem("all parked")
		await get_tree().process_frame
		_mem("1 frame")
		await get_tree().physics_frame
		_mem("1 physics frame")
		for i in 5:
			await get_tree().physics_frame
		_mem("6 physics frames")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("props"):
		var r := RandomNumberGenerator.new()
		for k in 3:
			for i in 20:
				var prop := Prop.new()
				prop.build(self, "car", r)
				add_child(prop)
			_mem("after %d cars" % ((k + 1) * 20))
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("pop"):
		var pp := Population.new()
		_mem("Population.new()")
		add_child(pp)
		_mem("add_child(population)")
		var a := Actor.new()
		_mem("Actor.new()")
		get_tree().quit()
		return
	var w := World.new()
	add_child(w)
	_mem("world built")
	if OS.get_cmdline_user_args().has("build"):
		get_tree().quit()
		return
	w.spawn_player("flash", Vector3(560, 0.5, -440))
	for i in 30:
		await get_tree().process_frame
	_mem("player in")
	for k in 4:
		for id in ["earth2", "earth1"]:
			w.travel_to(id, "breach")
			for i in 10:
				await get_tree().process_frame
		_mem("after travel round %d" % k)
	for k in 3:
		for i in 25:
			w.spawn_npc_character(Game.roster[(k * 25 + i) % Game.roster.size()]["id"], i % 2 == 0)
		for i in 30:
			await get_tree().process_frame
		w.clear_npcs()
		for i in 10:
			await get_tree().process_frame
		_mem("after spawn/clear %d" % k)
	get_tree().quit()
