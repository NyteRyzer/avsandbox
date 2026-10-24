class_name QTE
extends CanvasLayer
## Quick-time events. Time slows while one runs, a big prompt shows which
## key to hit, and a ring or bar shows how long you have.
##
##   press    - hit one key before the ring closes
##   mash     - hammer a key to fill the bar before time runs out (it drains)
##   sequence - hit a run of keys in order, each in its own short window
##
## start(kind, opts, done) calls done(success) at the end. opts:
##   action (press/mash), actions (sequence), time (seconds per prompt),
##   presses (mash target), title (text above the prompt), slow (time scale)

signal ended(success: bool)

const KEY_NAMES := {"interact": "G", "attack": "LMB", "secondary": "RMB", "jump": "SPACE", "dodge": "V", "ability": "E",
	"special": "Q", "ultimate": "R", "block": "B", "fly": "F"}
const PAD_NAMES := {"interact": "D-UP", "attack": "RT", "secondary": "LT", "jump": "A", "dodge": "X", "ability": "RB",
	"special": "Y", "ultimate": "R3", "block": "D-RIGHT", "fly": "LB"}
const WRONG_KEYS := ["interact", "attack", "jump", "dodge", "ability", "special", "block"]

var world
var active := false
var kind := ""
var _actions: Array = []
var _step := 0
var _window := 1.5
var _t := 0.0
var _fill := 0.0
var _presses := 10.0
var _done: Callable
var _saved_scale := 1.0
var _root: Control
var _title: Label
var _key: Label
var _hint: Label
var _ring: Control
var _bar: ProgressBar
var _pulse := 0.0
var last_result := false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_title = _label(30, Color("#ffd23a"))
	_title.anchor_top = 0.26
	_title.anchor_bottom = 0.32
	_root.add_child(_title)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.anchor_left = 0.5
	_ring.anchor_right = 0.5
	_ring.anchor_top = 0.5
	_ring.anchor_bottom = 0.5
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_root.add_child(_ring)
	_key = _label(54, Color.WHITE)
	_key.anchor_top = 0.44
	_key.anchor_bottom = 0.56
	_root.add_child(_key)
	_hint = _label(18, Color("#e8e8e8"))
	_hint.anchor_top = 0.63
	_hint.anchor_bottom = 0.68
	_root.add_child(_hint)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_left = 0.36
	_bar.anchor_right = 0.64
	_bar.anchor_top = 0.69
	_bar.anchor_bottom = 0.71
	_bar.max_value = 1.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#ffd23a")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	_bar.add_theme_stylebox_override("fill", fg)
	_bar.add_theme_stylebox_override("background", bg)
	_root.add_child(_bar)
	_root.visible = false


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func key_name(action: String) -> String:
	if Input.get_connected_joypads().size() > 0:
		return PAD_NAMES.get(action, action.to_upper())
	return KEY_NAMES.get(action, action.to_upper())


func start(p_kind: String, opts: Dictionary, done := Callable()) -> void:
	if active:
		_finish(false)
	kind = p_kind
	_done = done
	_step = 0
	_t = 0.0
	_fill = 0.0
	_window = float(opts.get("time", 1.6 if kind != "mash" else 3.5))
	_presses = float(opts.get("presses", 12))
	match kind:
		"sequence":
			_actions = opts.get("actions", ["dodge", "jump", "attack"])
		_:
			_actions = [str(opts.get("action", "interact"))]
	active = true
	_title.text = str(opts.get("title", ""))
	_hint.text = {"press": "PRESS", "mash": "MASH", "sequence": "PRESS IN ORDER"}.get(kind, "")
	_bar.visible = kind == "mash"
	_root.visible = true
	_saved_scale = Engine.time_scale
	Engine.time_scale = float(opts.get("slow", 0.25))
	_show_key()
	Sfx.play("event", null, -6.0, 0.4)


func _show_key() -> void:
	var a: String = _actions[mini(_step, _actions.size() - 1)]
	_key.text = "[ %s ]" % key_name(a)
	if kind == "sequence":
		var parts := []
		for k in _actions.size():
			var n := key_name(_actions[k])
			parts.append(("> %s <" % n) if k == _step else ("✓" if k < _step else n))
		_hint.text = "  ".join(parts)


## Feeds one press in (the keyboard/pad does this; tests call it directly).
func press(action: String) -> void:
	if not active:
		return
	var want: String = _actions[mini(_step, _actions.size() - 1)]
	match kind:
		"mash":
			if action == want:
				_fill += 1.0 / _presses
				_pulse = 1.0
				Sfx.play("punch", null, -12.0, 0.3)
				if _fill >= 1.0:
					_finish(true)
		"press":
			if action == want:
				_finish(true)
			elif action in WRONG_KEYS:
				_finish(false)
		"sequence":
			if action == want:
				_step += 1
				_t = 0.0
				_pulse = 1.0
				Sfx.play("click", null, 0.0)
				if _step >= _actions.size():
					_finish(true)
				else:
					_show_key()
			elif action in WRONG_KEYS:
				_finish(false)


func _process(delta: float) -> void:
	if not active:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	for a in WRONG_KEYS + ["ultimate"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			press(a)
			if not active:
				return
	_t += real
	_pulse = maxf(0.0, _pulse - real * 4.0)
	_key.scale = Vector2.ONE * (1.0 + _pulse * 0.15)
	if kind == "mash":
		_fill = maxf(0.0, _fill - real * 0.12)
		_bar.value = _fill
	_ring.queue_redraw()
	if _t >= _window:
		_finish(false)


func _draw_ring() -> void:
	if not active:
		return
	var left := clampf(1.0 - _t / _window, 0.0, 1.0)
	var col := Color("#ffd23a").lerp(Color("#ff4a3a"), 1.0 - left)
	_ring.draw_arc(Vector2.ZERO, 84.0, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 10.0)
	_ring.draw_arc(Vector2.ZERO, 84.0, -PI * 0.5, -PI * 0.5 + TAU * left, 64, col, 8.0)


func _finish(success: bool) -> void:
	if not active:
		return
	active = false
	last_result = success
	_root.visible = false
	Engine.time_scale = _saved_scale if _saved_scale > 0.05 else 1.0
	if Game.slowmo_left <= 0.0:
		Engine.time_scale = 1.0
	Sfx.play("event" if success else "hit", null, -2.0 if success else -6.0)
	if world and world.hud:
		world.hud.show_banner("SUCCESS!" if success else "MISSED!", Color("#60ff90") if success else Color("#ff6a6a"))
	var cb := _done
	_done = Callable()
	ended.emit(success)
	if cb.is_valid():
		cb.call(success)


func cancel() -> void:
	if active:
		active = false
		_root.visible = false
		Engine.time_scale = 1.0
		_done = Callable()
