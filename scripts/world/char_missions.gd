class_name CharMissions
extends Node
## Personal missions: a short story for whoever you're playing. The big names
## have hand-written storylines (Barry chases the Man in Yellow, Kara flies
## home to Argo City, Oliver goes back to Lian Yu...); everyone else gets one
## built from their home city, their team and their nemesis. Progress is saved
## per character.
##
## Step kinds:
##   defeat   - beat the foes waiting at a landmark ("thug" / "police" = goons)
##   goto     - reach a landmark (optionally on another Earth / place)
##   interior - walk into a room
##   rescue   - reach the people in danger at a landmark
##   travel   - get to another place in the multiverse

const HOME_LANDMARK := {"star": "Star City Downtown", "central": "Central City Downtown", "national": "National City Downtown",
	"freeland": "Freeland Downtown", "gotham": "Gotham City Downtown", "smallville": "Smallville Main Street", "any": "Central City Downtown"}
const CITY_NAME := {"star": "Star City", "central": "Central City", "national": "National City", "freeland": "Freeland",
	"gotham": "Gotham", "smallville": "Smallville", "any": "Central City"}
## Where each team meets: [kind, target, place].
const TEAM_HQ := {
	"Team Flash": ["interior", "star_labs", "earth1"], "Team Arrow": ["interior", "bunker", "earth1"],
	"Legends": ["goto", "The Waverider", "earth1"], "Justice Society": ["interior", "jsa_hq", "earth1"],
	"Super Friends": ["interior", "deo", "earth1"], "Super Family": ["interior", "kent_barn", "earth1"],
	"Team Batwoman": ["interior", "batcave", "earth1"], "Pierce Family": ["goto", "Garfield High", "earth1"],
	"Paragons": ["goto", "Time Bureau HQ", "vanishing_point"],
	"Injustice Society": ["goto", "JSA Headquarters", "earth1"], "Legion of Doom": ["goto", "Time Bureau HQ", "vanishing_point"],
	"Rogues": ["goto", "Iron Heights", "earth1"], "Evil Speedsters": ["goto", "Speed Force Heart", "speedforce"],
	"League of Assassins": ["goto", "Lian Yu", "earth1"], "Star City Underworld": ["goto", "Star City Docks", "earth1"],
	"Kryptonian Threats": ["goto", "Hall of Elders", "argo"], "Gotham Underworld": ["goto", "Arkham Asylum", "earth1"],
	"Freeland Syndicate": ["goto", "Freeland Clinic", "earth1"], "Central City Metas": ["goto", "S.T.A.R. Labs", "earth1"],
}

