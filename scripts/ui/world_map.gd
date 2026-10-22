class_name WorldMap
extends CanvasLayer
## The full map (M): every island, bridge and landmark, where you are, the
## current event, mission and waypoint. Pick a landmark to set a waypoint, or
## fast-travel to any landmark you've already visited.

var world
var _map: Control
var _list: VBoxContainer
var _selected: Dictionary = {}
var _selected_place := ""   # which Earth _selected belongs to
var _travel: Button
var _info: Label


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_top = 30
	row.offset_right = -30
	row.offset_bottom = -30
	row.add_theme_constant_override("separation", 20)
	row.theme = UITheme.get_theme()
	add_child(row)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.draw.connect(_draw_map)
	_map.clip_contents = true
	_map.gui_input.connect(_map_input)
	row.add_child(_map)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(340, 0)
	row.add_child(side)
	side.add_child(UITheme.label("MAP", 30, UITheme.ACCENT))
	_info = UITheme.label("", 15, UITheme.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	_list = VBoxContainer.new()
	scroll.add_child(_list)
	_travel = UITheme.button("Fast travel", _fast_travel, 320)
	side.add_child(_travel)
	side.add_child(UITheme.button("Clear waypoint", func() -> void:
		world.waypoint = Vector3.INF
		_refresh(), 320))
	side.add_child(UITheme.button("Close  [M]", close, 320))
	side.add_child(UITheme.label("Wheel: zoom  ·  drag: pan\n● gold landmark  ■ blue entrance  ■ green subway\n· orange food  · cyan vending/ATM  · blue phone\n● pink fragment  ● red mission  ● blue personal", 13, UITheme.DIM))


func toggle() -> void:
	if visible:
		close()
	elif not world.pause_menu.visible and not world.sandbox_menu.visible:
		open()


func open() -> void:
	if world.place_id != _selected_place:
		_selected = {}   # a landmark picked on another Earth isn't here
	visible = true
	get_tree().paused = true
	world.capture_mouse(false)
	_refresh()


func _ride(st: Dictionary) -> void:
	subway_from = ""
	close()
	world.teleport_player(st["pos"] + Vector3.UP * 0.3)
	world.notify("Next stop: " + str(st["name"]), Color("#d8ffe0"))
	Game.record("subway_rides")


func close() -> void:
	subway_from = ""
	visible = false
	get_tree().paused = false
	world.capture_mouse(true)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("map") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


## Subway mode: the list is every station; pick one to ride there.
var subway_from := ""


func open_subway(from: String) -> void:
	subway_from = from
	open()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if subway_from != "":
		_info.text = "SUBWAY: pick a station to ride to."
		for st in world.city.subways:
			if st["name"] == subway_from:
				continue
			var stop: Dictionary = st
			var b := UITheme.button(str(st["name"]), func() -> void: _ride(stop), 320)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_list.add_child(b)
		_travel.disabled = true
		_map.queue_redraw()
		return
	var found: Array = Game.progress.get("discovered", [])
	for l in world.city.landmarks:
		if l.get("interior", false):
			continue
		var name: String = l["name"]
		var known: bool = found.has(name) or world.place_id != "earth1"
		var mark: Dictionary = l
		var b := UITheme.button(name if known else "???  (" + str(l.get("district", "")) + ")", func() -> void: _pick(mark), 320)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
	_travel.disabled = _selected.is_empty() or not _known(_selected)
	_info.text = "Visited %d landmarks · Crisis Fragments %d / %d\nPick a landmark to set a waypoint. Fast travel works once you've been there." % [
		found.size(), world.collectibles.found_count(), Collectibles.TOTAL]
	_map.queue_redraw()


func _known(l: Dictionary) -> bool:
	return world.place_id != "earth1" or Game.progress.get("discovered", []).has(l["name"])


func _pick(l: Dictionary) -> void:
	_selected = l
	_selected_place = world.place_id
	world.waypoint = l["pos"]
	_refresh()


func _fast_travel() -> void:
	if _selected.is_empty() or not _known(_selected):
		return
	var pos: Vector3 = _selected["pos"]
	close()
	world.teleport_player(pos)
	world.notify("Fast travel: " + str(_selected["name"]), Color("#a0d0ff"))


var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.8)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_map.queue_redraw()


func _zoom_at(at: Vector2, f: float) -> void:
	var nz := clampf(_zoom * f, 1.0, 12.0)
	var k := nz / _zoom
	# Keep the point under the cursor still.
	_pan = (_pan - (at - _map.size * 0.5)) * k + (at - _map.size * 0.5)
	_zoom = nz
	if _zoom <= 1.0:
		_pan = Vector2.ZERO
	_map.queue_redraw()


