class_name Population
extends Node
## Keeps the streets alive around the player: civilians, police patrols and
## gangs, plus hero or villain "hunters" when the player's heat gets high.
## Also builds the generic NPC character definitions.

const RADIUS := 170.0
const DESPAWN := 240.0
const MAX_ACTORS := 72
const FIRST_NAMES := ["Alex", "Sam", "Jordan", "Maria", "Chen", "Priya", "Marcus", "Ivy", "Leo", "Nadia",
	"Omar", "Grace", "Tomas", "Aiko", "Dev", "Rosa", "Kwame", "Ellie", "Hank", "June"]
const GANGS := [
	{"name": "Ghost", "suit": "#141414", "legs": "#1a1a1a", "accent": "#2a2a2a"},
	{"name": "Rogue Crew", "suit": "#4a3a2a", "legs": "#2a3a5a", "accent": "#1a1a1a"},
	{"name": "Cadmus Agent", "suit": "#3a4248", "legs": "#2a3036", "accent": "#1a1a1a"},
	{"name": "The 100", "suit": "#2a2a2a", "legs": "#2a3a5a", "accent": "#b01818"},
]
const SKINS := ["#f1c9a5", "#e3b896", "#c99a78", "#a8714d", "#8d5a3b", "#5e3a26"]
const HAIRS := ["#16110e", "#3b2a1e", "#6a4a2a", "#c9a25a", "#8a3a1a", "#9a9a9a"]

var world
var rng := RandomNumberGenerator.new()
var _tick := 0.0
var _hunter_t := 20.0
var enabled := true


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if not enabled or world.player == null or not is_instance_valid(world.player):
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var p: Vector3 = world.player.global_position
	if world.city.kind != "metro" and world.city.kind != "western":
		_realm()
		return
	var counts := {"civilian": 0, "police": 0, "thug": 0}
	var total := 0
	for a in get_tree().get_nodes_in_group("actors"):
		if a == world.player:
			continue
		total += 1
		var d: float = a.global_position.distance_to(p)
		if d > DESPAWN and a.event_tag == "" and not a.is_ally_of_player() and not a.has_meta("pinned"):
			a.queue_free()
			continue
		if d < RADIUS and not a.dead and counts.has(a.team):
			counts[a.team] += 1
	_traffic(p)
	if total >= MAX_ACTORS:
		return
	var night: bool = world.day_night.is_night()
	var in_city: bool = not world.city.is_water(p) and p.y < 60.0
	var civ_target := (14 if night else 24) if in_city else 0
	var police_target := 3 + int(Game.heat * 2.0)
	var thug_target := 8 if night else 4
	if counts["civilian"] < civ_target:
		spawn_civilian(world.city.random_road_point(p, 50.0, RADIUS - 20.0, rng, true))
	if counts["police"] < police_target:
		var pos: Vector3 = world.city.random_road_point(p, 70.0, RADIUS - 10.0, rng)
		spawn_police(pos)
	if counts["thug"] < thug_target:
		var pos: Vector3 = world.city.random_road_point(p, 70.0, RADIUS - 10.0, rng)
		for k in rng.randi_range(1, 3):
			spawn_thug(pos + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))
	_hunters(0.5, p)


func _traffic(p: Vector3) -> void:
	var count := 0
	for car in get_tree().get_nodes_in_group("traffic"):
		var d: float = car.global_position.distance_to(p)
		if d > DESPAWN:
			car.queue_free()
		elif d < RADIUS:
			count += 1
	var target := 0
	if not world.city.is_water(p) and p.y < 80.0:
		target = 7 if world.day_night.is_night() else 12
	if count < target:
		spawn_traffic(world.city.random_road_point(p, 60.0, RADIUS - 10.0, rng, false))


func spawn_traffic(on_road: Vector3) -> Prop:
	var road: Vector3 = world.city.snap_to_road(on_road)
	var along_z := is_zero_approx(fmod(absf(road.x), City.CELL))
	var dir := Vector3.FORWARD if along_z else Vector3.RIGHT
	if rng.randf() < 0.5:
		dir = -dir
	var car := Prop.new()
	car.build(world, "car", rng)
	world.props_root.add_child(car)
	car.global_position = road + dir.cross(Vector3.UP) * Prop.LANE + Vector3.UP * 0.1
	car.rotation.y = atan2(-dir.x, -dir.z)
	car.start_driving(dir)
	return car


var _wraith_t := 25.0


## The Speed Force has Time Wraiths and the Anti-Matter Universe has Shadow
## Demons; Argo City and Vanishing Point are peaceful.
func _realm() -> void:
	if not world.city.kind in ["speedforce", "antimatter"]:
		return
	_wraith_t -= 0.5
	if _wraith_t <= 0.0:
		_wraith_t = 30.0
		if get_tree().get_nodes_in_group("wraiths").size() < 3:
			spawn_wraiths(2)


