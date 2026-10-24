class_name Missions
extends Node
## Story Mode: CRISIS CITY. Every Earth. Every legend. Every enemy. One final
## crisis.
##
## A five-act campaign. Each mission is a list of steps run in order:
##   scene     - a cutscene: [camera, speaker, line] shots (see _shot)
##   radio     - lines over comms while you play
##   rooftop   - start up on a roof near a landmark
##   goto      - reach a landmark
##   interior  - walk into a room
##   travel    - get to another Earth / era / realm
##   switch    - the story hands you another hero
##   rescue    - free civilians pinned under debris
##   defeat    - beat the foes waiting at a landmark (bosses get the full
##               boss fight: intro, clash, counter, finisher)
##   occupy    - the Architect's villains take over districts
##   liberate  - win back occupied districts
##   unlock_beaten - villains you beat join the resistance as playable
##   choose    - pick who delivers the final strike (decides the ending)
## Finishing a mission unlocks its characters. Progress is saved. In Sandbox
## mode the story is off and everyone is unlocked.

const ACTS := {
	0: ["PROLOGUE", "THE END OF EVERYTHING"],
	1: ["ACT I", "THE CITIES FALL"],
	2: ["ACT II", "THE BROKEN TIMELINE"],
	3: ["ACT III", "WAR OF THE EARTHS"],
	4: ["ACT IV", "THE VILLAINS' VICTORY"],
	5: ["ACT V", "ONE LAST TOMORROW"],
}

## Speaker name colours in cutscenes and on the radio.
const VOICES := {
	"Oliver Queen": "#5aff6a", "Felicity Smoak": "#ffd27a", "The Monitor": "#9fe0ff", "John Diggle": "#ffb070",
	"Malcolm Merlyn": "#ff6a5a", "Cisco Ramon": "#ffb070", "Barry Allen": "#ff5a4a", "Caitlin Snow": "#a8e8ff",
	"Iris West-Allen": "#ffc0d0", "Reverse-Flash": "#ffd23a", "Kara Danvers": "#6a9aff", "Alex Danvers": "#9ab0ff",
	"J'onn J'onzz": "#6aff9a", "Reign": "#ff5a5a", "Lex Luthor": "#6bff6b", "Sara Lance": "#f0f0f0", "Gideon": "#ffcf6a",
	"Ray Palmer": "#6ac8ff", "Mick Rory": "#ff8a3a", "Vandal Savage": "#c8a060", "Savitar": "#9fd8ff", "Jay Garrick": "#ffd23a",
	"Damien Darhk": "#c080ff", "Zoom": "#4a6aff", "Overgirl": "#ff4a4a", "Clark Kent": "#4a7aff", "Lois Lane": "#ffd0a0",
	"Kate Kane": "#ff4a4a", "Alice": "#ffd0e0", "Jefferson Pierce": "#8fd0ff", "Tobias Whale": "#e8e8e8",
	"The Architect": "#ffe6a0", "John Constantine": "#ffcf6a", "Courtney Whitmore": "#ffd23a", "Harbinger": "#9fe0ff",
	"Narrator": "#ffffff",
}

