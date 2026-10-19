class_name Prop
extends RigidBody3D
## Physics props: crates and cars. Anything can knock them around, characters
## with super strength can lift and throw them, and cars explode when wrecked.

const FURNITURE := {
	"bench": {"size": Vector3(2.0, 0.95, 0.6), "mass": 60.0, "hp": 30.0, "color": "#2a2a2e"},
	"hydrant": {"size": Vector3(0.45, 0.8, 0.45), "mass": 90.0, "hp": 25.0, "color": "#c82a1e"},
	"mailbox": {"size": Vector3(0.65, 1.35, 0.55), "mass": 70.0, "hp": 30.0, "color": "#1e3a8a"},
	"dumpster": {"size": Vector3(2.2, 1.4, 1.4), "mass": 400.0, "hp": 60.0, "color": "#2a5a2a"},
	"newsbox": {"size": Vector3(0.5, 1.0, 0.45), "mass": 40.0, "hp": 20.0, "color": "#c8a020"},
}
const CAR_COLORS := ["#b0201a", "#1f4fa8", "#e8e8e8", "#1a1a1a", "#8a8f99", "#2e7d32", "#d8a514", "#5a2a86", "#c0602a"]

var kind := "crate"
var hp := 40.0
var max_hp := 40.0
var exploded := false
var world
var holder: Actor = null
var thrown_by: Actor = null
var thrown_t := 0.0
var _body_mat: StandardMaterial3D
var _fire: CPUParticles3D
var _merged: MeshInstance3D
## Car body style (sedan, hatch, suv, van, sports, pickup, taxi, police).
var style := ""
var _siren_mats: Array = []
var _siren_t := 0.0

# Traffic: a driving car is a kinematic body following the street grid until
# something hits it, then it becomes an ordinary physics car.
const LANE := 3.6
const DRIVE_SPEED := 13.0
var driving := false
var heading := Vector3.FORWARD
var _speed := 0.0
var _next_turn := Vector3.ZERO
var _block_t := 0.0
var _blocked := false

# Player driving: arcade handling on top of a kinematic body.
const TOP_SPEED := 34.0
const NITRO_SPEED := 54.0
var player_driven := false
var drive_speed := DRIVE_SPEED   # traffic cruising speed (getaway cars go faster)
var getaway := false
var driver: Actor = null
var _yaw := 0.0
var _hit_cd: Dictionary = {}


