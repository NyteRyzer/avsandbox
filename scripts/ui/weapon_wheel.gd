class_name WeaponWheel
extends CanvasLayer
## The weapon wheel: hold H, flick the mouse (or right stick) toward a weapon
## or power, let go to equip it. Time slows while it's open. Mouse wheel or
## Q / E flip between rings: primary, secondary, special, utility, emotes.

const RINGS := ["primary", "secondary", "special", "utility", "emotes"]
const RING_NAMES := {"primary": "PRIMARY (LMB)", "secondary": "SECONDARY (RMB)", "special": "POWER (Q)", "utility": "UTILITY (E)", "emotes": "EMOTES"}
const EMOTES := [{"name": "Wave"}, {"name": "Cheer"}, {"name": "Taunt"}, {"name": "Victory pose"}]
const MAX_SLICES := 12

var world
var ring := 0
var options: Array = []
var selected := -1
var _aim := Vector2.ZERO
var _canvas: Control
var _saved_scale := 1.0


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_wheel)
	add_child(_canvas)


func open() -> void:
	if visible or world.player == null or not is_instance_valid(world.player) or world.player.civilian:
		return
	visible = true
	_aim = Vector2.ZERO
	selected = -1
	_saved_scale = Engine.time_scale
	if Engine.time_scale > 0.3:
		Engine.time_scale = 0.25
	_load_ring()


func close(apply := true) -> void:
	if not visible:
		return
	visible = false
	Engine.time_scale = _saved_scale if _saved_scale < 0.99 else 1.0
	if apply and selected >= 0 and selected < options.size():
		_apply(selected)


func _base_def() -> Dictionary:
	var id := str(world.player.def.get("id", ""))
	return Costumes.apply(Game.get_character(id), str(Game.suit_choice.get(id, "")))


func _load_ring() -> void:
	var slot: String = RINGS[ring]
	if slot == "emotes":
		options = EMOTES
	else:
		options = Loadout.options(_base_def(), slot).slice(0, MAX_SLICES)
	selected = -1
	_canvas.queue_redraw()


func _apply(i: int) -> void:
	var slot: String = RINGS[ring]
	var p: Actor = world.player
	if slot == "emotes":
		Emotes.play(p, i + 1)
		return
	var id := str(p.def.get("id", ""))
	Loadout.choose(id, slot, i)
	p.set_kit(Loadout.apply(_base_def()))
	world.notify("%s: %s" % [RING_NAMES[slot], options[i].get("name", "")], Color("#c8e8ff"))
	FX.flash(world, p.model.hand_point(1.0), Color("#c8e8ff"), 0.6, 0.2, 0.6)
	Game.record("wheel_swaps")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_aim = (_aim + event.relative).limit_length(160.0)
		_pick()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var v := Vector2(Input.get_joy_axis(event.device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(event.device, JOY_AXIS_RIGHT_Y))
		if v.length() > 0.4:
			_aim = v * 160.0
			_pick()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		ring = (ring + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1) + RINGS.size()) % RINGS.size()
		_load_ring()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("special") or event.is_action_pressed("ability"):
		ring = (ring + (1 if event.is_action_pressed("ability") else -1) + RINGS.size()) % RINGS.size()
		_load_ring()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		close(false)
		get_viewport().set_input_as_handled()


func _pick() -> void:
	if _aim.length() < 30.0 or options.is_empty():
		selected = -1
	else:
		var ang := fposmod(atan2(_aim.x, -_aim.y), TAU)
		selected = int(round(ang / (TAU / options.size()))) % options.size()
	_canvas.queue_redraw()


func _draw_wheel() -> void:
	if not visible:
		return
	var size := _canvas.size
	var c := size * 0.5
	var r_out := minf(size.x, size.y) * 0.36
	var r_in := r_out * 0.36
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var n := maxi(1, options.size())
	var font := ThemeDB.fallback_font
	var cur := _current_index()
	for i in options.size():
		var a0 := (i - 0.5) * TAU / n - PI * 0.5
		var a1 := (i + 0.5) * TAU / n - PI * 0.5
		var pts := PackedVector2Array()
		for k in 9:
			var a := lerpf(a0, a1, k / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r_out)
		for k in 9:
			var a := lerpf(a1, a0, k / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r_in)
		var col := Color(0.08, 0.1, 0.16, 0.85)
		if i == cur:
			col = Color(0.16, 0.3, 0.2, 0.9)
		if i == selected:
			col = Color(0.25, 0.45, 0.8, 0.95)
		_canvas.draw_colored_polygon(pts, col)
		_canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.25), 1.5)
		var mid := (a0 + a1) * 0.5
		var lp := c + Vector2(cos(mid), sin(mid)) * (r_in + r_out) * 0.5
		var label := str(options[i].get("name", options[i].get("kind", "")))
		_canvas.draw_string(font, lp - Vector2(80, 2), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color.WHITE)
		var src := str(options[i].get("_source", ""))
		if src != "":
			_canvas.draw_string(font, lp + Vector2(-80, 15), src, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color(0.75, 0.85, 1.0, 0.8))
	_canvas.draw_circle(c, r_in * 0.92, Color(0.04, 0.05, 0.08, 0.92))
	var title: String = RING_NAMES[RINGS[ring]]
	_canvas.draw_string(font, c - Vector2(100, 8), title, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, UITheme.ACCENT)
	_canvas.draw_string(font, c + Vector2(-100, 16), "wheel / Q E: change ring", HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(1, 1, 1, 0.6))
	if selected >= 0 and selected < options.size():
		_canvas.draw_string(font, c + Vector2(-100, 38), "release H to equip", HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color("#9fd8ff"))
	_canvas.draw_line(c, c + _aim.limit_length(r_in * 0.9), Color(1, 1, 1, 0.5), 2.0)


## Which option is equipped right now (highlighted green).
func _current_index() -> int:
	var slot: String = RINGS[ring]
	if slot == "emotes":
		return -1
	var p: Actor = world.player
	if p == null or not is_instance_valid(p):
		return -1
	var have: String = str(p.def.get(slot, {}).get("name", "None"))
	for i in options.size():
		if str(options[i].get("name", "")) == have:
			return i
	return -1