const MISSIONS := [
	# ---------------------------------------------------------------- PROLOGUE
	{"id": "prologue", "act": 0, "title": "The End of Everything", "hero": "green_arrow", "steps": [
		{"do": "scene", "shots": [
			["black", "Oliver Queen", "For years, I believed my mission was simple. Protect my city. Save the innocent. Stop the monsters hiding behind money, power, and corruption."],
			["black", "Oliver Queen", "Then I learned the truth. My city was only one piece of something much bigger."],
			["black", "Oliver Queen", "Worlds beyond our own. Timelines that should never have existed. People who were supposed to die... and people who should never have been born."],
			["black", "Oliver Queen", "Every time we saved the world, we thought we had won."],
			["aerial", "", ""],
			["player", "Oliver Queen", "Felicity, tell me you're seeing this."],
			["aerial", "Felicity Smoak", "I'm seeing about seventeen different versions of this, and somehow every single one is getting worse."],
			["player", "Oliver Queen", "Define worse."],
			["aerial", "Felicity Smoak", "The moon just disappeared from three parallel universes. And Oliver? Something is deleting entire timelines."],
			["sky", "", ""],
			["player", "Oliver Queen", "Get everyone underground. Now."],
			["sky", "The Monitor", "Oliver Queen. Your sacrifice was not the end."],
			["sky", "The Monitor", "It was the beginning."],
			["title", "CRISIS CITY", "THE MULTIVERSE IS UNDER ATTACK.\nYOUR LEGACY WILL DETERMINE WHAT SURVIVES."],
		]},
	]},
	# ------------------------------------------------------------------- ACT I
	{"id": "m01", "act": 1, "title": "A City Without Tomorrow", "hero": "green_arrow",
		"unlock": ["spartan", "overwatch", "black_canary", "speedy", "arsenal"],
		"unlock_note": "UNLOCKED: Star City open world", "next": "NEW OBJECTIVE: Reach S.T.A.R. Labs.", "steps": [
		{"do": "rooftop", "at": "Star City Downtown"},
		{"do": "goto", "at": "SCPD", "label": "Reach the evacuation zone"},
		{"do": "rescue", "at": "SCPD", "count": 3, "label": "Rescue civilians from the collapsing buildings"},
		{"do": "radio", "lines": [
			["John Diggle", "Oliver, I've got armed hostiles moving through the evacuation zone. They aren't ordinary soldiers."],
			["Oliver Queen", "Then what are they?"],
			["John Diggle", "They're wearing the faces of people we've already buried."]]},
		{"do": "defeat", "at": "Star City Downtown", "foes": ["shadow_demon", "shadow_demon", "shadow_demon", "shadow_demon"],
			"label": "Fight the shadow creatures"},
		{"do": "goto", "at": "Queen Consolidated", "label": "Locate the source of the temporal disturbance"},
		{"do": "defeat", "at": "Queen Consolidated", "foes": ["malcolm_merlyn"], "boss": true, "escape": true,
			"label": "Survive the arrival of an unexpected enemy",
			"intro": [["player", "No. You're dead."],
				["boss", "You really should stop saying that, Oliver. It keeps becoming embarrassing."],
				["player", "Malcolm."],
				["boss", "I assure you, this reunion is just as unpleasant for me."]],
			"outro": [["player", "Who brought you back?"],
				["boss", "You still think this is about bringing people back?"],
				["boss", "The world is being rewritten. And for once, Oliver, you aren't the man holding the pen."]]},
	]},
	{"id": "m02", "act": 1, "title": "The Fastest Man Alive", "hero": "",
		"unlock": ["flash", "vibe", "killer_frost", "iris_west", "joe_west", "kid_flash", "elongated_man", "chester_runk", "allegra"],
		"steps": [
		{"do": "interior", "target": "star_labs", "label": "Reach S.T.A.R. Labs"},
		{"do": "scene", "shots": [
			["player", "Cisco Ramon", "Okay, the good news: we know who's rewriting history. The bad news: we don't know who that is."],
			["player", "Barry Allen", "Every timeline I've ever changed is unravelling at once. Someone is pulling the threads."],
			["player", "Caitlin Snow", "Barry, there's a speed signature downtown. Yellow lightning."],
			["player", "Barry Allen", "Thawne."]]},
		{"do": "switch", "hero": "flash", "line": "Barry Allen suits up."},
		{"do": "defeat", "at": "Central City Downtown", "foes": ["reverse_flash"], "boss": true, "label": "Stop the Reverse-Flash",
			"intro": [["boss", "Hello, Barry. Someone finally offered me a world where you never existed."],
				["player", "Whoever's using you, Eobard, they'll throw you away."],
				["boss", "Maybe. But I get to erase you first."]],
			"outro": [["boss", "You don't understand... he's offering every one of us what we want most."],
				["player", "Who is?"], ["boss", "The Architect."]]},
	]},
	{"id": "m03", "act": 1, "title": "Girl of Steel", "hero": "supergirl",
		"unlock": ["martian_manhunter", "sentinel", "dreamer", "brainiac_5", "lena_luthor", "guardian", "mon_el"],
		"steps": [
		{"do": "radio", "lines": [["Alex Danvers", "Kara, CatCo is coming apart. People are trapped on every floor."],
			["Kara Danvers", "On my way."]]},
		{"do": "rescue", "at": "CatCo Worldwide", "count": 3, "label": "Save the people trapped at CatCo"},
		{"do": "defeat", "at": "The D.E.O.", "foes": ["reign"], "boss": true, "label": "Stop Reign at the D.E.O.",
			"intro": [["boss", "Humanity has finally asked to be judged. The Architect has given them to me."],
				["player", "Nobody asked for this, Reign."], ["boss", "Then I will judge you first."]]},
	]},
	# ------------------------------------------------------------------ ACT II
	{"id": "m04", "act": 2, "title": "The Broken Timeline", "hero": "white_canary",
		"unlock": ["atom", "heat_wave_hero", "zari", "gideon", "constantine", "citizen_steel", "behrad", "ava_sharpe", "rip_hunter", "amaya", "mona_wu"],
		"steps": [
		{"do": "goto", "at": "The Waverider", "label": "Get to the Waverider"},
		{"do": "scene", "shots": [
			["player", "Gideon", "Captain, history has been rewritten in four hundred places at once. The worst is 1942."],
			["player", "Sara Lance", "Let me guess. Vandal Savage."],
			["player", "Gideon", "He has been told he will rule the world. Someone is keeping their promises."]]},
		{"do": "travel", "place": "1942", "label": "Jump to 1942 (the Waverider's time console, or the Tab menu)"},
		{"do": "defeat", "at": "Central City Downtown", "foes": ["vandal_savage", "thug", "thug"], "boss": true, "label": "Stop Vandal Savage in 1942"},
	]},
	{"id": "m05", "act": 2, "title": "Speed Force Collapse", "hero": "flash",
		"unlock": ["jay_garrick", "jesse_quick", "xs", "flash_90"],
		"steps": [
		{"do": "radio", "lines": [["Jay Garrick", "Barry, the Speed Force is splitting apart. Something in there is wearing your face."]]},
		{"do": "travel", "place": "speedforce", "label": "Run into the Speed Force"},
		{"do": "defeat", "at": "Speed Force Heart", "foes": ["time_wraith", "time_wraith", "time_wraith"], "label": "Drive off the Time Wraiths"},
		{"do": "defeat", "at": "Speed Force Heart", "foes": ["savitar"], "boss": true, "label": "Face Savitar",
			"intro": [["boss", "In this timeline there is only one Flash. Me."],
				["player", "You're a time remnant, Savitar. You're what I could have become."],
				["boss", "I am what you will become."]]},
	]},
	{"id": "m06", "act": 2, "title": "The Temporal Zone", "hero": "white_canary",
		"unlock": ["nora_darhk", "charlie", "astra_logue", "spooner", "hawkgirl", "hawkman", "vixen"],
		"steps": [
		{"do": "travel", "place": "vanishing_point", "label": "Get to the Vanishing Point"},
		{"do": "defeat", "at": "Time Bureau HQ", "foes": ["damien_darhk"], "boss": true, "label": "Stop Damien Darhk",
			"intro": [["boss", "He gave me a world where my wife and daughter never died. You'd take that from me?"],
				["player", "He's lying to you, Damien. He's lying to all of you."],
				["boss", "Then I'll take my chances."]]},
	]},
	# ----------------------------------------------------------------- ACT III
	{"id": "m07", "act": 3, "title": "Earth-2 Is Burning", "hero": "flash", "unlock": ["pariah"], "steps": [
		{"do": "travel", "place": "earth2", "label": "Breach to Earth-2"},
		{"do": "defeat", "at": "Central City Downtown", "foes": ["zoom"], "boss": true, "label": "Stop Zoom"},
	]},
	{"id": "m08", "act": 3, "title": "The Reich of Earth-X", "hero": "supergirl", "unlock": ["the_ray", "superman"], "steps": [
		{"do": "travel", "place": "earthx", "label": "Breach to Earth-X"},
		{"do": "defeat", "at": "Central City Downtown", "foes": ["overgirl", "dark_arrow"], "boss": true, "label": "Shut down Overgirl and Dark Arrow"},
	]},
	{"id": "m09", "act": 3, "title": "Smallville Falls", "hero": "superman", "unlock": ["jordan_kent", "steel", "lois_lane", "natalie_irons"], "steps": [
		{"do": "radio", "lines": [["Lois Lane", "Clark, something just landed at the farm. The ground is cracking for miles."],
			["Clark Kent", "Get the boys out, Lois. Now."]]},
		{"do": "defeat", "at": "Kent Farm", "foes": ["doomsday"], "boss": true, "label": "Stop Doomsday at the Kent Farm"},
	]},
	{"id": "m10", "act": 3, "title": "Gotham's Darkest Night", "hero": "batwoman", "unlock": ["ryan_wilder", "batwing"], "steps": [
		{"do": "defeat", "at": "Arkham Asylum", "foes": ["alice", "thug", "thug"], "boss": true, "label": "Stop Alice at Arkham Asylum",
			"intro": [["boss", "Kate! He promised me a Wonderland where you never left me."],
				["player", "Beth, whoever he is, he doesn't keep promises."], ["boss", "Neither did you."]]},
	]},
	{"id": "m11", "act": 3, "title": "Lightning in Freeland", "hero": "black_lightning", "unlock": ["thunder", "lightning", "grace_choi"], "steps": [
		{"do": "defeat", "at": "Freeland Clinic", "foes": ["tobias_whale", "thug", "thug", "thug"], "boss": true, "label": "Take down Tobias Whale"},
		{"do": "scene", "shots": [
			["sky", "The Architect", "You have all fought so bravely. It changes nothing."],
			["sky", "The Architect", "The worlds are mine to merge. Welcome to Crisis City."],
			["title", "THE ARCHITECT", "HAS MERGED THE WORLDS"]]},
	]},
	# ------------------------------------------------------------------ ACT IV
	{"id": "m12", "act": 4, "title": "The Villains' Victory", "hero": "", "steps": [
		{"do": "scene", "shots": [
			["aerial", "Narrator", "The heroes lost. Every Earth is now one city, and the villains rule its districts."],
			["player", "Felicity Smoak", "Whoever's still out there: we're rebuilding. One district at a time."]]},
		{"do": "occupy", "districts": [0, 1, 2, 4]},
		{"do": "liberate", "count": 3, "label": "Liberate occupied districts"},
		{"do": "unlock_beaten"},
	]},
	{"id": "m13", "act": 4, "title": "Rebuild the Resistance", "hero": "",
		"unlock": ["stargirl", "wildcat", "hourman", "dr_midnite", "starman", "dr_fate", "green_lantern", "jade", "obsidian", "stripe", "johnny_thunder"],
		"steps": [
		{"do": "radio", "lines": [["Courtney Whitmore", "Hello? Is anyone still out there? The Injustice Society has us pinned down at the JSA!"]]},
		{"do": "defeat", "at": "JSA Headquarters", "foes": ["icicle", "brainwave", "thug", "thug"], "boss": true, "label": "Free the JSA"},
	]},
	# ------------------------------------------------------------------- ACT V
	{"id": "m14", "act": 5, "title": "One Last Tomorrow", "hero": "green_arrow", "steps": [
		{"do": "scene", "shots": [
			["aerial", "Oliver Queen", "Every hero. Every world. This is where we take it back."]]},
		{"do": "switch", "hero": "green_arrow", "line": "Green Arrow leads the ground assault."},
		{"do": "defeat", "at": "Star City Downtown", "foes": ["prometheus", "deathstroke", "thug", "thug"], "label": "Lead the ground assault"},
		{"do": "switch", "hero": "flash", "line": "The Flash races to stop the temporal engine."},
		{"do": "defeat", "at": "Central City Downtown", "foes": ["godspeed", "red_death"], "label": "Stop the temporal engine"},
		{"do": "switch", "hero": "supergirl", "line": "Supergirl takes on the cosmic defenses."},
		{"do": "defeat", "at": "National City Downtown", "foes": ["cyborg_superman", "metallo"], "label": "Break the cosmic defenses"},
		{"do": "switch", "hero": "batwoman", "line": "Batwoman leads the resistance in Gotham."},
		{"do": "defeat", "at": "Gotham City Downtown", "foes": ["black_mask", "hush", "thug", "thug"], "label": "Hold Gotham"},
		{"do": "switch", "hero": "constantine", "line": "Constantine goes after the magic keeping the Architect alive."},
		{"do": "travel", "place": "vanishing_point", "label": "Infiltrate the Citadel Beyond Time"},
		{"do": "defeat", "at": "Time Bureau HQ", "foes": ["neron"], "label": "Break the spell on the Citadel"},
		{"do": "switch", "hero": "green_arrow", "line": "Oliver reaches the Architect."},
		{"do": "defeat", "at": "Time Bureau HQ", "foes": ["the_architect"], "boss": true, "mult": 5.0, "label": "Defeat the Architect",
			"intro": [["boss", "Look at them. Every hero. Every villain. Every world you've ever failed to save. All gathered in one place."],
				["player", "You think bringing everyone together makes you stronger?"],
				["boss", "I think it makes you predictable."],
				["player", "Then you haven't been paying attention."],
				["boss", "You cannot save everyone."],
				["player", "Maybe not. But they don't have to face this alone."]]},
		{"do": "choose", "label": "Choose who delivers the final strike"},
	]},
]