## Time Wraiths (Speed Force) or Shadow Demons (anti-matter): realm hunters.
func spawn_wraiths(count: int) -> void:
	var p: Vector3 = world.player.global_position
	for k in count:
		var ang := rng.randf() * TAU
		var pos := p + Vector3(cos(ang) * 40.0, 6.0, sin(ang) * 40.0)
		var team := "villain" if Game.player_side() == 1 else "hero"
		var a := spawn_character(wraith_def() if world.city.kind != "antimatter" else shadow_demon_def(), team, pos)
		a.add_to_group("wraiths")
		a.brain.detect = 300.0
		a.brain.leash = 0.0
		a.grudges[world.player.get_instance_id()] = 9999.0
		FX.portal(world, a.chest(), Color("#a8c8ff"))


## Argo City's citizens: Kryptonians in robes bearing their houses' crests.
func spawn_kryptonians(count: int) -> void:
	var houses := [["#c8102e", "#f2c21b"], ["#1d3fa8", "#bfe8ff"], ["#5a5a6a", "#e8e8e8"], ["#2a7a4a", "#e8e0a0"]]
	for k in count:
		var d := civilian_def()
		var h: Array = houses[rng.randi() % houses.size()]
		d["alias"] = "Kryptonian"
		d["name"] = "Citizen of Argo"
		d["look"]["suit"] = "#e8e8ee" if k % 2 == 0 else "#2a3a6a"
		d["look"]["pants"] = d["look"]["suit"]
		d["look"]["coat_color"] = "#d8dce4" if k % 2 == 0 else "#1a2448"
		d["look"]["extras"] = ["coat", "cape"]
		d["look"]["cape"] = h[0]
		d["look"]["emblem"] = {"kind": "glyph", "c1": h[1], "c2": h[0], "size": 0.12}
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(20.0, 160.0)
		var a := spawn_character(d, "civilian", Vector3(cos(ang) * dist, 0.5, sin(ang) * dist))
		a.set_meta("pinned", true)


func shadow_demon_def() -> Dictionary:
	return {
		"id": "shadow_demon", "name": "Shadow Demon", "alias": "Shadow Demon", "side": "villain", "home": "any",
		"health": 90, "speed": 1.2, "power": 0.9, "movement": "flight", "fly_speed": 1.2,
		"primary": {"kind": "melee", "damage": 11, "style": "claw"},
		"secondary": {"kind": "bolt", "damage": 10, "color": "#ff2a3a", "style": "antimatter"},
		"special": {"kind": "rage"},
		"look": {"suit": "#0a0406", "legs": "#0a0406", "accent": "#3a0a10", "skin": "#140808", "hair": "#000000",
			"extras": ["wings"], "eye_glow": "#ff2a3a", "build": "bulky", "scale": 1.1,
			"anim": {"idle": "hunched", "run": "lumber", "fly": "cosmic_dive"}},
	}


func wraith_def() -> Dictionary:
	return {
		"id": "time_wraith", "name": "Time Wraith", "alias": "Time Wraith", "side": "villain", "home": "any",
		"health": 140, "speed": 1.3, "power": 1.0, "movement": "flight", "fly_speed": 1.4,
		"primary": {"kind": "melee", "damage": 14, "element": "ice"},
		"secondary": {"kind": "psychic", "damage": 10},
		"special": {"kind": "rage"},
		"look": {"suit": "#141820", "legs": "#0c0e14", "accent": "#2a3040", "skin": "#3a3e48", "hair": "#0a0a0a",
			"extras": ["hood", "cape"], "cape": "#10141c", "eye_glow": "#c8e0ff", "build": "male", "scale": 1.15,
			"anim": {"idle": "hunched", "run": "stalk", "fly": "hunched"}},
	}


func _hunters(step: float, p: Vector3) -> void:
	var trigger := 3.0 if Game.player_side() == -1 else 4.0
	if Game.heat < trigger:
		_hunter_t = 15.0
		return
	_hunter_t -= step
	if _hunter_t > 0.0:
		return
	_hunter_t = 30.0
	var c := Game.random_character("hero")
	var pos: Vector3 = world.city.random_road_point(p, 60.0, 90.0, rng)
	var a := spawn_character(c, "hero", pos)
	a.brain.detect = 400.0
	a.grudges[world.player.get_instance_id()] = 60.0
	world.notify("%s is hunting you!" % a.display_name, Color("#ff8060"))


# --- Spawning ---------------------------------------------------------------

func spawn_character(c: Dictionary, team: String, pos: Vector3, follow: Actor = null) -> Actor:
	var a := Actor.new()
	a.world = world
	a.setup(c, team)
	var brain := AIBrain.new()
	brain.role = "civilian" if team == "civilian" else "fighter"
	brain.home = pos
	brain.detect = 30.0 if team in ["police", "thug"] else 55.0
	a.brain = brain
	a.follow_target = follow
	world.actors_root.add_child(a)
	a.global_position = pos + Vector3.UP * 0.3
	a.rotation.y = rng.randf() * TAU
	return a


