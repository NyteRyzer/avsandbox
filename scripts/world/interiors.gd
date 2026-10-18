class_name Interiors
extends RefCounted
## Walk-in interiors: S.T.A.R. Labs, the Arrow Bunker, Jitters, CatCo, the
## D.E.O. and the Waverider's bridge. Each is a furnished room built far
## below the map with its own lights; doors in the city lead to them and an
## exit leads back. Interactables (suits on display, Gideon, the captain's
## chair, the Breach Room) are registered on the city for the World to run.

const DEPTH := -320.0
const SPACING := 140.0
const ORDER := ["star_labs", "bunker", "jitters", "catco", "deo", "waverider"]
const BUNKER_SUITS := ["green_arrow", "speedy", "black_canary", "spartan", "wild_dog", "arsenal"]
const NAMES := {"star_labs": "S.T.A.R. Labs", "bunker": "The Arrow Bunker", "jitters": "Jitters",
	"catco": "CatCo Worldwide", "deo": "The D.E.O.", "waverider": "The Waverider"}

var city: City
var base := Vector3.ZERO
var _mats: Dictionary = {}


static func origin(id: String) -> Vector3:
	return Vector3(ORDER.find(id) * SPACING, DEPTH, 3000.0)


static func is_inside(p: Vector3) -> bool:
	return p.y < DEPTH + 60.0 and p.y > DEPTH - 60.0 and absf(p.z - 3000.0) < 80.0


## Which room a point is in ("" outside).
static func room_at(p: Vector3) -> String:
	if not is_inside(p):
		return ""
	return ORDER[clampi(int(round(p.x / SPACING)), 0, ORDER.size() - 1)]


static func build_all(c: City) -> void:
	for id in ORDER:
		var b := Interiors.new()
		b.city = c
		b.base = origin(id)
		b.call("_" + id)


