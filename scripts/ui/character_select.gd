class_name CharacterSelect
extends CanvasLayer
## Roster browser with filters, search and a rotating 3D preview.

signal picked(id: String)
signal back

var swap_mode := false
var _suit_pick: OptionButton
var _filter := "all"
var _search := ""
var _grid: GridContainer
var _preview_root: Node3D
var _model: CharacterModel
var _name: Label
var _alias: Label
var _show: Label
var _bio: Label
var _stats: VBoxContainer
var _powers: Label
var _play: Button
var _selected := ""
var _filter_buttons: Dictionary = {}
var _team_pick: OptionButton
var _team := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme = UITheme.get_theme()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	margin.add_child(cols)

	# Left column: header, filters, grid.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	left.add_child(UITheme.label("CHOOSE YOUR CHARACTER", 34, UITheme.ACCENT))
	left.add_child(UITheme.label("%d heroes and %d villains from across the multiverse" % [Game.heroes().size(), Game.villains().size()], 16, UITheme.DIM))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for f in [["all", "All"], ["hero", "Heroes"], ["villain", "Villains"]]:
		var key: String = f[0]
		var b := UITheme.button(f[1], func() -> void: _set_filter(key), 120)
		b.toggle_mode = true
		_filter_buttons[key] = b
		bar.add_child(b)
	var search := LineEdit.new()
	search.placeholder_text = "Search names or shows..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(t: String) -> void:
		_search = t.to_lower()
		_rebuild())
	bar.add_child(search)
	_team_pick = OptionButton.new()
	_team_pick.add_item("All teams")
	for t in Teams.TEAMS.keys():
		_team_pick.add_item(t)
	_team_pick.item_selected.connect(func(i: int) -> void:
		_team = "" if i == 0 else str(Teams.TEAMS.keys()[i - 1])
		_rebuild())
	bar.add_child(_team_pick)
	bar.add_child(UITheme.button("Random", _pick_random, 110))
	left.add_child(bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	var bottom := HBoxContainer.new()
	bottom.add_child(UITheme.button("Back", func() -> void: back.emit(), 160))
	left.add_child(bottom)

	# Right column: preview and details.
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(500, 0)
	cols.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(470, 340)
	rv.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	_build_preview(sv)
	_name = UITheme.label("", 30, Color.WHITE)
	_alias = UITheme.label("", 17, UITheme.DIM)
	_show = UITheme.label("", 15, UITheme.ACCENT)
	_bio = UITheme.label("", 16)
	_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio.custom_minimum_size = Vector2(460, 0)
	rv.add_child(_name)
	rv.add_child(_alias)
	rv.add_child(_show)
	rv.add_child(_bio)
	_stats = VBoxContainer.new()
	rv.add_child(_stats)
	_powers = UITheme.label("", 15)
	_powers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_powers.custom_minimum_size = Vector2(460, 0)
	rv.add_child(_powers)
	_suit_pick = OptionButton.new()
	_suit_pick.item_selected.connect(_on_suit)
	rv.add_child(_suit_pick)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(spacer)
	_play = UITheme.button("PLAY", _confirm)
	_play.custom_minimum_size = Vector2(0, 56)
	_play.add_theme_font_size_override("font_size", 24)
	rv.add_child(_play)

	_set_filter("all")
	_select(Game.selected_id if Game.by_id.has(Game.selected_id) else Game.roster[0]["id"])


func open(swap: bool) -> void:
	swap_mode = swap
	visible = true
	_select(_selected if _selected != "" else Game.selected_id)


func _build_preview(sv: SubViewport) -> void:
	_preview_root = Node3D.new()
	sv.add_child(_preview_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_preview_root.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.6, 0)
	light.light_energy = 1.3
	_preview_root.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.6, 0.75, 1.0)
	_preview_root.add_child(rim)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.4
	floor_mesh.bottom_radius = 1.5
	floor_mesh.height = 0.1
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = CharacterModel.mat(Color(0.15, 0.17, 0.24))
	floor_mi.position = Vector3(0, -0.05, 0)
	_preview_root.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 4.2)
	cam.rotation.x = -0.08
	cam.fov = 40
	cam.current = true
	_preview_root.add_child(cam)


func _set_filter(f: String) -> void:
	_filter = f
	for k in _filter_buttons:
		_filter_buttons[k].set_pressed_no_signal(k == f)
	_rebuild()


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for c in Game.roster:
		if _filter != "all" and c["side"] != _filter:
			continue
		if _team != "" and not Teams.TEAMS[_team]["members"].has(c["id"]):
			continue
		if _search != "":
			var hay := ("%s %s %s" % [c["alias"], c["name"], c["show"]]).to_lower()
			if not hay.contains(_search):
				continue
		_grid.add_child(_card(c))


