class_name Minimap
extends Control
## Camera-aligned radar: nearby buildings, people (red = hostile, blue =
## allies, grey = civilians), the active event and the player.

var world
var meters := 130.0


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(230, 230)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.03, 0.05, 0.09, 0.8))
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var player: Actor = world.player
	var p := player.global_position
	var yaw: float = world.cam.yaw
	var right := Vector2(cos(yaw), -sin(yaw))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var center := size * 0.5
	var k := size.x * 0.5 / meters
	var to_screen := func(wx: float, wz: float) -> Vector2:
		var rel := Vector2(wx - p.x, wz - p.z)
		return center + Vector2(rel.dot(right), -rel.dot(fwd)) * k

	# Coastline
	var land_rects: Array = []
	for isl in world.city.islands:
		land_rects.append(isl["land"])
	for e in world.city.extra_land:
		land_rects.append(e["rect"])
	land_rects.append_array(world.city.bridges)
	for r in land_rects:
		var rr2: Rect2 = r
		var corners := PackedVector2Array([to_screen.call(rr2.position.x, rr2.position.y), to_screen.call(rr2.end.x, rr2.position.y),
			to_screen.call(rr2.end.x, rr2.end.y), to_screen.call(rr2.position.x, rr2.end.y)])
		draw_colored_polygon(corners, Color(0.12, 0.13, 0.15, 0.9))
	for b in world.city.buildings_near(p, meters * 1.5):
		var r: Rect2 = b["rect"]
		var h: float = b["h"]
		var shade := clampf(0.25 + h / 400.0, 0.25, 0.6)
		var poly := PackedVector2Array([to_screen.call(r.position.x, r.position.y), to_screen.call(r.end.x, r.position.y),
			to_screen.call(r.end.x, r.end.y), to_screen.call(r.position.x, r.end.y)])
		draw_colored_polygon(poly, Color(shade, shade + 0.03, shade + 0.08, 0.95) if h >= 0.0 else Color(0.4, 0.7, 0.9, 0.6))
	for a in world.get_tree().get_nodes_in_group("actors"):
		if a == player or a.dead:
			continue
		var s: Vector2 = to_screen.call(a.global_position.x, a.global_position.z)
		if not rect.has_point(s):
			continue
		var col := Color(0.75, 0.75, 0.75, 0.8)
		var radius := 2.5
		if a.is_ally_of_player():
			col = Color("#5fa8ff")
			radius = 4.0
		elif a.is_hostile_to(player) or player.is_hostile_to(a):
			col = Color("#ff4848")
			radius = 3.5
		elif a.team == "police":
			col = Color("#8ab4ff")
		elif a.team != "civilian":
			col = Color("#ffd27a")
			radius = 3.0
		if a.def.get("id", "") not in ["civilian", "police", "thug"]:
			radius += 1.5
		draw_circle(s, radius, col)
	if not world.events.active.is_empty():
		var ep: Vector3 = world.events.active["pos"]
		var s: Vector2 = to_screen.call(ep.x, ep.z)
		var clamped := center + (s - center).limit_length(size.x * 0.5 - 10.0)
		draw_circle(clamped, 7.0, Color("#ffd23a"))
		draw_circle(clamped, 4.0, Color("#1a1a1a"))
	if world.waypoint != Vector3.INF:
		var ws: Vector2 = to_screen.call(world.waypoint.x, world.waypoint.z)
		draw_circle(center + (ws - center).limit_length(size.x * 0.5 - 10.0), 6.0, Color("#3affd0"))
	var rp: Vector3 = world.race.target_pos()
	if rp != Vector3.INF:
		var s2: Vector2 = to_screen.call(rp.x, rp.z)
		draw_circle(center + (s2 - center).limit_length(size.x * 0.5 - 10.0), 7.0, Color("#3affd0"))
	var mp: Vector3 = world.missions.target_pos()
	if mp != Vector3.INF:
		var s: Vector2 = to_screen.call(mp.x, mp.z)
		var clamped := center + (s - center).limit_length(size.x * 0.5 - 10.0)
		draw_circle(clamped, 8.0, Color("#ff6a4a"))
		draw_circle(clamped, 3.5, Color("#ffffff"))
	for st in world.city.subways:
		var sp: Vector3 = st["pos"]
		var q: Vector2 = to_screen.call(sp.x, sp.z)
		if q.distance_to(center) < size.x * 0.5 - 6.0:
			draw_rect(Rect2(q - Vector2(3.5, 3.5), Vector2(7, 7)), Color("#3aff6a"))
	for pt in world.city.points:
		var pp: Vector3 = pt["pos"]
		var q2: Vector2 = to_screen.call(pp.x, pp.z)
		if q2.distance_to(center) < size.x * 0.5 - 6.0 and pt["kind"] != "subway":
			draw_circle(q2, 2.0, Color("#ffd27a"))
	var mg: Vector3 = world.street_crime.target_pos()
	if mg != Vector3.INF:
		var s4: Vector2 = to_screen.call(mg.x, mg.z)
		draw_circle(center + (s4 - center).limit_length(size.x * 0.5 - 10.0), 6.0, Color("#ffb070"))
	var cp: Vector3 = world.char_missions.target_pos()
	if cp != Vector3.INF:
		var s3: Vector2 = to_screen.call(cp.x, cp.z)
		var cl := center + (s3 - center).limit_length(size.x * 0.5 - 10.0)
		draw_circle(cl, 8.0, Color("#3ab8ff"))
		draw_circle(cl, 3.5, Color("#ffffff"))
	# Player arrow (always points up: the map rotates with the camera).
	var facing: float = -(player.rotation.y - yaw)
	var tip := Vector2(0, -9).rotated(facing)
	var l := Vector2(-6, 6).rotated(facing)
	var rr := Vector2(6, 6).rotated(facing)
	draw_colored_polygon(PackedVector2Array([center + tip, center + rr, center + l]), Color.WHITE)
	draw_rect(rect, Color(1, 1, 1, 0.15), false, 2.0)