func build(p_world, p_kind: String, rng: RandomNumberGenerator = null) -> void:
	world = p_world
	kind = p_kind
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	collision_layer = Game.LAYER_PROPS
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	body_entered.connect(_on_body_entered)
	add_to_group("props")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	shape.shape = box
	add_child(shape)
	if kind == "bike":
		# A motorcycle (the Arrowbike, or any parked bike): quick and nimble.
		mass = 220.0
		max_hp = 45.0
		box.size = Vector3(0.7, 1.1, 2.1)
		shape.position = Vector3(0, 0.6, 0)
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = Color(["#1a1a1a", "#1e4a22", "#8a1010", "#2a2a3a", "#d8a514", "#1f4fa8"][rng.randi() % 6])
		_merged = VehicleModel.build_bike(self, _body_mat.albedo_color)
	elif kind == "car":
		mass = 900.0
		max_hp = 70.0
		if style == "":
			var roll := rng.randf()
			style = "sedan"
			for pair in [["hatch", 0.15], ["suv", 0.3], ["van", 0.38], ["sports", 0.45], ["pickup", 0.53], ["taxi", 0.62], ["police", 0.66]]:
				if roll < pair[1]:
					style = pair[0]
					break
		var paint := Color(VehicleModel.PAINTS[rng.randi() % VehicleModel.PAINTS.size()])
		if style == "taxi":
			paint = Color("#f0c818")
		elif style == "police":
			paint = Color("#141418")
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = paint
		var built := VehicleModel.build_car(self, style, paint)
		_merged = built["body"]
		_siren_mats = built["lights"]
		var sz: Vector3 = built["size"]
		box.size = Vector3(sz.x, sz.y - 0.15, sz.z)
		shape.position = Vector3(0, (sz.y - 0.15) * 0.5 + 0.1, 0)
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, 0.4, 0)
	elif kind in FURNITURE:
		# Street furniture: benches, fire hydrants, mailboxes, dumpsters,
		# newspaper boxes. All of it can be thrown.
		var f: Dictionary = FURNITURE[kind]
		mass = float(f["mass"])
		max_hp = float(f["hp"])
		var sz: Vector3 = f["size"]
		box.size = sz
		shape.position = Vector3(0, sz.y * 0.5, 0)
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = Color(str(f["color"]))
		_body_mat.metallic = 0.3
		_body_mat.roughness = 0.6
		match kind:
			"bench":
				var wood := CharacterModel.mat(Color("#7a5434"))
				_mesh(Vector3(sz.x, 0.08, 0.45), Vector3(0, 0.45, 0), wood)
				_mesh(Vector3(sz.x, 0.4, 0.06), Vector3(0, 0.75, 0.22), wood)
				for sx in [-0.8, 0.8]:
					_mesh(Vector3(0.08, 0.45, 0.45), Vector3(sx, 0.22, 0), _body_mat)
			"hydrant":
				_mesh(Vector3(0.32, 0.6, 0.32), Vector3(0, 0.3, 0), _body_mat)
				_mesh(Vector3(0.42, 0.12, 0.42), Vector3(0, 0.62, 0), _body_mat)
				_mesh(Vector3(0.5, 0.12, 0.14), Vector3(0, 0.42, 0), _body_mat)
				_mesh(Vector3(0.2, 0.14, 0.2), Vector3(0, 0.74, 0), _body_mat)
			"mailbox":
				_mesh(Vector3(0.6, 0.9, 0.5), Vector3(0, 0.75, 0), _body_mat)
				_mesh(Vector3(0.62, 0.2, 0.52), Vector3(0, 1.25, 0), _body_mat)
				for sx in [-0.25, 0.25]:
					_mesh(Vector3(0.08, 0.3, 0.08), Vector3(sx, 0.15, 0), CharacterModel.mat(Color("#2a2a2a")))
			"dumpster":
				_mesh(Vector3(sz.x, sz.y * 0.9, sz.z), Vector3(0, sz.y * 0.45, 0), _body_mat)
				_mesh(Vector3(sz.x + 0.06, 0.08, sz.z + 0.06), Vector3(0, sz.y * 0.92, 0), CharacterModel.mat(Color("#1a3a1a")))
			"newsbox":
				_mesh(Vector3(0.5, 1.0, 0.45), Vector3(0, 0.5, 0), _body_mat)
				_mesh(Vector3(0.4, 0.3, 0.02), Vector3(0, 0.75, -0.235), CharacterModel.mat(Color("#e8e8d8"), 0.4))
	else:
		mass = 40.0
		max_hp = 30.0
		var s := rng.randf_range(0.9, 1.4)
		box.size = Vector3.ONE * s
		shape.position = Vector3(0, s * 0.5, 0)
		var c := Color("#8a6a3a") if rng.randf() < 0.6 else Color("#4a5a6a")
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = c
		_mesh(Vector3.ONE * s, Vector3(0, s * 0.5, 0), _body_mat)
		var trim := CharacterModel.mat(c.darkened(0.35))
		_mesh(Vector3(s * 1.02, s * 0.12, s * 1.02), Vector3(0, s * 0.5, 0), trim)
	hp = max_hp
	if not is_vehicle():
		_merged = CharacterModel.merge_children(self, 0.0)
	for c in get_children():
		if c is GeometryInstance3D:
			c.visibility_range_end = 220.0