## Hand-written storylines.
const STORIES := {
	"flash": [
		{"title": "Lightning Strikes Twice", "kind": "defeat", "at": "Central City Downtown", "foes": ["weather_wizard", "thug", "thug"],
			"brief": "Mark Mardon is tearing up Central City with a storm. Shut him down."},
		{"title": "Run Into the Speed Force", "kind": "goto", "at": "Speed Force Heart", "place": "speedforce",
			"brief": "Something is wrong with your speed. Run fast enough to break into the Speed Force and find its heart."},
		{"title": "The Man in Yellow", "kind": "defeat", "at": "S.T.A.R. Labs", "foes": ["reverse_flash"], "boss": true,
			"brief": "Eobard Thawne is back at S.T.A.R. Labs. Finish it, Barry."}],
	"kid_flash": [
		{"title": "Wally's First Run", "kind": "defeat", "at": "Central City Downtown", "foes": ["thug", "thug", "thug", "thug"],
			"brief": "Barry's out of town. Show Central City it has another speedster."},
		{"title": "Faster Than Barry", "kind": "goto", "at": "Speed Force Heart", "place": "speedforce",
			"brief": "Find out how far your speed can take you."},
		{"title": "God of Speed", "kind": "defeat", "at": "Central City Downtown", "foes": ["savitar"], "boss": true,
			"brief": "Savitar has come back from the future. Save Iris."}],
	"supergirl": [
		{"title": "Protect National City", "kind": "defeat", "at": "CatCo Worldwide", "foes": ["livewire", "thug", "thug"],
			"brief": "Livewire has taken CatCo's broadcast tower. Get her off the air."},
		{"title": "The Last City of Krypton", "kind": "goto", "at": "Argo City Plaza", "place": "argo",
			"brief": "Your mother's message came from Argo City. Fly straight up, out of the atmosphere, and find it."},
		{"title": "Worldkiller", "kind": "defeat", "at": "The D.E.O.", "foes": ["reign"], "boss": true,
			"brief": "Reign is attacking the D.E.O. Stop her before she purges the city."}],
	"superman": [
		{"title": "Smallville Strong", "kind": "rescue", "at": "Smallville Main Street", "count": 4,
			"brief": "A tornado has torn through Main Street. Get everyone to safety."},
		{"title": "Last Son of Krypton", "kind": "goto", "at": "Hall of Elders", "place": "argo",
			"brief": "Fly to Argo City and speak with the Elders about where you came from."},
		{"title": "Doomsday", "kind": "defeat", "at": "Kent Farm", "foes": ["doomsday"], "boss": true,
			"brief": "The monster that killed Superman on another Earth has landed in Smallville. Protect your family."}],
	"green_arrow": [
		{"title": "Return to Lian Yu", "kind": "goto", "at": "Lian Yu",
			"brief": "The island made you who you are. Go back and remember why."},
		{"title": "The List", "kind": "defeat", "at": "Star City Docks", "foes": ["thug", "thug", "thug", "count_vertigo"],
			"brief": "Count Vertigo is moving his drug through the docks. You have failed this city, Count."},
		{"title": "Deathstroke", "kind": "defeat", "at": "Queen Consolidated", "foes": ["deathstroke"], "boss": true,
			"brief": "Slade Wilson has taken Queen Consolidated. Settle this."}],
	"batwoman": [
		{"title": "Over Gotham", "kind": "goto", "at": "Wayne Tower",
			"brief": "Grapple up and glide across Gotham's rooftops to Wayne Tower. Hold jump while falling to glide."},
		{"title": "The Wonderland Gang", "kind": "defeat", "at": "Arkham Asylum", "foes": ["thug", "thug", "thug", "thug"],
			"brief": "Alice's gang is breaking into Arkham. Stop them."},
		{"title": "Down the Rabbit Hole", "kind": "defeat", "at": "Crows Security", "foes": ["alice"], "boss": true,
			"brief": "Your sister is waiting for you at Crows Security. Bring Beth home."}],
	"ryan_wilder": [
		{"title": "The New Bat", "kind": "rescue", "at": "Gotham City Downtown", "count": 3,
			"brief": "The False Face Society has hostages downtown. Get them out."},
		{"title": "The Batcave", "kind": "interior", "target": "batcave", "brief": "Luke has new tech for you at the Batcave."},
		{"title": "Black Mask", "kind": "defeat", "at": "Wayne Tower", "foes": ["black_mask", "thug", "thug"], "boss": true,
			"brief": "Roman Sionis has taken Wayne Tower. Take it back."}],
	"stargirl": [
		{"title": "The New JSA", "kind": "interior", "target": "jsa_hq",
			"brief": "Find the old Justice Society headquarters in Smallville. The Cosmic Staff knows the way."},
		{"title": "Injustice in Blue Valley", "kind": "defeat", "at": "Smallville Main Street", "foes": ["solomon_grundy", "brainwave"],
			"brief": "The Injustice Society is back. Grundy and Brainwave are tearing up Main Street."},
		{"title": "Icicle", "kind": "defeat", "at": "Smallville Water Tower", "foes": ["icicle"], "boss": true,
			"brief": "Jordan Mahkent is freezing the town. End his plan."}],
	"white_canary": [
		{"title": "All Hands on Deck", "kind": "goto", "at": "The Waverider", "brief": "Get back to the Waverider, Captain."},
		{"title": "An Anachronism in 1942", "kind": "defeat", "at": "Central City Downtown", "place": "1942", "foes": ["vandal_savage"], "boss": true,
			"brief": "Vandal Savage is rewriting World War II. Take the Waverider to 1942."},
		{"title": "The Time Demon", "kind": "defeat", "at": "Time Bureau HQ", "place": "vanishing_point", "foes": ["mallus"], "boss": true,
			"brief": "Mallus is breaking free at Vanishing Point. Legends never quit."}],
	"black_lightning": [
		{"title": "Principal by Day", "kind": "rescue", "at": "Garfield High", "count": 4, "brief": "The 100 have Garfield High locked down. Get the students out."},
		{"title": "Clean Up Freeland", "kind": "defeat", "at": "Freeland Downtown", "foes": ["thug", "thug", "thug", "painkiller"],
			"brief": "Painkiller is working for the ASA now. Stop him."},
		{"title": "Tobias Whale", "kind": "defeat", "at": "Freeland Clinic", "foes": ["tobias_whale"], "boss": true,
			"brief": "Tobias Whale is at the clinic. It ends tonight."}],
	"martian_manhunter": [
		{"title": "The Director's Orders", "kind": "interior", "target": "deo", "brief": "Report to the D.E.O."},
		{"title": "Cadmus", "kind": "defeat", "at": "L-Corp", "foes": ["cyborg_superman"], "boss": true,
			"brief": "Cyborg Superman is hunting aliens around L-Corp. Protect them."},
		{"title": "National City Beach", "kind": "rescue", "at": "National City Beach", "count": 3, "brief": "Swimmers are caught in a rip current. Get them out."}],
	"vibe": [
		{"title": "Breach Hunting", "kind": "defeat", "at": "Central City Downtown", "foes": ["thug", "thug", "mirror_master"],
			"brief": "Something came through a breach downtown. Vibe it out."},
		{"title": "Earth-2", "kind": "goto", "at": "Central City Downtown", "place": "earth2", "brief": "Open a breach to Earth-2 (Q)."},
		{"title": "The Dampener", "kind": "defeat", "at": "S.T.A.R. Labs", "foes": ["cicada"], "boss": true,
			"brief": "Cicada wants every meta's powers gone, starting with yours."}],
	"constantine": [
		{"title": "Something Wicked", "kind": "defeat", "at": "Gotham City Downtown", "foes": ["shadow_demon", "shadow_demon", "shadow_demon"],
			"brief": "Demons are crawling out of Gotham's sewers. Banish them."},
		{"title": "Astra's Deal", "kind": "goto", "at": "Arkham Asylum", "brief": "Astra Logue left a message at Arkham. Find it."},
		{"title": "Neron", "kind": "defeat", "at": "Arkham Asylum", "foes": ["neron"], "boss": true, "brief": "Neron wants your soul back. Send him to Hell."}],
	"reverse_flash": [
		{"title": "Harrison Wells", "kind": "interior", "target": "star_labs", "brief": "Your lab. Your pawn. Get to S.T.A.R. Labs."},
		{"title": "The Negative Speed Force", "kind": "goto", "at": "Speed Force Heart", "place": "speedforce",
			"brief": "Run into the Speed Force and corrupt its heart."},
		{"title": "It's Always Been Me", "kind": "defeat", "at": "Central City Downtown", "foes": ["flash"], "boss": true,
			"brief": "Barry Allen is waiting. Show him who the fastest man alive really is."}],
	"reign": [
		{"title": "The Worldkillers", "kind": "defeat", "at": "National City Downtown", "foes": ["police", "police", "police", "police"],
			"brief": "Purge the sinners of National City."},
		{"title": "Krypton's Legacy", "kind": "goto", "at": "Hall of Elders", "place": "argo", "brief": "Fly to Argo City. The Elders will kneel."},
		{"title": "Supergirl", "kind": "defeat", "at": "CatCo Worldwide", "foes": ["supergirl"], "boss": true, "brief": "Only one Kryptonian can save this world. Prove it's you."}],
	"icicle": [
		{"title": "The ISA Reunites", "kind": "goto", "at": "Smallville Water Tower", "brief": "Gather the Injustice Society at the water tower."},
		{"title": "Project New America", "kind": "defeat", "at": "Smallville Main Street", "foes": ["police", "police", "police"],
			"brief": "Clear Main Street. Nothing can stop Project New America."},
		{"title": "Stargirl", "kind": "defeat", "at": "JSA Headquarters", "foes": ["stargirl", "wildcat"], "boss": true,
			"brief": "The new JSA is hiding in their brownstone. Freeze them out."}],
}


