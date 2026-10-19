class_name Projectile
extends Node3D
## Arrows, blades, boomerangs, grenades, missiles and energy blasts. Moves by
## ray-casting each step so fast projectiles never tunnel through walls or
## people. Arrows stick where they land, boomerangs fly home, missiles home
## in, and grenades bounce until their fuse runs out.

static var _mesh_cache: Dictionary = {}
static var spawned := 0

var shooter: Actor
var world
var velocity := Vector3.ZERO
var damage := 10.0
var element := ""
var radius := 0.0   # > 0 makes it explode on impact
var gravity := 0.0
var life := 3.0
var color := Color.WHITE
var style := "energy"
var returns := false
var homing: Actor = null
var fuse := -1.0
var effect := ""        # trick arrows: net, flash, poison, fire, freeze, drain
var ricochet := 0       # bounces on to this many more foes
var _exclude: Array[RID] = []
var _spin: Node3D
var _spin_axis := Vector3.UP
var _spin_rate := 0.0
var _out_t := 0.0
var _coming_back := false
var _hit_once: Dictionary = {}
var _trail_t := 0.0


func setup(p_world, p_shooter: Actor, from: Vector3, vel: Vector3, p_damage: float, p_style: String, p_color: Color, p_element := "", p_radius := 0.0) -> void:
	spawned += 1
	world = p_world
	shooter = p_shooter
	velocity = vel
	damage = p_damage
	style = p_style
	color = p_color
	element = p_element
	radius = p_radius
	if is_instance_valid(shooter):
		_exclude.append(shooter.get_rid())
	world.fx_root.add_child(self)
	global_position = from
	_build()


func _mesh(key: String, builder: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		var mb := MeshBuilder.new()
		var glow := MeshBuilder.new()
		builder.call(mb, glow)
		var mesh := ArrayMesh.new()
		for pair in [[mb, "metal"], [glow, "glow"]]:
			var b: MeshBuilder = pair[0]
			if b.is_empty():
				continue
			var m := b.commit(pair[1])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
			mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.material(pair[1]))
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


