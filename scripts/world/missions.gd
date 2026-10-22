class_name Missions
extends Node
## The story campaign, "Crisis on Infinite Earths": seven chapters that send
## you across the multiverse, plus the natives you meet on other Earths
## (Zoom on Earth-2, the Reich on Earth-X...). Progress is saved.
##
## Each chapter has one objective:
##   interior  - walk into a room (e.g. S.T.A.R. Labs)
##   defeat    - travel to a place and defeat the characters waiting there
##   return    - get back to Earth-1

const CHAPTERS := [
	{"title": "The Monitor's Warning", "kind": "interior", "target": "star_labs",
		"brief": "A red sky over Central City. Get to S.T.A.R. Labs: Cisco is picking up something huge."},
	{"title": "The Fastest Man Alive... on Earth-2", "kind": "defeat", "place": "earth2", "foes": ["zoom"], "boss": true,
		"brief": "Zoom is stealing speed from every speedster on Earth-2. Breach there and stop him.",
		"hint": "Breach to Earth-2: play as Vibe, use the S.T.A.R. Labs Breach Room, or run there as a speedster."},
	{"title": "Crisis on Earth-X", "kind": "defeat", "place": "earthx", "foes": ["overgirl", "dark_arrow"], "boss": true,
		"brief": "Overgirl and Dark Arrow are building a weapon to invade every Earth. Shut them down."},
	{"title": "Into the Speed Force", "kind": "defeat", "place": "speedforce", "foes": ["time_wraith", "time_wraith", "time_wraith"],
		"brief": "The Speed Force is failing. Run into it (or take the S.T.A.R. Labs treadmill) and drive off the Time Wraiths.",
		"hint": "Only speedsters can reach the Speed Force. Switch with Esc, or use the Tab menu's Multiverse tab."},
	{"title": "The Death of Earth-90", "kind": "defeat", "place": "earth90", "foes": ["shadow_demon", "shadow_demon", "shadow_demon", "shadow_demon"],
		"brief": "The anti-matter wave is erasing Earth-90. Hold off the Shadow Demons while its people escape."},
	{"title": "The Anti-Monitor", "kind": "defeat", "place": "antimatter", "foes": ["anti_monitor"], "boss": true,
		"brief": "The source of the Crisis waits at the dawn of time. Breach into the Anti-Matter Universe and end this."},
	{"title": "Earth-Prime", "kind": "return", "place": "earth1",
		"brief": "It's over. Head home through the light (or any breach) and see what the new multiverse looks like."},
]

## Who you meet when you arrive somewhere: [character id, how many, boss?]
const NATIVES := {
	"earth2": [["zoom", 1, false]],
	"earthx": [["overgirl", 1, false], ["dark_arrow", 1, false]],
	"earth99": [["batwoman", 1, false]],
	"earth90": [["shadow_demon", 3, false]],
	"1942": [["vandal_savage", 1, false]],
	"2046": [["deathstroke", 1, false]],
	"3030": [["brainiac_5", 1, false]],
	"old_west": [["vandal_savage", 1, false]],
	"earth19": [["captain_cold", 1, false]],
}

var world
var chapter := 0
var foes: Array = []
var _spawned_for := -1
var _beaten: Dictionary = {}   # instance ids of this chapter's foes seen knocked out
var _marker: Node3D


func _ready() -> void:
	chapter = int(Game.settings.get("crisis_chapter", 0))


func current() -> Dictionary:
	return CHAPTERS[chapter] if chapter < CHAPTERS.size() else {}


func is_complete() -> bool:
	return chapter >= CHAPTERS.size()


func restart() -> void:
	_set_chapter(0)


func _set_chapter(n: int) -> void:
	chapter = n
	_spawned_for = -1
	foes.clear()
	Game.settings["crisis_chapter"] = n
	Game.save_settings()
	var c := current()
	if not c.is_empty():
		world.hud.show_banner("CHAPTER %d: %s" % [n + 1, str(c["title"]).to_upper()], Color("#ff9a6a"))
		world.notify(str(c["brief"]), Color("#ffc8a0"))
		if c.has("hint") and world.place_id != str(c.get("place", "")):
			world.notify(str(c["hint"]), Color("#ffe080"))


## The HUD's tracker text.
func tracker() -> String:
	if is_complete():
		return ""
	var c := current()
	var text := "CRISIS %d/%d: %s\n" % [chapter + 1, CHAPTERS.size(), c["title"]]
	match str(c["kind"]):
		"interior":
			text += "Go inside " + Interiors.NAMES[c["target"]]
		"defeat":
			if world.place_id != str(c["place"]):
				text += "Travel to " + Multiverse.dest(str(c["place"]))["name"]
			else:
				var left := foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
				text += "Defeat them: %d left" % left
		"return":
			text += "Return to Earth-1"
	return text


