class_name Achievements
extends RefCounted
## Lifetime achievements, unlocked from the stats Game.record() keeps.

const LIST := [
	["first_blood", "First Blood", "Knock out your first enemy.", "kos", 1],
	["street_sweeper", "Street Sweeper", "Knock out 100 enemies.", "kos", 100],
	["army_of_one", "Army of One", "Knock out 500 enemies.", "kos", 500],
	["boss_slayer", "Boss Slayer", "Defeat a boss.", "bosses", 1],
	["big_game", "Big Game Hunter", "Defeat 10 bosses.", "bosses", 10],
	["finisher", "Finisher", "Perform 10 takedowns.", "takedowns", 10],
	["untouchable", "Untouchable", "Pull off 10 perfect parries.", "parries", 10],
	["crime_fighter", "On Patrol", "Complete 5 events.", "events", 5],
	["city_saver", "Guardian of the City", "Complete 25 events.", "events", 25],
	["collector", "Collector", "Find 10 Crisis Fragments.", "fragments", 10],
	["all_fragments", "Paragon of Truth", "Find all 40 Crisis Fragments.", "fragments", 40],
	["explorer", "Explorer", "Discover 20 landmarks.", "discovered", 20],
	["cartographer", "Cartographer", "Discover 50 landmarks.", "discovered", 50],
	["shutterbug", "Shutterbug", "Take a photo in photo mode.", "photos", 1],
	["secret_identity", "Secret Identity", "Change out of costume.", "changes", 1],
	["road_trip", "Road Trip", "Drive 5 different cars.", "drives", 5],
	["tourist", "Multiverse Tourist", "Travel between worlds 5 times.", "travels", 5],
	["ultimate_power", "Ultimate Power", "Unleash 10 ultimates.", "ultimates", 10],
	["fastest_alive", "The Fastest Man Alive", "Cover 50 km on foot.", "distance", 50000],
	["racer", "Racer", "Finish 3 races.", "races", 3],
	["crisis_averted", "One Last Tomorrow", "Finish the Crisis City story.", "story_complete", 1],
	["first_responder", "First Responder", "Stop 5 Crisis Events in time.", "crises_averted", 5],
	["liberator", "Liberator", "Liberate 3 occupied districts.", "districts_liberated", 3],
	["no_one_left_behind", "No One Left Behind", "Rescue 3 heroes from erased timelines.", "heroes_rescued", 3],
	["finish_them", "Finish Them", "Land 5 boss finishers.", "boss_finishers", 5],
	["clash_of_titans", "Clash of Titans", "Win 5 boss clashes.", "boss_clashes_won", 5],
	["matrix", "Not Even Close", "Pull off 10 perfect dodges.", "perfect_dodges", 10],
	["free_runner", "Free Runner", "Do 50 double jumps.", "double_jumps", 50],
	["parkour", "Rooftop Runner", "Finish a rooftop free-run.", "rooftop_runs", 1],
	["boss_rush", "Boss Rush", "Beat every boss in a Boss Rush.", "boss_rushes", 1],
	["firefighter", "Firefighter", "Rescue 10 people from burning buildings.", "rescues", 10],
	["chase_master", "Pursuit", "Stop 3 getaway cars.", "chases", 3],
	["survivor", "Survivor", "Reach wave 10 in the Survival Simulator.", "waves_best", 10],
]


## Unlocks anything newly earned. Returns the names unlocked.
static func check(key: String, value: float) -> Array:
	var out := []
	var have: Array = Game.progress["achievements"]
	for a in LIST:
		if a[3] == key and value >= float(a[4]) and not have.has(a[0]):
			have.append(a[0])
			out.append(a)
	return out


static func describe() -> String:
	var have: Array = Game.progress["achievements"]
	var lines := PackedStringArray()
	for a in LIST:
		var done := have.has(a[0])
		var prog := minf(Game.stat(a[3]), float(a[4]))
		lines.append("%s  %s  -  %s  (%d/%d)" % ["[X]" if done else "[ ]", a[1], a[2], int(prog), int(a[4])])
	return "\n".join(lines)