func _m(color: String, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.1f" % [color, emission]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color)
		m.roughness = 0.7
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = Color(color)
			m.emission_energy_multiplier = emission
		_mats[key] = m
	return _mats[key]


func box(p: Vector3, s: Vector3, color: String, collide := true, emission := 0.0, rot := 0.0) -> void:
	city.add_box(base + p, s, _m(color, emission), collide, rot)


func light(p: Vector3, color := Color(1, 0.95, 0.85), energy := 1.6, radius := 20.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	l.position = base + p
	city.add_child(l)


## Labels read from their +Z side; `rot` turns them like add_box does.
func label(text: String, p: Vector3, size := 1.2, color := Color.WHITE, rot := 0.0) -> void:
	var l := Label3D.new()
	l.rotation.y = rot
	l.text = text
	l.font_size = 128
	l.pixel_size = size / 128.0 * 2.0
	l.modulate = color
	l.outline_size = 12
	l.position = base + p
	city.add_child(l)


## A room: floor, ceiling and four walls with an opening for the exit door.
func room(size: Vector3, floor_color: String, wall_color: String, ceiling_color := "#2a2c30") -> void:
	var h := size.y
	box(Vector3(0, -0.25, 0), Vector3(size.x, 0.5, size.z), floor_color)
	box(Vector3(0, h + 0.25, 0), Vector3(size.x, 0.5, size.z), ceiling_color)
	box(Vector3(-size.x * 0.5, h * 0.5, 0), Vector3(0.5, h, size.z), wall_color)
	box(Vector3(size.x * 0.5, h * 0.5, 0), Vector3(0.5, h, size.z), wall_color)
	box(Vector3(0, h * 0.5, -size.z * 0.5), Vector3(size.x, h, 0.5), wall_color)
	box(Vector3(0, h * 0.5, size.z * 0.5), Vector3(size.x, h, 0.5), wall_color)


## An exit in a wall. `rot` turns the door so it faces into the room:
## 0 for the south (+Z) wall, -PI/2 for the west wall.
func exit_door(p: Vector3, outside: String, rot := 0.0) -> void:
	var inward := Vector3(0, 0, -1).rotated(Vector3.UP, rot)
	box(p + Vector3(0, 1.4, 0), Vector3(2.2, 2.8, 0.2), "#3a2a1a", true, 0.0, rot)
	box(p + Vector3(0, 3.0, 0) + inward * 0.1, Vector3(2.8, 0.3, 0.3), "#5a5a5a", false, 0.0, rot)
	label("EXIT", p + Vector3(0, 3.5, 0) + inward * 0.35, 0.5, Color("#7aff8a"), rot + PI)
	city.doors.append({"name": "Exit to " + outside, "pos": base + p + Vector3(0, 0.5, 0) + inward * 1.5, "interior": "exit", "outside": _id()})


func spawn(p: Vector3) -> void:
	city.landmarks.append({"name": "Inside " + NAMES[_id()], "pos": base + p, "district": NAMES[_id()], "interior": true})


func interactable(name: String, p: Vector3, action: String, data := "") -> void:
	city.doors.append({"name": name, "pos": base + p, "interior": action, "data": data})


func _id() -> String:
	return ORDER[int(round(base.x / SPACING))]


func screen(p: Vector3, s: Vector2, color := "#3a8aff", rot := 0.0) -> void:
	box(p, Vector3(s.x, s.y, 0.08), "#101418", false, 0.0, rot)
	box(p + Vector3(0, 0, 0.05).rotated(Vector3.UP, rot), Vector3(s.x * 0.92, s.y * 0.85, 0.02), color, false, 1.6, rot)


func desk(p: Vector3, w := 2.4, rot := 0.0, screen_color := "#3a8aff") -> void:
	box(p + Vector3(0, 0.75, 0), Vector3(w, 0.08, 1.0), "#cfd4da", true, 0.0, rot)
	box(p + Vector3(0, 0.37, 0), Vector3(w * 0.9, 0.74, 0.9), "#5a6068", true, 0.0, rot)
	screen(p + Vector3(0, 1.25, -0.2).rotated(Vector3.UP, rot), Vector2(0.9, 0.55), screen_color, rot)


## A costume on a stand behind glass, facing -Z (face_z = -1) or +Z. The
## player can step up to it and suit up as that character.
func mannequin(id: String, p: Vector3, face_z := -1.0) -> void:
	var c := Game.get_character(id)
	if c.is_empty():
		return
	var m := CharacterModel.new()
	m.position = base + p
	m.rotation.y = 0.0 if face_z < 0.0 else PI
	city.add_child(m)
	m.build(c.get("look", {}))
	box(p + Vector3(0, 0.1, 0), Vector3(1.2, 0.2, 1.2), "#2a2a2a")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 1.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.4
	glass.roughness = 0.05
	city.add_box(base + p + Vector3(0, 1.2, 0.65 * face_z), Vector3(1.3, 2.2, 0.05), glass, false)
	label(str(c["alias"]).to_upper(), p + Vector3(0, 2.5, 0.7 * face_z), 0.3, Color("#d8ffd0"), 0.0 if face_z > 0.0 else PI)
	interactable("Suit up as " + str(c["alias"]), p + Vector3(0, 0.5, 1.4 * face_z), "suit", id)


# --- Rooms --------------------------------------------------------------------

func _star_labs() -> void:
	# The Cortex
	room(Vector3(34, 6, 28), "#d6dade", "#e8ecef", "#bfc6cc")
	for x in [-10.0, 0.0, 10.0]:
		light(Vector3(x, 5.2, 0), Color(0.85, 0.92, 1.0), 1.8, 22.0)
	desk(Vector3(-3, 0, -2), 3.0)
	desk(Vector3(3, 0, -2), 3.0)
	desk(Vector3(0, 0, -5.5), 4.0)
	screen(Vector3(0, 3.4, -13.6), Vector2(12, 3.4), "#1e5fbf")
	label("S.T.A.R. LABS", Vector3(0, 3.4, -13.4), 1.3, Color("#ffffff"))
	label("CORTEX", Vector3(-10, 4.6, -13.6), 0.6, Color("#9fd0ff"))
	for k in 3:
		box(Vector3(-12 + k * 2.6, 1.2, -12.8), Vector3(2.0, 2.4, 0.8), "#a8b0b8")
	# Speed Lab treadmill along the east wall
	box(Vector3(13, 0.25, 4), Vector3(3.0, 0.5, 9.0), "#3a3d42")
	box(Vector3(13, 0.52, 4), Vector3(2.4, 0.04, 8.4), "#1a1a1a", false)
	box(Vector3(13, 1.4, -0.6), Vector3(3.0, 2.0, 0.2), "#cfd4da")
	label("SPEED LAB", Vector3(13, 3.8, 4), 0.6, Color("#ffd23a"))
	interactable("Run into the Speed Force (treadmill)", Vector3(13, 0.5, 4), "speedforce")
	# The Pipeline: a row of metahuman cells with blue force fields
	for k in 4:
		var z := -6.0 + k * 5.0
		box(Vector3(-15.5, 1.6, z), Vector3(2.4, 3.2, 3.6), "#7a8088")
		box(Vector3(-14.2, 1.6, z), Vector3(0.05, 2.6, 2.6), "#5ab8ff", false, 1.2)
	label("THE PIPELINE", Vector3(-14, 4.2, 1.5), 0.6, Color("#9fd0ff"), PI * 0.5)
	# Cisco's Breach Room
	box(Vector3(8, 0.1, 10), Vector3(5, 0.2, 5), "#1a2a44")
	box(Vector3(8, 2.2, 12.2), Vector3(3.2, 4.0, 0.2), "#5ab8ff", false, 1.6)
	label("BREACH ROOM", Vector3(8, 4.6, 12), 0.6, Color("#9fd0ff"))
	interactable("Open a breach to another Earth", Vector3(8, 0.5, 9), "breach_room")
	spawn(Vector3(0, 0.5, 9))
	exit_door(Vector3(0, 0, 13.7), "S.T.A.R. Labs")


func _bunker() -> void:
	room(Vector3(30, 5, 22), "#3a3c40", "#4a4c50", "#2a2c30")
	for x in [-8.0, 0.0, 8.0]:
		light(Vector3(x, 4.4, 0), Color(0.7, 1.0, 0.75), 1.5, 18.0)
	box(Vector3(0, 0.02, 2), Vector3(10, 0.05, 7), "#2a4a8a", false)
	# Salmon ladder
	for side in [-1.0, 1.0]:
		box(Vector3(-10 + side * 1.0, 2.4, -8), Vector3(0.2, 4.8, 0.2), "#7a7a7a")
	for k in 5:
		box(Vector3(-10, 1.6 + k * 0.6, -8), Vector3(2.2, 0.06, 0.06), "#b0b0b0", false)
	box(Vector3(-10, 3.2, -8), Vector3(2.6, 0.08, 0.08), "#e0e0e0", false)
	label("SALMON LADDER", Vector3(-10, 4.4, -7.8), 0.4, Color("#c8ffd0"))
	# Computer bank
	box(Vector3(6, 0.75, -6), Vector3(7, 0.1, 1.6), "#202224")
	for k in 3:
		screen(Vector3(3.8 + k * 2.2, 1.6, -6.6), Vector2(1.9, 1.1), "#3aff6a")
	# Suits on display
	for k in BUNKER_SUITS.size():
		mannequin(BUNKER_SUITS[k], Vector3(-7.5 + k * 3.0, 0.2, 9.4))
	# Arrow rack
	box(Vector3(12, 1.4, 4), Vector3(0.4, 2.8, 4), "#3a2a1a")
	for k in 8:
		box(Vector3(11.8, 1.6, 2.5 + k * 0.4), Vector3(0.04, 1.6, 0.04), "#c8b090", false)
	label("THE BUNKER", Vector3(0, 3.6, -10.8), 0.9, Color("#3aff6a"))
	spawn(Vector3(0, 0.5, 0))
	exit_door(Vector3(-14.75, 0, 0), "Verdant", -PI * 0.5)


func _jitters() -> void:
	room(Vector3(20, 4.2, 16), "#6a4a32", "#c8a882", "#4a3424")
	light(Vector3(-4, 3.8, 0), Color(1, 0.82, 0.55), 1.6, 14.0)
	light(Vector3(4, 3.8, 0), Color(1, 0.82, 0.55), 1.6, 14.0)
	box(Vector3(0, 0.55, -5.5), Vector3(12, 1.1, 1.2), "#5a3a22")
	box(Vector3(0, 1.12, -5.5), Vector3(12.2, 0.06, 1.3), "#2a1a10")
	box(Vector3(-3, 1.5, -5.6), Vector3(1.0, 0.8, 0.7), "#b0b0b0")
	box(Vector3(0, 2.8, -7.7), Vector3(8, 1.6, 0.1), "#2a1a10", false)
	label("JITTERS", Vector3(0, 3.1, -7.6), 0.8, Color("#ffd27a"))
	label("COFFEE  ·  TEA  ·  THE FLASH-UCCINO", Vector3(0, 2.4, -7.6), 0.25, Color("#f0e0c0"))
	for k in 6:
		var p := Vector3(-6 + (k % 3) * 6.0, 0, 0 + (k / 3) * 4.5)
		box(p + Vector3(0, 0.72, 0), Vector3(1.4, 0.06, 1.4), "#4a3020")
		box(p + Vector3(0, 0.36, 0), Vector3(0.15, 0.72, 0.15), "#2a1a10")
		for side in [-1.0, 1.0]:
			box(p + Vector3(side * 1.1, 0.45, 0), Vector3(0.5, 0.06, 0.5), "#3a2a1a")
	spawn(Vector3(0, 0.5, 5))
	exit_door(Vector3(0, 0, 7.7), "Jitters")


func _catco() -> void:
	room(Vector3(36, 4.6, 26), "#d8d8dc", "#f0f0f2", "#e8e8ea")
	for x in [-12.0, 0.0, 12.0]:
		light(Vector3(x, 4.2, 0), Color(1, 1, 0.98), 1.6, 20.0)
	for row in 3:
		for k in 4:
			desk(Vector3(-12 + k * 5.0, 0, -4 + row * 4.0), 2.2, 0.0, "#e0e8ff")
	# Cat Grant's glass office
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 1.0, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	city.add_box(base + Vector3(11, 2.3, -9), Vector3(10, 4.6, 0.08), glass, true)
	desk(Vector3(11, 0, -11.5), 3.0, 0.0, "#ffffff")
	label("CATCO WORLDWIDE MEDIA", Vector3(0, 3.6, -12.7), 0.8, Color("#202020"))
	# Balcony with a view (Kara's favourite spot)
	box(Vector3(-17.9, 2.3, 0), Vector3(0.3, 4.6, 8), "#b8d8f0", false, 0.6)
	label("BALCONY", Vector3(-17.5, 3.6, 0), 0.4, Color("#204060"), PI * 0.5)
	interactable("Step out onto the balcony", Vector3(-16, 0.5, 0), "balcony")
	spawn(Vector3(0, 0.5, 9))
	exit_door(Vector3(0, 0, 12.7), "CatCo Worldwide")


func _deo() -> void:
	room(Vector3(34, 7, 30), "#2a2e36", "#3a404a", "#1e2228")
	for x in [-10.0, 10.0]:
		light(Vector3(x, 6.2, 0), Color(0.7, 0.82, 1.0), 1.6, 22.0)
	light(Vector3(0, 2.0, 0), Color(0.4, 0.7, 1.0), 2.0, 10.0)
	box(Vector3(0, 0.5, 0), Vector3(6, 1.0, 6), "#1a1e24")
	box(Vector3(0, 1.05, 0), Vector3(5.4, 0.04, 5.4), "#4fa8ff", false, 1.8)
	label("D.E.O.", Vector3(0, 5.6, -14.6), 1.4, Color("#bcd4ff"))
	for k in 5:
		screen(Vector3(-12 + k * 6.0, 3.0, -14.6), Vector2(4.5, 2.6), "#2a6aff")
	for k in 6:
		desk(Vector3(-12.5 + k * 5.0, 0, 8), 2.4, PI, "#2a6aff")
	spawn(Vector3(0, 0.5, 10))
	exit_door(Vector3(0, 0, 14.7), "The D.E.O.")


func _waverider() -> void:
	room(Vector3(22, 5, 20), "#3a4048", "#5a626c", "#2a3038")
	light(Vector3(0, 4.5, 0), Color(0.75, 0.9, 1.0), 1.8, 18.0)
	light(Vector3(0, 2.0, -8), Color(0.5, 0.8, 1.0), 1.4, 10.0)
	# Front viewport onto the Temporal Zone
	box(Vector3(0, 2.6, -9.6), Vector3(14, 3.4, 0.2), "#7a5aff", false, 1.6)
	label("THE TEMPORAL ZONE", Vector3(0, 4.0, -9.4), 0.5, Color("#e0d8ff"))
	# Captain's chair and the helm
	box(Vector3(0, 0.5, -2), Vector3(1.2, 1.0, 1.2), "#202428")
	box(Vector3(0, 1.4, -1.5), Vector3(1.2, 1.6, 0.25), "#202428")
	box(Vector3(0, 0.95, -5), Vector3(5, 0.12, 1.4), "#a8b0b8")
	box(Vector3(0, 1.02, -5), Vector3(4.4, 0.02, 1.0), "#4fd0ff", false, 1.6)
	interactable("Take the helm (fly the Waverider)", Vector3(0, 0.5, -3), "helm")
	# Gideon
	box(Vector3(-7, 1.2, -5), Vector3(0.6, 2.4, 0.6), "#5a626c")
	var gideon := SphereMesh.new()
	gideon.radius = 0.6
	gideon.height = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = gideon
	mi.material_override = _m("#ffb84a", 2.5)
	mi.position = base + Vector3(-7, 2.9, -5)
	city.add_child(mi)
	label("GIDEON", Vector3(-7, 3.9, -5), 0.4, Color("#ffd27a"))
	interactable("Ask Gideon to plot a course through time", Vector3(-7, 0.5, -3.5), "time_console")
	for side in [-1.0, 1.0]:
		for k in 3:
			box(Vector3(side * 9.5, 1.0, -3 + k * 3.0), Vector3(1.4, 1.2, 2.2), "#4a525c")
	spawn(Vector3(0, 0.5, 6))
	exit_door(Vector3(0, 0, 9.7), "The Waverider")
