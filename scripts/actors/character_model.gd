class_name CharacterModel
extends Node3D
## A stylised humanoid built from primitive meshes using a character's "look"
## (suit colours plus costume extras like capes, hoods and cowls), with a
## simple procedural animator for walking, running, flying and attacking.
## The model faces -Z.

static var _mat_cache: Dictionary = {}

var look: Dictionary = {}
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var body: Node3D
var head: Node3D
var cape: Node3D
var wings: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []

var _phase := 0.0
var _punch_t := 0.0
var _punch_side := 1.0
var _aim_t := 0.0
var _hit_t := 0.0
var _pitch := 0.0
var _override: Material = null
var _flash_mat: StandardMaterial3D

var hip_y := 0.95
var leg_len := 0.9
var arm_len := 0.66
var shoulder_y := 1.52
var head_y := 1.77


static func mat(color: Color, emission := 0.0, unshaded := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [color.to_html(), emission, unshaded, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.65
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


func build(look_def: Dictionary) -> void:
	look = look_def
	for c in get_children():
		c.queue_free()
	meshes.clear()
	wings.clear()
	var suit := Color(str(look.get("suit", "#444444")))
	var accent := Color(str(look.get("accent", "#222222")))
	var skin := Color(str(look.get("skin", "#c99a78")))
	var hair := Color(str(look.get("hair", "#3b2a1e")))
	var extras: Array = look.get("extras", [])
	var has := func(e: String) -> bool: return extras.has(e)
	var gorilla: bool = has.call("gorilla")
	var armored: bool = has.call("armor")

	if gorilla:
		hip_y = 0.75
		leg_len = 0.7
		arm_len = 0.95
		shoulder_y = 1.45
		head_y = 1.62
	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	# Legs
	leg_l = _pivot(body, Vector3(-0.12, hip_y, 0))
	leg_r = _pivot(body, Vector3(0.12, hip_y, 0))
	var boot_color := accent
	if has.call("boots_red"):
		boot_color = Color("#c81d25")
	var legs_color := Color(str(look.get("legs", look.get("suit", "#444444"))))
	for leg in [leg_l, leg_r]:
		_capsule(leg, 0.095, leg_len, Vector3(0, -leg_len * 0.5, 0), legs_color)
		_box(leg, Vector3(0.17, 0.2, 0.26), Vector3(0, -leg_len + 0.06, -0.03), boot_color)

	# Torso
	var torso_size := Vector3(0.48, 0.62, 0.27)
	if armored:
		torso_size = Vector3(0.56, 0.66, 0.33)
	if gorilla:
		torso_size = Vector3(0.8, 0.75, 0.6)
	var torso_y := hip_y + torso_size.y * 0.5 + 0.02
	_box(body, torso_size, Vector3(0, torso_y, 0), suit)
	_box(body, Vector3(torso_size.x + 0.02, 0.07, torso_size.z + 0.02), Vector3(0, hip_y + 0.05, 0), accent)
	var chest_z := -torso_size.z * 0.5 - 0.005
	var chest_y := torso_y + 0.12
	if has.call("emblem_s"):
		_box(body, Vector3(0.18, 0.15, 0.02), Vector3(0, chest_y, chest_z), Color("#f2c21b"))
		_box(body, Vector3(0.12, 0.09, 0.025), Vector3(0, chest_y, chest_z - 0.004), Color("#c81d25"))
	elif has.call("emblem_bolt"):
		_disc(body, 0.09, Vector3(0, chest_y, chest_z), Color("#f5f0e0") if suit.r > 0.5 else accent)
		_box(body, Vector3(0.03, 0.15, 0.03), Vector3(0, chest_y, chest_z - 0.01), Color("#f2c21b"), 0.6).rotation.z = 0.5
	elif has.call("emblem_bat"):
		_box(body, Vector3(0.3, 0.07, 0.02), Vector3(0, chest_y, chest_z), accent)
		_box(body, Vector3(0.1, 0.12, 0.02), Vector3(0, chest_y - 0.03, chest_z), accent)
	elif has.call("emblem_x"):
		var bar := _box(body, Vector3(0.05, 0.42, 0.02), Vector3(0.0, torso_y, chest_z), accent)
		bar.rotation.z = 0.6
		var bar2 := _box(body, Vector3(0.05, 0.42, 0.02), Vector3(0.0, torso_y, chest_z), accent)
		bar2.rotation.z = -0.6
	elif has.call("emblem_star"):
		_disc(body, 0.08, Vector3(0, chest_y, chest_z), Color("#f5f5f5"))
	elif has.call("emblem"):
		_disc(body, 0.08, Vector3(0, chest_y, chest_z), accent)
	if has.call("coat") or has.call("coat_short"):
		var coat_len := 0.95 if has.call("coat") else 0.45
		var coat_col := suit.darkened(0.25)
		_box(body, Vector3(torso_size.x + 0.06, coat_len, torso_size.z + 0.06),
			Vector3(0, hip_y + 0.4 - coat_len * 0.5 + 0.12, 0.0), coat_col)
	if armored:
		for side in [-1.0, 1.0]:
			_sphere(body, 0.13, Vector3(side * (torso_size.x * 0.5 + 0.02), shoulder_y + 0.04, 0), accent)
	if has.call("quiver"):
		var q := _box(body, Vector3(0.12, 0.5, 0.1), Vector3(0.1, torso_y + 0.05, torso_size.z * 0.5 + 0.06), Color("#3a2a1a"))
		q.rotation.z = -0.35
	if has.call("shield"):
		pass  # added to the arm below

	# Arms
	var shoulder_x := torso_size.x * 0.5 + 0.07
	arm_l = _pivot(body, Vector3(-shoulder_x, shoulder_y, 0))
	arm_r = _pivot(body, Vector3(shoulder_x, shoulder_y, 0))
	var arm_r_radius := 0.075 if not gorilla else 0.13
	for arm in [arm_l, arm_r]:
		_capsule(arm, arm_r_radius, arm_len, Vector3(0, -arm_len * 0.5, 0), suit)
		_sphere(arm, arm_r_radius + 0.01, Vector3(0, -arm_len, 0), accent if not gorilla else skin.darkened(0.2))
	if has.call("bow"):
		_box(arm_l, Vector3(0.03, 1.1, 0.04), Vector3(0, -arm_len, -0.06), Color("#2a1e14"))
	if has.call("sword"):
		_box(arm_r, Vector3(0.035, 0.05, 0.95), Vector3(0, -arm_len, -0.45), Color("#c8cdd2"), 0.2)
	if has.call("staff"):
		_box(arm_r, Vector3(0.035, 1.6, 0.035), Vector3(0, -arm_len, 0), Color("#d9c27a") if has.call("emblem_star") else Color("#3a2a1a"), 0.3 if has.call("emblem_star") else 0.0)
	if has.call("shield"):
		_disc(arm_l, 0.3, Vector3(-0.08, -arm_len * 0.6, 0), accent).rotation = Vector3(0, 0, PI * 0.5)

	# Head
	head = _pivot(body, Vector3(0, head_y, 0))
	if gorilla:
		head.position.z = -0.18
	var head_r := 0.14 if not gorilla else 0.2
	var cowl: bool = has.call("cowl")
	var head_color := suit if cowl else skin
	_sphere(head, head_r, Vector3.ZERO, head_color)
	_capsule(body, 0.06, 0.12, Vector3(0, head_y - 0.15, 0), skin if not cowl else suit)
	if cowl:
		_box(head, Vector3(0.17, 0.08, 0.07), Vector3(0, -0.07, -0.1), skin)
		if has.call("bolt_wings"):
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.02, 0.05, 0.12), Vector3(side * 0.14, 0.03, 0.0), Color("#f2c21b"), 0.4).rotation.x = -0.4
		if has.call("bat_ears"):
			for side in [-1.0, 1.0]:
				_cone(head, 0.035, 0.12, Vector3(side * 0.075, 0.15, 0.0), suit)
		if has.call("hair_long"):
			_box(head, Vector3(0.26, 0.42, 0.08), Vector3(0, -0.18, 0.12), hair)
	elif not has.call("bald") and not gorilla:
		var h := _sphere(head, head_r + 0.012, Vector3(0, 0.03, 0.025), hair)
		h.scale = Vector3(1.0, 0.85, 1.0)
		if has.call("hair_long"):
			_box(head, Vector3(0.27, 0.4, 0.08), Vector3(0, -0.15, 0.11), hair)
	if gorilla:
		_box(head, Vector3(0.22, 0.12, 0.12), Vector3(0, -0.07, -0.15), skin.darkened(0.3))
	# Face details
	var eye_z := -head_r + 0.01
	if has.call("mask_dark"):
		_box(head, Vector3(0.27, 0.055, 0.06), Vector3(0, 0.02, eye_z), Color("#101010"))
	if has.call("mask_star"):
		_box(head, Vector3(0.27, 0.055, 0.06), Vector3(0, 0.02, eye_z), Color("#e0c068"))
	if has.call("mask_t"):
		_box(head, Vector3(0.24, 0.05, 0.06), Vector3(0, 0.03, eye_z), Color("#101010"))
		_box(head, Vector3(0.05, 0.13, 0.06), Vector3(0, -0.03, eye_z), Color("#101010"))
	if has.call("mask_hockey"):
		_box(head, Vector3(0.24, 0.27, 0.06), Vector3(0, -0.01, eye_z + 0.005), Color("#ececec"))
		_box(head, Vector3(0.2, 0.04, 0.07), Vector3(0, 0.03, eye_z), Color("#101010"))
	if has.call("mask_deathstroke"):
		_sphere(head, head_r + 0.01, Vector3.ZERO, Color("#151515"))
		var half := _box(head, Vector3(0.13, 0.26, 0.04), Vector3(0.065, 0.0, eye_z - 0.005), accent)
		half.rotation.y = 0.0
		_box(head, Vector3(0.06, 0.03, 0.05), Vector3(0.06, 0.03, eye_z - 0.02), Color("#000000"))
	if has.call("mask_reign"):
		_box(head, Vector3(0.27, 0.11, 0.06), Vector3(0, 0.02, eye_z), Color("#101010"))
	if has.call("mask_bandana"):
		_box(head, Vector3(0.27, 0.1, 0.06), Vector3(0, -0.06, eye_z + 0.005), accent if accent.r > 0.3 else Color("#2a2a2a"))
	if has.call("cap"):
		var crown := _sphere(head, head_r + 0.015, Vector3(0, 0.05, 0), suit)
		crown.scale = Vector3(1.0, 0.7, 1.0)
		_box(head, Vector3(0.22, 0.02, 0.12), Vector3(0, 0.06, -0.16), Color("#0e0e0e"))
	if has.call("goggles"):
		_box(head, Vector3(0.28, 0.065, 0.06), Vector3(0, 0.03, eye_z), Color("#2a2a2a"))
		for side in [-1.0, 1.0]:
			_disc(head, 0.035, Vector3(side * 0.055, 0.03, eye_z - 0.035), Color("#ff9a2a"), 0.5)
	if has.call("glow_eyes") or has.call("glow_eyes_red"):
		var ec := Color("#ff2a2a") if has.call("glow_eyes_red") else Color(str(look.get("trail", look.get("accent", "#bfe8ff"))))
		for side in [-1.0, 1.0]:
			_box(head, Vector3(0.05, 0.022, 0.03), Vector3(side * 0.05, 0.025, eye_z - 0.02), ec, 3.0)
	if has.call("hood"):
		var hood := _sphere(head, head_r + 0.05, Vector3(0, 0.03, 0.06), suit.darkened(0.1))
		hood.scale = Vector3(1.05, 1.1, 1.0)
		_box(body, Vector3(0.36, 0.2, 0.2), Vector3(0, shoulder_y + 0.04, 0.08), suit.darkened(0.1))
	if has.call("helmet"):
		_sphere(head, head_r + 0.025, Vector3(0, 0.01, 0), accent.lightened(0.15))
		_box(head, Vector3(0.24, 0.07, 0.06), Vector3(0, 0.02, eye_z - 0.02), Color("#0d1a26"), 0.5)
	if has.call("helmet_savitar"):
		var hm := _sphere(head, head_r + 0.04, Vector3(0, 0.02, 0), suit.darkened(0.15))
		hm.scale = Vector3(1.0, 1.25, 1.1)
		_cone(head, 0.04, 0.2, Vector3(0, 0.24, 0), suit)
	if has.call("helmet_hawk"):
		var hm2 := _sphere(head, head_r + 0.02, Vector3(0, 0.03, 0), accent)
		hm2.scale = Vector3(1.0, 0.8, 1.15)
		_cone(head, 0.03, 0.16, Vector3(0, 0.0, -0.16), accent).rotation.x = -PI * 0.5
	if has.call("winged_helmet"):
		var brim := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.17
		cyl.height = 0.1
		cyl.material = mat(Color("#b8b8b8"))
		brim.mesh = cyl
		brim.position = Vector3(0, 0.09, 0)
		head.add_child(brim)
		meshes.append(brim)
		for side in [-1.0, 1.0]:
			_box(head, Vector3(0.015, 0.06, 0.13), Vector3(side * 0.14, 0.11, 0.02), Color("#c9a227"), 0.3).rotation.x = -0.5
	if has.call("flame_head"):
		var f := _sphere(head, head_r + 0.06, Vector3(0, 0.12, 0.02), Color("#ff8a1e"), 4.0, true, 0.85)
		f.scale = Vector3(1.0, 1.5, 1.0)
	if has.call("glow_head"):
		_sphere(head, head_r + 0.03, Vector3(0, 0.02, 0), Color("#9a7aff"), 1.5, true, 0.35)

	# Back
	if has.call("cape"):
		var cape_color := Color("#c81d25")
		if has.call("emblem_bat"):
			cape_color = suit
		elif has.call("mask_reign"):
			cape_color = Color("#151515")
		elif has.call("emblem_x"):
			cape_color = Color("#1b2f73")
		cape = _pivot(body, Vector3(0, shoulder_y + 0.03, torso_size.z * 0.5 + 0.03))
		_box(cape, Vector3(torso_size.x + 0.06, 1.0, 0.03), Vector3(0, -0.5, 0), cape_color)
	if has.call("wings"):
		for side in [-1.0, 1.0]:
			var w := _pivot(body, Vector3(side * 0.12, shoulder_y - 0.05, torso_size.z * 0.5 + 0.05))
			var feather := _box(w, Vector3(0.9, 0.5, 0.03), Vector3(side * 0.45, -0.1, 0), Color("#8a6a3a"))
			feather.rotation.z = side * -0.15
			wings.append(w)

	scale = Vector3.ONE * float(look.get("scale", 1.0))
	_flash_mat = mat(Color(1.0, 0.45, 0.4), 0.6)
	var pivots: Array[Node3D] = [body, head, arm_l, arm_r, leg_l, leg_r]
	if cape:
		pivots.append(cape)
	pivots.append_array(wings)
	for pivot in pivots:
		var merged := merge_children(pivot)
		if merged:
			meshes = meshes.filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
			meshes.append(merged)


