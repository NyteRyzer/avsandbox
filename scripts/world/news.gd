class_name News
extends Node
## The local news reacts to what you do: headlines from Picture News, CatCo,
## the Gotham Gazette and friends scroll across the bottom of the screen.

const OUTLETS := {"Star City": "STAR CITY STAR", "The Glades": "STAR CITY STAR", "Central City": "PICTURE NEWS",
	"National City": "CATCO WORLDWIDE MEDIA", "Freeland": "FREELAND DAILY", "Gotham City": "GOTHAM GAZETTE",
	"Smallville": "SMALLVILLE LEDGER", "Keystone City": "KEYSTONE CHRONICLE", "Metropolis": "THE DAILY PLANET",
	"Blue Valley": "BLUE VALLEY BUGLE"}
const QUIET := ["Traffic is light across the bay bridges this evening.", "S.T.A.R. Labs denies rumours of a second particle accelerator.",
	"Jitters launches a new seasonal latte: the Flash-uccino.", "Mayor promises more streetlights for the Glades.",
	"CatCo's Kara Danvers wins a journalism award.", "Ivy Town professor claims to have shrunk a car. Again.",
	"Weather: clear skies, chance of meteor showers over Smallville.", "Wayne Enterprises reopens Wayne Tower's observation deck.",
	"Iron Heights warden reports \"no unusual activity\" for the third straight day."]

var world
var current := ""
var outlet := ""
var _t := 0.0
var _quiet_t := 40.0
var queue: Array = []


func report(text: String) -> void:
	queue.append(text)


func _outlet() -> String:
	if world.place_id != "earth1":
		return "THE MULTIVERSE TIMES"
	var d: String = world.city.district_at(world.player.global_position) if world.player else ""
	return OUTLETS.get(d, "PICTURE NEWS")


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	_t -= delta
	_quiet_t -= delta
	if _t <= 0.0:
		if not queue.is_empty():
			current = str(queue.pop_front())
			outlet = _outlet()
			_t = 9.0
		elif _quiet_t <= 0.0:
			_quiet_t = randf_range(45.0, 80.0)
			current = QUIET[randi() % QUIET.size()]
			outlet = _outlet()
			_t = 8.0
		else:
			current = ""


func hero_word() -> String:
	return world.player.display_name if world.player else "A masked figure"


## Headlines for the things that happen.
func on_event(title: String, hero_side: bool) -> void:
	var who := hero_word()
	if hero_side:
		report("%s stops \"%s\". Citizens cheer." % [who, title])
	else:
		report("%s strikes again: \"%s\". Police are baffled." % [who, title])


func on_boss(name: String) -> void:
	report("%s defeats %s in a battle that shook the city." % [hero_word(), name])


func on_heat(level: int) -> void:
	if Game.player_side() == 1:
		report("Police issue a warrant for %s after the latest rampage." % hero_word())
	else:
		report("Manhunt: %s now the most wanted person in the city (level %d)." % [hero_word(), level])
