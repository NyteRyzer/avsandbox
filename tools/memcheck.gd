extends Node
## Prints memory use while building the world, travelling and spawning, to
## spot leaks:  godot --headless --path . res://tools/memcheck.tscn

func _mem(label: String) -> void:
	print("MEM %-28s static %6.0f MB  objects %7d  nodes %6d  resources %6d" % [label,
		OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])


func _ready() -> void:
	_mem("start")
	var w := World.new()
	add_child(w)
	_mem("world built")
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