func _mesh(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


## Starts driving along the street the car is on, in direction `dir`.
func start_driving(dir: Vector3) -> void:
	driving = true
	heading = dir
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_speed = drive_speed
	_plan_next_intersection()
	add_to_group("traffic")


func stop_driving() -> void:
	if not driving:
		return
	driving = false
	freeze = false
	remove_from_group("traffic")
	linear_velocity = heading * _speed


func _plan_next_intersection() -> void:
	var p := global_position
	var along := p.dot(heading)
	var next := (floorf(along / City.CELL) + 1.0) * City.CELL
	_next_turn = heading * next


func _drive(delta: float) -> void:
	_block_t -= delta
	if _block_t <= 0.0:
		_block_t = 0.2
		var from := global_position + Vector3.UP * 0.8
		var q := PhysicsRayQueryParameters3D.create(from, from + heading * 9.0, Game.LAYER_ACTORS | Game.LAYER_PROPS, [get_rid()])
		_blocked = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_speed = move_toward(_speed, 0.0 if _blocked and not getaway else drive_speed, delta * (25.0 if _blocked and not getaway else 6.0))
	var p := global_position + heading * _speed * delta
	# Reached the next intersection: maybe turn.
	if (p.dot(heading) - _next_turn.dot(heading)) >= 0.0:
		var options: Array = [heading]
		var right := heading.cross(Vector3.UP)
		options.append(right)
		options.append(-right)
		var center := Vector3(roundf(p.x / City.CELL) * City.CELL, p.y, roundf(p.z / City.CELL) * City.CELL)
		options = options.filter(func(d: Vector3) -> bool:
			var ahead: Vector3 = center + d * City.CELL
			return world.city.on_grid(ahead))
		if options.is_empty():
			options = [-heading]
		var choice: Vector3 = options[0] if randf() < 0.5 and options.has(heading) else options[randi() % options.size()]
		if choice != heading:
			heading = choice
			var lane := heading.cross(Vector3.UP) * LANE
			p = center + lane
		_plan_next_intersection_from(p)
	p.y = 0.1
	global_position = p
	var target_yaw := atan2(-heading.x, -heading.z)  # the car's nose is -Z
	rotation = Vector3(0, lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0)), 0)


func _plan_next_intersection_from(p: Vector3) -> void:
	var along := p.dot(heading)
	_next_turn = heading * ((floorf(along / City.CELL + 0.001) + 1.0) * City.CELL)


func _physics_process(delta: float) -> void:
	if player_driven:
		_player_drive(delta)
	elif driving and holder == null:
		_drive(delta)
	if thrown_t > 0.0:
		thrown_t -= delta
	if global_position.y < -30.0:
		queue_free()
	if not _siren_mats.is_empty() and (driving or player_driven or getaway):
		# Police lights: red and blue, alternating.
		_siren_t += delta
		var on := int(_siren_t * 4.0) % 2 == 0
		_siren_mats[0].emission_energy_multiplier = 4.0 if on else 0.3
		_siren_mats[1].emission_energy_multiplier = 0.3 if on else 4.0


## The player gets behind the wheel.
func take_wheel(a: Actor) -> void:
	stop_driving()
	driver = a
	player_driven = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_speed = 0.0
	_yaw = rotation.y
	rotation = Vector3(0, _yaw, 0)
	global_position.y = maxf(global_position.y, 0.1)


func leave_wheel() -> void:
	player_driven = false
	driver = null
	freeze = false
	sleeping = false
	linear_velocity = heading * _speed


func speed_kmh() -> float:
	return absf(_speed) * 3.6


