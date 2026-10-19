class_name Helicopter
extends Node3D
## A news (or police) helicopter that circles overhead when things get loud:
## high heat, a boss fight or an event nearby. At night its searchlight
## follows you.

var world
var active := false
var _angle := 0.0
var _rotor: Node3D
var _light: SpotLight3D
var _calm := 0.0


func _ready() -> void:
	var body_mat := CharacterModel.mat(Color("#e8e8ec"))
	var stripe := CharacterModel.mat(Color("#2a5aaa"))
	var dark := CharacterModel.mat(Color("#1a1e24"))
	_part(_capsule(1.2, 4.4), Vector3.ZERO, Vector3(PI * 0.5, 0, 0), body_mat)
	_part(_box(Vector3(0.4, 0.4, 5.0)), Vector3(0, 0.3, 4.2), Vector3.ZERO, body_mat)
	_part(_box(Vector3(0.1, 1.4, 1.0)), Vector3(0, 0.9, 6.5), Vector3.ZERO, stripe)
	_part(_box(Vector3(2.5, 0.12, 0.2)), Vector3(0, -1.3, -0.6), Vector3.ZERO, dark)
	_part(_box(Vector3(2.5, 0.12, 0.2)), Vector3(0, -1.3, 0.8), Vector3.ZERO, dark)
	_part(_box(Vector3(0.1, 0.1, 2.6)), Vector3(1.1, -1.4, 0.1), Vector3.ZERO, dark)
	_part(_box(Vector3(0.1, 0.1, 2.6)), Vector3(-1.1, -1.4, 0.1), Vector3.ZERO, dark)
	_part(_box(Vector3(2.4, 0.3, 0.05)), Vector3(0, 0.1, -2.02), Vector3.ZERO, CharacterModel.mat(Color("#1a3a5a"), 0.3))
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.5, 0)
	add_child(_rotor)
	for k in 2:
		var blade := MeshInstance3D.new()
		blade.mesh = _box(Vector3(11.0, 0.06, 0.4))
		blade.material_override = dark
		blade.rotation.y = k * PI * 0.5
		_rotor.add_child(blade)
	var label := Label3D.new()
	label.text = "NEWS 6"
	label.font_size = 64
	label.pixel_size = 0.02
	label.position = Vector3(1.25, 0, 0)
	label.rotation.y = PI * 0.5
	add_child(label)
	_light = SpotLight3D.new()
	_light.spot_range = 90.0
	_light.spot_angle = 9.0
	_light.light_energy = 6.0
	_light.position = Vector3(0, -1.4, -1.0)
	add_child(_light)
	visible = false


func _part(mesh: Mesh, pos: Vector3, rot: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _wanted() -> bool:
	if world.city.kind != "metro" or world.inside != "":
		return false
	if Game.heat >= 2.0:
		return true
	var ev: Dictionary = world.events.active
	if not ev.is_empty() and world.player.global_position.distance_to(ev["pos"]) < 120.0:
		return true
	return world.hud.boss_panel.visible


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var p: Vector3 = world.player.global_position
	if _wanted():
		_calm = 20.0
		if not active:
			active = true
			visible = true
			global_position = p + Vector3(150, 70, 150)
			world.news.report("NEWS 6 is live over the scene.")
	elif active:
		_calm -= delta
		if _calm <= 0.0:
			active = false
	if not visible:
		return
	_rotor.rotate_y(delta * 30.0)
	_angle += delta * 0.25
	var target := p + Vector3(cos(_angle) * 45.0, 48.0, sin(_angle) * 45.0)
	if not active:
		target = global_position + (global_position - p).normalized() * 60.0 + Vector3.UP * 10.0
		if global_position.distance_to(p) > 400.0:
			visible = false
	global_position = global_position.lerp(target, clampf(delta * 0.6, 0.0, 1.0))
	look_at(Vector3(p.x, global_position.y, p.z), Vector3.UP)
	rotation.x = 0.12
	_light.visible = world.day_night.is_night() and active
	if _light.visible:
		_light.look_at(p, Vector3.UP)
