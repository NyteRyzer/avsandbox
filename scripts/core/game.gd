extends Node
## Global game state: the character roster, input bindings, settings,
## faction rules, the player's heat/score, and sandbox cheats.

signal heat_changed(value: float)
signal score_changed(value: int)
signal notify(text: String, color: Color)

const ROSTER_PATH := "res://data/roster.json"
const SETTINGS_PATH := "user://settings.cfg"

const LAYER_WORLD := 1
const LAYER_ACTORS := 2
const LAYER_PROPS := 4

const ATTACK_KINDS := ["melee", "arrow", "explosive_arrow", "throw", "bolt", "beam", "sonic", "lightning", "gun", "dash",
	"flame", "breath", "missiles", "telekinesis", "psychic"]
const SPECIAL_KINDS := ["time_slow", "tornado", "ground_slam", "smoke_bomb", "nova", "rage", "shrink",
	"invisibility", "invulnerable", "teleport", "drain", "sonic_scream", "arrow_storm", "boomerang_storm",
	"breath", "frag_grenade", "t_spheres", "animal_spirit", "shield_wall", "force_field", "storm",
	"missile_barrage", "dampen", "mind_control"]
const UTILITY_KINDS := ["grapple", "blitz", "dodge_flip", "emp", "foresight", "ice_wall", "phase", "teleport",
	"breath", "invulnerable"]
const MOVEMENTS := ["run", "speed", "flight", "grapple", "superjump", "ice", "hover"]
const ELEMENTS := ["", "fire", "ice", "shock", "push"]
const HOMES := ["star", "central", "national", "freeland", "gotham", "smallville", "any"]

var roster: Array = []
var by_id: Dictionary = {}
var roster_errors: PackedStringArray = []

var selected_id := "flash"
var settings := {
	"mouse_sensitivity": 0.25,
	"invert_y": false,
	"fullscreen": false,
	"shadows": true,
	"fov": 75.0,
	"volume": 0.8,
	"view_distance": 1200.0,
	"crisis_chapter": 0,
	"xp": 0,
}
var cheats := {"god_mode": false, "infinite_energy": false, "one_hit_ko": false, "no_heat": false}

var heat := 0.0
var score := 0
var player: Node = null
var slowmo_left := 0.0
var last_combat_pos := Vector3(INF, INF, INF)
var last_combat_time := -100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_roster()
	setup_input()
	load_settings()
	apply_settings()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if slowmo_left > 0.0:
		slowmo_left -= real_delta
		if slowmo_left <= 0.0:
			Engine.time_scale = 1.0
	if heat > 0.0:
		var before := floorf(heat)
		heat = maxf(0.0, heat - delta * 0.06)
		if floorf(heat) != before:
			heat_changed.emit(heat)


# --- Roster -----------------------------------------------------------------

func load_roster() -> void:
	roster.clear()
	by_id.clear()
	roster_errors.clear()
	var file := FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if file == null:
		roster_errors.append("cannot open " + ROSTER_PATH)
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("characters"):
		roster_errors.append("roster.json is not a valid roster")
		return
	for c in data["characters"]:
		var problems := validate_character(c)
		if problems.is_empty():
			roster.append(c)
			by_id[c["id"]] = c
		else:
			for p in problems:
				roster_errors.append("%s: %s" % [c.get("id", "?"), p])


