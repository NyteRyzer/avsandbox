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
# Autopilot: Gideon flies the ship to a city while you're aboard.
var course := Vector3.INF
var course_yaw := 0.0
var course_name := ""
signal course_done(name: String)
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
	_glow_mat = _mat("#6ad0ff", 0.0, 0.2)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color("#6ad0ff")
	_glow_mat.emission_energy_multiplier = 2.0
	_build_hull()
	var name_label := Label3D.new()
	name_label.text = "WAVERIDER"
	name_label.font_size = 160
	name_label.pixel_size = 0.02
	name_label.modulate = Color("#e8f4ff")
	name_label.outline_size = 16
	name_label.position = Vector3(5.75, 1.9, -2)
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
	box.size = Vector3(11, 7, 58)
	cs.shape = box
	body.add_child(cs)
	add_child(body)


## The ship as the show has it: a long, tapering silver fuselage with a raised
## bridge (its windows glowing), broad swept wings, two huge engines at the
## stern burning blue-white, canted tail fins, dark panelling and gold trim.
## Built from smooth lofts with the brushed-metal surface detail.
func _build_hull() -> void:
	var mb := MeshBuilder.new()
	# Painted hull plating (not mirror-bright metal), as on the show.
	var silver := Color("#9ea4ab")
	var panel := Color("#5c636c")
	var dark := Color("#2c3138")
	var gold := Color("#c9a24e")
	# Loft y runs from the stern (-) to the nose (+); turned so +y points -Z.
	var along := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	var hull_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		# Panel bands along the hull, a dark belly, a gold line down each side.
		if absf(absf(theta) - PI * 0.5) < 0.05:
			return gold
		if absf(theta) < 0.9:
			return dark
		if int(floor(t * 14.0)) % 3 == 0 and absf(theta) > 2.2:
			return panel
		return silver
	mb.loft([
		{"y": -27.0, "rx": 2.4, "rz": 2.2, "cz": 0.6},
		{"y": -24.0, "rx": 4.2, "rz": 3.2, "cz": 0.5},
		{"y": -14.0, "rx": 5.2, "rz": 3.9, "cz": 0.4},
		{"y": -2.0, "rx": 5.0, "rz": 3.7, "cz": 0.4},
		{"y": 10.0, "rx": 4.2, "rz": 3.1, "cz": 0.2},
		{"y": 19.0, "rx": 3.0, "rz": 2.3, "cz": -0.1},
		{"y": 25.0, "rx": 1.8, "rz": 1.5, "cz": -0.3},
		{"y": 29.0, "rx": 0.6, "rz": 0.6, "cz": -0.4},
		{"y": 30.5, "rx": 0.05, "rz": 0.05, "cz": -0.4},
	], along, hull_col, 28, true, false, 1.0, [], 2)
	# The raised bridge section along the spine, with its long window band.
	var hump_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		if t > 0.62 and t < 0.93 and absf(theta) > 2.1:
			return MeshBuilder.tagged(Color("#1c3550"), "wet")
		return silver if absf(theta) > 1.6 else panel
	mb.loft([
		{"y": -18.0, "rx": 1.0, "rz": 0.6, "cz": 3.0},
		{"y": -14.0, "rx": 2.9, "rz": 1.6, "cz": 3.2},
		{"y": 4.0, "rx": 3.2, "rz": 1.9, "cz": 3.0},
		{"y": 13.0, "rx": 2.6, "rz": 1.6, "cz": 2.5},
		{"y": 19.0, "rx": 1.6, "rz": 1.0, "cz": 1.9},
		{"y": 21.5, "rx": 0.2, "rz": 0.2, "cz": 1.5},
	], along, hump_col, 24, true, true, 1.0, [], 2)
	for side in [-1.0, 1.0]:
		# Broad wings swept back from mid-ship, with gold leading edges.
		# (Outline y becomes +Z, aft: the tips sweep back behind the roots.)
		var wing := PackedVector2Array([Vector2(side * 4.4, -6.0), Vector2(side * 17.5, 9.0), Vector2(side * 19.0, 14.5),
			Vector2(side * 15.0, 15.5), Vector2(side * 4.4, 10.0)])
		if side < 0.0:
			wing.reverse()
		var flat := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.8, 0)) * Transform3D(Basis(Vector3.FORWARD, side * 0.05), Vector3.ZERO)
		mb.prism(wing, 0.7, flat, silver)
		mb.tube(Vector3(side * 4.4, -0.75, -6.0), Vector3(side * 17.5, -0.75, 9.0), 0.36, 0.2, Transform3D(), gold, 8)
		mb.box(Vector3(side * 16.0, -0.75, 13.0), Vector3(3.0, 0.75, 4.0), Transform3D(), panel)
		# The two big engines at the stern.
		var ex: float = side * 6.8
		mb.loft([
			{"y": -29.0, "rx": 2.3, "rz": 2.3, "cx": ex, "cz": 0.2},
			{"y": -27.0, "rx": 2.6, "rz": 2.6, "cx": ex, "cz": 0.2},
			{"y": -14.0, "rx": 2.4, "rz": 2.4, "cx": ex, "cz": 0.2},
			{"y": -6.0, "rx": 1.6, "rz": 1.6, "cx": ex * 0.9, "cz": 0.2},
			{"y": -2.0, "rx": 0.4, "rz": 0.4, "cx": ex * 0.85, "cz": 0.2},
		], along, func(t: float, theta: float, _r: Dictionary) -> Color:
			return gold if t > 0.04 and t < 0.1 else (dark if absf(theta) < 1.0 else silver), 22, false, true)
		# Engine pylons joining them to the hull.
		mb.box(Vector3(side * 4.8, 0.2, 18.0), Vector3(3.4, 1.0, 10.0), Transform3D(), panel)
		# Canted tail fins.
		var fin := PackedVector2Array([Vector2(0, 0), Vector2(0, 5.5), Vector2(-3.5, 7.0), Vector2(-7.5, 0)])
		var fin_xf := Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.FORWARD, side * 0.35), Vector3(side * 2.2, 2.6, 18.5))
		mb.prism(fin, 0.4, fin_xf, silver)
	# Running lights and the boarding hatch at the stern.
	mb.box(Vector3(0, -2.6, 24.0), Vector3(3.6, 0.3, 4.0), Transform3D(), dark)
	mb.make_instance(_visual, "gloss", true)
	var lights := MeshBuilder.new()
	for side in [-1.0, 1.0]:
		lights.ellipsoid(Vector3(side * 18.6, -0.75, 14.5), Vector3(0.25, 0.25, 0.25), Transform3D(), Color("#ff4a3a") if side < 0 else Color("#4aff7a"), 8, 4)
		lights.box(Vector3(side * 3.3, 3.3, -6.0), Vector3(0.12, 0.25, 20.0), Transform3D(), Color("#ffb04a"))
	lights.make_instance(_visual, "glow")
	# Exhaust: discs that swell with thrust.
	for side in [-1.0, 1.0]:
		var g := _part(_cylinder(2.1, 2.1, 0.3), Vector3(side * 6.8, 0.2, 29.2), Vector3(PI * 0.5, 0, 0), Vector3.ONE, _glow_mat)
		_glows.append(g)
		var halo := _part(_cylinder(2.7, 2.7, 0.1), Vector3(side * 6.8, 0.2, 29.5), Vector3(PI * 0.5, 0, 0), Vector3.ONE, FX.glow_mat(Color("#9ad8ff"), 0.35))
		_glows.append(halo)


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


