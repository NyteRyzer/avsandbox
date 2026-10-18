class_name Prop
extends RigidBody3D
## Physics props: crates and cars. Anything can knock them around, characters
## with super strength can lift and throw them, and cars explode when wrecked.

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
	if kind == "car":
		mass = 900.0
		max_hp = 70.0
		box.size = Vector3(2.0, 1.3, 4.4)
		shape.position = Vector3(0, 0.75, 0)
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, 0.4, 0)
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = Color(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		_body_mat.metallic = 0.5
		_body_mat.roughness = 0.35
		_mesh(Vector3(2.0, 0.75, 4.4), Vector3(0, 0.62, 0), _body_mat)
		_mesh(Vector3(1.8, 0.6, 2.3), Vector3(0, 1.28, 0.2), _body_mat)
		var glass := CharacterModel.mat(Color("#1c2a38"))
		_mesh(Vector3(1.84, 0.45, 2.0), Vector3(0, 1.3, 0.2), glass)
		var lamp := CharacterModel.mat(Color("#fff2c0"), 2.0)
		var tail := CharacterModel.mat(Color("#ff2020"), 1.5)
		for sx in [-0.7, 0.7]:
			_mesh(Vector3(0.35, 0.15, 0.05), Vector3(sx, 0.75, -2.21), lamp)
			_mesh(Vector3(0.35, 0.15, 0.05), Vector3(sx, 0.75, 2.21), tail)
		var tire := CharacterModel.mat(Color("#141414"))
		for wx in [-0.95, 0.95]:
			for wz in [-1.4, 1.4]:
				var w := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.36
				cyl.bottom_radius = 0.36
				cyl.height = 0.28
				cyl.radial_segments = 12
				cyl.material = tire
				w.mesh = cyl
				w.position = Vector3(wx, 0.36, wz)
				w.rotation.z = PI * 0.5
				add_child(w)
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
	_merged = CharacterModel.merge_children(self, 0.5 if kind == "car" else 0.0)
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
	_speed = DRIVE_SPEED
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
	_speed = move_toward(_speed, 0.0 if _blocked else DRIVE_SPEED, delta * (25.0 if _blocked else 6.0))
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
	if driving and holder == null:
		_drive(delta)
	if thrown_t > 0.0:
		thrown_t -= delta
	if global_position.y < -30.0:
		queue_free()


func hit(dmg: float, impulse: Vector3, source: Actor) -> void:
	if holder:
		return
	stop_driving()
	sleeping = false
	apply_central_impulse(impulse * (mass / 60.0 if kind == "crate" else mass / 400.0))
	if exploded:
		return
	hp -= dmg
	if hp <= 0.0:
		if kind == "car":
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
		var dmg := minf(70.0, speed * (2.2 if kind == "car" else 0.8))
		body.take_damage(dmg, src, "", linear_velocity.normalized() * 10.0 + Vector3.UP * 6.0)
	if thrown_t > 0.0 and speed > 14.0 and not exploded:
		hp -= speed * (1.5 if kind == "car" else 3.0)
		if hp <= 0.0:
			if kind == "car":
				_explode(thrown_by if is_instance_valid(thrown_by) else null)
			else:
				_smash()
	if world:
		Sfx.play("slam" if kind == "car" else "punch", global_position, -6.0)


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
	FX.sparks(world, global_position + Vector3.UP * 0.5, Color("#8a6a3a"), 16, 6.0, 0.6)
	Sfx.play("punch", global_position, 0.0)
	queue_free()
