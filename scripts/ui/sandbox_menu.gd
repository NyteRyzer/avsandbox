class_name SandboxMenu
extends CanvasLayer
## Tab menu of sandbox tools: spawn any character as an ally or enemy, drop
## props, crowds, gangs and police, control time, weather and gravity, start
## events, toggle cheats and teleport around the city.

var world
var _char_pick: OptionButton
var _ids: Array = []
var _time_slider: HSlider
var _time_label: Label
var _freeze: CheckBox


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.get_theme()
	add_child(center)
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(820, 560)
	center.add_child(outer)
	var head := HBoxContainer.new()
	var title := UITheme.label("SANDBOX TOOLS", 30, UITheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.button("Close  [Tab]", close, 160))
	outer.add_child(head)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	tabs.add_child(_spawn_tab())
	tabs.add_child(_world_tab())
	tabs.add_child(_events_tab())
	tabs.add_child(_cheats_tab())
	tabs.add_child(_teleport_tab())


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if world.pause_menu.visible:
		return
	visible = true
	_time_slider.set_value_no_signal(world.day_night.hour)
	_time_label.text = _hour_text(world.day_night.hour)
	_freeze.set_pressed_no_signal(world.day_night.frozen)
	get_tree().paused = true
	world.capture_mouse(false)


func close() -> void:
	visible = false
	get_tree().paused = false
	world.capture_mouse(true)