func spawn_civilian(pos: Vector3) -> Actor:
	return spawn_character(civilian_def(), "civilian", pos)


func spawn_police(pos: Vector3) -> Actor:
	return spawn_character(police_def(), "police", pos)


func spawn_thug(pos: Vector3, gang := -1) -> Actor:
	if gang < 0:
		gang = world.city.district_index(pos)
	return spawn_character(thug_def(gang), "thug", pos)


const SHOES := ["#f2f2ee", "#1a1a1a", "#5a3a22", "#2a2a3a", "#8a8a8a", "#b02a2a"]
const JEANS := ["#2a3a5a", "#1e2a44", "#3a4a6a", "#22222a", "#5a5a5e", "#6a5a44", "#2e3a2e"]


## A passer-by: real clothes (T-shirts, hoodies, business suits, dresses,
## jackets), bare hands, shoes, all sorts of hair and builds.
func civilian_def() -> Dictionary:
	var female := rng.randf() < 0.5
	var shirt := Color.from_hsv(rng.randf(), rng.randf_range(0.15, 0.7), rng.randf_range(0.35, 0.92))
	var skin: String = SKINS[rng.randi() % SKINS.size()]
	var look := {
		"suit": shirt.to_html(false), "pants": JEANS[rng.randi() % JEANS.size()], "accent": "#2a2a2a",
		"skin": skin, "hair": HAIRS[rng.randi() % HAIRS.size()], "extras": [], "build": "female" if female else "male",
		"gloves": skin, "glove_length": 0.0, "boots": SHOES[rng.randi() % SHOES.size()], "boot_height": 0.1,
		"no_belt": rng.randf() < 0.6, "belt": "#3a2a1e", "scale": rng.randf_range(0.92, 1.05),
		"eye_color": ["#3a2a1a", "#2a4a6a", "#4a5a2a", "#1a1a1a"][rng.randi() % 4],
	}
	if female:
		look["hair_style"] = ["long", "ponytail", "bob", "curly", "wild", "long"][rng.randi() % 6]
	else:
		look["hair_style"] = ["short", "buzz", "slick", "curly", "bald", "short", "long"][rng.randi() % 7]
		if rng.randf() < 0.4:
			look["facial"] = ["stubble", "beard", "goatee"][rng.randi() % 3]
	if rng.randf() < 0.12 and not female:
		look["build"] = "bulky"
	match rng.randi() % 6:
		0, 1:
			look["sleeve"] = 0.45    # T-shirt
		2:
			look["extras"].append("jacket")
			look["coat_color"] = Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.15, 0.5)).to_html(false)
		3:
			# Office clothes
			look["suit"] = ["#1e2430", "#2a2a2e", "#3a3a40", "#4a3a2a"][rng.randi() % 4]
			look["pants"] = look["suit"]
			look["collar"] = "#e8e8e8"
			look["extras"].append("coat_short")
			look["coat_color"] = look["suit"]
			look["boots"] = "#1a1a1a"
		4:
			if female:
				look["extras"].append("skirt")
				look["skirt_color"] = shirt.darkened(0.2).to_html(false)
				look["sleeve"] = 0.45
			else:
				look["sleeve"] = 1.0    # sleeves rolled up
		5:
			look["sleeve"] = 0.0 if rng.randf() < 0.5 else 2.0
			if look["sleeve"] == 2.0:
				look["extras"].append("coat")
				look["coat_color"] = ["#5a4a3a", "#2a2a30", "#6a5a48", "#3a4a5a"][rng.randi() % 4]
	# Accessories: hoodies, ties, backpacks, hats, glasses, sneakers.
	var office: bool = look.get("collar", "") == "#e8e8e8"
	if office:
		look["extras"].append("tie")
		look["tie_color"] = ["#7a1a2a", "#1a2a5a", "#2a4a2a", "#5a4a1a", "#3a3a3a"][rng.randi() % 5]
	elif rng.randf() < 0.18:
		look["extras"].append("hoodie")
		look["sleeve"] = 2.0
		look["coat_color"] = look["suit"]
	if not office and rng.randf() < 0.22:
		look["extras"].append("backpack")
		look["pack_color"] = ["#2a3a4a", "#5a1a1a", "#1a1a1a", "#3a5a2a", "#6a5a2a"][rng.randi() % 5]
	var hat := rng.randf()
	if hat < 0.1:
		look["extras"].append("beanie")
		look["hat_color"] = Color.from_hsv(rng.randf(), 0.4, rng.randf_range(0.2, 0.6)).to_html(false)
	elif hat < 0.18 and not office:
		look["extras"].append("cap")
	if rng.randf() < 0.15:
		look["extras"].append("glasses")
	if not office and rng.randf() < 0.6:
		look["sole"] = "#f2f2ee" if rng.randf() < 0.7 else "#1a1a1a"
	look["anim"] = _civ_anim()
	var name: String = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	return {
		"id": "civilian", "name": name, "alias": name, "side": "", "home": "any",
		"health": 35, "speed": rng.randf_range(0.75, 0.95), "power": 0.4, "movement": "run",
		"primary": {"kind": "melee", "damage": 4}, "secondary": {"kind": "melee", "damage": 4},
		"special": {"kind": "rage"},
		"look": look,
	}