## How the story ends, by who lands the final strike.
const ENDINGS := {
	"green_arrow": "Oliver lowers his bow. For once, the city he saved is every city. He finally rests.",
	"flash": "Barry outruns the collapse and stitches the timelines back together. Central City wakes to a sunrise it almost lost.",
	"supergirl": "Kara holds the merged worlds together long enough for each Earth to find its way home. Hope wins.",
	"superman": "Clark carries the Architect into the sun. On a farm in Smallville, two boys watch the sky and wait for their dad.",
	"white_canary": "Sara takes the Waverider on one last jump and seals the Architect outside time. The Legends throw a party.",
	"batwoman": "Gotham's lights come back on one block at a time, and the Bat-Signal shines over a city that remembers.",
	"black_lightning": "Jefferson walks the streets of Freeland at dawn. The kids are back in school. That's the victory.",
	"constantine": "John lights a cigarette in the ruins of the Citadel. 'Bloody heroes,' he mutters, and smiles.",
	"stargirl": "Courtney plants the Cosmic Staff in the ground of Blue Valley. A new Justice Society is born.",
}
const DEFAULT_ENDING := "%s strikes the final blow. Crisis City splits back into its many Earths, every one of them free."

var world
var chapter := 0        # mission index (the name the rest of the game uses)
var step := 0
var foes: Array = []
var trapped: Array = []
var _spawned_for := -1  # the step whose foes/civilians are out (-1: none)
var _seen_dead: Dictionary = {}
var _boss_gone := false
var _saved := 0
var _target := Vector3.INF
var _marker: Node3D
var _scene_running := false
var _chooser: CanvasLayer
var _liberated_at_start := 0


