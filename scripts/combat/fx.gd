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


static func lightning(world, a: Vector3, b: Vector3, color: Color, life := 0.2, jitter := 0.6, segments := 6) -> void:
	var prev := a
	var mat := CharacterModel.mat(color.lightened(0.3), 0.0, true)
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := a.lerp(b, t)
		if i < segments:
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root(world).add_child(mi)
		place_line(mi, prev, p, 0.06)
		_free_after(mi, life * randf_range(0.6, 1.0))
		prev = p


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


static func flash(world, pos: Vector3, color: Color, radius: float, life := 0.35, alpha := 0.7) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh()
	var m := glow_mat(color, alpha)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root(world).add_child(mi)
	mi.global_position = pos
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


static func damage_number(world, pos: Vector3, amount: float, on_player: bool) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64 if amount >= 20 else 48
	l.pixel_size = 0.006
	l.outline_size = 12
	l.no_depth_test = true
	l.modulate = Color("#ff5050") if on_player else (Color("#ffd23a") if amount >= 20 else Color.WHITE)
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
