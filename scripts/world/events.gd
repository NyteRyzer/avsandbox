class_name Events
extends Node
## Dynamic open-world events: crimes in progress, super-villain sightings,
## police raids, heists, and breaches full of doppelgangers from other
## Earths. Which events appear depends on whether you play a hero or villain.

signal changed

const HERO_EVENTS := ["robbery", "villain_attack", "breach", "gang_war", "dominators", "jailbreak", "fire", "chase",
	"team_attack", "nemesis", "incursion", "falling", "meteors", "runaway"]
const VILLAIN_EVENTS := ["police_raid", "hero_patrol", "heist", "breach", "dominators", "team_patrol", "nemesis",
	"incursion", "meteors"]
const ACTIVITY_INFO := {
	"fire": ["Building fire! Rescue the people trapped inside", "#ff8a2a"],
	"chase": ["Getaway car! Stop the robbers", "#ffd23a"],
	"incursion": ["Breach incursion! Smash the breach shut", "#ff4a6a"],
	"falling": ["People are falling from a rooftop! Catch them", "#ffd23a"],
	"meteors": ["Meteor shower! Smash them before they land", "#ff8a3a"],
	"runaway": ["Runaway car! Get in front of it and stop it", "#ffd23a"],
}

var world
var active: Dictionary = {}
var cooldown := 20.0
var rng := RandomNumberGenerator.new()
var completed := 0
var _marker: Node3D
var enabled := true


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if not enabled or world.player == null or not is_instance_valid(world.player):
		return
	if active.is_empty():
		cooldown -= delta
		if cooldown <= 0.0:
			start_random()
		return
	active["time"] += delta
	if active.has("custom"):
		var act: Activity = active["custom"]
		if not is_instance_valid(act):
			_finish()
			return
		active["remaining"] = act.remaining()
		active["total"] = maxi(int(active["total"]), act.total)
		active["pos"] = act.marker_pos()
		if _marker:
			_marker.global_position = act.marker_pos()
		if act.done:
			_complete()
		elif act.failed or world.player.global_position.distance_to(act.center) > 900.0:
			_expire()
		return
	var alive := 0
	for a in active["actors"]:
		if is_instance_valid(a) and not a.dead:
			alive += 1
	active["remaining"] = alive
	var far: bool = world.player.global_position.distance_to(active["pos"]) > 700.0
	if alive == 0:
		_complete()
	elif active["time"] > 300.0 or far:
		_expire()
	if _marker:
		_marker.rotation.y += delta * 0.6


