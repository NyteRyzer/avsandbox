class_name BreachPortal
extends Node3D
## A breach you can see and walk through: it tears open in front of you
## (swirling vortex, crackling rings, sparks and the name of the Earth on the
## other side), waits, and sends you across when you step into it. On the
## far side an exit breach spits you out and seals behind you.

signal entered

const SHADER := preload("res://shaders/breach_portal.gdshader")
const OPEN_TIME := 0.9
const LIFETIME := 25.0
const RADIUS := 1.5

var world
var dest_id := ""
var exit_only := false
var color := Color("#4fa8ff")
var state := "opening"
var t := 0.0
var _face: MeshInstance3D
var _face_mat: ShaderMaterial
var _rings: Array[MeshInstance3D] = []
var _motes: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _label: Label3D


func setup(w, id: String, c: Color, label := "", exit := false) -> BreachPortal:
	world = w
	dest_id = id
	color = c
	exit_only = exit
	_build(label)
	return self


func _build(label: String) -> void:
	_face_mat = ShaderMaterial.new()
	_face_mat.shader = SHADER
	_face_mat.set_shader_parameter("tint", color)
	_face_mat.set_shader_parameter("open", 0.0)
	_face = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.6, RADIUS * 3.0) * 1.3
	_face.mesh = quad
	_face.material_override = _face_mat
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_face)
	# Counter-rotating rings of energy around the rim.
	for i in 3:
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS * (0.98 + i * 0.07)
		torus.outer_radius = torus.inner_radius + 0.05 - i * 0.012
		torus.rings = 40
		torus.ring_segments = 5
		mi.mesh = torus
		mi.material_override = FX.glow_mat(color.lightened(0.15 + i * 0.15), 0.8 - i * 0.2)
		mi.rotation.x = PI * 0.5
		mi.scale = Vector3(1.0, 1.0, 1.2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rings.append(mi)
	# Motes of light spiralling into the eye.
	for i in 14:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = FX.glow_mat(color.lightened(0.5), 0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_motes.append(mi)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, 0, 0.6)
	add_child(_light)
	if label != "":
		_label = Label3D.new()
		_label.text = label.to_upper()
		_label.font_size = 48
		_label.pixel_size = 0.005
		_label.outline_size = 12
		_label.modulate = color.lightened(0.55)
		_label.outline_modulate = Color(0, 0, 0, 0.8)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.position = Vector3(0, RADIUS * 1.3 + 0.35, 0)
		_label.no_depth_test = true
		_label.modulate.a = 0.0
		add_child(_label)
	scale = Vector3.ONE * 0.05


func _process(delta: float) -> void:
	t += delta
	var open := 1.0
	match state:
		"opening":
			var k := clampf(t / OPEN_TIME, 0.0, 1.0)
			# Overshoot as it tears open, then settle.
			open = 1.0 + sin(k * PI) * 0.12 * (1.0 - k) if k < 1.0 else 1.0
			scale = Vector3.ONE * lerpf(0.05, 1.0, 1.0 - pow(1.0 - k, 3.0))
			if k >= 1.0:
				state = "open"
				t = 0.0
		"open":
			scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.015)
			if t > (2.2 if exit_only else LIFETIME):
				close()
			elif not exit_only:
				_check_enter()
		"closing":
			var k := clampf(t / 0.5, 0.0, 1.0)
			scale = Vector3.ONE * lerpf(1.0, 0.02, k * k)
			open = 1.0 - k * 0.5
			if k >= 1.0:
				queue_free()
				return
	_face_mat.set_shader_parameter("open", open)
	for i in _rings.size():
		_rings[i].rotation.y += delta * (2.4 if i % 2 == 0 else -3.1) * (1.0 + i * 0.3)
	for i in _motes.size():
		var ph := fposmod(t * 0.45 + i / float(_motes.size()), 1.0)
		var ang := i * 2.4 + t * 2.0 + ph * 5.0
		var r := RADIUS * 1.15 * (1.0 - ph)
		_motes[i].position = Vector3(cos(ang) * r, sin(ang) * r * 1.15, 0.05)
	_light.light_energy = (2.2 + sin(t * 9.0) * 0.4) * scale.x
	if _label:
		_label.modulate.a = clampf(scale.x * 1.4 - 0.3, 0.0, 1.0) if state != "closing" else 0.0
	if randf() < delta * 6.0 and world:
		var ang := randf() * TAU
		var local := Vector3(cos(ang) * RADIUS, sin(ang) * RADIUS * 1.15, 0) * scale.x
		FX.sparks(world, global_transform * local, color.lightened(0.4), 4, 3.0, 0.3)


## The player walks into the breach's face: close enough to its centre and
## within a stride of its plane.
func _check_enter() -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var local: Vector3 = global_transform.affine_inverse() * world.player.chest()
	if absf(local.z) < 0.7 and Vector2(local.x, local.y / 1.15).length() < RADIUS * 0.9:
		state = "closing"
		t = 0.0
		entered.emit()


func close() -> void:
	if state == "closing":
		return
	state = "closing"
	t = 0.0
	Sfx.play("teleport", global_position, -8.0, 0.3)