var world
var enabled := true
var steps: Array = []
var index := 0
var char_id := ""
var foes: Array = []
var trapped: Array = []
var _spawned := false
var _marker: Node3D
var _target := Vector3.INF
var _seen_dead: Dictionary = {}
var _saved := 0


func _ready() -> void:
	if not Game.progress.has("char_missions"):
		Game.progress["char_missions"] = {}


## Builds the story for whoever is being played (called on every character change).
func set_character(def: Dictionary) -> void:
	_cleanup()
	char_id = str(def.get("id", ""))
	steps = story_for(def)
	index = int(Game.progress["char_missions"].get(char_id, 0))
	if not is_complete() and world.hud:
		var s := current()
		world.notify("PERSONAL MISSION: %s - %s" % [s["title"], s["brief"]], Color("#9fd8ff"))


static func story_for(def: Dictionary) -> Array:
	var id := str(def.get("id", ""))
	if STORIES.has(id):
		return STORIES[id]
	var home := str(def.get("home", "any"))
	var at: String = HOME_LANDMARK.get(home, "Central City Downtown")
	var city: String = CITY_NAME.get(home, "Central City")
	var hero := str(def.get("side", "hero")) == "hero"
	var out := []
	if hero:
		out.append({"title": "Protect %s" % city, "kind": "defeat", "at": at, "foes": ["thug", "thug", "thug", "thug", "thug"],
			"brief": "A gang is running wild in %s. Show them who protects this city." % city})
	else:
		out.append({"title": "Crime Spree in %s" % city, "kind": "defeat", "at": at, "foes": ["police", "police", "police", "police"],
			"brief": "The police are in your way in %s. Move them." % city})
	var team := Teams.main_team(id)
	if TEAM_HQ.has(team):
		var hq: Array = TEAM_HQ[team]
		var step := {"title": "%s Needs You" % team if hero else "Meeting of the %s" % team, "kind": hq[0], "place": hq[2],
			"brief": "%s is gathering. Get there." % team}
		if hq[0] == "interior":
			step["target"] = hq[1]
			step["brief"] = "%s is gathering at %s. Get there." % [team, Interiors.NAMES.get(hq[1], hq[1])]
		else:
			step["at"] = hq[1]
			step["brief"] = "%s is gathering at %s. Get there." % [team, hq[1]]
		out.append(step)
	else:
		out.append({"title": "People in Danger", "kind": "rescue", "at": at, "count": 3,
			"brief": "People are trapped in %s. Get to them." % city} if hero else
			{"title": "Hostages", "kind": "defeat", "at": at, "foes": ["police", "police", "police"], "brief": "Take what you came for."})
	var nem := Teams.nemesis(id)
	if nem == "" or not Game.by_id.has(nem):
		var pool := Game.villains() if hero else Game.heroes()
		nem = str(pool[hash(id) % pool.size()]["id"])
	var nd: Dictionary = Game.get_character(nem)
	out.append({"title": "Nemesis: %s" % nd.get("alias", nem), "kind": "defeat", "at": at, "foes": [nem], "boss": true,
		"brief": "%s has come for you in %s. Only one of you walks away." % [nd.get("alias", nem), city]})
	return out