func start_random(kind := "") -> void:
	if not active.is_empty():
		_expire()
	var hero: bool = Game.player_side() == 1
	if kind == "":
		var pool: Array = HERO_EVENTS if hero else VILLAIN_EVENTS
		kind = pool[rng.randi() % pool.size()]
	if kind in ["jailbreak", "fire", "chase", "falling", "runaway"] and world.city.kind != "metro":
		kind = "robbery"
	if ACTIVITY_INFO.has(kind):
		_start_activity(kind)
		return
	var p: Vector3 = world.player.global_position
	var pos: Vector3 = world.city.random_road_point(Vector3(p.x, 0, p.z), 90.0, 220.0, rng)
	if kind == "jailbreak":
		pos = world.city.landmark("Iron Heights").get("pos", pos) + Vector3(60, 0, 0)
	var district: String = world.city.district_at(pos)
	var pop: Population = world.population
	var actors: Array = []
	var title := ""
	var enemy_team := "villain" if hero else "hero"
	var color := Color("#ff4040")
	match kind:
		"robbery":
			title = "Robbery in progress"
			var gang: int = world.city.district_index(pos)
			for k in rng.randi_range(4, 6):
				actors.append(pop.spawn_thug(_near(pos, 6.0), gang))
		"gang_war":
			title = "Gang war"
			for k in 4:
				actors.append(pop.spawn_thug(_near(pos, 8.0), 0))
			for k in 4:
				actors.append(pop.spawn_thug(_near(pos + Vector3(12, 0, 0), 8.0), 3))
		"villain_attack":
			var v := Game.random_character("villain")
			title = "%s is attacking %s" % [v["alias"], district]
			actors.append(pop.spawn_character(v, "villain", pos))
			for k in 3:
				actors.append(pop.spawn_thug(_near(pos, 7.0)))
		"breach":
			title = "Breach! Doppelgangers from another Earth"
			color = Color("#4fa8ff")
			for k in 2:
				var c := Game.random_character()
				var a: Actor = pop.spawn_character(c, enemy_team, _near(pos, 6.0))
				a.display_name = "Earth-%d %s" % [rng.randi_range(2, 52), c["alias"]]
				actors.append(a)
			FX.portal(world, pos + Vector3.UP * 3.0, Color("#4fa8ff"))
		"dominators":
			title = "Dominator invasion!"
			color = Color("#c47aff")
			for k in 6:
				var a: Actor = pop.spawn_character(dominator_def(), "villain" if hero else "hero", _near(pos, 10.0) + Vector3.UP * 20.0)
				a.grudges[world.player.get_instance_id()] = 60.0
				actors.append(a)
			FX.portal(world, pos + Vector3.UP * 20.0, Color("#c47aff"))
		"jailbreak":
			title = "Jailbreak at Iron Heights!"
			color = Color("#ff9a3a")
			for k in 2:
				var v := Game.random_character("villain")
				actors.append(pop.spawn_character(v, "villain", _near(pos, 8.0)))
			for k in 5:
				var d: Dictionary = pop.thug_def(0)
				d["alias"] = "Escaped Inmate"
				d["look"]["suit"] = "#e86a1a"
				d["look"]["legs"] = "#e86a1a"
				d["look"]["extras"] = []
				actors.append(pop.spawn_character(d, "thug", _near(pos, 10.0)))
		"police_raid":
			title = "Police raid in %s" % district
			color = Color("#4f8aff")
			for k in 6:
				actors.append(pop.spawn_police(_near(pos, 7.0)))
		"hero_patrol":
			var h := Game.random_character("hero")
			title = "%s is on patrol" % h["alias"]
			color = Color("#4f8aff")
			actors.append(pop.spawn_character(h, "hero", pos))
			for k in 2:
				actors.append(pop.spawn_police(_near(pos, 6.0)))
		"team_attack", "team_patrol":
			# A whole team at once: the Injustice Society, the Rogues, the Legends...
			var side := "villain" if kind == "team_attack" else "hero"
			var team := Teams.random_team(side, 3)
			var ids: Array = Teams.members(team).filter(func(id) -> bool: return id != str(world.player.def.get("id", "")))
			ids.shuffle()
			color = Teams.color(team)
			title = ("The %s is attacking %s!" if team.begins_with("Injustice") or team.begins_with("Legion") else "%s strike %s!") % [team, district]
			if side == "hero":
				title = "%s on patrol in %s" % [team, district]
			for id in ids.slice(0, 3):
				var a: Actor = pop.spawn_character(Game.get_character(id), side, _near(pos, 7.0))
				a.grudges[world.player.get_instance_id()] = 30.0
				actors.append(a)
			if actors.is_empty():
				return
			actors[0].make_boss(1.6)
		"nemesis":
			# Your archenemy comes for you, personally.
			var nid := Teams.nemesis(str(world.player.def.get("id", "")))
			if nid == "" or not Game.by_id.has(nid):
				kind = "villain_attack" if hero else "hero_patrol"
				var v := Game.random_character("villain" if hero else "hero")
				nid = v["id"]
			var nd: Dictionary = Game.get_character(nid)
			var nside := str(nd["side"])
			if nside == str(world.player.team):
				nside = enemy_team
			title = "NEMESIS: %s has come for you" % nd["alias"]
			color = Color("#ff2a6a")
			var n: Actor = pop.spawn_character(nd, nside, pos)
			n.make_boss(2.2)
			n.display_name = str(nd["alias"])
			n.grudges[world.player.get_instance_id()] = 120.0
			n.brain.detect = 120.0
			actors.append(n)
			var line: String = Emotes.LINES.get(nid, "")
			if line != "":
				world.notify("%s: \"%s\"" % [nd["alias"], line], color)
			if world.news:
				world.news.report("%s spotted in %s, hunting %s." % [nd["alias"], district, world.player.def["alias"]])
		"heist":
			title = "Heist: take out the armored-truck guards"
			color = Color("#ffd23a")
			for k in 5:
				actors.append(pop.spawn_police(_near(pos, 6.0)))
			var truck := Prop.new()
			truck.build(world, "car")
			world.props_root.add_child(truck)
			truck.global_position = pos + Vector3.UP * 0.5
	for a in actors:
		a.event_tag = kind
		a.brain.home = pos
		a.brain.leash = 30.0
		a.brain.detect = 38.0
		if kind == "nemesis":
			a.brain.leash = 400.0
			a.brain.detect = 150.0
	active = {"kind": kind, "title": title, "pos": pos, "actors": actors, "time": 0.0,
		"remaining": actors.size(), "total": actors.size(), "district": district}
	_spawn_marker(pos, color, title)
	world.notify("NEW EVENT: " + title, color)
	Sfx.play("event", null, -2.0)
	changed.emit()