## Everyday people walk all sorts of ways.
func _civ_anim() -> Dictionary:
	var runs := ["athlete", "strut", "swagger", "bounce", "glide", "marching", "heavy"]
	var idles := ["relaxed", "pockets", "hands_hips", "arms_crossed", "relaxed", "regal"]
	return {"run": runs[rng.randi() % runs.size()], "idle": idles[rng.randi() % idles.size()],
		"stride": rng.randf_range(0.85, 1.15), "cadence": rng.randf_range(0.85, 1.15), "arms": rng.randf_range(0.6, 1.3),
		"lean": rng.randf_range(-0.05, 0.15), "tempo": rng.randf_range(0.7, 1.3)}


func police_def() -> Dictionary:
	var skin: String = SKINS[rng.randi() % SKINS.size()]
	var female := rng.randf() < 0.3
	return {
		"id": "police", "name": "Police Officer", "alias": "Police Officer", "side": "hero", "home": "any",
		"health": 70, "speed": 0.95, "power": 0.7, "movement": "run",
		"primary": {"kind": "gun", "damage": 5, "cooldown": 0.45}, "secondary": {"kind": "melee", "damage": 7},
		"special": {"kind": "rage"},
		"look": {"suit": "#1d2a44", "pants": "#151a24", "accent": "#0e0e0e", "skin": skin,
			"hair": HAIRS[rng.randi() % HAIRS.size()], "extras": ["cap", "emblem_star"], "build": "female" if female else "male",
			"hair_style": "ponytail" if female else ["short", "buzz"][rng.randi() % 2], "gloves": skin, "glove_length": 0.0,
			"boots": "#0e0e0e", "boot_height": 0.14, "belt": "#0e0e0e", "sleeve": 0.45 if rng.randf() < 0.5 else 2.0,
			"gear": {"right": "pistol"},
			"anim": {"run": "marching", "idle": ["hands_hips", "arms_crossed", "relaxed"][rng.randi() % 3],
				"stride": rng.randf_range(0.9, 1.1), "tempo": rng.randf_range(0.8, 1.1)}},
	}


func thug_def(gang: int) -> Dictionary:
	var g: Dictionary = GANGS[clampi(gang, 0, GANGS.size() - 1)]
	var armed := rng.randf() < 0.55
	var extras := []
	if rng.randf() < 0.5:
		extras.append("mask_bandana")
	if rng.randf() < 0.45:
		extras.append("hood")
	extras.append("jacket" if rng.randf() < 0.6 else "leather")
	if not extras.has("hood") and rng.randf() < 0.35:
		extras.append("beanie" if rng.randf() < 0.6 else "cap")
	return {
		"id": "thug", "name": g["name"], "alias": g["name"], "side": "villain", "home": "any",
		"health": 55, "speed": 0.95, "power": 0.7, "movement": "run",
		"primary": {"kind": "gun", "damage": 5, "cooldown": 0.5} if armed else {"kind": "melee", "damage": 9},
		"secondary": {"kind": "melee", "damage": 8},
		"special": {"kind": "rage"},
		"look": {"suit": g["suit"], "legs": g["legs"], "accent": g["accent"],
			"skin": SKINS[rng.randi() % SKINS.size()], "hair": HAIRS[rng.randi() % HAIRS.size()],
			"coat_color": g["suit"], "glove_length": 0.0, "boots": SHOES[rng.randi() % SHOES.size()], "boot_height": 0.12,
			"hair_style": ["short", "buzz", "bald", "curly"][rng.randi() % 4], "facial": ["", "stubble", "beard", "goatee"][rng.randi() % 4],
			"no_belt": true, "sleeve": 2.0 if rng.randf() < 0.7 else 0.45, "sole": "#e8e8e8", "hat_color": g["accent"],
			"extras": extras, "anim": {"run": ["swagger", "heavy", "stalk", "athlete"][rng.randi() % 4],
				"idle": ["menace", "pockets", "fists", "hunched"][rng.randi() % 4], "cadence": rng.randf_range(0.85, 1.15), "sway": rng.randf_range(0.0, 0.2)}},
	}