func _player_drive(delta: float) -> void:
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var throttle := -mv.y
	var nitro := Input.is_action_pressed("sprint")
	var top := (NITRO_SPEED if nitro else TOP_SPEED) * (1.35 if kind == "bike" else 1.0)
	if Input.is_action_pressed("jump"):
		_speed = move_toward(_speed, 0.0, 45.0 * delta)
	elif throttle > 0.05:
		_speed = move_toward(_speed, top * throttle, (24.0 if nitro else 15.0) * delta)
	elif throttle < -0.05:
		_speed = move_toward(_speed, -10.0, (30.0 if _speed > 0.0 else 10.0) * delta)
	else:
		_speed = move_toward(_speed, 0.0, 5.0 * delta)
	var grip := clampf(absf(_speed) / 8.0, 0.0, 1.0)
	_yaw -= mv.x * grip * signf(_speed) * (1.9 if Input.is_action_pressed("jump") else 1.4) * delta
	heading = Vector3(0, 0, -1).rotated(Vector3.UP, _yaw)
	var space := get_world_3d().direct_space_state
	var p := global_position
	# Walls and buildings stop the car (and dent it).
	var dir := heading * signf(_speed)
	var from := p + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (2.6 + absf(_speed) * delta), Game.LAYER_WORLD, [get_rid()])
	var wall := space.intersect_ray(q)
	if not wall.is_empty() and absf(_speed) > 0.5:
		if absf(_speed) > 15.0:
			Sfx.play("slam", p, -4.0)
			world.shake_at(p, 0.3)
			hp -= absf(_speed) * 0.4
		_speed *= -0.25
	p += heading * _speed * delta
	# Follow the ground; drive off the edge and you fall.
	var dq := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 6.0, Game.LAYER_WORLD, [get_rid()])
	var ground := space.intersect_ray(dq)
	if not ground.is_empty() and ground["position"].y > p.y - 1.5:
		p.y = lerpf(p.y, ground["position"].y, clampf(delta * 12.0, 0.0, 1.0))
	else:
		p.y -= 12.0 * delta
	global_position = p
	rotation = Vector3(0, _yaw, -mv.x * grip * (0.35 if kind == "bike" else 0.05))
	# Running people over, and ramming other cars.
	for k in _hit_cd.keys():
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)
	if absf(_speed) > 7.0:
		var front := p + heading * signf(_speed) * 2.2
		for a in get_tree().get_nodes_in_group("actors"):
			if a == driver or a.dead or _hit_cd.has(a.get_instance_id()):
				continue
			if a.global_position.distance_to(front) < 2.4:
				_hit_cd[a.get_instance_id()] = 1.0
				a.take_damage(absf(_speed) * 1.6, driver, "", heading * signf(_speed) * absf(_speed) * 0.7 + Vector3.UP * 7.0)
				Sfx.play("punch", a.global_position, 0.0)
				_speed *= 0.85
		for prop in get_tree().get_nodes_in_group("props"):
			if prop == self or _hit_cd.has(prop.get_instance_id()):
				continue
			if prop.global_position.distance_to(front) < 3.0:
				_hit_cd[prop.get_instance_id()] = 1.0
				prop.hit(absf(_speed) * 0.8, heading * signf(_speed) * absf(_speed) * 40.0 + Vector3.UP * 200.0, driver)
				_speed *= 0.6
	if hp <= 0.0 and not exploded:
		world.exit_vehicle()
		_explode(driver)
	elif global_position.y < -2.5:
		world.exit_vehicle()


func is_vehicle() -> bool:
	return kind == "car" or kind == "bike"


func hit(dmg: float, impulse: Vector3, source: Actor) -> void:
	if getaway and driving:
		# A getaway car keeps going until it's badly damaged.
		hp -= dmg
		FX.sparks(world, global_position + Vector3.UP, Color("#ffd080"), 6, 4.0)
		if hp < max_hp * 0.35:
			getaway = false
			stop_driving()
			FX.smoke(world, global_position + Vector3.UP, 2.0, 3.0)
		return
	if holder or player_driven:
		if player_driven and not exploded:
			hp -= dmg * 0.5
		return
	stop_driving()
	sleeping = false
	apply_central_impulse(impulse * (mass / 60.0 if kind == "crate" else mass / 400.0))
	if exploded:
		return
	hp -= dmg
	if hp <= 0.0:
		if is_vehicle():
			_explode(source)
		else:
			_smash()


