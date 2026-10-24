class_name SettingsPanel
extends VBoxContainer
## Settings controls shared by the title screen and the pause menu.

signal closed

const CONTROLS_TEXT := """MOVE          W A S D / left stick
LOOK          Mouse / right stick      ZOOM   Mouse wheel
JUMP          Space / A                SPRINT / SUPER SPEED   Shift / L3
PRIMARY       Left mouse / RT          SECONDARY              Right mouse / LT
SPECIAL       Q / Y                    UTILITY, LIFT & THROW  E / RB
ULTIMATE      R / R3                   FLY (flyers)           F / LB
DODGE         V / X                    BLOCK (tap to parry)   B / D-pad right
LOCK-ON       Z or middle mouse        INTERACT / TAKEDOWN    G / D-pad up
COSTUME       T / D-pad down           SWITCH TO ALLY         Y
SCAN          hold X                   MAP & FAST TRAVEL      M
PHOTO MODE    P                        EMOTES                 5 6 7 8
EXTRA POWERS  1 2 3                    WEAPON WHEEL           hold H
GLIDE (capes) hold Space while falling   TELEKINESIS  E (aim), LMB throws
LOADOUT       character select, or any HQ armory
SANDBOX TOOLS Tab / Back               PAUSE  Esc / Start      HIDE HUD  F1"""


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UITheme.label("SETTINGS", 28, UITheme.ACCENT))
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.05, 1.0, 0.01)
	_slider("Field of view", "fov", 55.0, 100.0, 1.0)
	_slider("Master volume", "volume", 0.0, 1.0, 0.05)
	_slider("Music volume", "music", 0.0, 1.0, 0.05)
	_slider("View distance", "view_distance", 300.0, 2000.0, 50.0)
	_slider("Difficulty (0 easy, 1 normal, 2 hard)", "difficulty", 0.0, 2.0, 1.0)
	_check("Invert look Y", "invert_y")
	_slider("Graphics (0 low, 1 medium, 2 high, 3 ultra)", "graphics", 0.0, 3.0, 1.0)
	_check("Shadows", "shadows")
	_check("Fullscreen", "fullscreen")
	_check("Mission cutscenes", "cutscenes")
	_check("Quick-time events in boss fights", "qte")
	add_child(HSeparator.new())
	add_child(UITheme.label("CONTROLS", 22, UITheme.ACCENT))
	var c := UITheme.label(CONTROLS_TEXT, 15, UITheme.TEXT)
	add_child(c)
	add_child(UITheme.button("Back", func() -> void:
		Game.save_settings()
		closed.emit(), 200))


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(text, 17)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Game.settings[key]
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := UITheme.label(_fmt(s.value), 16, UITheme.DIM)
	value_label.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v: float) -> void:
		Game.settings[key] = v
		value_label.text = _fmt(v)
		Game.apply_settings())
	row.add_child(s)
	row.add_child(value_label)
	add_child(row)


func _fmt(v: float) -> String:
	return str(int(v)) if v >= 10.0 else "%.2f" % v


func _check(text: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = Game.settings[key]
	cb.toggled.connect(func(on: bool) -> void:
		Game.settings[key] = on
		Game.apply_settings())
	add_child(cb)