func _ready() -> void:
	var s := _state()
	chapter = int(s.get("mission", 0))
	step = int(s.get("step", 0))


func _state() -> Dictionary:
	if typeof(Game.progress.get("story")) != TYPE_DICTIONARY:
		Game.progress["story"] = {}
	return Game.progress["story"]


func story_on() -> bool:
	return Game.mode == "story"


func current() -> Dictionary:
	return MISSIONS[chapter] if chapter < MISSIONS.size() else {}


func current_step() -> Dictionary:
	var m := current()
	if m.is_empty():
		return {}
	var steps: Array = m["steps"]
	return steps[step] if step < steps.size() else {}


func is_complete() -> bool:
	return chapter >= MISSIONS.size()


func _save() -> void:
	var s := _state()
	s["mission"] = chapter
	s["step"] = step
	Game.save_settings()


## Start over from the prologue (unlocks are kept).
func restart() -> void:
	_cleanup()
	var s := _state()
	s["occupied"] = []
	s["beaten"] = []
	s["liberated"] = 0
	s.erase("ending")
	_set_chapter(0)


## Starts mission `n` from its first step.
func _set_chapter(n: int) -> void:
	_cleanup()
	chapter = n
	step = 0
	_save()
	if not story_on() or is_complete():
		return
	_begin_mission()