func is_complete() -> bool:
	return index >= steps.size()


func current() -> Dictionary:
	return steps[index] if index < steps.size() else {}


func _place(s: Dictionary) -> String:
	return str(s.get("place", "earth1"))


func tracker() -> String:
	if is_complete() or char_id == "":
		return ""
	var s := current()
	var text := "PERSONAL %d/%d: %s\n" % [index + 1, steps.size(), s["title"]]
	if world.place_id != _place(s):
		return text + "Travel to " + Multiverse.dest(_place(s))["name"]
	match str(s["kind"]):
		"defeat":
			if not _spawned:
				return text + "Go to " + str(s["at"])
			var left := foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
			return text + "Defeat them: %d left" % left
		"rescue":
			if not _spawned:
				return text + "Go to " + str(s["at"])
			return text + "Reach the people in danger: %d left" % trapped.filter(func(a) -> bool: return is_instance_valid(a)).size()
		"interior":
			return text + "Go inside " + str(Interiors.NAMES.get(s["target"], s["target"]))
		"goto":
			return text + "Get to " + str(s["at"])
		"travel":
			return text + "Travel there"
	return text


func _landmark_pos(name: String) -> Vector3:
	var l: Dictionary = world.city.landmark(name)
	return l["pos"] if not l.is_empty() else Vector3.INF


func target_pos() -> Vector3:
	if is_complete() or char_id == "":
		return Vector3.INF
	var s := current()
	if world.place_id != _place(s):
		return Vector3.INF
	if str(s["kind"]) == "interior":
		if world.inside != "":
			return Vector3.INF
		if not Interiors.is_remote(str(s["target"])):
			return Interiors.outside_point(str(s["target"]))
		for d in world.city.doors:
			if d["interior"] == s["target"]:
				return d["pos"]
		return Vector3.INF
	return _target