static var _vertex_color_mat: StandardMaterial3D


## Merges a node's plain (opaque, unlit-free) primitive mesh children into one
## vertex-coloured mesh, cutting a character from ~25 draw calls to ~7.
## Returns the merged MeshInstance3D, or null when there was nothing to merge.
static func merge_children(parent: Node3D, metallic := 0.0) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var merged: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if not (child is MeshInstance3D) or child.is_queued_for_deletion():
			continue
		var pm := child.mesh as PrimitiveMesh
		if pm == null:
			continue
		var m := pm.material as StandardMaterial3D
		if m == null or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			continue
		var arrays := pm.get_mesh_arrays()
		var xf: Transform3D = child.transform
		var nb := xf.basis.inverse().transposed()
		var base := verts.size()
		var c := m.albedo_color
		for v in arrays[Mesh.ARRAY_VERTEX]:
			verts.append(xf * v)
			colors.append(c)
		for n in arrays[Mesh.ARRAY_NORMAL]:
			normals.append((nb * n).normalized())
		for i in arrays[Mesh.ARRAY_INDEX]:
			indices.append(base + i)
		merged.append(child)
	if merged.size() < 2:
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if metallic > 0.0:
		var vm := StandardMaterial3D.new()
		vm.vertex_color_use_as_albedo = true
		vm.vertex_color_is_srgb = true
		vm.metallic = metallic
		vm.roughness = 0.35
		mesh.surface_set_material(0, vm)
	else:
		if _vertex_color_mat == null:
			_vertex_color_mat = StandardMaterial3D.new()
			_vertex_color_mat.vertex_color_use_as_albedo = true
			_vertex_color_mat.vertex_color_is_srgb = true
			_vertex_color_mat.roughness = 0.65
		mesh.surface_set_material(0, _vertex_color_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	for child in merged:
		child.queue_free()
	return mi


# --- Animation --------------------------------------------------------------

func punch() -> void:
	_punch_t = 0.18
	_punch_side = -_punch_side


func aim() -> void:
	_aim_t = 0.5


func flash_hit() -> void:
	_hit_t = 0.08


## Overrides every surface with one material (used for freeze, invisibility,
## steel skin and so on). Pass null to restore the costume.
func set_override(m: Material) -> void:
	if m == _override:
		return
	_override = m
	_apply_override(m)


func _apply_override(m: Material) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_override = m


func animate(delta: float, hspeed: float, grounded: bool, flying: bool, vspeed: float, dead: bool) -> void:
	if _hit_t > 0.0:
		_hit_t -= delta
		_apply_override(_flash_mat if _hit_t > 0.0 else _override)
	var k := clampf(delta * 12.0, 0.0, 1.0)
	if dead:
		_pitch = lerpf(_pitch, -PI * 0.5, k * 0.5)
		body.rotation.x = _pitch
		body.position.y = lerpf(body.position.y, 0.15, k * 0.5)
		return
	body.position.y = lerpf(body.position.y, 0.0, k)
	var target_pitch := 0.0
	var leg_a := 0.0
	var leg_b := 0.0
	var arm_a := 0.0
	var arm_b := 0.0
	if flying:
		var t := clampf(hspeed / 30.0, 0.0, 1.0)
		target_pitch = -t * 1.25
		arm_a = lerpf(0.3, 2.9, t)
		arm_b = lerpf(-0.2, 0.25, t)
		leg_a = 0.1 + sin(Time.get_ticks_msec() * 0.003) * 0.08
		leg_b = 0.25
		if t < 0.2:
			arm_a = 0.3
			arm_b = 0.3
	elif not grounded:
		leg_a = -0.7
		leg_b = 0.3
		arm_a = -0.6 if vspeed > 0 else 0.4
		arm_b = arm_a
	else:
		var amp := clampf(hspeed / 7.0, 0.0, 1.0) * 0.85
		var rate := minf(hspeed, 14.0) * 1.5 + (hspeed - 14.0) * 0.15 if hspeed > 14.0 else hspeed * 1.5
		_phase += delta * rate
		var s := sin(_phase)
		leg_a = s * amp
		leg_b = -s * amp
		arm_a = -s * amp * 0.9
		arm_b = s * amp * 0.9
		if hspeed > 14.0:
			target_pitch = -0.45
			leg_a *= 1.3
			leg_b *= 1.3
			arm_a = -s * 1.1 - 0.4
			arm_b = s * 1.1 - 0.4
	if _aim_t > 0.0:
		_aim_t -= delta
		arm_a = PI * 0.5
		arm_b = PI * 0.4
	if _punch_t > 0.0:
		_punch_t -= delta
		if _punch_side > 0:
			arm_b = PI * 0.5
		else:
			arm_a = PI * 0.5
	_pitch = lerpf(_pitch, target_pitch, k * 0.6)
	body.rotation.x = _pitch
	leg_l.rotation.x = lerpf(leg_l.rotation.x, leg_a, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, leg_b, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, arm_a, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_b, k)
	if cape:
		var sway := clampf(hspeed / 25.0, 0.0, 1.0)
		var flutter := sin(Time.get_ticks_msec() * 0.012) * 0.08 * sway
		cape.rotation.x = lerpf(cape.rotation.x, -(0.08 + sway * 1.2) - flutter, k * 0.5)
	for i in wings.size():
		var side := -1.0 if i == 0 else 1.0
		var flap := 0.0
		if flying:
			flap = sin(Time.get_ticks_msec() * 0.008) * 0.35
		wings[i].rotation.z = side * (0.15 + flap)


# --- Mesh helpers -----------------------------------------------------------

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _add(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	meshes.append(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat(color, emission)
	return _add(parent, m, pos)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0, unshaded := false, alpha := 1.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	m.material = mat(color, emission, unshaded, alpha)
	return _add(parent, m, pos)


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	m.material = mat(color)
	return _add(parent, m, pos)


func _disc(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.02
	m.radial_segments = 16
	m.material = mat(color, emission)
	var mi := _add(parent, m, pos)
	mi.rotation.x = PI * 0.5
	return mi


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	m.material = mat(color)
	return _add(parent, m, pos)