## Called when you first take control: pick the story up where you left it.
func begin_session() -> void:
	if not story_on() or is_complete():
		return
	_begin_mission()


func _begin_mission() -> void:
	var m := current()
	var act: Array = ACTS.get(int(m["act"]), ["", ""])
	if step == 0:
		world.hud.show_banner("%s: %s" % [act[0], str(m["title"]).to_upper()], Color("#ff9a6a"))
	var hero := str(m.get("hero", ""))
	if hero != "" and world.player and is_instance_valid(world.player) and str(world.player.def.get("id", "")) != hero:
		Game.unlock(hero)
		world.spawn_player(hero)
		world.notify("This mission: %s." % str(Game.get_character(hero).get("alias", hero)), Color("#ffd27a"))
	elif hero != "":
		Game.unlock(hero)
	_spawned_for = -1
	_scene_running = false


## The HUD's tracker text.
func tracker() -> String:
	if not story_on():
		return ""
	if is_complete():
		return "CRISIS CITY: complete.  Every hero and villain is unlocked."
	var m := current()
	var act: Array = ACTS.get(int(m["act"]), ["", ""])
	var text := "%s · %s\n" % [act[0], str(m["title"]).to_upper()]
	var s := current_step()
	match str(s.get("do", "")):
		"defeat":
			var left := foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
			text += str(s.get("label", "Defeat them"))
			if _spawned_for == step:
				text += " (%d left)" % left
		"rescue":
			text += str(s.get("label", "Rescue them"))
			if _spawned_for == step:
				text += " (%d left)" % trapped.size()
		"liberate":
			text += "%s: %d / %d" % [str(s.get("label", "Liberate districts")), int(_state().get("liberated", 0)) - _liberated_at_start,
				int(s.get("count", 1))]
		_:
			text += str(s.get("label", ""))
	return text


func _process(_delta: float) -> void:
	if not story_on() or world == null or world.player == null or not is_instance_valid(world.player) or is_complete():
		return
	if world.cinematic or _chooser != null:
		return
	var s := current_step()
	if s.is_empty():
		_complete_mission()
		return
	var p: Vector3 = world.player.global_position
	match str(s["do"]):
		"scene":
			if not _scene_running:
				_scene_running = true
				world.cutscene.play(_shots(s["shots"]), func(_skipped: bool) -> void:
					_scene_running = false
					_next_step())
		"radio":
			for l in s["lines"]:
				world.notify("%s: \"%s\"" % [l[0], l[1]], Color(str(VOICES.get(str(l[0]), "#ffffff"))))
			_next_step()
		"rooftop":
			var roof := _rooftop_near(_where(str(s["at"])))
			if roof != Vector3.INF:
				world.teleport_player(roof)
			_next_step()
		"goto":
			_ensure_marker(_where(str(s["at"])))
			if Vector2(p.x - _target.x, p.z - _target.z).length() < float(s.get("radius", 30.0)) and world.inside == "":
				_next_step()
		"interior":
			if world.inside == str(s["target"]):
				_next_step()
		"travel":
			if world.place_id == str(s["place"]):
				_next_step()
		"switch":
			var hero := str(s["hero"])
			Game.unlock(hero)
			if str(world.player.def.get("id", "")) != hero:
				world.spawn_player(hero, world.player.global_position)
			world.notify(str(s.get("line", "")), Color("#ffd27a"))
			_next_step()
		"rescue":
			_tick_rescue(s, p)
		"defeat":
			_tick_defeat(s, p)
		"occupy":
			for d in s["districts"]:
				world.crisis.occupy(int(d))
			_liberated_at_start = int(_state().get("liberated", 0))
			_state()["liberate_base"] = _liberated_at_start
			_next_step()
		"liberate":
			_liberated_at_start = int(_state().get("liberate_base", _liberated_at_start))
			if int(_state().get("liberated", 0)) - _liberated_at_start >= int(s.get("count", 1)) or world.crisis.occupied().is_empty():
				_next_step()
			else:
				var next: int = world.crisis.nearest_occupied(p)
				if next >= 0:
					_ensure_marker(world.city.district_center(next))
		"unlock_beaten":
			var names := []
			for id in _state().get("beaten", []):
				if Game.unlock(str(id)):
					names.append(str(Game.get_character(str(id)).get("alias", id)))
			if not names.is_empty():
				world.notify("Villains who refuse the Architect's control join the resistance: %s. They're playable now." % ", ".join(names), Color("#ff9a6a"))
				world.hud.show_banner("VILLAINS UNLOCKED", Color("#ff6a5a"))
			_next_step()
		"choose":
			_open_chooser()


