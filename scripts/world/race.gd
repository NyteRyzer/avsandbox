class_name Race
extends Node
## Checkpoint races: a chain of glowing rings through the streets (or the
## sky). Run, fly or drive through them before the clock runs out. Faster
## finishes earn more points; speedsters get a tighter clock.

const RINGS := 8

var world
var active := false
var points: Array[Vector3] = []
var index := 0
var time := 0.0
var limit := 0.0
var _rings: Array[Node3D] = []
var _best: Dictionary = {}


func start(airborne := false) -> void:
	stop()
	var p: Vector3 = world.player.global_position
	var r := RandomNumberGenerator.new()
	r.randomize()
	points.clear()
	var at := p
	var dir := Vector3(-world.cam.global_basis.z.x, 0, -world.cam.global_basis.z.z).normalized()
	var total := 0.0
	for k in RINGS:
		dir = dir.rotated(Vector3.UP, r.randf_range(-0.9, 0.9))
		var next := at + dir * r.randf_range(70.0, 120.0)
		if world.city.kind == "metro":
			next = world.city.snap_to_road(next)
		next.y = (r.randf_range(20.0, 90.0) if airborne else 0.0) + 2.5
		total += at.distance_to(next)
		points.append(next)
		at = next
	var fast: bool = world.player.movement == "speed"
	limit = total / (40.0 if fast else 16.0) + 15.0
	index = 0
	time = 0.0
	active = true
	for k in points.size():
		_rings.append(_ring(points[k], k == points.size() - 1))
	_highlight()
	world.hud.show_banner("RACE!  %d CHECKPOINTS" % RINGS, Color("#3affd0"))
	world.notify("Race through the rings: %.0f seconds on the clock." % limit, Color("#3affd0"))
	Sfx.play("event", null, 0.0)


func stop() -> void:
	active = false
	for n in _rings:
		if is_instance_valid(n):
			n.queue_free()
	_rings.clear()


func _ring(pos: Vector3, finish: bool) -> Node3D:
	var n := Node3D.new()
	world.fx_root.add_child(n)
	n.global_position = pos
	var torus := TorusMesh.new()
	torus.inner_radius = 4.2
	torus.outer_radius = 5.0
	torus.rings = 32
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.rotation.x = PI * 0.5
	mi.material_override = FX.glow_mat(Color("#ffd23a") if finish else Color("#3affd0"), 0.9)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _highlight() -> void:
	for k in _rings.size():
		var n := _rings[k]
		if not is_instance_valid(n):
			continue
		n.visible = k >= index
		n.scale = Vector3.ONE * (1.3 if k == index else 0.8)
		if k + 1 < points.size() and Vector2(points[k + 1].x - points[k].x, points[k + 1].z - points[k].z).length() > 0.5:
			n.look_at(Vector3(points[k + 1].x, points[k].y, points[k + 1].z), Vector3.UP)


func target_pos() -> Vector3:
	return points[index] if active and index < points.size() else Vector3.INF


func tracker() -> String:
	if not active:
		return ""
	return "RACE  ·  checkpoint %d/%d  ·  %.1f s left" % [index + 1, points.size(), maxf(0.0, limit - time)]


func _process(delta: float) -> void:
	if not active or world.player == null or not is_instance_valid(world.player):
		return
	time += delta
	for n in _rings:
		if is_instance_valid(n):
			n.rotate_object_local(Vector3.FORWARD, delta * 1.5)
	var p: Vector3 = world.player.global_position + Vector3.UP
	if p.distance_to(points[index]) < 7.0 or Vector2(p.x - points[index].x, p.z - points[index].z).length() < 6.0 and absf(p.y - points[index].y) < 9.0:
		FX.ring(world, points[index], Color("#3affd0"), 6.0, 0.4)
		Sfx.play("click", null, 4.0)
		index += 1
		if index >= points.size():
			_finish()
			return
		_highlight()
	if time > limit:
		world.notify("Out of time! Race failed.", Color("#ff8080"))
		stop()


func _finish() -> void:
	var left := limit - time
	var reward := 100 + int(left * 8.0)
	Game.add_score(reward)
	var id: String = world.player.def.get("id", "")
	var best := float(_best.get(id, INF))
	var record := time < best
	if record:
		_best[id] = time
	world.hud.show_banner("FINISHED IN %.1f s%s" % [time, "  ·  NEW BEST" if record else ""], Color("#3affd0"))
	world.notify("Race complete  +%d" % reward, Color("#60ff90"))
	Sfx.play("event", null, 2.0)
	stop()
