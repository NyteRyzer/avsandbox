class_name FX
extends RefCounted
## Short-lived visual effects built from primitive meshes and CPU particles,
## so they render the same on every platform and renderer.

static var _unit_box: BoxMesh
static var _unit_sphere: SphereMesh
static var _spark_mesh: SphereMesh


static func _root(world) -> Node3D:
	return world.fx_root


static func _box_mesh() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


static func _sphere_mesh() -> SphereMesh:
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 0.5
		_unit_sphere.height = 1.0
		_unit_sphere.radial_segments = 20
		_unit_sphere.rings = 10
	return _unit_sphere


static func glow_mat(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _free_after(node: Node, seconds: float) -> void:
	var t := node.create_tween()
	t.tween_interval(seconds)
	t.tween_callback(node.queue_free)


## Creates a reusable box mesh instance for beams, ropes and tracers.
static func make_line(world, color: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh()
	mi.material_override = CharacterModel.mat(color, 0.0, true, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	return mi


static func place_line(mi: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		mi.visible = false
		return
	mi.visible = true
	var dir := d / length
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up) * Basis.from_scale(Vector3(width, width, length))
	mi.global_transform = Transform3D(basis, (a + b) * 0.5)


static func line(world, a: Vector3, b: Vector3, color: Color, width: float, life: float) -> void:
	var mi := make_line(world, color)
	place_line(mi, a, b, width)
	_free_after(mi, life)


## A jagged bolt: a bright core, a soft glow sleeve and a few forks.
static func lightning(world, a: Vector3, b: Vector3, color: Color, life := 0.2, jitter := 0.6, segments := 6, forks := 1) -> void:
	var core := CharacterModel.mat(color.lightened(0.55), 0.0, true)
	var glow := CharacterModel.mat(color, 0.0, true, 0.35)
	var pts := [a]
	for i in range(1, segments):
		var t := float(i) / segments
		pts.append(a.lerp(b, t) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter)
	pts.append(b)
	var width := 0.045 if jitter < 1.0 else 0.07
	for i in pts.size() - 1:
		_bolt_segment(world, pts[i], pts[i + 1], core, width, life)
		_bolt_segment(world, pts[i], pts[i + 1], glow, width * 4.0, life * 0.8)
	for f in forks:
		if pts.size() < 3:
			break
		var from: Vector3 = pts[randi_range(1, pts.size() - 2)]
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 0.5), randf_range(-1, 1)).normalized() * a.distance_to(b) * 0.25
		var mid := from + off * 0.5 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter * 0.5
		_bolt_segment(world, from, mid, core, width * 0.6, life * 0.6)
		_bolt_segment(world, mid, from + off, core, width * 0.5, life * 0.5)


static func _bolt_segment(world, a: Vector3, b: Vector3, m: Material, width: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	place_line(mi, a, b, width)
	_free_after(mi, life * randf_range(0.6, 1.0))


static func sparks(world, pos: Vector3, color: Color, count := 12, speed := 6.0, life := 0.5) -> void:
	if _spark_mesh == null:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.06
		_spark_mesh.height = 0.12
		_spark_mesh.radial_segments = 6
		_spark_mesh.rings = 3
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.material_override = CharacterModel.mat(color, 0.0, true)
	p.amount = maxi(1, count)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_after(p, life + 0.3)


## A real light for a power effect, so it lights up the street and the
## people around it. Capped, so a big brawl doesn't drown in lights.
const MAX_FX_LIGHTS := 14


static func light(parent: Node3D, color: Color, light_range: float, energy: float, life := -1.0) -> OmniLight3D:
	if parent == null or not parent.is_inside_tree() or parent.get_tree().get_nodes_in_group("fx_lights").size() >= MAX_FX_LIGHTS:
		return null
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = light_range
	l.light_energy = energy
	l.shadow_enabled = false
	l.add_to_group("fx_lights")
	parent.add_child(l)
	if life > 0.0:
		var t := l.create_tween()
		t.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
		t.tween_callback(l.queue_free)
	return l


static func flash(world, pos: Vector3, color: Color, radius: float, life := 0.35, alpha := 0.7) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh()
	var m := glow_mat(color, alpha)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	mi.global_position = pos
	if radius >= 1.0:
		light(mi, color, radius * 4.0, 2.5, life)
	mi.scale = Vector3.ONE * radius * 0.3
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(m, "albedo_color:a", 0.0, life)
	t.chain().tween_callback(mi.queue_free)


static func ring(world, pos: Vector3, color: Color, radius: float, life := 0.4, normal := Vector3.UP) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	mi.mesh = torus
	var m := glow_mat(color, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	var up := normal.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	mi.global_transform = Transform3D(Basis(x, up, z), pos)
	var start := mi.global_transform.basis
	var tw := mi.create_tween().set_parallel(true)
	var grow := func(s: float) -> void:
		mi.global_transform.basis = start * Basis.from_scale(Vector3(s, 1.0, s))
	tw.tween_method(grow, 0.3, radius, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## A cone of rings flying forward, used for sonic attacks.
static func sonic_wave(world, origin: Vector3, dir: Vector3, color: Color, reach: float) -> void:
	for i in 4:
		var pos := origin + dir * (reach * (0.2 + 0.2 * i))
		var r := 1.0 + reach * 0.12 * (i + 1)
		var w: WeakRef = weakref(world)
		var later := func() -> void:
			var live = w.get_ref()
			if live:
				FX.ring(live, pos, color, r, 0.35, dir)
		world.get_tree().create_timer(0.04 * i).timeout.connect(later)


static func smoke(world, pos: Vector3, radius: float, life := 2.5) -> void:
	for i in 9:
		var off := Vector3(randf_range(-1, 1), randf_range(0, 0.8), randf_range(-1, 1)) * radius * 0.6
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.62, 0.62, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root(world).add_child(mi)
		mi.global_position = pos + off
		mi.scale = Vector3.ONE * radius * 0.2
		var t := mi.create_tween().set_parallel(true)
		t.tween_property(mi, "scale", Vector3.ONE * radius * randf_range(0.4, 0.65), life * 0.4).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "albedo_color:a", 0.0, life).set_delay(life * 0.3)
		t.chain().tween_callback(mi.queue_free)


static func damage_number(world, pos: Vector3, amount: float, on_player: bool, crit := false) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount))) + ("!" if crit else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 84 if crit else (64 if amount >= 20 else 48)
	l.pixel_size = 0.006
	l.outline_size = 12
	l.no_depth_test = true
	l.modulate = Color("#ff5050") if on_player else (Color("#ff8a2a") if crit else (Color("#ffd23a") if amount >= 20 else Color.WHITE))
	_root(world).add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "global_position", l.global_position + Vector3.UP * 1.2, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


static func portal(world, pos: Vector3, color: Color) -> void:
	ring(world, pos, color, 2.2, 0.5, Vector3.FORWARD)
	flash(world, pos, color, 1.5, 0.4, 0.5)
	sparks(world, pos, color, 20, 8.0)


## A spinning funnel that follows an actor while their tornado is active.
static func tornado(world, actor: Node3D, life: float, color: Color) -> void:
	var holder := Node3D.new()
	_root(world).add_child(holder)
	for i in 5:
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0
		mi.mesh = torus
		mi.material_override = glow_mat(color, 0.45)
		mi.position = Vector3(0, 0.5 + i * 1.6, 0)
		mi.scale = Vector3.ONE * (2.0 + i * 1.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	var target: WeakRef = weakref(actor)
	var spin := func(v: float) -> void:
		var followed = target.get_ref()
		if followed and is_instance_valid(holder):
			holder.global_position = followed.global_position
			holder.rotation.y = v * 40.0
			for c in holder.get_children():
				c.rotation.x = sin(v * 30.0 + c.position.y) * 0.15
	var t := holder.create_tween()
	t.tween_method(spin, 0.0, life, life)
	t.tween_callback(holder.queue_free)


# --- Particle emitters -------------------------------------------------------

static var _puff_mesh: SphereMesh
static var _puff_mat: StandardMaterial3D


static func _puff() -> SphereMesh:
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.5
		_puff_mesh.height = 1.0
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
		_puff_mat = StandardMaterial3D.new()
		_puff_mat.vertex_color_use_as_albedo = true
		_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _puff_mesh


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / maxf(1.0, colors.size() - 1), colors[i])
	g.remove_point(0)
	g.remove_point(0)
	return g


## A cone stream of particles (flamethrower, freeze breath, super breath,
## cold-gun mist) that the caller points along -Z and switches on and off.
static func stream_emitter(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _puff()
	p.material_override = _puff_mat
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0, -1)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.25))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	match kind:
		"flame":
			p.amount = 90
			p.lifetime = 0.45
			p.spread = 11.0
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 22.0
			p.gravity = Vector3(0, 3, 0)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.8
			p.color_ramp = _ramp([Color(1, 0.95, 0.6, 0.95), Color(1, 0.6, 0.15, 0.85), Color(0.9, 0.25, 0.05, 0.5), Color(0.2, 0.2, 0.2, 0.0)])
		"frost":
			p.amount = 80
			p.lifetime = 0.5
			p.spread = 9.0
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 20.0
			p.gravity = Vector3(0, -1, 0)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.6
			p.color_ramp = _ramp([Color(1, 1, 1, 0.9), Color(0.75, 0.92, 1, 0.7), Color(0.6, 0.85, 1, 0.0)])
		"wind":
			p.amount = 70
			p.lifetime = 0.45
			p.spread = 13.0
			p.initial_velocity_min = 22.0
			p.initial_velocity_max = 28.0
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.5
			p.color_ramp = _ramp([Color(1, 1, 1, 0.55), Color(0.85, 0.9, 1, 0.3), Color(1, 1, 1, 0.0)])
		"burn":
			p.amount = 20
			p.lifetime = 0.6
			p.local_coords = false
			p.direction = Vector3.UP
			p.spread = 25.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, 2, 0)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.35
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.35
			p.color_ramp = _ramp([Color(1, 0.9, 0.5, 0.9), Color(1, 0.45, 0.1, 0.7), Color(0.3, 0.3, 0.3, 0.0)])
		"ice_trail":
			p.amount = 40
			p.lifetime = 1.2
			p.direction = Vector3.UP
			p.spread = 60.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0, -1, 0)
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.3
			p.color_ramp = _ramp([Color(0.9, 0.97, 1, 0.9), Color(0.7, 0.9, 1, 0.0)])
	return p


