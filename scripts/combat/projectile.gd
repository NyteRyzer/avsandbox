class_name Projectile
extends Node3D
## Arrows, thrown blades, energy bolts and boomerangs. Moves by ray-casting
## each step so fast projectiles never tunnel through walls or people.

var shooter: Actor
var world
var velocity := Vector3.ZERO
var damage := 10.0
var element := ""
var radius := 0.0   # > 0 makes it explode on impact
var gravity := 0.0
var life := 3.0
var color := Color.WHITE
var style := "bolt"
var _exclude: Array[RID] = []
var _spin: Node3D


func setup(p_world, p_shooter: Actor, from: Vector3, vel: Vector3, p_damage: float, p_style: String, p_color: Color, p_element := "", p_radius := 0.0) -> void:
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


func _build() -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match style:
		"arrow":
			gravity = 4.0
			var m := BoxMesh.new()
			m.size = Vector3(0.035, 0.035, 0.85)
			m.material = CharacterModel.mat(Color("#5a4630"))
			mi.mesh = m
			var tip := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.07, 0.07, 0.14)
			tm.material = CharacterModel.mat(color, 2.0 if radius > 0.0 else 0.2)
			tip.mesh = tm
			tip.position = Vector3(0, 0, -0.45)
			add_child(tip)
		"throw":
			var m := BoxMesh.new()
			m.size = Vector3(0.32, 0.03, 0.12)
			m.material = CharacterModel.mat(color, 0.3)
			mi.mesh = m
			_spin = mi
		_:
			var m := SphereMesh.new()
			m.radius = 0.2
			m.height = 0.4
			m.radial_segments = 10
			m.rings = 5
			m.material = CharacterModel.mat(color, 3.0, true)
			mi.mesh = m
			var halo := MeshInstance3D.new()
			var hm := SphereMesh.new()
			hm.radius = 0.38
			hm.height = 0.76
			hm.material = CharacterModel.mat(color, 0.0, true, 0.3)
			halo.mesh = hm
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(halo)
	add_child(mi)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_finish(global_position, null)
		return
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
		_finish(hit["position"], col)
		return
	global_position = to
	if velocity.length() > 0.1:
		var dir := velocity.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
		global_transform.basis = Basis.looking_at(dir, up)
	if _spin:
		_spin.rotation.y += delta * 30.0
	if style == "bolt" and randf() < 0.3:
		FX.sparks(world, global_position, color, 1, 1.0, 0.25)


func _finish(pos: Vector3, col) -> void:
	var src: Actor = shooter if is_instance_valid(shooter) else null
	if radius > 0.0:
		Abilities.explode(world, pos, radius, damage, src, element, color)
	else:
		if col is Actor:
			var knock := velocity.normalized() * (3.0 + damage * 0.2) + Vector3.UP * 2.0
			col.take_damage(damage, src, element, knock)
			Sfx.play("hit", pos, -4.0)
		elif col is Prop:
			col.hit(damage, velocity.normalized() * damage * 0.6, src)
		FX.sparks(world, pos, color, 8, 4.0, 0.3)
		if element == "ice":
			FX.flash(world, pos, Color("#bff0ff"), 0.8, 0.25)
		elif element == "fire":
			FX.flash(world, pos, Color("#ff8a1e"), 0.9, 0.25)
	queue_free()
