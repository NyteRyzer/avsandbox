class_name Hud
extends CanvasLayer
## In-game overlay: health and energy, ability bar with cooldowns, minimap,
## district and clock, event tracker, heat stars, score, notifications,
## crosshair and target info.

var world
var root: Control
var name_label: Label
var alias_label: Label
var hp_bar: ProgressBar
var energy_bar: ProgressBar
var ult_bar: ProgressBar
var status_label: Label
var ability_labels: Array[Label] = []
var minimap: Minimap
var district_label: Label
var clock_label: Label
var event_label: Label
var mission_label: Label
var heat_label: Label
var score_label: Label
var notes: VBoxContainer
var crosshair: Control
var target_label: Label
var target_bar: ProgressBar
var ko_label: Label
var banner: Label
var hint_label: Label
var _banner_t := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_hud_theme()
	add_child(root)

	# Top-left: identity, health, energy.
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(340, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	name_label = UITheme.label("", 24, Color.WHITE)
	alias_label = UITheme.label("", 15, UITheme.DIM)
	v.add_child(name_label)
	v.add_child(alias_label)
	hp_bar = _bar(Color("#e04848"))
	energy_bar = _bar(Color("#48a8e0"))
	v.add_child(hp_bar)
	v.add_child(energy_bar)
	ult_bar = _bar(Color("#ffd23a"))
	ult_bar.custom_minimum_size = Vector2(300, 8)
	v.add_child(ult_bar)
	status_label = UITheme.label("", 15, UITheme.ACCENT)
	v.add_child(status_label)

	# Bottom-left: abilities.
	var ab := PanelContainer.new()
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ab.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ab.position = Vector2(20, -200)
	ab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(ab)
	var av := VBoxContainer.new()
	ab.add_child(av)
	for i in 6:
		var l := UITheme.label("", 16)
		av.add_child(l)
		ability_labels.append(l)
	ab.anchor_top = 1.0
	ab.anchor_bottom = 1.0
	ab.offset_top = -214
	ab.offset_bottom = -20

	# Top-right: minimap and clock.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -250
	right.offset_right = -20
	right.offset_top = 20
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	minimap = Minimap.new()
	minimap.world = world
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(minimap)
	district_label = UITheme.label("", 18, Color.WHITE)
	district_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(district_label)
	clock_label = UITheme.label("", 15, Color("#c8d0e0"))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(clock_label)
	heat_label = UITheme.label("", 22, Color("#ff7040"))
	heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(heat_label)
	score_label = UITheme.label("", 16, UITheme.ACCENT)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(score_label)
	mission_label = UITheme.label("", 15, Color("#ffb08a"))
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size = Vector2(230, 0)
	mission_label.add_theme_constant_override("outline_size", 6)
	mission_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	right.add_child(mission_label)

	# Top-centre: event tracker.
	event_label = UITheme.label("", 20, Color("#ffe080"))
	event_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	event_label.anchor_left = 0.5
	event_label.anchor_right = 0.5
	event_label.offset_left = -400
	event_label.offset_right = 400
	event_label.offset_top = 24
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_constant_override("outline_size", 6)
	event_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	root.add_child(event_label)

	banner = UITheme.label("", 44, Color.WHITE)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = 110
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(banner)

	# Left-middle: notification feed.
	notes = VBoxContainer.new()
	notes.position = Vector2(20, 230)
	notes.custom_minimum_size = Vector2(520, 0)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes)

	# Centre: crosshair and target info.
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	target_label = UITheme.label("", 16, Color.WHITE)
	target_label.set_anchors_preset(Control.PRESET_CENTER)
	target_label.offset_left = -200
	target_label.offset_right = 200
	target_label.offset_top = -70
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_constant_override("outline_size", 6)
	target_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(target_label)
	target_bar = _bar(Color("#e04848"))
	target_bar.set_anchors_preset(Control.PRESET_CENTER)
	target_bar.offset_left = -80
	target_bar.offset_right = 80
	target_bar.offset_top = -44
	target_bar.offset_bottom = -36
	target_bar.custom_minimum_size = Vector2(160, 8)
	root.add_child(target_bar)

	hint_label = UITheme.label("", 16, Color(1, 1, 1, 0.85))
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.offset_left = -360
	hint_label.offset_right = 360
	hint_label.offset_top = 48
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(hint_label)

	ko_label = UITheme.label("", 56, Color("#ff5050"))
	ko_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko_label.add_theme_constant_override("outline_size", 12)
	ko_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ko_label.visible = false
	root.add_child(ko_label)

	Game.heat_changed.connect(_on_heat_changed)
	Game.score_changed.connect(_on_score_changed)
	_refresh_heat()
	_refresh_score()


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 14)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UITheme.box(color, 4)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	b.add_theme_stylebox_override("fill", fill)
	return b