func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: the GUI would otherwise eat Tab for focus.
	if visible and (event.is_action_pressed("sandbox_menu") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _page(name: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = name
	v.add_theme_constant_override("separation", 10)
	return v


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	return g


func _spawn_tab() -> Control:
	var v := _page("Spawn")
	v.add_child(UITheme.label("Character", 20, UITheme.ACCENT))
	_char_pick = OptionButton.new()
	var sorted := Game.roster.duplicate()
	sorted.sort_custom(func(a, b): return str(a["alias"]) < str(b["alias"]))
	for c in sorted:
		_char_pick.add_item("%s  (%s)" % [c["alias"], "Hero" if c["side"] == "hero" else "Villain"])
		_ids.append(c["id"])
	v.add_child(_char_pick)
	var g := _grid(2)
	g.add_child(UITheme.button("Spawn as ally", func() -> void: _spawn_selected(true), 380))
	g.add_child(UITheme.button("Spawn as enemy", func() -> void: _spawn_selected(false), 380))
	g.add_child(UITheme.button("Random allied team (3)", func() -> void: _spawn_random(true, 3), 380))
	g.add_child(UITheme.button("Random enemy squad (3)", func() -> void: _spawn_random(false, 3), 380))
	v.add_child(g)
	v.add_child(UITheme.label("People and props", 20, UITheme.ACCENT))
	var g2 := _grid(3)
	g2.add_child(UITheme.button("Civilians x10", func() -> void: _crowd("civilian", 10), 250))
	g2.add_child(UITheme.button("Gang x5", func() -> void: _crowd("thug", 5), 250))
	g2.add_child(UITheme.button("Police squad x5", func() -> void: _crowd("police", 5), 250))
	g2.add_child(UITheme.button("Car", func() -> void: world.spawn_prop_here("car"), 250))
	g2.add_child(UITheme.button("Crate stack", _crates, 250))
	g2.add_child(UITheme.button("Clear all NPCs", func() -> void: world.clear_npcs(), 250))
	v.add_child(g2)
	return v


func _spawn_selected(ally: bool) -> void:
	world.spawn_npc_character(_ids[_char_pick.selected], ally)


func _spawn_random(ally: bool, n: int) -> void:
	for k in n:
		world.spawn_npc_character(Game.random_character()["id"], ally)


func _crowd(kind: String, n: int) -> void:
	var p: Vector3 = world.player.global_position
	var fwd: Vector3 = -world.cam.global_basis.z
	fwd.y = 0
	var base := p + fwd.normalized() * 14.0
	for k in n:
		var pos := base + Vector3(randf_range(-5, 5), 0.3, randf_range(-5, 5))
		pos.y = maxf(p.y, 0.3)
		match kind:
			"civilian":
				world.population.spawn_civilian(pos)
			"thug":
				world.population.spawn_thug(pos).set_meta("pinned", true)
			"police":
				world.population.spawn_police(pos).set_meta("pinned", true)


func _crates() -> void:
	for k in 6:
		world.spawn_prop_here("crate")


func _world_tab() -> Control:
	var v := _page("World")
	v.add_child(UITheme.label("Time of day", 20, UITheme.ACCENT))
	var row := HBoxContainer.new()
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 23.99
	_time_slider.step = 0.05
	_time_slider.custom_minimum_size = Vector2(520, 24)
	_time_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time_label = UITheme.label("", 18)
	_time_slider.value_changed.connect(func(h: float) -> void:
		world.day_night.hour = h
		world.day_night._apply()
		_time_label.text = _hour_text(h))
	row.add_child(_time_slider)
	row.add_child(_time_label)
	v.add_child(row)
	_freeze = CheckBox.new()
	_freeze.text = "Freeze time"
	_freeze.toggled.connect(func(on: bool) -> void: world.day_night.frozen = on)
	v.add_child(_freeze)
	var presets := HBoxContainer.new()
	for pair in [["Dawn", 6.5], ["Noon", 12.0], ["Sunset", 18.6], ["Midnight", 0.0]]:
		var h: float = pair[1]
		presets.add_child(UITheme.button(pair[0], func() -> void:
			_time_slider.value = h, 120))
	v.add_child(presets)
	v.add_child(UITheme.label("Weather", 20, UITheme.ACCENT))
	var wrow := HBoxContainer.new()
	for w in ["clear", "rain", "storm", "fog"]:
		var ww: String = w
		wrow.add_child(UITheme.button(w.capitalize(), func() -> void: world.day_night.set_weather(ww), 120))
	v.add_child(wrow)
	v.add_child(UITheme.label("Gravity", 20, UITheme.ACCENT))
	var grow := HBoxContainer.new()
	var gs := HSlider.new()
	gs.min_value = 0.15
	gs.max_value = 2.0
	gs.step = 0.05
	gs.value = 1.0
	gs.custom_minimum_size = Vector2(520, 24)
	gs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gl := UITheme.label("1.00x", 18)
	gs.value_changed.connect(func(g: float) -> void:
		world.gravity_scale = g
		gl.text = "%.2fx" % g)
	grow.add_child(gs)
	grow.add_child(gl)
	v.add_child(grow)
	var pop := CheckBox.new()
	pop.text = "Ambient population (civilians, police, gangs)"
	pop.button_pressed = true
	pop.toggled.connect(func(on: bool) -> void: world.population.enabled = on)
	v.add_child(pop)
	return v


func _hour_text(h: float) -> String:
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


func _events_tab() -> Control:
	var v := _page("Events")
	v.add_child(UITheme.label("Start an event near you", 20, UITheme.ACCENT))
	var g := _grid(2)
	var names := {
		"robbery": "Robbery in progress", "gang_war": "Gang war", "villain_attack": "Super-villain attack",
		"breach": "Breach: doppelgangers", "police_raid": "Police raid", "hero_patrol": "Hero patrol",
		"heist": "Armored-truck heist",
	}
	for k in names.keys():
		var kind: String = k
		g.add_child(UITheme.button(names[k], func() -> void:
			world.events.start_random(kind)
			close(), 380))
	v.add_child(g)
	v.add_child(UITheme.label("Heroes get robberies, gang wars and villain attacks;\nvillains get raids, patrols and heists. Breaches hit everyone.", 15, UITheme.DIM))
	return v


func _cheats_tab() -> Control:
	var v := _page("Cheats")
	var labels := {"god_mode": "God mode (take no damage)", "infinite_energy": "Infinite energy",
		"one_hit_ko": "One-hit knockouts", "no_heat": "No heat (police ignore you)"}
	for key in labels.keys():
		var k: String = key
		var cb := CheckBox.new()
		cb.text = labels[key]
		cb.button_pressed = Game.cheats[k]
		cb.toggled.connect(func(on: bool) -> void:
			Game.cheats[k] = on
			if k == "no_heat" and on:
				Game.clear_heat())
		v.add_child(cb)
	var row := HBoxContainer.new()
	row.add_child(UITheme.button("Clear heat", func() -> void: Game.clear_heat(), 200))
	row.add_child(UITheme.button("Full heal", func() -> void:
		world.player.heal(99999.0)
		world.player.energy = world.player.max_energy, 200))
	v.add_child(row)
	return v


func _teleport_tab() -> Control:
	var v := _page("Teleport")
	v.add_child(UITheme.label("Landmarks", 20, UITheme.ACCENT))
	var g := _grid(3)
	for l in world.city.landmarks:
		var pos: Vector3 = l["pos"]
		g.add_child(UITheme.button(l["name"], func() -> void:
			world.teleport_player(pos)
			close(), 250))
	v.add_child(g)
	return v