# --- Shapes and auras --------------------------------------------------------

## A curved, fading ribbon tracing a weapon swing.
static func slash_arc(world, center: Vector3, basis: Basis, color: Color, radius: float, from_angle: float, to_angle: float, life := 0.18) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	for i in steps:
		var a0 := lerpf(from_angle, to_angle, float(i) / steps)
		var a1 := lerpf(from_angle, to_angle, float(i + 1) / steps)
		var fade0 := float(i) / steps
		var fade1 := float(i + 1) / steps
		var o0 := Vector3(sin(a0), 0, -cos(a0)) * radius
		var o1 := Vector3(sin(a1), 0, -cos(a1)) * radius
		var in0 := o0 * 0.55
		var in1 := o1 * 0.55
		var c0 := Color(color, 0.75 * fade0)
		var c1 := Color(color, 0.75 * fade1)
		for v in [[in0, c0], [o0, c0], [o1, c1], [in0, c0], [o1, c1], [in1, c1]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	mi.global_transform = Transform3D(basis, center)
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, life)
	t.tween_callback(mi.queue_free)


## Ice crystals encasing a frozen actor. Returns the node so the actor can
## remove it when it thaws.
static func ice_block(target: Node3D, size: float) -> Node3D:
	var holder := Node3D.new()
	var m := CharacterModel.mat(Color("#bfeaff"), 0.3, false, 0.55)
	for i in 9:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.18, 0.32) * size
		cm.height = randf_range(0.8, 1.6) * size
		cm.radial_segments = 5
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := randf() * TAU
		mi.position = Vector3(cos(ang) * 0.3, randf_range(0.3, 1.4), sin(ang) * 0.3) * size
		mi.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		holder.add_child(mi)
	target.add_child(holder)
	return holder