func on_player_changed() -> void:
	var p: Actor = world.player
	name_label.text = p.def["alias"]
	name_label.add_theme_color_override("font_color", UITheme.side_color(p.def["side"]).lightened(0.3))
	alias_label.text = "%s  ·  %s  ·  %s" % [p.def["name"], "Hero" if p.def["side"] == "hero" else "Villain", p.def["show"]]
	_refresh_score()


func notify(text: String, color := Color.WHITE) -> void:
	var l := UITheme.label(text, 17, color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notes.add_child(l)
	while notes.get_child_count() > 6:
		notes.get_child(0).queue_free()
		notes.remove_child(notes.get_child(0))
	var t := l.create_tween()
	t.tween_interval(4.5)
	t.tween_property(l, "modulate:a", 0.0, 1.0)
	t.tween_callback(l.queue_free)


## A big centred title, e.g. an ultimate's name or a mission update.
func show_banner(text: String, color := Color.WHITE) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	_banner_t = 3.0


func show_district(d: String) -> void:
	banner.add_theme_color_override("font_color", Color.WHITE)
	banner.text = d
	banner.modulate.a = 1.0
	_banner_t = 3.0


func show_ko(on: bool, text := "") -> void:
	ko_label.visible = on
	ko_label.text = text + "\n\nRespawning..."


func _on_heat_changed(_v: float) -> void:
	_refresh_heat()


func _on_score_changed(_v: int) -> void:
	_refresh_score()


func _refresh_heat() -> void:
	var n := int(floorf(Game.heat))
	heat_label.text = "HEAT  " + "*".repeat(n) + "-".repeat(5 - n) if n > 0 else ""


func _refresh_score() -> void:
	var villain := Game.player_side() == -1
	score_label.text = "%s: %d\nRank %d · %s" % ["Infamy" if villain else "Reputation", Game.score, Game.rank(), Game.rank_title(Game.player_side())]


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var p: Actor = world.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	energy_bar.max_value = p.max_energy
	energy_bar.value = p.energy
	var status := PackedStringArray()
	if p.flying:
		status.append("FLYING")
	if Game.slowmo_left > 0.0:
		status.append("SLOW-MO %.1fs" % Game.slowmo_left)
	if p.shrunk:
		status.append("SHRUNK")
	if p.invis_t > 0.0:
		status.append("INVISIBLE")
	if p.invuln_t > 0.0:
		status.append("INVULNERABLE")
	if p.rage_t > 0.0:
		status.append("POWERED UP")
	if p.frozen_t > 0.0:
		status.append("FROZEN")
	if p.burn_t > 0.0:
		status.append("BURNING")
	if p.swimming:
		status.append("SWIMMING")
	if p.held_prop:
		status.append("CARRYING")
	status_label.text = "  ".join(status)

	var d: Dictionary = p.def
	ability_labels[0].text = "[LMB]  " + Abilities.describe(d["primary"]) + _cd(p, "primary")
	ability_labels[1].text = "[RMB]  " + Abilities.describe(d["secondary"]) + _cd(p, "secondary")
	ability_labels[2].text = "[Q]  " + str(d["special"].get("name", d["special"]["kind"])) + _cd(p, "special")
	var e_text := ""
	var util := p.utility_name()
	if util != "":
		e_text = "[E]  " + util + _cd(p, "utility")
	if p.strength:
		e_text += ("  ·  " if e_text != "" else "[E]  ") + "Lift / throw"
	ability_labels[3].text = e_text
	var move_text := ""
	match p.movement:
		"speed":
			move_text = "[Shift]  Super speed  (run up walls, across water)"
		"flight":
			move_text = "[F]  Fly  ·  [Space/Ctrl] up/down  ·  [Shift] boost"
		"hover":
			move_text = "Hover chair  ·  [Space/Ctrl] up/down"
		"superjump":
			move_text = "[Space]  Super jump"
		"ice":
			move_text = "[Shift]  Ice slide"
		_:
			move_text = "[Shift]  Sprint"
	move_text += "   ·   [V] Dodge"
	if p.combo_count >= 3:
		move_text += "   ·   %d HIT COMBO" % p.combo_count
	ability_labels[4].text = move_text
	var u := Ultimate.for_character(d)
	ult_bar.value = p.ult
	if p.ult_active:
		ability_labels[5].text = "[R]  " + str(u.get("name", "Ultimate")) + "   ACTIVE"
	elif p.ult >= 100.0:
		ability_labels[5].text = "[R]  " + str(u.get("name", "Ultimate")) + "   READY!"
	else:
		ability_labels[5].text = "[R]  %s   %d%%" % [u.get("name", "Ultimate"), int(p.ult)]
	ability_labels[5].add_theme_color_override("font_color", UITheme.ACCENT if p.ult >= 100.0 or p.ult_active else UITheme.DIM)
	ability_labels[2].add_theme_color_override("font_color", UITheme.ACCENT if p.cooldowns["special"] <= 0.0 and p.energy >= Abilities.special_cost(d["special"]) else UITheme.DIM)

	district_label.text = world.place_name(p.global_position)
	hint_label.text = world.interact_prompt()
	if world.ship.piloted:
		hint_label.text = "WAVERIDER  ·  [Shift] boost  ·  [LMB] cannons  ·  [Q] time jump  ·  [G] leave the helm"
	var h: float = world.day_night.hour
	clock_label.text = "%02d:%02d  ·  %s" % [int(h), int(fmod(h, 1.0) * 60.0), world.day_night.weather.capitalize()]

	mission_label.text = world.missions.tracker()
	if world.race.active:
		mission_label.text = world.race.tracker() + "\n\n" + mission_label.text
	var ev: Dictionary = world.events.active
	if ev.is_empty():
		event_label.text = ""
	else:
		var to: Vector3 = ev["pos"] - p.global_position
		event_label.text = "%s\n%d m  ·  %d / %d left" % [ev["title"], int(Vector2(to.x, to.z).length()), ev["remaining"], ev["total"]]

	if _banner_t > 0.0:
		_banner_t -= delta
		banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_update_target(p)
	crosshair.queue_redraw()


func _cd(p: Actor, slot: String) -> String:
	var c: float = p.cooldowns[slot]
	return "   (%.1fs)" % c if c > 0.25 else ""


func _update_target(p: Actor) -> void:
	target_label.text = ""
	target_bar.visible = false
	hint_label.text = ""
	var cam: Camera3D = world.cam.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * 120.0
	var exclude: Array[RID] = [p.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_ACTORS | Game.LAYER_WORLD, exclude)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Actor:
		var a: Actor = hit["collider"]
		var tag := ""
		if a.is_ally_of_player():
			tag = "  (ally)"
		elif a.is_hostile_to(p):
			tag = "  (hostile)"
		target_label.text = a.display_name + tag
		target_label.add_theme_color_override("font_color", Color("#ff8080") if tag == "  (hostile)" else (Color("#9fd0ff") if tag != "" else Color.WHITE))
		target_bar.visible = true
		target_bar.max_value = a.max_hp
		target_bar.value = a.hp
	if p.strength and p.held_prop == null:
		for prop in world.get_tree().get_nodes_in_group("props"):
			if prop.global_position.distance_to(p.global_position) < 5.0 * p.size:
				hint_label.text = "[E] Lift " + ("car" if prop.kind == "car" else "crate")
				break
	elif p.held_prop:
		hint_label.text = "[LMB / E] Throw"


func _draw_crosshair() -> void:
	var c := Color(1, 1, 1, 0.85)
	crosshair.draw_line(Vector2(-10, 0), Vector2(-4, 0), c, 2.0)
	crosshair.draw_line(Vector2(4, 0), Vector2(10, 0), c, 2.0)
	crosshair.draw_line(Vector2(0, -10), Vector2(0, -4), c, 2.0)
	crosshair.draw_line(Vector2(0, 4), Vector2(0, 10), c, 2.0)
	crosshair.draw_circle(Vector2.ZERO, 1.5, c)