func _add_mesh(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build() -> void:
	var c := color
	match style:
		"arrow", "explosive_arrow":
			gravity = 3.0
			life = 4.0
			var tip := Color("#c8ccd2") if style == "arrow" else Color("#ff3a1a")
			_add_mesh(_mesh("arrow|" + style, func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				Gear.arrow(mb, Transform3D(), Color("#3a2a1a"), tip)
				if style == "explosive_arrow":
					glow.ellipsoid(Vector3(0, 0, -0.36), Vector3(0.025, 0.025, 0.04), Transform3D(), Color("#ff3a1a"))))
		"knife", "cicada_dagger", "dagger":
			var glowing := style == "cicada_dagger"
			_spin = _add_mesh(_mesh("blade|" + str(glowing), func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				Gear.blade(glow if glowing else mb, Transform3D(), 0.26, 0.022, Color("#ff3a2a") if glowing else Gear.STEEL, Gear.DARK, Gear.DARK, glowing)))
			_spin_axis = Vector3.RIGHT
			_spin_rate = 22.0
		"batarang":
			_spin = _add_mesh(_mesh("batarang", func(mb: MeshBuilder, _g: MeshBuilder) -> void:
				Gear.batarang(mb, Transform3D(), Color("#1c1c1e"))))
			_spin_rate = 30.0
		"shuriken":
			_spin = _add_mesh(_mesh("shuriken", func(mb: MeshBuilder, _g: MeshBuilder) -> void:
				Gear.shuriken(mb, Transform3D(), Color("#c0c0c0"))))
			_spin_rate = 36.0
		"boomerang":
			_spin = _add_mesh(_mesh("boomerang", func(mb: MeshBuilder, _g: MeshBuilder) -> void:
				Gear.boomerang(mb, Transform3D(), Color("#d8d8d8"))))
			_spin_rate = 28.0
			if radius > 0.0:
				var bulb := _add_mesh(_mesh("bulb", func(_m: MeshBuilder, glow: MeshBuilder) -> void:
					glow.ellipsoid(Vector3.ZERO, Vector3(0.05, 0.05, 0.05), Transform3D(), Color("#ff6a1a"))))
				bulb.position = Vector3(0, 0.03, 0)
		"helmet":
			_spin = _add_mesh(_mesh("helmet", func(mb: MeshBuilder, _g: MeshBuilder) -> void:
				mb.loft([{"y": 0.0, "rx": 0.16, "rz": 0.17}, {"y": 0.02, "rx": 0.15, "rz": 0.16}, {"y": 0.08, "rx": 0.1, "rz": 0.11}, {"y": 0.1, "rx": 0.002, "rz": 0.002}],
					Transform3D(), Color("#b8b8b8"), 16)))
			_spin_rate = 18.0
		"mace":
			_spin = _add_mesh(_mesh("mace", func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				Gear.build("mace", mb, glow, Transform3D(Basis(), Vector3(0, 0, 0.3)), {})))
			_spin_axis = Vector3.RIGHT
			_spin_rate = 16.0
		"grenade":
			gravity = 22.0
			life = 6.0
			_add_mesh(_mesh("grenade|" + c.to_html(), func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				mb.ellipsoid(Vector3.ZERO, Vector3(0.07, 0.09, 0.07), Transform3D(), Color("#3a4a2a"))
				glow.ellipsoid(Vector3(0, 0.09, 0), Vector3(0.02, 0.02, 0.02), Transform3D(), c)))
		"missile":
			life = 4.0
			_add_mesh(_mesh("missile", func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				mb.tube(Vector3(0, 0, 0.2), Vector3(0, 0, -0.2), 0.04, 0.04, Transform3D(), Color("#d8d8d8"))
				mb.tube(Vector3(0, 0, -0.2), Vector3(0, 0, -0.3), 0.04, 0.0, Transform3D(), Color("#b01c1c"))
				glow.ellipsoid(Vector3(0, 0, 0.23), Vector3(0.035, 0.035, 0.05), Transform3D(), Color("#ffb040"))))
		"lightning":
			pass  # drawn every frame as a crackling bolt
		"ice":
			_add_mesh(_mesh("ice", func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				glow.tube(Vector3(0, 0, 0.25), Vector3(0, 0, -0.05), 0.0, 0.09, Transform3D(), Color("#dff6ff"), 5)
				glow.tube(Vector3(0, 0, -0.05), Vector3(0, 0, -0.35), 0.09, 0.0, Transform3D(), Color("#ffffff"), 5)))
		"tsphere":
			_add_mesh(_mesh("tsphere", func(mb: MeshBuilder, glow: MeshBuilder) -> void:
				mb.ellipsoid(Vector3.ZERO, Vector3(0.1, 0.1, 0.1), Transform3D(), Color("#1a1a1a"))
				glow.box(Vector3(0, 0, -0.095), Vector3(0.08, 0.02, 0.01), Transform3D(), Color("#ff3030"))
				glow.box(Vector3(0, -0.02, -0.095), Vector3(0.02, 0.06, 0.01), Transform3D(), Color("#ff3030"))))
		"cosmic":
			_spin = _add_mesh(_mesh("cosmic", func(_m: MeshBuilder, glow: MeshBuilder) -> void:
				var star := PackedVector2Array()
				for i in 10:
					var a := -PI * 0.5 + i * PI / 5.0
					var r := 0.22 if i % 2 == 0 else 0.09
					star.append(Vector2(cos(a) * r, sin(a) * r))
				glow.prism(star, 0.05, Transform3D(), Color("#fff2a0"))))
			_spin_axis = Vector3.BACK
			_spin_rate = 10.0
			_halo(c, 0.4)
		_:
			# Energy orbs: fireball, vibe, magic, dream, antimatter, plain energy.
			var r := 0.18
			if style == "antimatter":
				r = 0.4
			elif style == "fireball":
				r = 0.25
			var core := c.lightened(0.5)
			_add_mesh(_mesh("orb|%s|%.2f" % [c.to_html(), r], func(_m: MeshBuilder, glow: MeshBuilder) -> void:
				glow.ellipsoid(Vector3.ZERO, Vector3.ONE * r, Transform3D(), core, 12, 8)))
			_halo(c, r * 2.2)
			if style == "vibe":
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.32
				torus.outer_radius = 0.38
				ring.mesh = torus
				ring.material_override = FX.glow_mat(c, 0.6)
				ring.rotation.x = PI * 0.5
				add_child(ring)
				_spin = ring
				_spin_axis = Vector3.FORWARD
				_spin_rate = 0.0


func _halo(c: Color, r: float) -> void:
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = r
	hm.height = r * 2.0
	hm.radial_segments = 12
	hm.rings = 6
	halo.mesh = hm
	halo.material_override = CharacterModel.mat(c, 0.0, true, 0.28)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


func _physics_process(delta: float) -> void:
	life -= delta
	if fuse > 0.0:
		fuse -= delta
		if fuse <= 0.0:
			_finish(global_position, null)
			return
	if life <= 0.0:
		_finish(global_position, null)
		return
	_out_t += delta
	if returns and not _coming_back and _out_t > 0.55:
		_coming_back = true
		_hit_once.clear()
	if _coming_back:
		if not is_instance_valid(shooter):
			queue_free()
			return
		var home := shooter.chest()
		var to := home - global_position
		if to.length() < 1.2:
			queue_free()
			return
		velocity = velocity.lerp(to.normalized() * maxf(velocity.length(), 45.0), clampf(delta * 6.0, 0.0, 1.0))
	elif homing and is_instance_valid(homing) and not homing.dead:
		var want := (homing.chest() - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(delta * 3.5, 0.0, 1.0))
		velocity = velocity.normalized() * minf(velocity.length() + delta * 30.0, 70.0)
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	for attempt in 3:
		var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ACTORS | Game.LAYER_PROPS, _exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col = hit["collider"]
		if col is Actor and is_instance_valid(shooter) and not shooter.can_hurt(col):
			_exclude.append(col.get_rid())
			continue
		if style == "grenade" and not (col is Actor):
			# Bounce off the ground and walls.
			var n: Vector3 = hit["normal"]
			velocity = velocity.bounce(n) * 0.45
			global_position = hit["position"] + n * 0.1
			return
		if returns and col is Actor:
			# Boomerangs and helmets pass through what they hit, once each.
			if not _hit_once.has(col):
				_hit_once[col] = true
				_damage(hit["position"], col)
			_exclude.append(col.get_rid())
			continue
		if returns and not _coming_back:
			_coming_back = true
			global_position = hit["position"] + hit["normal"] * 0.2
			return
		if ricochet > 0 and col is Actor:
			# Guardian's shield, Captain Boomerang: bounce on to the next foe.
			_damage(hit["position"], col)
			_exclude.append(col.get_rid())
			ricochet -= 1
			var next: Actor = null
			var nd := 18.0
			for o in get_tree().get_nodes_in_group("actors"):
				if o == col or not is_instance_valid(shooter) or not shooter.can_hurt(o) or o.team == "civilian":
					continue
				var d: float = o.global_position.distance_to(col.global_position)
				if d < nd:
					nd = d
					next = o
			if next:
				global_position = hit["position"]
				velocity = (next.chest() - global_position).normalized() * maxf(velocity.length(), 40.0)
				life = maxf(life, 1.5)
				return
		_finish(hit["position"], col, hit.get("normal", Vector3.UP))
		return
	global_position = to
	if velocity.length() > 0.1:
		var dir := velocity.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
		global_transform.basis = Basis.looking_at(dir, up)
	if _spin:
		_spin.rotate_object_local(_spin_axis, delta * _spin_rate)
	_trail(delta)


func _trail(delta: float) -> void:
	_trail_t -= delta
	if _trail_t > 0.0:
		return
	_trail_t = 0.03
	match style:
		"lightning":
			FX.lightning(world, global_position - velocity.normalized() * 2.5, global_position, color, 0.12, 0.35, 4, 0)
		"fireball":
			FX.sparks(world, global_position, Color("#ff9a3a"), 3, 1.5, 0.35)
		"missile":
			FX.smoke(world, global_position - velocity.normalized() * 0.3, 0.6, 0.5)
		"energy", "vibe", "magic", "dream", "antimatter", "cosmic", "tsphere":
			if randf() < 0.5:
				FX.sparks(world, global_position, color, 1, 1.0, 0.25)


func _damage(pos: Vector3, col) -> void:
	var src: Actor = shooter if is_instance_valid(shooter) else null
	if col is Actor:
		var knock := velocity.normalized() * (3.0 + damage * 0.2) + Vector3.UP * 2.0
		col.take_damage(damage, src, element, knock)
		if effect != "":
			Powers.on_projectile_hit(src, col, effect, color)
		if src:
			src.combo_hit(1)
		Sfx.play("hit", pos, -4.0)
	elif col is Prop:
		col.hit(damage, velocity.normalized() * damage * 0.6, src)


func _finish(pos: Vector3, col, normal := Vector3.UP) -> void:
	var src: Actor = shooter if is_instance_valid(shooter) else null
	if radius > 0.0:
		var flashbang := style == "grenade" and element == "shock"
		if flashbang:
			FX.flash(world, pos, Color.WHITE, radius, 0.5, 0.95)
			for o in world.get_tree().get_nodes_in_group("actors"):
				if src and src.can_hurt(o) and o.global_position.distance_to(pos) < radius:
					o.stun_t = maxf(o.stun_t, 3.0)
					FX.stun_stars(o, 2.0 * o.size, 3.0)
			Sfx.play("explosion", pos, -2.0)
		else:
			Abilities.explode(world, pos, radius, damage, src, element, color if style != "missile" else Color("#ffaa33"))
	else:
		_damage(pos, col)
		FX.sparks(world, pos, color, 8, 4.0, 0.3)
		match element:
			"ice":
				FX.flash(world, pos, Color("#bff0ff"), 0.8, 0.25)
			"fire":
				FX.flash(world, pos, Color("#ff8a1e"), 0.9, 0.25)
			"shock":
				FX.lightning(world, pos, pos + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)), color, 0.15, 0.3, 3, 0)
		# Arrows and blades that hit scenery stay stuck in it for a while.
		if style in ["arrow", "knife", "shuriken", "batarang"] and not (col is Actor) and col != null:
			var stuck := Node3D.new()
			for ch in get_children():
				ch.reparent(stuck, false)
			world.fx_root.add_child(stuck)
			stuck.global_transform = Transform3D(global_transform.basis, pos - velocity.normalized() * 0.15)
			var t := stuck.create_tween()
			t.tween_interval(8.0)
			t.tween_callback(stuck.queue_free)
	queue_free()