func _next_step() -> void:
	_clear_marker()
	_spawned_for = -1
	step += 1
	_save()
	if current_step().is_empty():
		_complete_mission()


func _complete_mission() -> void:
	var m := current()
	_cleanup()
	var reward := 300 + chapter * 120
	Game.add_score(reward)
	Game.record("chapters")
	var names := []
	for id in m.get("unlock", []):
		if Game.unlock(str(id)):
			names.append(str(Game.get_character(str(id)).get("alias", id)))
	if int(m["act"]) > 0:
		world.hud.show_banner("MISSION COMPLETE: %s" % str(m["title"]).to_upper(), Color("#60ff90"))
		world.notify("MISSION COMPLETE: %s  +%d" % [m["title"], reward], Color("#60ff90"))
	if m.has("unlock_note"):
		world.notify(str(m["unlock_note"]), Color("#ffd23a"))
	if not names.is_empty():
		world.notify("UNLOCKED: " + ", ".join(names), Color("#ffd23a"))
	if m.has("next"):
		world.notify(str(m["next"]), Color("#ffc8a0"))
	Sfx.play("event", null, 2.0)
	if world.player and is_instance_valid(world.player):
		world.player.heal(world.player.max_hp)
		world.player.ult = 100.0
	var next_act := int(MISSIONS[chapter + 1]["act"]) if chapter + 1 < MISSIONS.size() else -1
	if next_act != int(m["act"]) and next_act > 0:
		var act: Array = ACTS[next_act]
		world.cutscene.play([{"black": true, "title": str(act[0]), "sub": str(act[1]), "dur": 3.0}])
	chapter += 1
	step = 0
	_save()
	if is_complete():
		_finish_story()
	else:
		_begin_mission()


func _finish_story() -> void:
	for c in Game.roster:
		Game.unlock(str(c["id"]))
	Game.save_settings()
	Game.record("story_complete")
	world.hud.show_banner("CRISIS CITY: THE END", Color("#ffd23a"))
	world.notify("Every hero and villain is unlocked. Crisis City is yours to explore.", Color("#ffd23a"))


# --- Cutscene shots -------------------------------------------------------------

## [camera, speaker, line] -> a Cutscene shot. Cameras: black, title, aerial,
## sky (looking up from the street), player (close-up), boss (close-up).
func _shot(spec: Array) -> Dictionary:
	var cam := str(spec[0])
	var speaker := str(spec[1])
	var line := str(spec[2]) if spec.size() > 2 else ""
	var color := Color(str(VOICES.get(speaker, "#ffd27a")))
	var dur := clampf(1.8 + line.length() * 0.045, 2.4, 7.0)
	var p: Actor = world.player
	match cam:
		"black":
			return {"black": true, "speaker": speaker, "line": line, "color": color, "dur": dur}
		"title":
			return {"black": true, "title": speaker, "sub": line, "dur": 4.5}
		"player":
			var s := Cutscene.close_up(p, dur, line, color)
			s["speaker"] = speaker
			return s
		"boss":
			var b: Actor = foes[0] if not foes.is_empty() and is_instance_valid(foes[0]) else p
			var s2 := Cutscene.close_up(b, dur, line, color)
			s2["speaker"] = speaker
			return s2
		"sky":
			var eye := p.global_position + Vector3(0, 2.0, 0) - p.forward() * 4.0
			return {"from": eye, "to": eye + Vector3.UP * 1.5, "look": p.global_position + Vector3(0, 120, 0) + p.forward() * 160.0,
				"dur": dur, "speaker": speaker, "line": line, "color": color}
		_:
			return Cutscene.aerial(p.global_position, maxf(dur, 3.0), speaker, line, color)


func _shots(specs: Array) -> Array:
	var out: Array = []
	for spec in specs:
		out.append(_shot(spec))
	return out


# --- Places ----------------------------------------------------------------------

