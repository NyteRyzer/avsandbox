class_name UITheme
extends RefCounted
## Shared look for every menu and HUD element.

const BG := Color(0.04, 0.05, 0.09, 0.88)
const PANEL := Color(0.08, 0.1, 0.16, 0.92)
const ACCENT := Color("#ffcc22")
const HERO := Color("#5fa8ff")
const VILLAIN := Color("#ff5050")
const TEXT := Color("#e8ecf4")
const DIM := Color("#8a93a8")

static var _theme: Theme
static var _hud_theme: Theme


static func get_hud_theme() -> Theme:
	if _hud_theme:
		return _hud_theme
	_hud_theme = get_theme().duplicate()
	_hud_theme.set_constant("outline_size", "Label", 6)
	_hud_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	return _hud_theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	var glass := box(PANEL, 12, Color(1, 1, 1, 0.1))
	glass.shadow_color = Color(0, 0, 0, 0.35)
	glass.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", glass)
	t.set_stylebox("panel", "Panel", glass)
	t.set_stylebox("normal", "Button", box(Color(0.12, 0.15, 0.23), 8, Color(1, 1, 1, 0.1)))
	var hover := box(Color(0.18, 0.23, 0.35), 8, ACCENT * Color(1, 1, 1, 0.5))
	hover.border_width_left = 4
	hover.border_color = ACCENT
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.26, 0.1), 8, ACCENT))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 6, ACCENT))
	t.set_stylebox("disabled", "Button", box(Color(0.1, 0.11, 0.15), 6, Color(1, 1, 1, 0.04)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), 4))
	t.set_stylebox("fill", "ProgressBar", box(Color("#e04848"), 4))
	t.set_stylebox("panel", "TabContainer", box(PANEL, 8))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.2, 0.25, 0.37), 6))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.1, 0.12, 0.18), 6))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.16, 0.2, 0.3), 6))
	t.set_stylebox("normal", "LineEdit", box(Color(0.06, 0.07, 0.11), 6, Color(1, 1, 1, 0.12)))
	t.set_stylebox("normal", "OptionButton", box(Color(0.14, 0.17, 0.25), 6, Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover", "OptionButton", box(Color(0.2, 0.25, 0.37), 6, ACCENT * Color(1, 1, 1, 0.6)))
	_theme = t
	return t


static func box(color: Color, radius := 6, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_width := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 40)
	var on_press := func() -> void:
		Sfx.play("click", null, -6.0, 0.0)
		callback.call()
	b.pressed.connect(on_press)
	return b


static func side_color(side: String) -> Color:
	return HERO if side == "hero" else VILLAIN
