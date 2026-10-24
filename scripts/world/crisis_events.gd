class_name CrisisEvents
extends Node
## Crisis Events (Story Mode): while you roam, a crisis breaks out in another
## city and the clock starts. The world remembers what you do about it:
##   - get there in time and beat the attackers: the city is safe, and if they
##     were holding a hero from an erased timeline, that hero is freed and
##     becomes playable
##   - let the clock run out: the villains occupy that district. Walk into an
##     occupied district and its occupation force comes for you; beat their
##     lieutenant to liberate it
## Occupied districts are saved, show on the HUD, and the Act IV story starts
## by handing most of the map to the Architect's villains.

const RESPONSE_TIME := 180.0
const FIRST_DELAY := 150.0
const BETWEEN := 300.0

var world
var enabled := true
var cooldown := FIRST_DELAY
var current: Dictionary = {}       # the active crisis: district, villain, captive, t, foes, spawned
var _force: Array = []             # the occupation force out in the district you're in
var _force_district := -1
var _marker: Node3D


func _state() -> Dictionary:
	return world.missions._state()


func occupied() -> Array:
	var s := _state()
	if typeof(s.get("occupied")) != TYPE_ARRAY:
		s["occupied"] = []
	return s["occupied"]


func is_occupied(district: int) -> bool:
	return occupied().has(district)


func occupy(district: int) -> void:
	if not is_occupied(district):
		occupied().append(district)
		Game.save_settings()


func liberate(district: int) -> void:
	occupied().erase(district)
	_state()["liberated"] = int(_state().get("liberated", 0)) + 1
	Game.record("districts_liberated")
	Game.add_score(400)
	world.hud.show_banner("%s LIBERATED" % City.DISTRICTS[district].to_upper(), Color("#60ff90"))
	world.notify("%s is free again." % City.DISTRICTS[district], Color("#60ff90"))
	Game.save_settings()


func nearest_occupied(p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for d in occupied():
		var c: Vector3 = world.city.district_center(int(d))
		var dist := c.distance_to(p)
		if dist < best_d:
			best_d = dist
			best = int(d)
	return best


## Crises only happen in Story Mode, on Earth-1, outdoors, once you've got
## the run of the city, and not in the middle of a story fight.
func _can_run() -> bool:
	if not enabled or not world.missions.story_on() or world.place_id != "earth1" or world.city.kind != "metro":
		return false
	if world.missions.chapter < 2:
		return false
	return true


func _free_roam() -> bool:
	if world.missions.is_complete():
		return true
	return str(world.missions.current_step().get("do", "")) in ["goto", "interior", "travel", "liberate"]


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player) or world.cinematic:
		return
	if not _can_run():
		return
	_tick_occupation()
	if current.is_empty():
		if world.inside == "" and _free_roam():
			cooldown -= delta
			if cooldown <= 0.0:
				start_crisis()
	else:
		_tick_crisis(delta)


## Something breaks out in another district.
func start_crisis(district := -1) -> Dictionary:
	var here: int = world.city.district_index(world.player.global_position)
	var options: Array = []
	for i in City.DISTRICTS.size():
		if i != here and not is_occupied(i):
			options.append(i)
	if options.is_empty():
		cooldown = BETWEEN
		return {}
	if district < 0:
		district = options[randi() % options.size()]
	var villains := Game.roster.filter(func(c) -> bool: return c["side"] == "villain" and c["id"] != "the_architect")
	var villain: String = villains[randi() % villains.size()]["id"]
	# Sometimes they're holding a hero from an erased timeline.
	var locked := Game.roster.filter(func(c) -> bool: return c["side"] == "hero" and not Game.is_unlocked(c["id"]))
	var captive := ""
	if not locked.is_empty() and randf() < 0.7:
		captive = locked[randi() % locked.size()]["id"]
	current = {"district": district, "villain": villain, "captive": captive, "t": RESPONSE_TIME, "spawned": false, "foes": []}
	var name: String = City.DISTRICTS[district]
	var who := str(Game.get_character(villain).get("alias", villain))
	world.hud.show_banner("CRISIS IN %s" % name.to_upper(), Color("#ff5a4a"))
	world.notify("CRISIS: %s is attacking %s! You have %d seconds to respond." % [who, name, int(RESPONSE_TIME)], Color("#ff7a6a"))
	if captive != "":
		world.notify("They're holding %s, pulled from an erased timeline." % str(Game.get_character(captive).get("alias", captive)), Color("#ffb0a0"))
	_place_marker(world.city.district_center(district))
	Sfx.play("event", null, 0.0)
	return current


func _tick_crisis(delta: float) -> void:
	var d := int(current["district"])
	var center: Vector3 = world.city.district_center(d)
	var p: Vector3 = world.player.global_position
	if _marker == null or not is_instance_valid(_marker):
		_place_marker(center)
	if not current["spawned"]:
		current["t"] = float(current["t"]) - delta
		if Vector2(p.x - center.x, p.z - center.z).length() < 160.0:
			_spawn_attack(center)
		elif float(current["t"]) <= 0.0:
			_fail()
		return
	var standing := 0
	for a in current["foes"]:
		if is_instance_valid(a) and not a.dead:
			standing += 1
	if standing == 0:
		_resolve()