func _process(_delta: float) -> void:
	if not enabled or world == null or world.player == null or not is_instance_valid(world.player) or is_complete() or char_id == "":
		return
	if str(world.player.def.get("id", "")) != char_id:
		return
	var s := current()
	if world.place_id != _place(s):
		return
	var kind := str(s["kind"])
	if kind == "interior":
		if world.inside == str(s["target"]):
			_advance()
		return
	if kind == "travel":
		_advance()
		return
	if world.inside != "":
		return
	if _target == Vector3.INF:
		_target = _landmark_pos(str(s.get("at", "")))
		if _target == Vector3.INF:
			_target = world.player.global_position + Vector3(0, 0, -30)
		_spawn_marker(_target)
	var p: Vector3 = world.player.global_position
	var d := Vector2(p.x - _target.x, p.z - _target.z).length()
	match kind:
		"goto":
			if d < 25.0:
				_advance()
		"defeat":
			if not _spawned and d < 90.0:
				_spawn_foes(s)
			elif _spawned:
				var alive := 0
				for a in foes:
					if is_instance_valid(a):
						if a.dead:
							_seen_dead[a.get_instance_id()] = true
						else:
							alive += 1
				if alive == 0:
					if not _seen_dead.is_empty():
						_advance()
					else:
						_spawned = false   # cleared away by something else: set them up again
		"rescue":
			if not _spawned and d < 90.0:
				_spawn_trapped(int(s.get("count", 3)))
			elif _spawned:
				for c in trapped.duplicate():
					if not is_instance_valid(c):
						trapped.erase(c)
					elif c.global_position.distance_to(p) < 3.5:
						FX.flash(world, c.chest(), Color("#60ff90"), 1.0, 0.3)
						world.notify("Saved! %d to go." % (trapped.size() - 1), Color("#60ff90"))
						Game.record("rescues")
						trapped.erase(c)
						c.queue_free()
						_saved += 1
				if trapped.is_empty():
					if _saved > 0:
						_advance()
					else:
						_spawned = false


func _spawn_foes(s: Dictionary) -> void:
	_spawned = true
	foes.clear()
	var pop: Population = world.population
	var enemy_team := "villain" if Game.player_side() == 1 else "hero"
	for id in s["foes"]:
		var pos: Vector3 = _target + Vector3(randf_range(-8, 8), 0.5, randf_range(-8, 8))
		var a: Actor
		match str(id):
			"thug":
				a = pop.spawn_thug(pos)
			"police":
				a = pop.spawn_police(pos)
			_:
				a = world.missions._spawn(str(id), pos)
				if s.get("boss", false):
					a.make_boss(2.5)
					a.display_name = str(a.display_name) + " (BOSS)"
		a.set_meta("pinned", true)
		a.grudges[world.player.get_instance_id()] = 9999.0
		a.brain.leash = 0.0
		a.brain.detect = 90.0
		foes.append(a)
	world.notify("%s: they're here!" % current()["title"], Color("#9fd8ff"))


func _spawn_trapped(n: int) -> void:
	_spawned = true
	trapped.clear()
	for k in n:
		var ang := k * TAU / n
		var pos := _target + Vector3(cos(ang) * 10.0, 0.5, sin(ang) * 10.0)
		var c: Actor = world.population.spawn_civilian(pos)
		c.brain = null
		c.set_meta("pinned", true)
		c.set_meta("trapped", true)
		trapped.append(c)
	world.notify("Reach them before it's too late!", Color("#60ff90"))


func _advance() -> void:
	var s := current()
	var reward := 200 + index * 150
	Game.add_score(reward)
	Game.record("personal_missions")
	var lvl := Game.add_mastery(char_id, 120.0)
	world.notify("MISSION COMPLETE: %s  +%d" % [s["title"], reward], Color("#60ff90"))
	if lvl > 0:
		world.notify("Mastery level %d!" % lvl, Color("#ffd23a"))
	Sfx.play("event", null, 2.0)
	world.player.heal(world.player.max_hp)
	_cleanup()
	index += 1
	Game.progress["char_missions"][char_id] = index
	Game.save_settings()
	if is_complete():
		world.hud.show_banner("%s: STORY COMPLETE" % str(world.player.def["alias"]).to_upper(), Color("#9fd8ff"))
		Game.record("stories")
	else:
		var n := current()
		world.hud.show_banner(str(n["title"]).to_upper(), Color("#9fd8ff"))
		world.notify(str(n["brief"]), Color("#c8e8ff"))


## Called when travelling or switching characters: the old setup goes away.
func _cleanup() -> void:
	for a in foes + trapped:
		if is_instance_valid(a) and not a.is_player:
			a.queue_free()
	foes.clear()
	trapped.clear()
	_spawned = false
	_seen_dead.clear()
	_saved = 0
	_target = Vector3.INF
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func reset_progress() -> void:
	Game.progress["char_missions"].erase(char_id)
	index = 0
	_cleanup()


func _spawn_marker(pos: Vector3) -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = Node3D.new()
	world.fx_root.add_child(_marker)
	_marker.global_position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.6
	cyl.height = 300.0
	beam.mesh = cyl
	beam.material_override = FX.glow_mat(Color("#3ab8ff"), 0.25)
	beam.position = Vector3(0, 150.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam)
