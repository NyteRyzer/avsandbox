class_name Waverider
extends Node3D
## The Waverider: a time ship parked on its landing pad. Walk up the ramp to
## board it (its bridge is one of the interiors); take the helm to fly it
## anywhere on the map, fire its cannons, and jump to another era.
##
## While piloting, the player's actor rides along hidden inside the ship so
## the camera, minimap and HUD keep working unchanged.

const CRUISE := 55.0
const BOOST := 150.0

var world
var piloted := false
var velocity := Vector3.ZERO
var yaw := 0.0
var body: StaticBody3D
var _visual: Node3D
var _glows: Array[MeshInstance3D] = []
var _glow_mat: StandardMaterial3D
var _cannon_t := 0.0
var _saved_zoom := 5.5
var _saved_layer := 0
var _bob := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var hull := _mat("#a3acb6", 0.6, 0.35)
	var dark := _mat("#2a3038", 0.4, 0.5)
	var trim := _mat("#c8a050", 0.7, 0.3)
	var glass := _mat("#1a3a5a", 0.2, 0.1)
	glass.emission_enabled = true
	glass.emission = Color("#3a8aff")
	glass.emission_energy_multiplier = 0.4
	_glow_mat = _mat("#6ad0ff", 0.0, 0.2)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color("#6ad0ff")
	_glow_mat.emission_energy_multiplier = 2.0
	# Hull: a long flattened capsule with a pointed nose.
	_part(_capsule(5.0, 44.0), Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0), Vector3(1.35, 1, 0.55), hull)
	_part(_capsule(3.6, 20.0), Vector3(0, 2.2, 4), Vector3(PI * 0.5, 0, 0), Vector3(1.2, 1, 0.5), dark)
	_part(_cone(3.4, 0.4, 12.0), Vector3(0, -0.2, -26), Vector3(-PI * 0.5, 0, 0), Vector3(1.3, 1, 0.5), hull)
	# Cockpit canopy
	_part(_sphere(3.0), Vector3(0, 2.4, -13), Vector3.ZERO, Vector3(1.0, 0.5, 1.9), glass)
	# Swept wings with gold trim
	for side in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(16, 0.8, 11)
		_part(wing, Vector3(side * 12.0, -0.6, 7), Vector3(0, side * -0.35, side * 0.06), Vector3.ONE, hull)
		var edge := BoxMesh.new()
		edge.size = Vector3(16.4, 0.3, 0.8)
		_part(edge, Vector3(side * 12.3, -0.2, 1.8 + absf(side) * 0.3), Vector3(0, side * -0.35, side * 0.06), Vector3.ONE, trim)
		# Engine nacelles
		_part(_cylinder(1.9, 1.6, 12.0), Vector3(side * 6.0, -0.4, 17), Vector3(PI * 0.5, 0, 0), Vector3.ONE, dark)
		var g := _part(_cylinder(1.5, 1.5, 0.3), Vector3(side * 6.0, -0.4, 23.2), Vector3(PI * 0.5, 0, 0), Vector3.ONE, _glow_mat)
		_glows.append(g)
	# Tail fins
	for side in [-1.0, 1.0]:
		var fin := BoxMesh.new()
		fin.size = Vector3(0.6, 6.0, 8.0)
		_part(fin, Vector3(side * 3.0, 4.2, 16), Vector3(0.3, 0, side * 0.3), Vector3.ONE, hull)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.2, 0.6, 30.0)
	for side in [-1.0, 1.0]:
		_part(stripe, Vector3(side * 6.7, 0.4, -2), Vector3.ZERO, Vector3.ONE, trim)
	var name_label := Label3D.new()
	name_label.text = "WAVERIDER"
	name_label.font_size = 160
	name_label.pixel_size = 0.02
	name_label.modulate = Color("#e8f4ff")
	name_label.outline_size = 16
	name_label.position = Vector3(6.85, 0.0, -2)
	name_label.rotation.y = PI * 0.5
	_visual.add_child(name_label)
	# Boarding ramp light at the stern
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#9fd8ff")
	lamp.light_energy = 1.5
	lamp.omni_range = 14.0
	lamp.position = Vector3(0, -2.5, 25)
	add_child(lamp)
	# Collision so people can stand on it and bullets hit it.
	body = StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(13, 5, 50)
	cs.shape = box
	body.add_child(cs)
	add_child(body)


