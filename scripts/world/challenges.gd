class_name Challenges
extends Node
## Three rotating challenges at a time ("perform 3 takedowns", "find a
## Crisis Fragment"...). Finish one for a reward and a new one replaces it.

const POOL := [
	["Knock out %d enemies", "kos", [10, 20, 30]],
	["Perform %d takedowns", "takedowns", [2, 3, 5]],
	["Pull off %d perfect parries", "parries", [2, 3, 5]],
	["Complete %d events", "events", [1, 2, 3]],
	["Find %d Crisis Fragment(s)", "fragments", [1, 2]],
	["Discover %d new landmarks", "discovered", [3, 5, 8]],
	["Unleash %d ultimate(s)", "ultimates", [1, 2, 3]],
	["Defeat %d boss(es)", "bosses", [1, 2]],
	["Run %d m", "distance", [2000, 5000]],
	["Finish %d race(s)", "races", [1, 2]],
	["Rescue %d people from fires", "rescues", [2, 4]],
	["Stop %d getaway car(s)", "chases", [1, 2]],
	["Change into civilian clothes %d time(s)", "changes", [1, 2]],
]

var world
var active: Array = []   # {text, key, start, need}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	while active.size() < 3:
		_add()
	Game.stat_changed.connect(_on_stat)


func _exit_tree() -> void:
	if Game.stat_changed.is_connected(_on_stat):
		Game.stat_changed.disconnect(_on_stat)


func _add() -> void:
	for attempt in 20:
		var c: Array = POOL[rng.randi() % POOL.size()]
		if active.any(func(a) -> bool: return a["key"] == c[1]):
			continue
		var need: int = c[2][rng.randi() % c[2].size()]
		active.append({"text": str(c[0]) % need, "key": c[1], "start": Game.stat(c[1]), "need": need})
		return


func progress_of(ch: Dictionary) -> float:
	return Game.stat(ch["key"]) - float(ch["start"])


func _on_stat(key: String, value: float) -> void:
	# Achievements ride on the same signal.
	for a in Achievements.check(key, value):
		if world and world.hud:
			world.hud.show_banner("ACHIEVEMENT: " + str(a[1]).to_upper(), Color("#ffd23a"))
			world.notify("Achievement unlocked: %s - %s" % [a[1], a[2]], Color("#ffd23a"))
			Sfx.play("event", null, 2.0)
	for ch in active.duplicate():
		if ch["key"] == key and progress_of(ch) >= float(ch["need"]):
			active.erase(ch)
			var reward := 150
			Game.add_score(reward)
			if world:
				world.notify("CHALLENGE COMPLETE: %s  +%d" % [ch["text"], reward], Color("#60ff90"))
			_add()


func tracker() -> String:
	var lines := PackedStringArray()
	for ch in active:
		lines.append("%s  %d/%d" % [ch["text"], int(minf(progress_of(ch), ch["need"])), int(ch["need"])])
	return "\n".join(lines)