## World -> map coordinates: fit the whole play area into the panel.
func _to_map(x: float, z: float) -> Vector2:
	var bounds := Rect2(-850, -850, 1700, 1700)
	if world.city.kind == "metro" and not world.city.islands.is_empty():
		bounds = world.city.islands[0]["land"]
		for isl in world.city.islands:
			bounds = bounds.merge(isl["land"])
		bounds = bounds.grow(250.0)
	var span := maxf(bounds.size.x, bounds.size.y)
	var center := bounds.get_center()
	var s := minf(_map.size.x, _map.size.y) / span * _zoom
	return _map.size * 0.5 + _pan + (Vector2(x, z) - center) * s


func _rect(r: Rect2, color: Color) -> void:
	var a := _to_map(r.position.x, r.position.y)
	var b := _to_map(r.end.x, r.end.y)
	_map.draw_rect(Rect2(a, b - a), color)


func _draw_map() -> void:
	if world == null:
		return
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.05, 0.12, 0.2))
	var city: City = world.city
	for isl in city.islands:
		_rect(isl["land"], Color(0.2, 0.24, 0.2))
		_rect(isl["grid"], Color(0.28, 0.3, 0.32))
		var c: Vector2 = isl["center"]
		_map.draw_string(ThemeDB.fallback_font, _to_map(c.x, c.y) - Vector2(60, 0), str(isl["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.8))
	for e in city.extra_land:
		_rect(e["rect"], Color(0.24, 0.26, 0.22))
	for b in city.bridges:
		_rect(b, Color(0.4, 0.4, 0.42))
	# Building footprints, lighter the taller they are.
	for b in city.buildings:
		var h: float = b["h"]
		_rect(b["rect"], Color(0.42, 0.44, 0.48).lerp(Color(0.75, 0.78, 0.84), clampf(h / 160.0, 0.0, 1.0)))
	# Entrances, subways and street stops
	for room in Interiors.placed:
		if not Interiors.is_remote(room):
			var op := Interiors.outside_point(room)
			var q := _to_map(op.x, op.z)
			_map.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color("#3aa0ff"))
	for st in city.subways:
		var sp: Vector3 = st["pos"]
		var q := _to_map(sp.x, sp.z)
		_map.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color("#3aff6a"))
		_map.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color.WHITE, false, 1.0)
	if _zoom >= 2.5:
		var cols := {"food_cart": Color("#ffb070"), "vending": Color("#6ad0ff"), "atm": Color("#6ad0ff"), "phone_booth": Color("#3a6aff"),
			"hoop": Color("#e8601a"), "fountain": Color("#bfe8ff")}
		for pt in city.points:
			if cols.has(pt["kind"]):
				var pp: Vector3 = pt["pos"]
				_map.draw_circle(_to_map(pp.x, pp.z), 2.5, cols[pt["kind"]])
	if world.collectibles:
		for s2 in world.collectibles.remaining():
			var fp: Vector3 = s2["pos"]
			if Game.progress["discovered"].size() > 6:
				_map.draw_circle(_to_map(fp.x, fp.z), 3.0, Color("#ff4fd8"))
	for l in city.landmarks:
		if l.get("interior", false):
			continue
		var p: Vector3 = l["pos"]
		var known := _known(l)
		_map.draw_circle(_to_map(p.x, p.z), 4.0, Color("#ffd23a") if known else Color(0.6, 0.6, 0.6, 0.6))
		if l == _selected:
			_map.draw_arc(_to_map(p.x, p.z), 9.0, 0, TAU, 16, Color.WHITE, 2.0)
	if not world.events.active.is_empty():
		var ep: Vector3 = world.events.active["pos"]
		_map.draw_circle(_to_map(ep.x, ep.z), 7.0, Color("#ffd23a"))
	var mp: Vector3 = world.missions.target_pos()
	if mp != Vector3.INF:
		_map.draw_circle(_to_map(mp.x, mp.z), 7.0, Color("#ff6a4a"))
	var cp: Vector3 = world.char_missions.target_pos()
	if cp != Vector3.INF:
		_map.draw_circle(_to_map(cp.x, cp.z), 7.0, Color("#3ab8ff"))
	if world.waypoint != Vector3.INF:
		var wp: Vector3 = world.waypoint
		_map.draw_circle(_to_map(wp.x, wp.z), 8.0, Color("#3affd0"))
	if world.player and is_instance_valid(world.player):
		var pp: Vector3 = world.player.global_position
		var s := _to_map(pp.x, pp.z)
		var f := Vector2(-sin(world.cam.yaw), -cos(world.cam.yaw))
		_map.draw_colored_polygon(PackedVector2Array([s + f * 12.0, s + f.rotated(2.5) * 8.0, s + f.rotated(-2.5) * 8.0]), Color.WHITE)
