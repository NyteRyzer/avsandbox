class_name Activity
extends Node
## Event types that aren't just "knock everyone out":
##   fire  - a building is burning. Carry the trapped people (G) to the
##           ambulance, and put the fires out with ice, wind or super breath.
##   chase - a getaway car tears through the streets. Wreck it, then deal with
##           the robbers who climb out.

var world
var kind := ""
var center := Vector3.ZERO
var done := false
var failed := false
var time := 0.0
# fire
var trapped: Array = []
var fires: Array = []          # {node, hp, pos}
var rescued := 0
var total := 0
var ambulance := Vector3.ZERO
var _fire_tick := 0.0
# chase
var car: Prop
var robbers: Array = []


func remaining() -> int:
	if kind == "fire":
		return total - rescued
	if kind == "chase":
		if robbers.is_empty():
			return 1
		return robbers.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
	return 0


func marker_pos() -> Vector3:
	if kind == "chase" and is_instance_valid(car):
		return car.global_position
	return center


# --- Fire rescue ----------------------------------------------------------------

func start_fire(p_world, near: Vector3) -> bool:
	world = p_world
	kind = "fire"
	var city: City = world.city
	var options: Array = city.buildings_near(near, 220.0).filter(func(b) -> bool: return b["h"] > 10.0 and b["rect"].get_center().distance_to(Vector2(near.x, near.z)) > 50.0)
	if options.is_empty():
		return false
	var b: Dictionary = options[randi() % options.size()]
	var r: Rect2 = b["rect"]
	var front := Vector3(r.get_center().x, 0.2, r.position.y - 1.2)
	center = front
	ambulance = city.snap_to_road(front + Vector3(0, 0, -14.0), 4.0) + Vector3.UP * 0.1
	var h: float = minf(float(b["h"]), 24.0)
	for k in 6:
		var fp := Vector3(r.position.x + r.size.x * (0.15 + 0.7 * randf()), randf_range(1.5, h), r.position.y - 0.4)
		fires.append({"node": _flames(fp), "hp": 3, "pos": fp})
	total = 4
	for k in total:
		var pos := front + Vector3(randf_range(-r.size.x * 0.4, r.size.x * 0.4), 0.3, randf_range(-0.5, 0.5))
		var c: Actor = world.population.spawn_civilian(pos)
		c.brain = null
		c.set_meta("pinned", true)
		c.set_meta("trapped", true)
		c.event_tag = "fire"
		trapped.append(c)
	_ambulance()
	return true


func _flames(pos: Vector3) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	f.mesh = s
	f.material_override = FX.glow_mat(Color("#ff7a1a"), 0.85)
	f.amount = 40
	f.lifetime = 1.0
	f.direction = Vector3.UP
	f.spread = 20.0
	f.initial_velocity_min = 2.0
	f.initial_velocity_max = 4.0
	f.gravity = Vector3(0, 2.0, 0)
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.8
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(2.0, 0.6, 0.5)
	f.local_coords = false
	add_child(f)
	f.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color("#ff8a2a")
	light.omni_range = 9.0
	light.light_energy = 2.0
	f.add_child(light)
	return f


func _ambulance() -> void:
	var van := Node3D.new()
	add_child(van)
	van.global_position = ambulance
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 2.2, 5.0)
	body.mesh = bm
	body.material_override = CharacterModel.mat(Color("#f0f0f0"))
	body.position.y = 1.2
	van.add_child(body)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.25, 0.3, 5.05)
	stripe.mesh = sm
	stripe.material_override = CharacterModel.mat(Color("#c82a1e"), 1.2)
	stripe.position.y = 1.4
	van.add_child(stripe)
	var label := Label3D.new()
	label.text = "AMBULANCE - BRING THEM HERE"
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 3.4
	label.modulate = Color("#ffb0b0")
	van.add_child(label)


func carried_drop(c: Actor) -> bool:
	if c.global_position.distance_to(ambulance) < 8.0:
		rescued += 1
		trapped.erase(c)
		FX.flash(world, c.chest(), Color("#60ff90"), 1.0, 0.3)
		c.queue_free()
		world.notify("Rescued! %d / %d" % [rescued, total], Color("#60ff90"))
		Game.add_score(40)
		Game.record("rescues")
		return true
	return false


