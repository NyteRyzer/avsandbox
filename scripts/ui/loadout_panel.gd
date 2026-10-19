class_name LoadoutPanel
extends CanvasLayer
## The loadout screen: pick each slot's power or weapon for one character.
## Opened from character select or from an armory (S.T.A.R. Labs, the
## Bunker, the Batcave...).

signal closed(changed: bool)

var id := ""
var _rows: VBoxContainer
var _title: Label
var _info: Label
var _changed := false
var _was_paused := false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.get_theme()
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.08, 0.12, 0.96), 12))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_title = UITheme.label("LOADOUT", 30, UITheme.ACCENT)
	v.add_child(_title)
	v.add_child(UITheme.label("Signature powers first, then alternates, powers that fit the character, and the armory's weapons.", 15, UITheme.DIM))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	v.add_child(_rows)
	_info = UITheme.label("", 15, Color("#c8e8ff"))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.add_child(UITheme.button("Reset to signature kit", func() -> void:
		Loadout.reset(id)
		_changed = true
		_fill(), 260))
	bar.add_child(UITheme.button("Done", close, 200))
	v.add_child(bar)


func open(char_id: String) -> void:
	id = char_id
	_changed = false
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_fill()


func close() -> void:
	visible = false
	get_tree().paused = _was_paused
	closed.emit(_changed)


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var def: Dictionary = Game.get_character(id)
	_title.text = "LOADOUT: " + str(def.get("alias", id)).to_upper()
	var saved := Loadout.saved(id)
	for slot in Loadout.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UITheme.label(Loadout.SLOT_NAMES[slot], 16, UITheme.DIM)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var pick := OptionButton.new()
		pick.custom_minimum_size = Vector2(540, 0)
		var opts := Loadout.options(def, slot)
		for o in opts:
			pick.add_item("%s   [%s]" % [o.get("name", o.get("kind", "")), o.get("_source", "")])
		pick.selected = clampi(int(saved.get(slot, 0)), 0, opts.size() - 1)
		var s: String = slot
		pick.item_selected.connect(func(i: int) -> void:
			Loadout.choose(id, s, i)
			_changed = true
			_update_info())
		row.add_child(pick)
		_rows.add_child(row)
	_update_info()


func _update_info() -> void:
	var c := Loadout.apply(Game.get_character(id))
	_info.text = "Taking: " + Loadout.describe(c)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
