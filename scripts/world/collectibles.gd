class_name Collectibles
extends Node3D
## Forty Crisis Fragments hidden around Earth-1: on rooftops, in parks, on
## Lian Yu and inside Iron Heights' walls. Every five unlock an alternate suit.
## Found fragments are saved.

const TOTAL := 40

var world
var spots: Array = []          # {id, pos}
var _nodes: Dictionary = {}    # id -> Node3D
var _spin := 0.0


## Places them deterministically (the same spots every game).
func build() -> void:
	for n in get_children():
		n.queue_free()
	_nodes.clear()
	spots.clear()
	var city: City = world.city
	if city.kind != "metro" or world.place_id != "earth1":
		return
	var r := RandomNumberGenerator.new()
	r.seed = 4040
	for isl in city.islands:
		var c: Vector2 = isl["center"]
		var grid: Rect2 = isl["grid"]
		# Four on rooftops...
		var roofs: Array = city.buildings_near(Vector3(c.x, 0, c.y), City.HALF).filter(func(b) -> bool: return b["h"] > 12.0)
		for k in 4:
			if roofs.is_empty():
				break
			var b: Dictionary = roofs[r.randi() % roofs.size()]
			var rc: Vector2 = b["rect"].get_center()
			spots.append(Vector3(rc.x, float(b["h"]) + 2.0, rc.y))
		# ...and two at street level.
		for k in 2:
			var p := Vector3(r.randf_range(grid.position.x, grid.end.x), 0, r.randf_range(grid.position.y, grid.end.y))
			spots.append(city.snap_to_road(p, 6.0) + Vector3.UP * 1.4)
	# The rest in the far corners of the map.
	var extra := [Vector3(City.LIAN_YU.x + 40, 2.0, City.LIAN_YU.y + 120), Vector3(City.LIAN_YU.x - 80, 9.0, City.LIAN_YU.y - 60),
		Vector3(City.IRON_HEIGHTS.x, 2.0, City.IRON_HEIGHTS.y + 50), Vector3(0, 2.0, -462),
		Vector3(0, 46.0, -560), Vector3(-560, 46.0, 0)]
	for e in extra:
		if spots.size() < TOTAL:
			spots.append(e)
	var out := []
	for k in mini(spots.size(), TOTAL):
		out.append({"id": "frag_%02d" % k, "pos": spots[k]})
	spots = out
	var found: Array = Game.progress["collected"]
	for s in spots:
		if not found.has(s["id"]):
			_make(s)


func _make(s: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = s["pos"]
	var crystal := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = Vector3(0.6, 0.9, 0.6)
	crystal.mesh = m
	crystal.material_override = FX.glow_mat(Color("#ff4fd8"), 0.95)
	n.add_child(crystal)
	var low := MeshInstance3D.new()
	low.mesh = m
	low.material_override = crystal.material_override
	low.rotation.x = PI
	low.position.y = -0.9
	n.add_child(low)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff4fd8")
	light.omni_range = 6.0
	light.light_energy = 1.2
	n.add_child(light)
	_nodes[s["id"]] = n


func found_count() -> int:
	return Game.progress["collected"].size()


func remaining() -> Array:
	return spots.filter(func(s) -> bool: return _nodes.has(s["id"]))


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player) or _nodes.is_empty():
		return
	_spin += delta
	var p: Vector3 = world.player.chest()
	for id in _nodes.keys():
		var n: Node3D = _nodes[id]
		n.rotation.y = _spin * 1.5
		n.position.y += sin(_spin * 2.0) * 0.004
		if n.global_position.distance_to(p) < 2.6:
			_collect(id, n)


func _collect(id: String, n: Node3D) -> void:
	Game.progress["collected"].append(id)
	FX.flash(world, n.global_position, Color("#ff4fd8"), 2.0, 0.4, 0.7)
	FX.sparks(world, n.global_position, Color("#ff4fd8"), 30, 6.0, 0.6)
	n.queue_free()
	_nodes.erase(id)
	var count := found_count()
	Sfx.play("event", null, 2.0)
	world.notify("Crisis Fragment found: %d / %d" % [count, TOTAL], Color("#ff9ae8"))
	Game.add_score(50)
	Game.record("fragments")
	if count % 5 == 0:
		var suit := Costumes.unlock_next()
		if suit != "":
			world.hud.show_banner("NEW SUIT UNLOCKED", Color("#ff9ae8"))
			world.notify("Unlocked " + suit + " (pick it in character select)", Color("#ff9ae8"))
	Game.save_settings()
