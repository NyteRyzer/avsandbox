class_name Hazard
extends Node3D
## A lingering area power: Heat Wave's napalm, Metallo's kryptonite field,
## Captain Cold's cold front, Nyssa's poison cloud, or Stargirl's gravity
## well (which pulls everyone in, then implodes).

var source: Actor
var element := "fire"
var color := Color.WHITE
var radius := 7.0
var life := 8.0
var _tick := 0.0
var _pulled: Array = []


static func spawn(a: Actor, center: Vector3, p_element: String, p_color: Color, p_radius: float, p_life: float) -> Hazard:
	var h := Hazard.new()
	h.source = a
	h.element = p_element
	h.color = p_color
	h.radius = p_radius
	h.life = p_life
	a.world.fx_root.add_child(h)
	h.global_position = center
	h._build()
	return h


func _build() -> void:
	var disk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.08
	cyl.radial_segments = 32
	disk.mesh = cyl
	disk.material_override = FX.glow_mat(color, 0.35)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.position.y = 0.05 if element != "gravity" else -1.4
	add_child(disk)
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.4
	p.mesh = s
	p.material_override = FX.glow_mat(color, 0.7)
	p.amount = 60
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE if element == "gravity" else CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_sphere_radius = radius
	p.emission_box_extents = Vector3(radius * 0.8, 0.2, radius * 0.8)
	p.gravity = Vector3(0, 2.5, 0) if element != "gravity" else Vector3.ZERO
	p.radial_accel_min = -30.0 if element == "gravity" else 0.0
	p.radial_accel_max = -20.0 if element == "gravity" else 0.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	add_child(p)
	if element == "gravity":
		var core := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.9
		cs.height = 1.8
		core.mesh = cs
		core.material_override = FX.glow_mat(color, 0.9)
		add_child(core)
	Sfx.play("fire" if element == "fire" else ("freeze" if element == "ice" else "zap"), global_position, 0.0)


func _process(delta: float) -> void:
	life -= delta
	if not is_instance_valid(source):
		queue_free()
		return
	if element == "gravity":
		_gravity(delta)
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for o in get_tree().get_nodes_in_group("actors"):
			if not source.can_hurt(o) or o.global_position.distance_to(global_position) > radius:
				continue
			var dmg := 8.0 * source.power
			match element:
				"shock":
					# Kryptonite: crippling to Kryptonians.
					if o.def.get("id", "") in Powers.KRYPTONIANS:
						dmg *= 3.0
						o.stun_t = maxf(o.stun_t, 0.6)
				"poison":
					o.poison_t = maxf(o.poison_t, 2.0)
				"ice":
					o.frozen_t = maxf(o.frozen_t, 0.4)
			o.take_damage(dmg, source, element if element != "poison" else "", Vector3.ZERO)
	if life <= 0.0:
		queue_free()


func _gravity(delta: float) -> void:
	for o in get_tree().get_nodes_in_group("actors"):
		if not source.can_hurt(o):
			continue
		var to: Vector3 = global_position - o.global_position
		if to.length() < radius:
			o.velocity = o.velocity.lerp(to.normalized() * 14.0, clampf(delta * 4.0, 0.0, 1.0))
			if not _pulled.has(o):
				_pulled.append(o)
	if life <= 0.0:
		for o in _pulled:
			if is_instance_valid(o) and not o.dead and o.global_position.distance_to(global_position) < radius + 2.0:
				o.take_damage(32.0 * source.power, source, "shock", (o.global_position - global_position).normalized() * 16.0 + Vector3.UP * 8.0)
		FX.flash(source.world, global_position, color, radius * 0.6, 0.4)
		FX.ring(source.world, global_position, color, radius, 0.4)
		Sfx.play("explosion", global_position, 0.0)
		queue_free()
