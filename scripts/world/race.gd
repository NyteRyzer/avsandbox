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
var rooftop := false
var pads: Array[Vector3] = []
var _pad_t := 0.0


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


## A free-running course across the rooftops near you: you start on a roof,
## and a launch pad on each roof flings you across the street to the next
## one. Land it, climb up if you come in short, and hit the next pad.
func start_rooftops() -> bool:
	stop()
	if world.city.kind != "metro":
		world.notify("No rooftops to run here.", Color("#ff8080"))
		return false
	var p: Vector3 = world.player.global_position
	var roofs: Array = []
	for b in world.city.buildings:
		var h: float = b["h"]
		var c: Vector2 = (b["rect"] as Rect2).get_center()
		if h >= 8.0 and h <= 60.0 and c.distance_to(Vector2(p.x, p.z)) < 500.0 and (b["rect"] as Rect2).size.x > 8.0:
			roofs.append({"c": c, "h": h, "r": b["rect"]})
	if roofs.size() < RINGS + 1:
		world.notify("Not enough rooftops around here. Try downtown.", Color("#ff8080"))
		return false
	# Start on the nearest roof, then on to a nearby roof each time, mostly
	# onward and not too far up.
	roofs.sort_custom(func(a, b) -> bool: return (a["c"] as Vector2).distance_to(Vector2(p.x, p.z)) < (b["c"] as Vector2).distance_to(Vector2(p.x, p.z)))
	var chain: Array = [roofs[0]]
	var used := {0: true}
	var heading := Vector2.ZERO
	for k in RINGS:
		var cur: Dictionary = chain[-1]
		var best := -1
		var best_score := INF
		for i in roofs.size():
			if used.has(i):
				continue
			var d := (roofs[i]["c"] as Vector2).distance_to(cur["c"])
			var rise: float = roofs[i]["h"] - cur["h"]
			var gap := _gap(cur["r"], roofs[i]["r"])
			if d < 10.0 or gap > 60.0 or rise > 20.0:
				continue
			var dir := ((roofs[i]["c"] as Vector2) - (cur["c"] as Vector2)).normalized()
			var score := gap * 2.0 + d * 0.1 - (heading.dot(dir) * 12.0 if heading != Vector2.ZERO else 0.0)
			if score < best_score:
				best_score = score
				best = i
		if best < 0:
			break
		used[best] = true
		heading = ((roofs[best]["c"] as Vector2) - (cur["c"] as Vector2)).normalized()
		chain.append(roofs[best])
	if chain.size() < 4:
		world.notify("These rooftops are too far apart. Try another block.", Color("#ff8080"))
		return false
	points.clear()
	var total := 0.0
	for k in range(1, chain.size()):
		var c: Vector2 = chain[k]["c"]
		points.append(Vector3(c.x, float(chain[k]["h"]) + 2.5, c.y))
		total += (chain[k]["c"] as Vector2).distance_to(chain[k - 1]["c"])
	var start: Vector2 = chain[0]["c"]
	world.teleport_player(Vector3(start.x, float(chain[0]["h"]) + 1.0, start.y))
	pads.clear()
	pads.append(Vector3(start.x, float(chain[0]["h"]) + 0.1, start.y))
	for k in range(0, points.size() - 1):
		pads.append(points[k] + Vector3.DOWN * 2.4)
	for pd in pads:
		_rings.append(_pad(pd))
	limit = total / 9.0 + 25.0
	index = 0
	time = 0.0
	active = true
	rooftop = true
	for k in points.size():
		_rings.append(_ring(points[k], k == points.size() - 1))
	_highlight()
	world.hud.show_banner("ROOFTOP RUN!  %d ROOFS" % points.size(), Color("#3affd0"))
	world.notify("Step on the launch pads to fly roof to roof; climb up if you land short. %.0f seconds." % limit, Color("#3affd0"))
	Sfx.play("event", null, 0.0)
	return true


## The horizontal gap between two building footprints (0 if they touch).
static func _gap(a: Rect2, b: Rect2) -> float:
	var gx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var gz := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(gx, gz).length()


func _pad(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	world.fx_root.add_child(n)
	n.global_position = pos
	var disc := CylinderMesh.new()
	disc.top_radius = 2.0
	disc.bottom_radius = 2.2
	disc.height = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = FX.glow_mat(Color("#3affd0"), 0.85)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var tag := Label3D.new()
	tag.text = "LAUNCH"
	tag.font_size = 48
	tag.pixel_size = 0.01
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("#3affd0")
	tag.position = Vector3(0, 1.4, 0)
	n.add_child(tag)
	return n


## Fling the player in an arc from where they stand to `to`.
func _launch(to: Vector3) -> void:
	var a: Actor = world.player
	var from := a.global_position
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var g := Actor.GRAVITY * float(world.gravity_scale)
	var t := clampf(flat.length() / 24.0, 1.0, 3.0)
	var v := flat / t
	v.y = (to.y - from.y + 0.5 * g * t * t) / t
	a.velocity = v
	a.launch_t = t
	a.model.tumble(10.0)
	FX.ring(world, from + Vector3.UP * 0.2, Color("#3affd0"), 3.0, 0.4)
	Sfx.play("whoosh", from, 2.0)


func stop() -> void:
	rooftop = false
	pads.clear()
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
	if rooftop and index < pads.size() and world.player.is_on_floor() and world.player.launch_t <= 0.0:
		var pd: Vector3 = pads[index]
		var me: Vector3 = world.player.global_position
		if Vector2(me.x - pd.x, me.z - pd.z).length() < 3.2 and absf(me.y - pd.y) < 2.0:
			# A short wind-up on the pad, then up and away.
			_pad_t += delta
			if _pad_t > 0.35:
				_pad_t = 0.0
				_launch(points[index] + Vector3.DOWN * 1.5)
		else:
			_pad_t = 0.0
	if time > limit:
		world.notify("Out of time! Race failed.", Color("#ff8080"))
		stop()
	elif rooftop and world.player.is_on_floor() and world.player.global_position.y < 1.5:
		world.notify("You hit the street. Rooftop run failed.", Color("#ff8080"))
		stop()


func _finish() -> void:
	var left := limit - time
	var reward := 100 + int(left * 8.0)
	Game.add_score(reward)
	Game.record("races")
	if rooftop:
		Game.record("rooftop_runs")
	var id: String = world.player.def.get("id", "")
	var best := float(_best.get(id, INF))
	var record := time < best
	if record:
		_best[id] = time
	world.hud.show_banner("FINISHED IN %.1f s%s" % [time, "  ·  NEW BEST" if record else ""], Color("#3affd0"))
	world.notify("Race complete  +%d" % reward, Color("#60ff90"))
	Sfx.play("event", null, 2.0)
	stop()
