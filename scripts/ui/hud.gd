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
var style_label: Label
var boss_panel: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_trail: ProgressBar     # the chunk you just took off, draining after a beat
var boss_sub: Label
var boss_tag: Label
var _trail_hold := 0.0
var _last_boss: Actor = null
var overlay: Control      # lock-on marker and other world-space markers
var ticker: Label
var card: PanelContainer
var portrait: Control
var hp_text: Label
var ability_bar: AbilityBar
var move_hint: Label
var tracker_panel: PanelContainer


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_hud_theme()
	add_child(root)

	# Top-left: identity, health, energy.
	card = PanelContainer.new()
	card.position = Vector2(20, 20)
	card.custom_minimum_size = Vector2(360, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 12)
	card.add_child(card_row)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.draw.connect(_draw_portrait)
	card_row.add_child(portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card_row.add_child(v)
	name_label = UITheme.label("", 22, Color.WHITE)
	alias_label = UITheme.label("", 13, UITheme.DIM)
	v.add_child(name_label)
	v.add_child(alias_label)
	var hp_row := HBoxContainer.new()
	hp_bar = _bar(Color("#e04848"))
	hp_bar.custom_minimum_size = Vector2(200, 14)
	hp_row.add_child(hp_bar)
	hp_text = UITheme.label("", 12, Color("#ffd0d0"))
	hp_row.add_child(hp_text)
	v.add_child(hp_row)
	energy_bar = _bar(Color("#48a8e0"))
	energy_bar.custom_minimum_size = Vector2(200, 8)
	v.add_child(energy_bar)
	ult_bar = _bar(Color("#ffd23a"))
	ult_bar.custom_minimum_size = Vector2(200, 6)
	v.add_child(ult_bar)
	status_label = UITheme.label("", 15, UITheme.ACCENT)
	v.add_child(status_label)

	# Bottom-centre: the ability bar (the old text list stays, hidden, for tools).
	ability_bar = AbilityBar.new()
	ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ability_bar.anchor_left = 0.5
	ability_bar.anchor_right = 0.5
	ability_bar.anchor_top = 1.0
	ability_bar.anchor_bottom = 1.0
	ability_bar.offset_top = -132
	ability_bar.offset_bottom = -54
	root.add_child(ability_bar)
	move_hint = UITheme.label("", 13, Color(1, 1, 1, 0.75))
	move_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	move_hint.anchor_left = 0.5
	move_hint.anchor_right = 0.5
	move_hint.anchor_top = 1.0
	move_hint.anchor_bottom = 1.0
	move_hint.offset_left = -500
	move_hint.offset_right = 500
	move_hint.offset_top = -154
	move_hint.offset_bottom = -134
	move_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(move_hint)
	var ab := PanelContainer.new()
	ab.visible = false
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
	right.offset_left = -256
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
	var tracker := PanelContainer.new()
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_stylebox_override("panel", _accent_box(Color("#ff9a6a")))
	right.add_child(tracker)
	var tv := VBoxContainer.new()
	tracker.add_child(tv)
	tv.add_child(UITheme.label("OBJECTIVES", 13, Color("#ff9a6a")))
	mission_label = UITheme.label("", 14, Color("#ffd8c8"))
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size = Vector2(206, 0)
	tv.add_child(mission_label)
	tracker_panel = tracker

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
	notes.position = Vector2(20, 150)
	notes.custom_minimum_size = Vector2(470, 0)
	notes.add_theme_constant_override("separation", 4)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes)

	# Centre: crosshair and target info.
	style_label = UITheme.label("", 30, UITheme.ACCENT)
	style_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	style_label.anchor_left = 1.0
	style_label.offset_left = -330
	style_label.offset_right = -270
	style_label.offset_top = -120
	style_label.add_theme_constant_override("outline_size", 8)
	style_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(style_label)
	boss_panel = VBoxContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -330
	boss_panel.offset_right = 330
	boss_panel.offset_top = 64
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	root.add_child(boss_panel)
	boss_name = UITheme.label("", 24, Color("#ffd0c0"))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_constant_override("outline_size", 8)
	boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	boss_panel.add_child(boss_name)
	boss_sub = UITheme.label("", 13, Color("#d8c0b8"))
	boss_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_sub.add_theme_constant_override("outline_size", 5)
	boss_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	boss_panel.add_child(boss_sub)
	# The bar: a dark frame, the pale damage trail behind, the red health in
	# front, and notches where the fight's phases begin.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.7), 3))
	frame.custom_minimum_size = Vector2(660, 22)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(frame)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(652, 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)
	boss_trail = _bar(Color("#f0e0c0"))
	boss_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_trail.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	stack.add_child(boss_trail)
	boss_bar = _bar(Color("#c82828"))
	boss_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	stack.add_child(boss_bar)
	for f in [0.66, 0.33, 0.1]:
		var notch := ColorRect.new()
		notch.color = Color(1, 1, 1, 0.75) if f > 0.2 else Color("#ffd23a")
		notch.anchor_left = f
		notch.anchor_right = f
		notch.anchor_top = 0.0
		notch.anchor_bottom = 1.0
		notch.offset_left = -1
		notch.offset_right = 1
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(notch)
	boss_tag = UITheme.label("", 15, Color("#ff5a4a"))
	boss_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_tag.add_theme_constant_override("outline_size", 5)
	boss_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	boss_panel.add_child(boss_tag)
	ticker = UITheme.label("", 15, Color("#f0e8d0"))
	ticker.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ticker.anchor_left = 0.5
	ticker.anchor_right = 0.5
	ticker.offset_left = -420
	ticker.offset_right = 420
	ticker.offset_top = -46
	ticker.offset_bottom = -20
	ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker.add_theme_stylebox_override("normal", UITheme.box(Color(0.6, 0.05, 0.05, 0.75), 4))
	ticker.visible = false
	root.add_child(ticker)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
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
	# A toast: dark glass with a coloured edge, sliding in from the left.
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _accent_box(color))
	var l := UITheme.label(text, 15, color.lerp(Color.WHITE, 0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	toast.add_child(l)
	notes.add_child(toast)
	while notes.get_child_count() > 5:
		var old := notes.get_child(0)
		notes.remove_child(old)
		old.queue_free()
	toast.modulate.a = 0.0
	var t := toast.create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.18)
	t.tween_interval(4.5)
	t.tween_property(toast, "modulate:a", 0.0, 0.8)
	t.tween_callback(toast.queue_free)


## Dark glass with a coloured stripe down the left edge.
func _accent_box(color: Color) -> StyleBoxFlat:
	var sb := UITheme.box(Color(0.03, 0.04, 0.07, 0.72), 6)
	sb.border_width_left = 4
	sb.border_color = color
	sb.content_margin_left = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


## The player's badge: a ring in their colours with their initials.
func _draw_portrait() -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var p: Actor = world.player
	var look: Dictionary = p.def.get("look", {})
	var c := portrait.size * 0.5
	var main := Color(str(look.get("suit", "#444444")))
	var acc := Color(str(look.get("trail", look.get("accent", "#ffffff"))))
	portrait.draw_circle(c, 31.0, UITheme.side_color(str(p.def.get("side", "hero"))))
	portrait.draw_circle(c, 28.0, main.darkened(0.2))
	portrait.draw_arc(c, 24.0, 0, TAU, 32, acc, 3.0)
	# Ultimate charge around the edge
	portrait.draw_arc(c, 31.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(p.ult / 100.0, 0.0, 1.0), 40, UITheme.ACCENT, 3.0)
	var words := str(p.def.get("alias", "?")).replace("The ", "").split(" ")
	var ini := ""
	for w in words:
		if w != "" and ini.length() < 2:
			ini += w.substr(0, 1).to_upper()
	portrait.draw_string(ThemeDB.fallback_font, c + Vector2(-30, 8), ini, HORIZONTAL_ALIGNMENT_CENTER, 60, 22, Color.WHITE)


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
	hp_text.text = "  %d / %d" % [int(round(minf(p.hp, p.max_hp))), int(round(p.max_hp))]
	portrait.queue_redraw()
	energy_bar.max_value = p.max_energy
	energy_bar.value = p.energy
	var status := PackedStringArray()
	if p.civilian:
		status.append("CIVILIAN")
	if p.changing:
		status.append("CHANGING")
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
	if p.def.get("telekinetic", false):
		e_text += ("  ·  " if e_text != "" else "[E]  ") + ("Telekinetic throw (LMB)" if p.tk_hold or p.tk_actor else "Telekinesis: lift what you aim at")
	elif p.strength:
		e_text += ("  ·  " if e_text != "" else "[E]  ") + "Lift / throw"
	if not p.civilian and not p.powers.is_empty():
		var pw := PackedStringArray()
		for i in p.powers.size():
			pw.append("[%d] %s%s" % [i + 1, p.powers[i].get("name", p.powers[i]["kind"]), _cd(p, "power%d" % (i + 1))])
		e_text += ("\n" if e_text != "" else "") + "  ".join(pw) + "   ·  [H] Wheel"
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
	move_text += "   ·   [V] Dodge  ·  [B] Block  ·  [Z] Lock-on"
	if p.combo_count >= 3:
		move_text += "   ·   %d HIT COMBO  x%.1f" % [p.combo_count, 1.0 + minf(p.combo_count, 30) / 60.0]
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
	if p.civilian:
		ability_labels[2].text = "[T]  Suit up as " + str(p.suit_def.get("alias", ""))
		ability_labels[2].add_theme_color_override("font_color", UITheme.ACCENT)
		ability_labels[3].text = "In civilian clothes: no powers"
		ability_labels[4].text = "[Shift]  Sprint   ·   [V] Dodge"
		ability_labels[5].text = "[R]  " + str(u.get("name", "Ultimate")) + "   (suit up first)"
	elif Suitup.can_change(p):
		ability_labels[4].text += "   ·   [T] Civilian clothes"
	ability_labels[2].add_theme_color_override("font_color", UITheme.ACCENT if p.cooldowns["special"] <= 0.0 and p.energy >= Abilities.special_cost(d["special"]) else UITheme.DIM)
	_update_ability_bar(p, d)
	move_hint.text = ability_labels[4].text

	district_label.text = world.place_name(p.global_position)
	hint_label.text = world.interact_prompt()
	if world.ship.piloted:
		hint_label.text = "WAVERIDER  %d km/h  ·  alt %d m  ·  [A/D] turn  ·  [Shift] boost  ·  [LMB] cannons  ·  [Q] time jump  ·  [G] bridge  ·  [U] bail out" % [
			int(world.ship.velocity.length() * 3.6), int(world.ship.global_position.y)]
	var h: float = world.day_night.hour
	clock_label.text = "%02d:%02d  ·  %s" % [int(h), int(fmod(h, 1.0) * 60.0), world.day_night.weather.capitalize()]

	mission_label.text = world.missions.tracker()
	if world.street_crime.mugger:
		mission_label.text = "MUGGING: stop him! %ds\n\n" % int(world.street_crime.time_left) + mission_label.text
	var personal: String = world.char_missions.tracker()
	if personal != "":
		mission_label.text = personal + ("\n\n" + mission_label.text if mission_label.text != "" else "")
	if world.waypoint != Vector3.INF:
		var wd := Vector2(world.waypoint.x - p.global_position.x, world.waypoint.z - p.global_position.z).length()
		mission_label.text += "\nWaypoint: %d m" % int(wd)
	if world.race.active:
		mission_label.text = world.race.tracker() + "\n\n" + mission_label.text
	if world.survival.active:
		mission_label.text = world.survival.tracker() + "\n\n" + mission_label.text
	mission_label.text += "\n\nCHALLENGES\n" + world.challenges.tracker()
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
	overlay.queue_redraw()
	ticker.visible = world.news.current != ""
	if ticker.visible:
		ticker.text = "  %s  ·  %s  " % [world.news.outlet, world.news.current]
	var st: String = world.style.label()
	style_label.text = st
	style_label.modulate.a = clampf(world.style.points / 20.0, 0.0, 1.0) if st != "" else 0.0
	_update_boss(p)
	if p.blocking:
		status_label.text += "  BLOCKING"
	if p.lock_target:
		status_label.text += "  LOCKED ON"
	if world.team_bonus != "":
		status_label.text += "  TEAM-UP: " + str(world.team_bonus).to_upper()


func _update_ability_bar(p: Actor, d: Dictionary) -> void:
	var col := Color(str(d["look"].get("trail", d["look"].get("glow", "#ffcc22"))))
	if col.get_luminance() < 0.2:
		col = UITheme.ACCENT
	var tiles := []
	if p.civilian:
		tiles.append({"key": "LMB", "name": "Punch", "color": Color("#c8c8c8")})
		tiles.append({"key": "T", "name": "Suit up", "color": UITheme.ACCENT, "extra": "!"})
		ability_bar.set_slots(tiles)
		return
	var add := func(key: String, slot: String, spec: Dictionary, is_special: bool) -> void:
		var cd: float = p.cooldowns.get(slot, 0.0)
		var cmax: float = Abilities.special_cooldown(spec) if is_special else maxf(0.2, Abilities.cooldown(spec))
		var cost: float = Abilities.special_cost(spec) if is_special else Abilities.energy_cost(spec)
		var extra := ""
		if slot == "primary" and p.pickup_ammo > 0:
			extra = "x%d" % p.pickup_ammo
		tiles.append({"key": key, "name": str(spec.get("name", spec["kind"])), "cd": cd, "cd_max": cmax,
			"ready": p.energy >= cost, "color": col, "extra": extra})
	add.call("LMB", "primary", d["primary"], false)
	add.call("RMB", "secondary", d["secondary"], false)
	add.call("Q", "special", d["special"], true)
	if d.has("utility"):
		add.call("E", "utility", d["utility"], true)
	elif p.movement == "grapple":
		tiles.append({"key": "E", "name": "Grappling line", "color": col})
	for i in p.powers.size():
		add.call(str(i + 1), "power%d" % (i + 1), p.powers[i], true)
	var u := Ultimate.for_character(d)
	tiles.append({"key": "R", "name": str(u.get("name", "Ultimate")), "cd": 0.0, "ready": p.ult >= 100.0 or p.ult_active,
		"color": UITheme.ACCENT, "extra": "READY" if p.ult >= 100.0 and not p.ult_active else ("%d%%" % int(p.ult) if not p.ult_active else "ON")})
	ability_bar.set_slots(tiles)
	ability_bar.offset_left = -ability_bar.custom_minimum_size.x * 0.5
	ability_bar.offset_right = ability_bar.custom_minimum_size.x * 0.5


func _cd(p: Actor, slot: String) -> String:
	var c: float = p.cooldowns[slot]
	return "   (%.1fs)" % c if c > 0.25 else ""


func _update_target(p: Actor) -> void:
	target_label.text = ""
	target_bar.visible = false
	# hint_label already holds this frame's [G] prompt; lift/throw hints only
	# show when there's nothing to interact with.
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
	if hint_label.text != "":
		return
	if p.strength and p.held_prop == null:
		for prop in world.get_tree().get_nodes_in_group("props"):
			if prop.global_position.distance_to(p.global_position) < 5.0 * p.size:
				hint_label.text = "[E] Lift " + str(prop.kind).replace("newsbox", "newspaper box")
				break
	elif p.held_prop:
		hint_label.text = "[LMB / E] Throw"


const SCAN_NAMES := {"supergirl": "X-RAY VISION", "superman": "X-RAY VISION", "mon_el": "X-RAY VISION", "jordan_kent": "X-RAY VISION",
	"reign": "WORLDKILLER SIGHT", "overgirl": "X-RAY VISION", "batwoman": "DETECTIVE COWL", "red_death": "DETECTIVE COWL",
	"vibe": "VIBE SENSE", "martian_manhunter": "TELEPATHIC SCAN", "grodd": "TELEPATHIC SCAN", "dreamer": "PRECOGNITION",
	"green_arrow": "OVERWATCH (FELICITY)", "speedy": "OVERWATCH (FELICITY)", "spartan": "OVERWATCH (FELICITY)",
	"black_canary": "OVERWATCH (FELICITY)", "mr_terrific": "T-SPHERE SCAN", "brainiac_5": "COLUAN SCAN"}


## Hold X to scan: enemies, allies and Crisis Fragments show through walls.
func _draw_scan(cam: Camera3D) -> void:
	var p: Actor = world.player
	overlay.draw_rect(Rect2(Vector2.ZERO, overlay.size), Color(0.2, 0.5, 1.0, 0.08))
	var title: String = SCAN_NAMES.get(p.def.get("id", ""), "SPEED FORCE SENSE" if p.movement == "speed" else "SCAN")
	overlay.draw_string(ThemeDB.fallback_font, Vector2(overlay.size.x * 0.5 - 120, 140), title, HORIZONTAL_ALIGNMENT_CENTER, 240, 22, Color("#9fd0ff"))
	for a in world.get_tree().get_nodes_in_group("actors"):
		if a == p or a.dead:
			continue
		var d: float = a.global_position.distance_to(p.global_position)
		if d > 120.0 or cam.is_position_behind(a.chest()):
			continue
		var col := Color("#ff4848") if a.is_hostile_to(p) or p.is_hostile_to(a) else (Color("#5fa8ff") if a.is_ally_of_player() else Color(0.8, 0.8, 0.8, 0.5))
		if a.team == "civilian":
			continue
		var s := cam.unproject_position(a.chest())
		overlay.draw_rect(Rect2(s - Vector2(5, 5), Vector2(10, 10)), col, false, 2.0)
		if a.boss or a.def.get("id", "") not in ["thug", "police"]:
			overlay.draw_string(ThemeDB.fallback_font, s + Vector2(8, -6), "%s  %dm" % [a.display_name, int(d)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	for f in world.collectibles.remaining():
		var fp: Vector3 = f["pos"]
		if fp.distance_to(p.global_position) < 150.0 and not cam.is_position_behind(fp):
			var s := cam.unproject_position(fp)
			overlay.draw_circle(s, 6.0, Color("#ff4fd8"))
			overlay.draw_string(ThemeDB.fallback_font, s + Vector2(8, 4), "Crisis Fragment %dm" % int(fp.distance_to(p.global_position)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ff9ae8"))


## The nearest boss you're fighting gets a big health bar.
func _update_boss(p: Actor) -> void:
	var boss: Actor = null
	var best := 90.0
	for a in world.get_tree().get_nodes_in_group("actors"):
		if a.boss and not a.dead and (a.is_hostile_to(p) or a.grudges.has(p.get_instance_id())):
			var d: float = a.global_position.distance_to(p.global_position)
			if d < best:
				best = d
				boss = a
	# The mission boss you're fighting takes the bar over any other.
	if world.boss_fight and world.boss_fight.active():
		boss = world.boss_fight.boss
	boss_panel.visible = boss != null and not world.cinematic
	if boss == null:
		_last_boss = null
		return
	if boss != _last_boss:
		_last_boss = boss
		boss_trail.max_value = boss.max_hp
		boss_trail.value = boss.hp
	boss_name.text = str(boss.display_name).replace(" (BOSS)", "").to_upper()
	var phase := 1
	if world.boss_fight and world.boss_fight.boss == boss:
		phase = world.boss_fight.phase
	else:
		phase = 1 if boss.hp > boss.max_hp * 0.66 else (2 if boss.hp > boss.max_hp * 0.33 else 3)
	var show := BossFight.title_for(boss)
	boss_sub.text = ("%s  ·  " % show if show != "" else "") + "PHASE %d / 3" % phase
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp
	boss_trail.max_value = boss.max_hp
	if boss_trail.value > boss.hp:
		_trail_hold -= get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if _trail_hold <= 0.0:
			boss_trail.value = maxf(boss.hp, boss_trail.value - boss.max_hp * 0.6 * get_process_delta_time() / maxf(Engine.time_scale, 0.01))
	else:
		boss_trail.value = boss.hp
		_trail_hold = 0.6
	var tags := []
	if boss.has_meta("enraged"):
		tags.append("ENRAGED")
	if boss.staggered_t > 0.0:
		tags.append("STAGGERED")
	if boss.hp < boss.max_hp * 0.1:
		tags.append("FINISH THEM")
	boss_tag.text = "  ·  ".join(tags)


func _draw_overlay() -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var cam: Camera3D = world.cam.camera
	if world.scanning:
		_draw_scan(cam)
	var lt: Actor = world.player.lock_target
	if lt and is_instance_valid(lt) and not cam.is_position_behind(lt.chest()):
		var s := cam.unproject_position(lt.chest() + Vector3.UP * 0.2)
		var c := Color("#ff5050")
		var r := 16.0
		for k in 4:
			var ang: float = k * PI * 0.5 + Time.get_ticks_msec() * 0.002
			var d := Vector2(cos(ang), sin(ang))
			overlay.draw_line(s + d * r, s + d * (r + 9.0), c, 3.0)
		overlay.draw_arc(s, r, 0, TAU, 24, Color(1, 0.3, 0.3, 0.6), 2.0)


func _draw_crosshair() -> void:
	var c := Color(1, 1, 1, 0.85)
	crosshair.draw_line(Vector2(-10, 0), Vector2(-4, 0), c, 2.0)
	crosshair.draw_line(Vector2(4, 0), Vector2(10, 0), c, 2.0)
	crosshair.draw_line(Vector2(0, -10), Vector2(0, -4), c, 2.0)
	crosshair.draw_line(Vector2(0, 4), Vector2(0, 10), c, 2.0)
	crosshair.draw_circle(Vector2.ZERO, 1.5, c)