func _mat(color: String, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = roughness
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 24
	return m


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 20
	return m


func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	return _cone(top, bottom, h)


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _part(mesh: Mesh, pos: Vector3, rot: Vector3, scl: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	_visual.add_child(mi)
	return mi


## Sets the ship down at a parking spot (the landing pad).
func park(at: Vector3) -> void:
	global_position = at
	yaw = 0.0
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func forward() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, yaw)


## Where people stand to board, or step off: the ground under the stern ramp.
func boarding_point() -> Vector3:
	var stern := global_position + Vector3(0, 0, 32).rotated(Vector3.UP, yaw)
	var from := Vector3(stern.x, global_position.y + 2.0, stern.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0, Game.LAYER_WORLD, [body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector3(stern.x, 0.5, stern.z)
	var p: Vector3 = hit["position"]
	return p + Vector3.UP * 0.5


func take_helm() -> void:
	var p: Actor = world.player
	piloted = true
	_saved_layer = p.collision_layer
	p.collision_layer = 0
	p.velocity = Vector3.ZERO
	p.flying = false
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_saved_zoom = world.cam.zoom
	world.cam.zoom = 30.0
	world.cam.zoom_max = 60.0
	world.cam.spring.add_excluded_object(body.get_rid())
	_carry_player()
	world.notify("You have the helm.  WASD fly · Space/Ctrl up/down · Shift boost · LMB cannons · Q time jump · G leave the helm", Color("#bfe8ff"))
	Sfx.play("teleport", global_position, 0.0)


func leave_helm() -> void:
	piloted = false
	velocity = Vector3.ZERO
	var p: Actor = world.player
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.visible = true
		p.collision_layer = _saved_layer
	world.cam.zoom = _saved_zoom
	world.cam.zoom_max = 18.0
	world.enter_interior("waverider", false)


func _carry_player() -> void:
	var p: Actor = world.player
	if p and is_instance_valid(p):
		p.global_position = global_position + Vector3.UP * 3.0
		p.invuln_t = 1.0


func _physics_process(delta: float) -> void:
	var thrust := 0.15
	if piloted:
		thrust = _fly(delta)
		_carry_player()
	else:
		_bob += delta
		_visual.position.y = sin(_bob * 1.3) * 0.25
	for g in _glows:
		g.scale = Vector3.ONE * (0.8 + thrust * 0.6)
	_glow_mat.emission_energy_multiplier = 1.5 + thrust * 3.0


func _fly(delta: float) -> float:
	var cam = world.cam
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd_in := -mv.y
	var boost := Input.is_action_pressed("sprint")
	var speed := BOOST if boost else CRUISE
	# The ship steers toward where the camera looks.
	var old_yaw := yaw
	yaw = lerp_angle(yaw, cam.yaw, clampf(delta * 1.6, 0.0, 1.0))
	var turn := wrapf(yaw - old_yaw, -PI, PI) / maxf(delta, 0.001)
	var fwd := forward()
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	var climb := clampf(cam.pitch + 0.25, -0.7, 0.7) * fwd_in * speed
	var up := 0.0
	if Input.is_action_pressed("jump"):
		up += 22.0
	if Input.is_action_pressed("descend"):
		up -= 22.0
	var desired := fwd * fwd_in * speed + right * mv.x * speed * 0.5 + Vector3.UP * (up + climb)
	velocity = velocity.lerp(desired, clampf(delta * 1.4, 0.0, 1.0))
	# Don't fly through buildings or the ground.
	var space := get_world_3d().direct_space_state
	var step := velocity * delta
	if step.length() > 0.001:
		var reach := step + step.normalized() * 14.0
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + reach, Game.LAYER_WORLD, [body.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			velocity = velocity.slide(n) * 0.6 + n * 4.0
			step = velocity * delta
	global_position += step
	global_position.y = clampf(global_position.y, 3.0, 900.0)
	var target_roll := clampf(-turn * 0.35 - mv.x * 0.25, -0.6, 0.6)
	var target_pitch := clampf(velocity.y / maxf(speed, 1.0), -0.4, 0.4)
	rotation = Vector3(lerpf(rotation.x, target_pitch, delta * 3.0), yaw, lerpf(rotation.z, target_roll, delta * 3.0))
	_cannon_t -= delta
	if Input.is_action_pressed("attack") and _cannon_t <= 0.0:
		_cannon_t = 0.22
		_fire_cannons()
	if Input.is_action_just_pressed("special"):
		world.travel_menu.open("time")
	return clampf(velocity.length() / BOOST, 0.0, 1.0)


func _fire_cannons() -> void:
	var cam_node: Camera3D = world.cam.camera
	var from := cam_node.global_position
	var dir := -cam_node.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 700.0, Game.LAYER_WORLD | Game.LAYER_ACTORS | Game.LAYER_PROPS, [body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit["position"] if not hit.is_empty() else from + dir * 700.0
	for side in [-1.0, 1.0]:
		var muzzle := global_position + (Vector3(side * 4.0, -1.5, -20.0)).rotated(Vector3.UP, yaw)
		FX.line(world, muzzle, target, Color("#ffb04a"), 0.35, 0.12)
	if not hit.is_empty():
		Abilities.explode(world, target, 5.0, 40.0, world.player, "fire", Color("#ffb04a"))
	Sfx.play("zap", global_position, -4.0, 0.2)