func _tick_fire(delta: float) -> void:
	# Someone trapped was knocked out (or removed): they can't be carried out
	# any more, so they no longer count towards finishing the rescue.
	for c in trapped.duplicate():
		if not is_instance_valid(c) or c.dead:
			trapped.erase(c)
			total -= 1
			world.notify("One of the trapped people didn't make it out.", Color("#ff8a6a"))
	if total <= 0:
		failed = true
		return
	_fire_tick -= delta
	if _fire_tick > 0.0:
		return
	_fire_tick = 0.25
	var p: Actor = world.player
	# Ice, wind and super breath put fires out.
	var dousing := false
	if p and is_instance_valid(p) and not p.civilian:
		for slot in ["primary", "secondary"]:
			var atk: Dictionary = p.def[slot]
			var held: bool = p.in_primary if slot == "primary" else p.in_secondary
			if held and (str(atk.get("element", "")) in ["ice", "push"] or atk["kind"] in ["breath", "sonic"]):
				dousing = true
		if p.breath_t > 0.0 or (p.movement == "speed" and p.whirl_t > 0.0) or p.tornado_t > 0.0:
			dousing = true
	for f in fires:
		if f["hp"] <= 0:
			continue
		var fp: Vector3 = f["pos"]
		if dousing and p.global_position.distance_to(fp) < 14.0:
			f["hp"] -= 1
			FX.smoke(world, fp, 1.5, 1.0)
			if f["hp"] <= 0:
				f["node"].emitting = false
				world.notify("Fire out!", Color("#9fd0ff"))
				Game.add_score(20)
		for a in get_tree().get_nodes_in_group("actors"):
			if not a.has_meta("trapped") and a.global_position.distance_to(fp) < 2.5:
				a.burn_t = maxf(a.burn_t, 1.0)
	for c in trapped:
		if is_instance_valid(c) and randf() < 0.1 and c != world.carrying:
			c.model.play("cast_up", 0.8)


# --- Getaway chase ----------------------------------------------------------------

func start_chase(p_world, near: Vector3) -> bool:
	world = p_world
	kind = "chase"
	var start: Vector3 = world.city.random_road_point(near, 60.0, 110.0)
	car = world.population.spawn_traffic(start)
	if car == null:
		return false
	car.getaway = true
	car.drive_speed = 26.0
	car.max_hp = 220.0
	car.hp = car.max_hp
	center = start
	return true


func _tick_chase() -> void:
	if not is_instance_valid(car):
		if robbers.is_empty():
			failed = true
		return
	if robbers.is_empty() and not car.getaway:
		# Wrecked: the robbers bail out and fight.
		for k in 2:
			var t: Actor = world.population.spawn_thug(car.global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3)))
			t.display_name = "Getaway Driver" if k == 0 else "Bank Robber"
			t.grudges[world.player.get_instance_id()] = 60.0
			t.set_meta("pinned", true)
			robbers.append(t)
		world.notify("The robbers are bailing out!", Color("#ffd23a"))
	if car.getaway and randf() < 0.3:
		FX.smoke(world, car.global_position + Vector3.UP * 0.6 - car.heading * 2.5, 0.6, 0.6)
	if car.getaway and car.global_position.distance_to(world.player.global_position) > 650.0:
		failed = true


func _process(delta: float) -> void:
	if world == null or done or failed:
		return
	time += delta
	match kind:
		"fire":
			_tick_fire(delta)
			if rescued >= total and rescued > 0:
				done = true
			elif time > 300.0:
				failed = true
		"chase":
			_tick_chase()
			if not robbers.is_empty() and remaining() == 0:
				done = true
				Game.record("chases")
			elif time > 240.0:
				failed = true


func cleanup() -> void:
	for c in trapped:
		if is_instance_valid(c):
			c.queue_free()
	if is_instance_valid(car) and car.getaway:
		car.getaway = false
		car.stop_driving()
	queue_free()
