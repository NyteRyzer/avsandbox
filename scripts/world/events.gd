class_name Events
extends Node
## Dynamic open-world events: crimes in progress, super-villain sightings,
## police raids, heists, and breaches full of doppelgangers from other
## Earths. Which events appear depends on whether you play a hero or villain.

signal changed

const HERO_EVENTS := ["robbery", "villain_attack", "breach", "gang_war"]
const VILLAIN_EVENTS := ["police_raid", "hero_patrol", "heist", "breach"]

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
	var p: Vector3 = world.player.global_position
	var pos: Vector3 = world.city.random_road_point(Vector3(p.x, 0, p.z), 90.0, 220.0, rng)
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
	active = {"kind": kind, "title": title, "pos": pos, "actors": actors, "time": 0.0,
		"remaining": actors.size(), "total": actors.size(), "district": district}
	_spawn_marker(pos, color, title)
	world.notify("NEW EVENT: " + title, color)
	Sfx.play("event", null, -2.0)
	changed.emit()


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
	var reward := 100 + int(active["total"]) * 20
	completed += 1
	Game.add_score(reward)
	world.notify("EVENT COMPLETE: %s  +%d" % [active["title"], reward], Color("#60ff90"))
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
	for a in active.get("actors", []):
		if is_instance_valid(a):
			a.event_tag = ""
	active = {}
	cooldown = rng.randf_range(25.0, 45.0)
	_clear_marker()
	changed.emit()


func _finish() -> void:
	active = {}
	cooldown = rng.randf_range(25.0, 45.0)
	_clear_marker()
	changed.emit()