## A landmark's position here (or something sensible if it doesn't exist).
func _where(at: String) -> Vector3:
	var lm: Dictionary = world.city.landmark(at)
	if not lm.is_empty():
		return lm["pos"]
	var fwd: Vector3 = world.player.forward()
	return world.player.global_position + fwd * 30.0


## The top of a building close to `pos`, for starting on the rooftops.
func _rooftop_near(pos: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := 400.0
	for b in world.city.buildings:
		var h: float = b["h"]
		if h < 14.0 or h > 70.0:
			continue
		var c: Vector2 = (b["rect"] as Rect2).get_center()
		var d := c.distance_to(Vector2(pos.x, pos.z))
		if d < best_d:
			best_d = d
			best = Vector3(c.x, h + 1.0, c.y)
	return best


func _ensure_marker(pos: Vector3) -> void:
	if _target.distance_to(pos) > 1.0 or _marker == null or not is_instance_valid(_marker):
		_target = pos
		_spawn_marker(pos)


# --- Rescue and defeat steps -------------------------------------------------------

func _tick_rescue(s: Dictionary, p: Vector3) -> void:
	var at := _where(str(s["at"]))
	_ensure_marker(at)
	if _spawned_for != step:
		if Vector2(p.x - at.x, p.z - at.z).length() < 90.0:
			_spawn_trapped(at, int(s.get("count", 3)))
		return
	for c in trapped.duplicate():
		if not is_instance_valid(c):
			trapped.erase(c)
		elif c.global_position.distance_to(p) < 3.5 and not world.qte.active and Time.get_ticks_msec() > int(c.get_meta("retry_at", 0)):
			if world.boss_fight.qte_enabled():
				var who: Actor = c
				world.qte.start("mash", {"action": "interact", "presses": 8, "time": 3.0, "title": "LIFT THE DEBRIS!"},
					func(ok: bool) -> void:
						if ok:
							_rescue(who)
						elif is_instance_valid(who):
							who.set_meta("retry_at", Time.get_ticks_msec() + 1500))
			else:
				_rescue(c)
	if trapped.is_empty():
		if _saved > 0:
			_next_step()
		else:
			_spawned_for = -1


func _rescue(c: Actor) -> void:
	if not is_instance_valid(c) or not trapped.has(c):
		return
	FX.flash(world, c.chest(), Color("#60ff90"), 1.0, 0.3)
	trapped.erase(c)
	world.notify("Saved! %d to go." % trapped.size(), Color("#60ff90"))
	Game.record("rescues")
	c.queue_free()
	_saved += 1


func _spawn_trapped(at: Vector3, n: int) -> void:
	_spawned_for = step
	_saved = 0
	trapped.clear()
	for k in n:
		var ang := k * TAU / n
		var pos: Vector3 = world.city.snap_to_road(at + Vector3(cos(ang) * 12.0, 0, sin(ang) * 12.0)) + Vector3.UP * 0.5
		var c: Actor = world.population.spawn_civilian(pos)
		c.brain = null
		c.set_meta("pinned", true)
		c.set_meta("trapped", true)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.4, 0.5, 1.6)
		slab.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#6a6460")
		slab.material_override = m
		slab.position = Vector3(0, 0.9, 0)
		slab.rotation = Vector3(0.2, randf() * TAU, 0.15)
		c.add_child(slab)
		trapped.append(c)
	world.notify("People are trapped under the rubble. Get to them!", Color("#60ff90"))


func _tick_defeat(s: Dictionary, p: Vector3) -> void:
	if world.inside != "":
		return
	var at := _where(str(s["at"]))
	_ensure_marker(at)
	if _spawned_for != step:
		if Vector2(p.x - at.x, p.z - at.z).length() < 120.0:
			_spawn_foes(s, at)
		return
	var standing := 0
	for a in foes:
		if is_instance_valid(a) and not a.dead:
			standing += 1
		elif is_instance_valid(a) and a.dead:
			_seen_dead[a.get_instance_id()] = true
	if standing == 0 and not world.cinematic:
		if _seen_dead.is_empty() and not _boss_gone:
			_spawned_for = -1   # cleared away by something else: set them up again
		elif world.boss_fight.boss == null and not world.boss_fight._escaping:
			# Wait for the boss's outro (or getaway) to play out first.
			_next_step()