func pick_up(a: Actor) -> void:
	stop_driving()
	holder = a
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0


func throw_from(a: Actor, vel: Vector3) -> void:
	holder = null
	freeze = false
	collision_layer = Game.LAYER_PROPS
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	linear_velocity = vel
	angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	thrown_by = a
	thrown_t = 3.0 if vel.length() > 1.0 else 0.0


func _on_body_entered(body: Node) -> void:
	var speed := linear_velocity.length()
	if speed < 9.0:
		return
	if body is Actor and body != thrown_by and not body.dead:
		var src: Actor = thrown_by if thrown_t > 0.0 and is_instance_valid(thrown_by) else null
		if src and not src.can_hurt(body):
			return
		var dmg := minf(70.0, speed * (2.2 if is_vehicle() else 0.8))
		body.take_damage(dmg, src, "", linear_velocity.normalized() * 10.0 + Vector3.UP * 6.0)
	if thrown_t > 0.0 and speed > 14.0 and not exploded:
		hp -= speed * (1.5 if is_vehicle() else 3.0)
		if hp <= 0.0:
			if is_vehicle():
				_explode(thrown_by if is_instance_valid(thrown_by) else null)
			else:
				_smash()
	if world:
		Sfx.play("slam" if is_vehicle() else "punch", global_position, -6.0)


func _explode(source: Actor) -> void:
	exploded = true
	Abilities.explode(world, global_position + Vector3.UP, 7.0, 45.0, source, "fire", Color("#ff8a2a"))
	apply_central_impulse(Vector3.UP * mass * 9.0)
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-1, 1), randf_range(-3, 3))
	if _merged:
		_merged.material_override = CharacterModel.mat(Color("#1e1a18"))
	_fire = CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.25
	m.height = 0.5
	m.material = CharacterModel.mat(Color("#ff7a1a"), 0.0, true, 0.8)
	_fire.mesh = m
	_fire.amount = 24
	_fire.lifetime = 0.8
	_fire.direction = Vector3.UP
	_fire.spread = 25.0
	_fire.initial_velocity_min = 2.0
	_fire.initial_velocity_max = 4.0
	_fire.gravity = Vector3(0, 2, 0)
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire.emission_box_extents = Vector3(0.8, 0.3, 1.6)
	_fire.position = Vector3(0, 1.2, 0)
	_fire.scale_amount_min = 0.5
	_fire.scale_amount_max = 1.5
	add_child(_fire)
	var t := create_tween()
	t.tween_interval(14.0)
	t.tween_callback(_stop_fire)
	if source and source.is_player:
		Game.add_heat(0.3 if Game.player_side() == 1 else 0.1)
		if Game.player_side() == -1:
			Game.add_score(5)


func _stop_fire() -> void:
	if is_instance_valid(_fire):
		_fire.emitting = false


func _smash() -> void:
	FX.sparks(world, global_position + Vector3.UP * 0.5, _body_mat.albedo_color if _body_mat else Color("#8a6a3a"), 16, 6.0, 0.6)
	if kind == "hydrant" and world:
		# A broken hydrant gushes water for a while.
		var gush := CPUParticles3D.new()
		var drop := SphereMesh.new()
		drop.radius = 0.08
		drop.height = 0.16
		gush.mesh = drop
		gush.material_override = CharacterModel.mat(Color(0.7, 0.85, 1.0), 0.0, true, 0.6)
		gush.amount = 120
		gush.lifetime = 1.4
		gush.direction = Vector3.UP
		gush.spread = 12.0
		gush.initial_velocity_min = 9.0
		gush.initial_velocity_max = 13.0
		gush.local_coords = false
		world.fx_root.add_child(gush)
		gush.global_position = global_position + Vector3.UP * 0.4
		world.get_tree().create_timer(12.0, false).timeout.connect(gush.queue_free)
		Sfx.play("smoke", global_position, 0.0)
	Sfx.play("punch", global_position, 0.0)
	queue_free()
