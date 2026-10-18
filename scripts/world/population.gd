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
	if world.city.kind == "speedforce":
		_speed_force()
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


func _speed_force() -> void:
	_wraith_t -= 0.5
	if _wraith_t <= 0.0:
		_wraith_t = 30.0
		if get_tree().get_nodes_in_group("wraiths").size() < 3:
			spawn_wraiths(2)


## Time Wraiths: the Speed Force's hunters, out for any speedster.
func spawn_wraiths(count: int) -> void:
	var p: Vector3 = world.player.global_position
	for k in count:
		var ang := rng.randf() * TAU
		var pos := p + Vector3(cos(ang) * 40.0, 6.0, sin(ang) * 40.0)
		var team := "villain" if Game.player_side() == 1 else "hero"
		var a := spawn_character(wraith_def(), team, pos)
		a.add_to_group("wraiths")
		a.brain.detect = 300.0
		a.brain.leash = 0.0
		a.grudges[world.player.get_instance_id()] = 9999.0
		FX.portal(world, a.chest(), Color("#a8c8ff"))


func wraith_def() -> Dictionary:
	return {
		"id": "time_wraith", "name": "Time Wraith", "alias": "Time Wraith", "side": "villain", "home": "any",
		"health": 140, "speed": 1.3, "power": 1.0, "movement": "flight", "fly_speed": 1.4,
		"primary": {"kind": "melee", "damage": 14, "element": "ice"},
		"secondary": {"kind": "psychic", "damage": 10},
		"special": {"kind": "rage"},
		"look": {"suit": "#141820", "legs": "#0c0e14", "accent": "#2a3040", "skin": "#3a3e48", "hair": "#0a0a0a",
			"extras": ["hood", "cape"], "cape": "#10141c", "eye_glow": "#c8e0ff", "build": "male", "scale": 1.15},
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


func civilian_def() -> Dictionary:
	var shirt := Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.35, 0.9))
	var legs := Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.15, 0.5))
	var extras := []
	if rng.randf() < 0.45:
		extras.append("hair_long")
	if rng.randf() < 0.15:
		extras.append("coat")
	var name: String = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	return {
		"id": "civilian", "name": name, "alias": name, "side": "", "home": "any",
		"health": 35, "speed": rng.randf_range(0.75, 0.95), "power": 0.4, "movement": "run",
		"primary": {"kind": "melee", "damage": 4}, "secondary": {"kind": "melee", "damage": 4},
		"special": {"kind": "rage"},
		"look": {"suit": shirt.to_html(false), "legs": legs.to_html(false), "accent": "#222222",
			"skin": SKINS[rng.randi() % SKINS.size()], "hair": HAIRS[rng.randi() % HAIRS.size()],
			"extras": extras, "scale": rng.randf_range(0.92, 1.05)},
	}


func police_def() -> Dictionary:
	return {
		"id": "police", "name": "Police Officer", "alias": "Police Officer", "side": "hero", "home": "any",
		"health": 70, "speed": 0.95, "power": 0.7, "movement": "run",
		"primary": {"kind": "gun", "damage": 5, "cooldown": 0.45}, "secondary": {"kind": "melee", "damage": 7},
		"special": {"kind": "rage"},
		"look": {"suit": "#1d2a44", "legs": "#151a24", "accent": "#0e0e0e",
			"skin": SKINS[rng.randi() % SKINS.size()], "hair": HAIRS[rng.randi() % HAIRS.size()],
			"extras": ["cap", "emblem_star"]},
	}


func thug_def(gang: int) -> Dictionary:
	var g: Dictionary = GANGS[clampi(gang, 0, GANGS.size() - 1)]
	var armed := rng.randf() < 0.55
	var extras := ["mask_bandana"]
	if rng.randf() < 0.6:
		extras.append("hood")
	return {
		"id": "thug", "name": g["name"], "alias": g["name"], "side": "villain", "home": "any",
		"health": 55, "speed": 0.95, "power": 0.7, "movement": "run",
		"primary": {"kind": "gun", "damage": 5, "cooldown": 0.5} if armed else {"kind": "melee", "damage": 9},
		"secondary": {"kind": "melee", "damage": 8},
		"special": {"kind": "rage"},
		"look": {"suit": g["suit"], "legs": g["legs"], "accent": g["accent"],
			"skin": SKINS[rng.randi() % SKINS.size()], "hair": HAIRS[rng.randi() % HAIRS.size()],
			"extras": extras},
	}