func _process(_delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player) or is_complete():
		return
	var c := current()
	match str(c["kind"]):
		"interior":
			if world.inside == str(c["target"]):
				_advance()
		"defeat":
			if world.place_id == str(c["place"]) and world.inside == "":
				if _spawned_for != chapter:
					_spawn_foes(c)
				else:
					# Only foes actually beaten count: if they were cleared away
					# (Survival, the sandbox), bring them back instead.
					var standing := 0
					for a in foes:
						if is_instance_valid(a) and not a.dead:
							standing += 1
						elif is_instance_valid(a) and a.dead:
							_beaten[a.get_instance_id()] = true
					if standing == 0:
						if _beaten.is_empty():
							_spawned_for = -1
						else:
							_advance()
		"return":
			if world.place_id == "earth1":
				_advance()


func _advance() -> void:
	var c := current()
	var reward := 250 + chapter * 150
	Game.add_score(reward)
	Game.record("chapters")
	world.notify("CHAPTER COMPLETE: %s  +%d" % [c["title"], reward], Color("#60ff90"))
	Sfx.play("event", null, 2.0)
	if world.player:
		world.player.heal(world.player.max_hp)
		world.player.ult = 100.0
	_clear_marker()
	if chapter + 1 >= CHAPTERS.size():
		chapter = CHAPTERS.size()
		Game.settings["crisis_chapter"] = chapter
		Game.save_settings()
		world.hud.show_banner("THE CRISIS IS OVER", Color("#ffd23a"))
		world.notify("You saved the multiverse! Restart the campaign from the pause menu any time.", Color("#ffd23a"))
		return
	_set_chapter(chapter + 1)


func _spawn_foes(c: Dictionary) -> void:
	_beaten.clear()
	_spawned_for = chapter
	foes.clear()
	var p: Vector3 = world.player.global_position
	var fwd: Vector3 = -world.cam.global_basis.z
	fwd.y = 0
	var center := p + fwd.normalized() * 28.0
	if world.city.kind == "metro":
		center = world.city.snap_to_road(center) + Vector3.UP * 0.5
	for id in c["foes"]:
		var a := _spawn(str(id), center + Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6)))
		if c.get("boss", false):
			a.make_boss(3.0 if id != "anti_monitor" else 6.0)
			a.display_name = a.display_name + " (BOSS)"
		a.add_to_group("mission_foes")
		foes.append(a)
	_spawn_marker(center)
	world.notify("They're here. Take them down!", Color("#ff8060"))


## Spawns a hostile character by id (roster or one of the realm creatures).
func _spawn(id: String, pos: Vector3) -> Actor:
	var pop: Population = world.population
	var d: Dictionary
	match id:
		"time_wraith":
			d = pop.wraith_def()
		"shadow_demon":
			d = pop.shadow_demon_def()
		_:
			d = Game.get_character(id)
	var team := "villain" if Game.player_side() == 1 else "hero"
	var a: Actor = pop.spawn_character(d, team, pos)
	a.set_meta("pinned", true)
	a.brain.leash = 0.0
	a.brain.detect = 120.0
	a.grudges[world.player.get_instance_id()] = 9999.0
	if d.get("id", "") == world.player.def.get("id", ""):
		a.display_name = Multiverse.dest(world.place_id)["name"] + " " + str(d["alias"])
	FX.breach(world, a.chest(), Color("#ff6a4a"), 0.8, 1.4)
	return a


## Called by the World after travelling somewhere: the locals show up.
func on_arrive(place: String) -> void:
	if not NATIVES.has(place):
		return
	var c := current()
	if str(c.get("place", "")) == place and str(c.get("kind", "")) == "defeat":
		return
	var p: Vector3 = world.player.global_position
	for n in NATIVES[place]:
		for k in int(n[1]):
			var ang := randf() * TAU
			var pos := p + Vector3(cos(ang), 0, sin(ang)) * randf_range(40.0, 70.0)
			if world.city.kind == "metro":
				pos = world.city.snap_to_road(pos) + Vector3.UP * 0.5
			var a := _spawn(str(n[0]), pos)
			a.brain.detect = 45.0
			a.grudges.clear()
			if a.display_name == str(Game.get_character(str(n[0])).get("alias", "")):
				a.display_name = Multiverse.dest(place)["name"] + " " + a.display_name
	if place == "earthx":
		for k in 6:
			var pos: Vector3 = world.city.random_road_point(p, 30.0, 90.0)
			var t: Actor = world.population.spawn_thug(pos, 2)
			t.display_name = "Earth-X Soldier"


func _spawn_marker(pos: Vector3) -> void:
	_clear_marker()
	_marker = Node3D.new()
	world.fx_root.add_child(_marker)
	_marker.global_position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 2.0
	cyl.height = 300.0
	beam.mesh = cyl
	beam.material_override = FX.glow_mat(Color("#ff6a4a"), 0.25)
	beam.position = Vector3(0, 150.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam)


func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## Where the minimap should point (the fight, or S.T.A.R. Labs).
func target_pos() -> Vector3:
	if is_complete():
		return Vector3.INF
	var c := current()
	if str(c["kind"]) == "interior" and world.inside == "":
		if not Interiors.is_remote(str(c["target"])):
			return Interiors.outside_point(str(c["target"]))
		for d in world.city.doors:
			if d["interior"] == c["target"]:
				return d["pos"]
	if _marker and is_instance_valid(_marker):
		return _marker.global_position
	return Vector3.INF