func validate_character(c: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key in ["id", "name", "alias", "side", "show", "home", "bio", "movement", "primary", "secondary", "special", "look"]:
		if not c.has(key):
			out.append("missing " + key)
	if not out.is_empty():
		return out
	if by_id.has(c["id"]):
		out.append("duplicate id")
	if not c["side"] in ["hero", "villain"]:
		out.append("bad side " + str(c["side"]))
	if not c["movement"] in MOVEMENTS:
		out.append("bad movement " + str(c["movement"]))
	if not c["home"] in HOMES:
		out.append("bad home " + str(c["home"]))
	for slot in ["primary", "secondary"]:
		var atk = c[slot]
		if typeof(atk) != TYPE_DICTIONARY or not atk.get("kind", "") in ATTACK_KINDS:
			out.append("bad %s attack" % slot)
		elif not atk.get("element", "") in ELEMENTS:
			out.append("bad element on " + slot)
	var sp = c["special"]
	if typeof(sp) != TYPE_DICTIONARY or not sp.get("kind", "") in SPECIAL_KINDS:
		out.append("bad special")
	if c.has("utility") and not c["utility"].get("kind", "") in UTILITY_KINDS:
		out.append("bad utility")
	var look = c["look"]
	for key in ["suit", "accent", "skin", "hair", "extras"]:
		if not look.has(key):
			out.append("look missing " + key)
	return out


func get_character(id: String) -> Dictionary:
	return by_id.get(id, roster[0] if not roster.is_empty() else {})


func heroes() -> Array:
	return roster.filter(func(c): return c["side"] == "hero")


func villains() -> Array:
	return roster.filter(func(c): return c["side"] == "villain")


func random_character(side := "") -> Dictionary:
	var pool := roster if side == "" else roster.filter(func(c): return c["side"] == side)
	return pool[randi() % pool.size()]


# --- Factions ---------------------------------------------------------------

## 1 = the side of law (heroes, police), -1 = the side of crime (villains,
## thugs), 0 = civilians.
static func side_of(team: String) -> int:
	match team:
		"hero", "police":
			return 1
		"villain", "thug":
			return -1
	return 0


func player_side() -> int:
	if player == null or not is_instance_valid(player):
		return 1
	return side_of(player.team)


func add_heat(amount: float) -> void:
	if cheats["no_heat"]:
		return
	var before := floorf(heat)
	heat = clampf(heat + amount, 0.0, 5.0)
	if floorf(heat) != before:
		heat_changed.emit(heat)
		if floorf(heat) > before:
			notify.emit("Heat level %d" % int(floorf(heat)), Color(1, 0.5, 0.3))


func clear_heat() -> void:
	heat = 0.0
	heat_changed.emit(heat)


signal rank_up(rank: int)

const HERO_RANKS := ["Rookie", "Vigilante", "Hero", "Protector", "Champion", "Paragon", "Legend", "Icon", "Myth", "Living Legend"]
const VILLAIN_RANKS := ["Thug", "Crook", "Rogue", "Menace", "Supervillain", "Warlord", "Mastermind", "Tyrant", "Conqueror", "God of Evil"]


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	if amount > 0:
		var before := rank()
		settings["xp"] = int(settings["xp"]) + amount
		if rank() > before:
			rank_up.emit(rank())


## Rank 1..20 from lifetime points. Each rank adds 3% health and power.
func rank() -> int:
	var xp := int(settings["xp"])
	var r := 1
	while r < 20 and xp >= xp_for(r + 1):
		r += 1
	return r


func xp_for(r: int) -> int:
	return int(400.0 * pow(float(r - 1), 1.6))


func rank_title(side: int) -> String:
	var list: Array = HERO_RANKS if side >= 0 else VILLAIN_RANKS
	return list[mini((rank() - 1) / 2, list.size() - 1)]


func rank_bonus() -> float:
	return 1.0 + (rank() - 1) * 0.03


func report_combat(pos: Vector3) -> void:
	last_combat_pos = pos
	last_combat_time = Time.get_ticks_msec() / 1000.0


func start_slowmo(seconds: float) -> void:
	slowmo_left = seconds
	Engine.time_scale = 0.25


## A brief freeze on heavy hits so they land with weight.
func hit_stop(seconds: float) -> void:
	if slowmo_left > 0.0 or DisplayServer.get_name() == "headless":
		return
	Engine.time_scale = 0.06
	get_tree().create_timer(seconds, true, false, true).timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	if slowmo_left <= 0.0:
		Engine.time_scale = 1.0


func end_slowmo() -> void:
	slowmo_left = 0.0
	Engine.time_scale = 1.0


func reset_session() -> void:
	end_slowmo()
	heat = 0.0
	score = 0
	player = null


# --- Input ------------------------------------------------------------------

func setup_input() -> void:
	_bind("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_bind("sprint", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_bind("descend", [_key(KEY_CTRL), _key(KEY_C), _button(JOY_BUTTON_B)])
	_bind("attack", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_bind("secondary", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_bind("special", [_key(KEY_Q), _button(JOY_BUTTON_Y)])
	_bind("ability", [_key(KEY_E), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind("fly", [_key(KEY_F), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_bind("dodge", [_key(KEY_V), _button(JOY_BUTTON_X)])
	_bind("interact", [_key(KEY_G), _button(JOY_BUTTON_DPAD_UP)])
	_bind("ultimate", [_key(KEY_R), _button(JOY_BUTTON_RIGHT_STICK)])
	_bind("sandbox_menu", [_key(KEY_TAB), _button(JOY_BUTTON_BACK)])
	_bind("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_bind("toggle_hud", [_key(KEY_F1)])


func _bind(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


# --- Settings ---------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		var value = cfg.get_value("settings", key, settings[key])
		if typeof(value) == typeof(settings[key]) or (typeof(settings[key]) == TYPE_FLOAT and typeof(value) == TYPE_INT):
			settings[key] = value
	var last = cfg.get_value("game", "selected_id", selected_id)
	if typeof(last) == TYPE_STRING and by_id.has(last):
		selected_id = last


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.set_value("game", "selected_id", selected_id)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, settings["volume"])))
	get_tree().call_group("settings_listeners", "on_settings_changed")