## Gideon takes the ship to `target`: climb above the skyline, cruise, then
## settle into a hover there, facing `face_yaw`.
func set_course(target: Vector3, face_yaw: float, name: String) -> void:
	course = target
	course_yaw = face_yaw
	course_name = name


func _autopilot(delta: float) -> float:
	var to := course - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var want_y := course.y if dist < 160.0 else maxf(course.y, 280.0)
	var speed := clampf(dist * 0.9, 6.0, 190.0)
	var v := flat.normalized() * minf(speed, dist / maxf(delta, 0.001)) if dist > 0.5 else Vector3.ZERO
	# Don't race ahead of the climb: the skyline is tall in places.
	if global_position.y < want_y - 40.0 and dist > 160.0:
		v *= 0.25
	v.y = clampf((want_y - global_position.y) * 1.2, -45.0, 60.0)
	global_position += v * delta
	var face := atan2(-flat.x, -flat.z) if dist > 60.0 else course_yaw
	yaw = lerp_angle(yaw, face, clampf(delta * 1.2, 0.0, 1.0))
	rotation = Vector3(0, yaw, 0)
	if dist < 1.0 and absf(to.y) < 1.0:
		global_position = course
		course = Vector3.INF
		course_done.emit(course_name)
	return clampf(speed / 190.0, 0.2, 1.0)