static func aura(target: Node3D, color: Color, size: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh()
	var m := glow_mat(color, 0.22)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.3, 2.2, 1.3) * size
	mi.position = Vector3(0, 1.0 * size, 0)
	target.add_child(mi)
	var t := mi.create_tween().set_loops(int(maxf(1.0, life / 0.6)))
	t.tween_property(m, "albedo_color:a", 0.08, 0.3)
	t.tween_property(m, "albedo_color:a", 0.25, 0.3)
	_free_after(mi, life)


static func bubble(target: Node3D, color: Color, size: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh()
	mi.material_override = glow_mat(color, 0.18)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 2.6 * size
	mi.position = Vector3(0, 1.0 * size, 0)
	target.add_child(mi)
	_free_after(mi, life)


static func stun_stars(target: Node3D, height: float, life: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, height, 0)
	target.add_child(holder)
	for i in 4:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		mi.mesh = sm
		mi.material_override = CharacterModel.mat(Color("#ffe060"), 0.0, true)
		mi.position = Vector3(cos(i * TAU / 4.0), 0, sin(i * TAU / 4.0)) * 0.28
		holder.add_child(mi)
	var t := holder.create_tween()
	t.tween_property(holder, "rotation:y", TAU * life * 1.5, life)
	t.tween_callback(holder.queue_free)


## A swirling multiverse breach: counter-rotating rings around a bright core.
static func breach(world, pos: Vector3, color: Color, life := 0.9, radius := 1.4) -> void:
	var holder := Node3D.new()
	_root(world).add_child(holder)
	holder.global_position = pos
	var cam: Camera3D = world.get_viewport().get_camera_3d()
	if cam:
		holder.look_at(cam.global_position, Vector3.UP)
	for i in 3:
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.55 + i * 0.18)
		torus.outer_radius = torus.inner_radius + 0.08
		torus.rings = 28
		torus.ring_segments = 5
		mi.mesh = torus
		mi.material_override = glow_mat(color.lightened(i * 0.15), 0.75)
		mi.rotation.x = PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	var core := MeshInstance3D.new()
	core.mesh = _sphere_mesh()
	core.material_override = glow_mat(Color(0.85, 0.95, 1.0), 0.6)
	core.scale = Vector3(radius, radius, 0.1)
	holder.add_child(core)
	holder.scale = Vector3.ONE * 0.1
	var t := holder.create_tween().set_parallel(true)
	t.tween_property(holder, "scale", Vector3.ONE, life * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 3:
		t.tween_property(holder.get_child(i), "rotation:y", (TAU if i % 2 == 0 else -TAU) * 1.5, life)
	t.chain().tween_property(holder, "scale", Vector3.ONE * 0.05, life * 0.2)
	t.tween_callback(holder.queue_free)


static func sonic_boom(world, pos: Vector3, dir: Vector3) -> void:
	ring(world, pos, Color(1, 1, 1), 5.0, 0.35, dir)
	ring(world, pos - dir * 1.5, Color(0.85, 0.92, 1.0), 3.5, 0.3, dir)
	Sfx.play("slam", pos, -2.0, 0.2)


static func storm_cloud(world, pos: Vector3, radius: float, life: float) -> void:
	var holder := Node3D.new()
	_root(world).add_child(holder)
	holder.global_position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.13, 0.16, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 10:
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := randf() * TAU
		mi.position = Vector3(cos(ang), 0, sin(ang)) * randf_range(0.0, radius * 0.7)
		mi.scale = Vector3(1.0, 0.45, 1.0) * randf_range(radius * 0.5, radius * 0.9)
		holder.add_child(mi)
	var t := holder.create_tween()
	t.tween_interval(life)
	t.tween_property(m, "albedo_color:a", 0.0, 1.0)
	t.tween_callback(holder.queue_free)


## Small floating health bar, billboarded above a character.
static func health_bar() -> Node3D:
	var holder := Node3D.new()
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.09)
	bg.mesh = q
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0, 0, 0, 0.65)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.no_depth_test = true
	bm.render_priority = 1
	bg.material_override = bm
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bg)
	var fill := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.86, 0.06)
	fq.center_offset = Vector3(0.43, 0, 0)
	fill.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#e04848")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	fm.render_priority = 2
	fill.material_override = fm
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.name = "Fill"
	holder.add_child(fill)
	return holder