func _spawn_attack(center: Vector3) -> void:
	current["spawned"] = true
	var foes: Array = []
	var p: Vector3 = world.player.global_position
	var at: Vector3 = world.city.snap_to_road(p.lerp(center, 0.6)) + Vector3.UP * 0.5
	var v: Actor = world.missions._spawn(str(current["villain"]), at)
	v.make_boss(1.6)
	foes.append(v)
	for k in 4:
		var t: Actor = world.population.spawn_thug(at + Vector3(randf_range(-8, 8), 0.5, randf_range(-8, 8)))
		t.set_meta("pinned", true)
		t.grudges[world.player.get_instance_id()] = 9999.0
		foes.append(t)
	if str(current["captive"]) != "":
		var c: Actor = world.population.spawn_character(Game.get_character(str(current["captive"])), world.player.team, at + Vector3(4, 0.5, 4))
		c.brain = null
		c.set_meta("pinned", true)
		c.set_meta("captive", true)
		current["captive_actor"] = c
	current["foes"] = foes
	world.notify("Stop %s!" % v.display_name, Color("#ff7a6a"))


func _resolve() -> void:
	var name: String = City.DISTRICTS[int(current["district"])]
	Game.add_score(300)
	Game.record("crises_averted")
	world.hud.show_banner("CRISIS AVERTED", Color("#60ff90"))
	world.notify("%s is safe. The city will remember that." % name, Color("#60ff90"))
	var captive := str(current["captive"])
	if captive != "" and Game.unlock(captive):
		var alias := str(Game.get_character(captive).get("alias", captive))
		world.notify("RESCUED: %s joins you from an erased timeline, and is now playable!" % alias, Color("#ffd23a"))
		world.hud.show_banner("%s UNLOCKED" % alias.to_upper(), Color("#ffd23a"))
		Game.record("heroes_rescued")
	var ca = current.get("captive_actor")
	if ca != null and is_instance_valid(ca):
		FX.flash(world, ca.chest(), Color("#ffd23a"), 1.5, 0.4)
		ca.queue_free()
	Game.save_settings()
	_end()


func _fail() -> void:
	var d := int(current["district"])
	occupy(d)
	world.hud.show_banner("%s HAS FALLEN" % City.DISTRICTS[d].to_upper(), Color("#ff3a3a"))
	world.notify("You didn't make it. %s's forces have occupied %s. Go back and liberate it." %
		[str(Game.get_character(str(current["villain"])).get("alias", "")), City.DISTRICTS[d]], Color("#ff7a6a"))
	Game.record("districts_lost")
	_end()


func _end() -> void:
	current = {}
	cooldown = BETWEEN
	_clear_marker()


## Walk into an occupied district and the occupation force comes for you.
func _tick_occupation() -> void:
	var p: Vector3 = world.player.global_position
	var here: int = world.city.district_index(p)
	var in_city: bool = not world.city.island_at(p).is_empty()
	if _force_district >= 0:
		var lieutenant: Actor = _force[0] if not _force.is_empty() else null
		if lieutenant == null or not is_instance_valid(lieutenant) or lieutenant.dead:
			var d := _force_district
			_clear_force(false)
			liberate(d)
		elif here != _force_district or not in_city:
			_clear_force(true)
		return
	if in_city and is_occupied(here) and world.inside == "":
		if current.is_empty() or int(current["district"]) != here:
			_spawn_force(here)


func _spawn_force(d: int) -> void:
	_force_district = d
	_force.clear()
	var p: Vector3 = world.player.global_position
	var at: Vector3 = world.city.snap_to_road(p + world.player.forward() * 35.0) + Vector3.UP * 0.5
	var villains := Game.roster.filter(func(c) -> bool: return c["side"] == "villain" and c["id"] != "the_architect")
	var v: Actor = world.missions._spawn(str(villains[randi() % villains.size()]["id"]), at)
	v.make_boss(1.8)
	v.display_name = "%s (Lieutenant)" % v.display_name
	_force.append(v)
	for k in 5:
		var t: Actor = world.population.spawn_thug(at + Vector3(randf_range(-10, 10), 0.5, randf_range(-10, 10)))
		t.set_meta("pinned", true)
		t.grudges[world.player.get_instance_id()] = 9999.0
		_force.append(t)
	world.notify("%s is occupied. Beat %s to liberate it!" % [City.DISTRICTS[d], v.display_name], Color("#ff7a6a"))


func _clear_force(despawn: bool) -> void:
	if despawn:
		for a in _force:
			if is_instance_valid(a) and not a.is_player:
				a.queue_free()
	_force.clear()
	_force_district = -1


func tracker() -> String:
	if not _can_run() and occupied().is_empty():
		return ""
	var lines := []
	if not current.is_empty():
		var name: String = City.DISTRICTS[int(current["district"])]
		if current["spawned"]:
			lines.append("CRISIS: stop the attack on %s" % name)
		else:
			lines.append("CRISIS: %s under attack  ·  %d s" % [name, int(maxf(0.0, float(current["t"])))])
	if not occupied().is_empty():
		var names := []
		for d in occupied():
			names.append(City.DISTRICTS[int(d)])
		lines.append("Occupied: " + ", ".join(names))
	return "\n".join(lines)


func _place_marker(pos: Vector3) -> void:
	_clear_marker()
	_marker = Node3D.new()
	world.fx_root.add_child(_marker)
	_marker.global_position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 5.0
	cyl.height = 400.0
	beam.mesh = cyl
	beam.material_override = FX.glow_mat(Color("#ff3a3a"), 0.3)
	beam.position = Vector3(0, 200.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam)


func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## Travelling away calls everything off (the crisis runs its course).
func reset() -> void:
	_clear_force(true)
	if not current.is_empty():
		if not current["spawned"]:
			current["t"] = minf(float(current["t"]), 30.0)
		else:
			for a in current["foes"]:
				if is_instance_valid(a):
					a.queue_free()
			current["spawned"] = false
	_clear_marker()
