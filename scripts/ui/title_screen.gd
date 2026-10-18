class_name TitleScreen
extends CanvasLayer
## Animated title screen with a speed-force lightning backdrop.

signal play
signal quit

var _bolts: Control
var _menu: VBoxContainer
var _settings: SettingsPanel
var _t := 0.0
var _streaks: Array = []


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_bolts = Control.new()
	_bolts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bolts.draw.connect(_draw_bolts)
	add_child(_bolts)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.get_theme()
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var title := UITheme.label("CRISIS CITY", 96, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color("#a3111a"))
	v.add_child(title)
	var sub := UITheme.label("An unofficial Arrowverse open-world sandbox", 24, UITheme.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.custom_minimum_size = Vector2(340, 0)
	v.add_child(_menu)
	var play_b := UITheme.button("PLAY", func() -> void: play.emit())
	play_b.custom_minimum_size = Vector2(0, 56)
	play_b.add_theme_font_size_override("font_size", 26)
	_menu.add_child(play_b)
	_menu.add_child(UITheme.button("Settings & Controls", _open_settings))
	_menu.add_child(UITheme.button("Quit", func() -> void: quit.emit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	var sp := PanelContainer.new()
	sp.add_child(_settings)
	sp.visible = false
	sp.name = "SettingsHolder"
	v.add_child(sp)
	var foot := UITheme.label("Fan-made and non-commercial. Not affiliated with or endorsed by DC, Warner Bros. or The CW.\nAll characters and names belong to their respective owners.", 13, UITheme.DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.offset_top = -60
	foot.offset_bottom = -14
	add_child(foot)
	var ver := UITheme.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0")), 13, UITheme.DIM)
	ver.position = Vector2(14, 10)
	add_child(ver)


func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.get_parent().visible = true


func _close_settings() -> void:
	_settings.get_parent().visible = false
	_menu.visible = true


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 6.0:
		var size := _bolts.size
		var y := randf() * size.y
		var colors := [Color("#ffcc22"), Color("#ff2a2a"), Color("#3aa0ff"), Color("#c48bff")]
		_streaks.append({"y": y, "x": -200.0, "speed": randf_range(1400, 2600), "color": colors[randi() % colors.size()], "seed": randi()})
	for s in _streaks:
		s["x"] += s["speed"] * delta
	_streaks = _streaks.filter(func(s): return s["x"] < _bolts.size.x + 600.0)
	_bolts.queue_redraw()


func _draw_bolts() -> void:
	for s in _streaks:
		var r := RandomNumberGenerator.new()
		r.seed = s["seed"]
		var pts := PackedVector2Array()
		var x: float = s["x"]
		for k in 10:
			pts.append(Vector2(x - k * 50.0, s["y"] + r.randf_range(-14, 14)))
		var col: Color = s["color"]
		_bolts.draw_polyline(pts, Color(col, 0.25), 8.0)
		_bolts.draw_polyline(pts, Color(col, 0.9), 2.0)