## Dominators: big-headed alien invaders with psychic blasts.
func dominator_def() -> Dictionary:
	return {
		"id": "dominator", "name": "Dominator", "alias": "Dominator", "side": "villain", "home": "any",
		"health": 110, "speed": 0.9, "power": 1.0, "movement": "flight", "fly_speed": 0.9,
		"primary": {"kind": "bolt", "damage": 12, "color": "#c47aff", "style": "energy"},
		"secondary": {"kind": "psychic", "damage": 12},
		"special": {"kind": "rage"},
		"look": {"suit": "#4a3a5a", "legs": "#3a2a4a", "accent": "#c47aff", "skin": "#8a8a7a", "hair": "#8a8a7a",
			"extras": ["glow_eyes", "armor"], "hair_style": "bald", "eye_glow": "#ffd23a", "build": "armored", "scale": 1.2,
			"anim": {"idle": "regal", "run": "glide", "fly": "levitate"}},
	}


func _near(pos: Vector3, r: float) -> Vector3:
	return pos + Vector3(rng.randf_range(-r, r), 0, rng.randf_range(-r, r))


func _spawn_marker(pos: Vector3, color: Color, title: String) -> void:
	_clear_marker()
	_marker = Node3D.new()
	world.fx_root.add_child(_marker)
	_marker.global_position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.8
	cyl.height = 400.0
	cyl.radial_segments = 12
	beam.mesh = cyl
	beam.material_override = FX.glow_mat(color, 0.25)
	beam.position = Vector3(0, 200.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam)
	var label := Label3D.new()
	label.text = title
	label.font_size = 96
	label.pixel_size = 0.03
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.4)
	label.position = Vector3(0, 14, 0)
	label.no_depth_test = true
	_marker.add_child(label)


func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _complete() -> void:
	if world.player and is_instance_valid(world.player):
		world.final_blow(world.player)
	var reward := 100 + int(active["total"]) * 20
	completed += 1
	Game.add_score(reward)
	world.notify("EVENT COMPLETE: %s  +%d" % [active["title"], reward], Color("#60ff90"))
	world.news.on_event(str(active["title"]), Game.player_side() == 1)
	Game.record("events")
	Sfx.play("event", null, 0.0)
	if world.player:
		world.player.heal(world.player.max_hp * 0.3)
	_finish()


func _expire() -> void:
	world.notify("Event ended: " + str(active.get("title", "")), Color("#a0a0a0"))
	for a in active.get("actors", []):
		if is_instance_valid(a):
			a.event_tag = ""
	_finish()


## Drops the current event without a message (used when changing worlds).
func reset() -> void:
	if active.has("custom") and is_instance_valid(active["custom"]):
		active["custom"].cleanup()
	for a in active.get("actors", []):
		if is_instance_valid(a):
			a.event_tag = ""
	active = {}
	cooldown = rng.randf_range(25.0, 45.0)
	_clear_marker()
	changed.emit()


## Fire rescues, getaway chases and the incidents (breach incursions,
## falling people, meteor showers, runaway cars) run as their own Activity.
func _start_activity(kind: String) -> void:
	var act: Activity = Incident.new() if kind in Incident.KINDS else Activity.new()
	world.fx_root.add_child(act)
	var ok := false
	var near: Vector3 = world.player.global_position
	if act is Incident:
		ok = (act as Incident).start(world, kind, near)
	else:
		ok = act.start_fire(world, near) if kind == "fire" else act.start_chase(world, near)
	if not ok:
		act.queue_free()
		start_random("robbery")
		return
	var title: String = ACTIVITY_INFO[kind][0]
	var color := Color(str(ACTIVITY_INFO[kind][1]))
	active = {"kind": kind, "title": title, "pos": act.marker_pos(), "actors": [], "time": 0.0, "custom": act,
		"remaining": act.remaining(), "total": maxi(act.remaining(), act.total), "district": world.city.district_at(act.center)}
	_spawn_marker(act.marker_pos(), color, title)
	world.notify("NEW EVENT: " + title, color)
	Sfx.play("event", null, -2.0)
	changed.emit()


func _finish() -> void:
	if active.has("custom") and is_instance_valid(active["custom"]):
		active["custom"].cleanup()
	active = {}
	cooldown = rng.randf_range(25.0, 45.0)
	_clear_marker()
	changed.emit()