## Sets the ship down at a parking spot (the landing pad).
func park(at: Vector3) -> void:
	course = Vector3.INF
	global_position = at
	yaw = 0.0
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func forward() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, yaw)


## Is `p` within `reach` metres of the hull (anywhere along it, parked or
## hovering overhead)?
func near(p: Vector3, reach: float) -> bool:
	if piloted:
		return false
	var a := global_position + forward() * 30.0
	var b := global_position - forward() * 30.0
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * t
	var flat := Vector2(p.x - closest.x, p.z - closest.z).length()
	return flat < reach and absf(p.y - closest.y) < 45.0


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
	world.cam.zoom = 42.0
	world.cam.zoom_max = 60.0
	world.cam.spring.add_excluded_object(body.get_rid())
	_carry_player()
	world.notify("You have the helm.  W/S thrust · A/D turn · mouse steer · Space/Ctrl up/down · Shift boost · LMB cannons · Q time jump · G walk to the bridge · U bail out", Color("#bfe8ff"))
	Sfx.play("teleport", global_position, 0.0)


func leave_helm() -> void:
	_release_pilot()
	world.enter_interior("waverider", false)
	# Stand up from the helm on the bridge, not back in the cargo bay.
	world._move_player(Interiors.to_world("waverider", Vector3(0, 0.6, -24.5)))


## Jump out of the ship where it hovers (fliers keep flying); it waits there.
func bail_out() -> void:
	_release_pilot()
	var p: Actor = world.player
	if p == null or not is_instance_valid(p):
		return
	var below := global_position + Vector3(0, -6.0, 0) - forward() * 2.0
	world._move_player(below)
	p.velocity = velocity * 0.5
	if p.movement == "flight":
		p.flying = true
	world.notify("You drop out of the Waverider. [U] calls it back.", Color("#bfe8ff"))
	FX.flash(world, p.chest(), Color("#bfe8ff"), 1.5, 0.3, 0.5)


func _release_pilot() -> void:
	piloted = false
	velocity = Vector3.ZERO
	var p: Actor = world.player
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.visible = true
		p.collision_layer = _saved_layer
	world.cam.zoom = _saved_zoom
	world.cam.zoom_max = 18.0


func _carry_player() -> void:
	var p: Actor = world.player
	if p and is_instance_valid(p):
		p.global_position = global_position + Vector3.UP * 7.0
		p.invuln_t = 1.0


func _physics_process(delta: float) -> void:
	var thrust := 0.15
	if piloted:
		course = Vector3.INF
		thrust = _fly(delta)
		_carry_player()
	elif course != Vector3.INF:
		thrust = _autopilot(delta)
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
	# A/D bank and turn the ship (the camera swings round with it).
	cam.yaw -= mv.x * 1.3 * delta
	var desired := fwd * fwd_in * speed + right * mv.x * speed * 0.12 + Vector3.UP * (up + climb)
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