# --- Power flourishes ---------------------------------------------------------

## A ground-level shockwave: a fast ring, a slower dust ring and a flash.
static func shockwave(world, pos: Vector3, color: Color, radius: float) -> void:
	ring(world, pos + Vector3.UP * 0.15, color, radius, 0.35)
	ring(world, pos + Vector3.UP * 0.1, color.lerp(Color("#d8d0c0"), 0.6), radius * 0.7, 0.7)
	flash(world, pos + Vector3.UP * 0.5, color, radius * 0.35, 0.25, 0.5)
	for k in 6:
		var ang := k * TAU / 6.0
		var p := pos + Vector3(cos(ang), 0.2, sin(ang)) * radius * 0.4
		smoke(world, p, 0.7, 0.6)


## Comic-book impact lines bursting out from a point.
static func burst_lines(world, pos: Vector3, color: Color, length := 4.0, count := 12) -> void:
	for k in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var a: Vector3 = pos + dir * randf_range(0.4, 1.0)
		line(world, a, a + dir * length * randf_range(0.6, 1.0), color, randf_range(0.04, 0.09), randf_range(0.12, 0.22))


## Glowing cracks radiating across the ground, fading over a few seconds.
static func ground_crack(world, pos: Vector3, color: Color, radius: float) -> void:
	var m := glow_mat(color, 0.85)
	var segs: Array = []
	for k in 9:
		var ang := k * TAU / 9.0 + randf_range(-0.2, 0.2)
		var cur := pos + Vector3(0, 0.06, 0)
		for seg in 3:
			var nxt := cur + Vector3(cos(ang), 0, sin(ang)) * radius * randf_range(0.15, 0.3)
			ang += randf_range(-0.4, 0.4)
			var mi := MeshInstance3D.new()
			mi.mesh = _box_mesh()
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root(world).add_child(mi)
			place_line(mi, cur, nxt, 0.18 - seg * 0.04)
			segs.append(mi)
			cur = nxt
	var root: Node = _root(world)
	var tw := root.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.5)
	var cleanup := func() -> void:
		for c in segs:
			if is_instance_valid(c):
				c.queue_free()
	root.get_tree().create_timer(3.1, false).timeout.connect(cleanup)


## A column of light pouring down (or up) at a point.
static func pillar(world, pos: Vector3, color: Color, height := 40.0, radius := 2.0, life := 0.8) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.6
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	var m := glow_mat(color, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	mi.global_position = pos + Vector3.UP * height * 0.5
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.1, 1.0, 0.1), life).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## Motes of energy streaming into a character's hands: a power charging up.
static func charge_up(target: Node3D, color: Color, life := 0.45) -> void:
	if not target is Actor:
		return
	var a: Actor = target
	var w = a.world
	if w == null:
		return
	var hands := [a.model.hand_point(1.0), a.model.hand_point(-1.0)]
	for h in hands:
		for k in 8:
			var from: Vector3 = h + Vector3(randf_range(-1, 1), randf_range(-0.5, 1.2), randf_range(-1, 1)).normalized() * randf_range(1.2, 2.2)
			line(w, from, h, color.lightened(0.3), 0.035, life * randf_range(0.5, 1.0))
		flash(w, h, color, 0.5, life, 0.8)