func _spawn_foes(s: Dictionary, at: Vector3) -> void:
	_spawned_for = step
	_seen_dead.clear()
	_boss_gone = false
	foes.clear()
	var center := at
	if world.city.kind == "metro":
		center = world.city.snap_to_road(center) + Vector3.UP * 0.5
	for id in s["foes"]:
		var pos := center + Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6))
		var a: Actor
		if str(id) == "thug":
			a = world.population.spawn_thug(pos)
			a.set_meta("pinned", true)
			a.grudges[world.player.get_instance_id()] = 9999.0
			a.brain.leash = 0.0
		else:
			a = _spawn(str(id), pos)
		if s.get("boss", false) and foes.filter(func(f) -> bool: return f.boss).is_empty() and str(id) != "thug":
			a.make_boss(float(s.get("mult", 3.0)))
			a.display_name = a.display_name + " (BOSS)"
		a.add_to_group("mission_foes")
		foes.append(a)
	world.notify("They're here. Take them down!", Color("#ff8060"))
	var boss: Actor = null
	for a in foes:
		if a.boss:
			boss = a
			break
	if boss:
		var bid := str(boss.def.get("id", ""))
		if not world.boss_fight.boss_done.is_connected(_on_boss_done):
			world.boss_fight.boss_done.connect(_on_boss_done)
		world.boss_fight.begin(boss, true, {"intro_lines": s.get("intro", []), "outro_lines": s.get("outro", []),
			"escape": bool(s.get("escape", false))})
		boss.set_meta("story_boss", bid)


func _on_boss_done(boss_id: String, escaped: bool) -> void:
	if escaped:
		_boss_gone = true
	var beaten: Array = _state().get("beaten", [])
	if not beaten.has(boss_id) and Game.by_id.has(boss_id):
		beaten.append(boss_id)
	_state()["beaten"] = beaten


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


# --- The final strike --------------------------------------------------------------

func _open_chooser() -> void:
	if _chooser != null:
		return
	_chooser = CanvasLayer.new()
	_chooser.layer = 22
	world.add_child(_chooser)
	world.cinematic = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.88
	_chooser.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.label("THE FINAL STRIKE", 34, UITheme.ACCENT))
	v.add_child(UITheme.label("Every hero who made it is here. Who ends this? Your choice decides how the story ends.", 17, UITheme.TEXT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id in final_choices():
		var c: Dictionary = Game.get_character(id)
		var b := UITheme.button(str(c.get("alias", id)), func() -> void: choose(id), 200)
		grid.add_child(b)


## Who can deliver the final strike: everyone you've unlocked, heroes first.
func final_choices() -> Array:
	var out: Array = []
	for c in Game.roster:
		if c["id"] != "the_architect" and (Game.progress["unlocked"] as Array).has(c["id"]):
			out.append(str(c["id"]))
	out.sort_custom(func(a, b) -> bool: return Game.get_character(a)["side"] == "hero" and Game.get_character(b)["side"] != "hero")
	return out


func choose(id: String) -> void:
	if _chooser:
		_chooser.queue_free()
		_chooser = null
	world.cinematic = false
	world.capture_mouse(true)
	var at: Vector3 = world.player.global_position
	world.spawn_player(id, at)
	_state()["ending"] = id
	var alias := str(Game.get_character(id).get("alias", id))
	var text: String = ENDINGS.get(id, DEFAULT_ENDING % alias)
	world.qte.start("press", {"action": "attack", "time": 3.0, "title": "%s: THE FINAL STRIKE" % alias.to_upper()},
		func(_ok: bool) -> void:
			FX.burst_lines(world, world.player.chest(), Color("#ffe6a0"), 6.0, 30)
			FX.shockwave(world, world.player.global_position, Color("#ffffff"), 30.0)
			world.cutscene.play([
				_shot(["aerial", "", ""]),
				{"black": true, "title": "CRISIS CITY", "sub": text, "dur": 7.0},
				{"black": true, "title": "THE END", "sub": "Thanks for playing.", "dur": 3.5}],
				func(_s: bool) -> void: _next_step()))
	if not world.boss_fight.qte_enabled():
		# No QTEs: the strike lands by itself.
		world.qte.press("attack")


# --- Markers and cleanup ---------------------------------------------------------------

func _cleanup() -> void:
	for a in foes + trapped:
		if is_instance_valid(a) and not a.is_player:
			a.queue_free()
	foes.clear()
	trapped.clear()
	_spawned_for = -1
	_seen_dead.clear()
	_boss_gone = false
	_scene_running = false
	_clear_marker()


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


## Called by the World after travelling somewhere: the locals show up
## (unless the story has its own fight waiting there).
func on_arrive(place: String) -> void:
	if not NATIVES.has(place):
		return
	if story_on() and not is_complete():
		for st in current().get("steps", []):
			if str(st.get("do", "")) in ["travel", "defeat"] and str(st.get("place", "")) == place:
				return
		if str(current().get("id", "")) in ["m04", "m05", "m06", "m07", "m08", "m14"]:
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
	_target = pos
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
	_target = Vector3.INF


## Where the minimap should point.
func target_pos() -> Vector3:
	if not story_on() or is_complete():
		return Vector3.INF
	var s := current_step()
	if str(s.get("do", "")) == "interior" and world.inside == "":
		var room := str(s["target"])
		if not Interiors.is_remote(room):
			return Interiors.outside_point(room)
		for d in world.city.doors:
			if d["interior"] == room:
				return d["pos"]
	if _marker and is_instance_valid(_marker):
		return _marker.global_position
	return Vector3.INF
