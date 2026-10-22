class_name JumpShip
extends Node3D
## The Legends' Jump Ship: a little shuttle that lives in the Waverider's
## cargo bay. A Legend whistles it down (J); it swoops in and lands; board it
## (G) and it flies you up to the Waverider. From the cargo bay it can also
## fly you back down to the city.

signal arrived

var world
var state := "idle"            # arriving, landed, flying, leaving
var carrying := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _peak := 40.0
var _t := 0.0
var _dur := 4.0
var _done: Callable
var _saved_layer := 0
var _glows: Array[MeshInstance3D] = []
var _wait := 0.0


func setup(w) -> JumpShip:
	world = w
	_build()
	return self


func _build() -> void:
	var mb := MeshBuilder.new()
	var hull := Color("#a4abb2")
	var dark := Color("#30363e")
	var gold := Color("#c9a24e")
	var along := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	mb.loft([
		{"y": -3.6, "rx": 1.0, "rz": 0.9, "cz": 0.1},
		{"y": -3.2, "rx": 1.4, "rz": 1.2, "cz": 0.1},
		{"y": 0.0, "rx": 1.5, "rz": 1.3, "cz": 0.1},
		{"y": 2.2, "rx": 1.2, "rz": 1.0, "cz": 0.0},
		{"y": 3.6, "rx": 0.55, "rz": 0.5, "cz": -0.1},
		{"y": 4.2, "rx": 0.05, "rz": 0.05, "cz": -0.1},
	], along, func(t: float, theta: float, _r: Dictionary) -> Color:
		if t > 0.62 and t < 0.86 and absf(theta) > 2.0:
			return MeshBuilder.tagged(Color("#1c3550"), "wet")
		if absf(absf(theta) - PI * 0.5) < 0.07:
			return gold
		return dark if absf(theta) < 1.0 else hull, 18, true, false, 1.0, [], 2)
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 1.3, -1.0), Vector2(side * 4.2, 1.6), Vector2(side * 4.4, 2.6), Vector2(side * 1.3, 2.0)])
		if side < 0.0:
			wing.reverse()
		mb.prism(wing, 0.22, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.2, 0)), hull)
		mb.loft([{"y": -3.9, "rx": 0.45, "rz": 0.45, "cx": side * 1.15}, {"y": -1.5, "rx": 0.5, "rz": 0.5, "cx": side * 1.15},
			{"y": -0.6, "rx": 0.1, "rz": 0.1, "cx": side * 1.15}], along, dark, 10, true, true)
		# Landing struts.
		mb.tube(Vector3(side * 0.9, -0.9, 1.0), Vector3(side * 1.1, -1.6, 1.0), 0.07, 0.07, Transform3D(), dark, 6)
		mb.tube(Vector3(side * 0.9, -0.9, -2.0), Vector3(side * 1.1, -1.6, -2.0), 0.07, 0.07, Transform3D(), dark, 6)
	mb.make_instance(self, "gloss", true)
	for side in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.38
		cyl.bottom_radius = 0.38
		cyl.height = 0.1
		g.mesh = cyl
		g.material_override = FX.glow_mat(Color("#8ad8ff"), 0.9)
		g.rotation.x = PI * 0.5
		g.position = Vector3(side * 1.15, 0.0, 3.95)
		add_child(g)
		_glows.append(g)
	var light := OmniLight3D.new()
	light.light_color = Color("#8ad8ff")
	light.omni_range = 8.0
	light.light_energy = 1.2
	light.position = Vector3(0, 0, 4.4)
	add_child(light)
	var tag := Label3D.new()
	tag.text = "JUMP SHIP"
	tag.font_size = 48
	tag.pixel_size = 0.01
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("#d8e8ff")
	tag.outline_size = 8
	tag.position = Vector3(0, 2.2, 0)
	add_child(tag)


## Swoop in from the sky and set down at `at`.
func arrive(at: Vector3) -> void:
	var back := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 90.0
	_go(at + back + Vector3.UP * 70.0, at, 25.0, 4.0, func() -> void:
		state = "landed"
		FX.ring(world, at, Color("#bfe8ff"), 4.0, 0.4)
		arrived.emit())
	state = "arriving"


## Fly the player from here to `target`, then call `done` (with the player
## still hidden aboard; `release_player` lets them out).
func carry_player_to(target: Vector3, done: Callable) -> void:
	var p: Actor = world.player
	carrying = true
	_saved_layer = p.collision_layer
	p.collision_layer = 0
	p.velocity = Vector3.ZERO
	p.flying = false
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var dist := global_position.distance_to(target)
	_go(global_position, target, clampf(dist * 0.15, 30.0, 120.0), clampf(dist / 90.0, 3.5, 9.0), func() -> void:
		done.call())
	state = "flying"
	Sfx.play("whoosh", global_position, 2.0)


func release_player(at: Vector3) -> void:
	var p: Actor = world.player
	carrying = false
	if p and is_instance_valid(p):
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.visible = true
		p.collision_layer = _saved_layer
		world._move_player(at)


## Lift off and fly away, then vanish.
func leave() -> void:
	state = "leaving"
	_go(global_position, global_position + Vector3(0, 120, 0) - _heading() * 150.0, 20.0, 3.5, queue_free)


func _go(from: Vector3, to: Vector3, peak: float, dur: float, done: Callable) -> void:
	_from = from
	_to = to
	_peak = peak
	_dur = dur
	_t = 0.0
	_done = done
	global_position = from


func _heading() -> Vector3:
	return -global_basis.z


func _process(delta: float) -> void:
	if state in ["arriving", "flying", "leaving"]:
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var pos := _from.lerp(_to, e) + Vector3.UP * sin(k * PI) * _peak
		var step := pos - global_position
		if Vector2(step.x, step.z).length() > 0.05:
			var yaw := atan2(-step.x, -step.z)
			rotation = Vector3(clampf(step.y * 0.3, -0.4, 0.4), lerp_angle(rotation.y, yaw, clampf(delta * 4.0, 0.0, 1.0)), 0.0)
		global_position = pos
		if carrying and world.player and is_instance_valid(world.player):
			world.player.global_position = global_position + Vector3.UP * 1.0
			world.player.invuln_t = 1.0
		for g in _glows:
			g.scale = Vector3.ONE * (1.0 + sin(_t * 30.0) * 0.1)
		if k >= 1.0:
			var cb := _done
			_done = Callable()
			if state != "leaving":
				state = "landed"
			if cb.is_valid():
				cb.call()
	elif state == "landed":
		rotation.x = lerpf(rotation.x, 0.0, delta * 3.0)