func _card(c: Dictionary) -> Button:
	var b := Button.new()
	var id: String = c["id"]
	b.text = c["alias"]
	b.custom_minimum_size = Vector2(170, 64)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side_col := UITheme.side_color(c["side"])
	var suit := Color(str(c["look"]["suit"]))
	var normal := UITheme.box(suit.darkened(0.55).lerp(Color(0.1, 0.12, 0.18), 0.4), 6, side_col * Color(1, 1, 1, 0.5))
	normal.border_width_left = 6
	normal.border_color = side_col
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = suit.darkened(0.3)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_font_size_override("font_size", 16)
	b.tooltip_text = "%s - %s" % [c["name"], c["show"]]
	b.pressed.connect(func() -> void:
		Sfx.play("click", null, -6.0, 0.0)
		_select(id))
	return b


## Alternate suits unlocked with Crisis Fragments.
func _fill_suits(id: String) -> void:
	_suit_pick.clear()
	_suit_pick.add_item("Suit: Classic")
	var variants := Costumes.unlocked(id)
	for v in variants:
		_suit_pick.add_item("Suit: " + str(v[1]))
	var chosen := str(Game.suit_choice.get(id, ""))
	for i in variants.size():
		if variants[i][1] == chosen:
			_suit_pick.select(i + 1)
	_suit_pick.visible = not variants.is_empty()


func _on_suit(index: int) -> void:
	var variants := Costumes.unlocked(_selected)
	Game.suit_choice[_selected] = "" if index == 0 else str(variants[index - 1][1])
	_select(_selected)


func _select(id: String) -> void:
	if not Game.by_id.has(id):
		return
	_selected = id
	var c: Dictionary = Costumes.apply(Game.by_id[id], str(Game.suit_choice.get(id, "")))
	_fill_suits(id)
	if _model:
		_model.queue_free()
	_model = CharacterModel.new()
	_preview_root.add_child(_model)
	_model.build(c["look"])
	var s := float(c["look"].get("scale", 1.0))
	_model.scale = Vector3.ONE * (1.0 / maxf(1.0, s * 0.85))
	_model.rotation.y = PI
	_name.text = c["alias"]
	_name.add_theme_color_override("font_color", UITheme.side_color(c["side"]).lightened(0.35))
	_alias.text = "%s  ·  %s" % [c["name"], "Hero" if c["side"] == "hero" else "Villain"]
	var teams := Teams.of(id)
	_show.text = str(c["show"]) + ("  ·  " + ", ".join(teams) if not teams.is_empty() else "")
	_bio.text = c["bio"]
	for k in _stats.get_children():
		k.queue_free()
	_stat("Health", float(c.get("health", 100)) / 260.0)
	_stat("Speed", 1.0 if c["movement"] == "speed" else float(c.get("speed", 1.0)) * 0.45 + (0.25 if c["movement"] == "flight" else 0.0))
	_stat("Power", float(c.get("power", 1.0)) / 1.45)
	var move_names := {"run": "Agile fighter", "speed": "Super speed", "flight": "Flight", "grapple": "Grappling line", "superjump": "Super jump"}
	var lines := PackedStringArray()
	lines.append("LMB  " + Abilities.describe(c["primary"]))
	lines.append("RMB  " + Abilities.describe(c["secondary"]))
	lines.append("Q    " + str(c["special"].get("name", c["special"]["kind"])))
	if c.has("utility"):
		lines.append("E    " + str(c["utility"].get("name", c["utility"]["kind"])))
	lines.append("R    ULTIMATE: " + str(Ultimate.for_character(c).get("name", "")))
	lines.append("Moves: " + move_names.get(c["movement"], c["movement"]) + ("  ·  Super strength" if c.get("strength", false) else ""))
	var lvl := Game.mastery_level(id)
	var next: String = "MAX" if lvl >= Game.MASTERY_XP.size() else "%d / %d XP" % [int(Game.mastery_xp(id)), Game.MASTERY_XP[lvl]]
	lines.append("Mastery level %d  (%s)" % [lvl, next])
	var nem := Teams.nemesis(id)
	if nem != "" and Game.by_id.has(nem):
		lines.append("Nemesis: " + str(Game.by_id[nem]["alias"]))
	_powers.text = "\n".join(lines)
	_play.text = ("BECOME " if swap_mode else "PLAY AS ") + str(c["alias"]).to_upper()


func _stat(label: String, value: float) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(label, 15, UITheme.DIM)
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(360, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.max_value = 1.0
	pb.value = clampf(value, 0.05, 1.0)
	var fill := UITheme.box(UITheme.ACCENT, 4)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	pb.add_theme_stylebox_override("fill", fill)
	row.add_child(pb)
	_stats.add_child(row)


func _pick_random() -> void:
	var pool: Array = Game.roster if _filter == "all" else Game.roster.filter(func(c): return c["side"] == _filter)
	_select(pool[randi() % pool.size()]["id"])


func _confirm() -> void:
	picked.emit(_selected)


func _process(delta: float) -> void:
	if _model and visible:
		_model.rotation.y += delta * 0.8
		_model.animate(delta, 0.0, true, false, 0.0, false)
