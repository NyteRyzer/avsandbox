class_name Teams
extends RefCounted
## Who fights alongside whom. Teams drive the character-select filter, the
## team-up bonus (fight next to a recruited teammate for extra damage),
## team events (the Injustice Society hits the city at once) and nemesis
## fights (your archenemy hunts you down).

const TEAMS := {
	"Team Flash": {"color": "#ff3a3a", "side": "hero", "members": ["flash", "kid_flash", "vibe", "killer_frost", "jay_garrick",
		"jesse_quick", "xs", "elongated_man", "flash_90", "iris_west", "chester_runk", "allegra", "pariah", "joe_west"]},
	"Team Arrow": {"color": "#3aaa4a", "side": "hero", "members": ["green_arrow", "spartan", "black_canary", "speedy", "arsenal",
		"wild_dog", "mr_terrific", "huntress", "blackstar", "ragman", "nyssa", "connor_hawke", "overwatch"]},
	"Legends": {"color": "#ff9a3a", "side": "hero", "members": ["white_canary", "atom", "firestorm", "heat_wave_hero", "vixen",
		"hawkgirl", "hawkman", "citizen_steel", "constantine", "zari", "rip_hunter", "amaya", "ava_sharpe", "mona_wu", "charlie",
		"behrad", "astra_logue", "spooner", "nora_darhk", "gideon"]},
	"Justice Society": {"color": "#ffd23a", "side": "hero", "members": ["stargirl", "wildcat", "hourman", "dr_midnite", "starman",
		"dr_fate", "green_lantern", "jade", "obsidian", "stripe", "johnny_thunder", "jay_garrick", "hawkman", "amaya"]},
	"Super Friends": {"color": "#3a6aff", "side": "hero", "members": ["supergirl", "martian_manhunter", "guardian", "mon_el",
		"dreamer", "brainiac_5", "sentinel", "lena_luthor"]},
	"Super Family": {"color": "#c8102e", "side": "hero", "members": ["superman", "jordan_kent", "steel", "lois_lane", "natalie_irons"]},
	"Team Batwoman": {"color": "#b0101a", "side": "hero", "members": ["batwoman", "ryan_wilder", "batwing"]},
	"Pierce Family": {"color": "#9fd0ff", "side": "hero", "members": ["black_lightning", "thunder", "lightning", "grace_choi"]},
	"Paragons": {"color": "#6ad0ff", "side": "hero", "members": ["the_monitor", "harbinger", "spectre", "the_ray", "flash", "supergirl",
		"batwoman", "white_canary", "martian_manhunter"]},
	"Injustice Society": {"color": "#8fd6ff", "side": "villain", "members": ["icicle", "brainwave", "solomon_grundy", "the_shade",
		"sportsmaster", "tigress", "eclipso", "dragon_king", "cindy_burman"]},
	"Legion of Doom": {"color": "#a01a1a", "side": "villain", "members": ["reverse_flash", "malcolm_merlyn", "damien_darhk", "captain_cold",
		"vandal_savage", "mallus", "neron"]},
	"Rogues": {"color": "#a8e8ff", "side": "villain", "members": ["captain_cold", "heat_wave", "weather_wizard", "mirror_master",
		"golden_glider", "pied_piper", "trickster", "captain_boomerang"]},
	"Evil Speedsters": {"color": "#ffd23a", "side": "villain", "members": ["reverse_flash", "zoom", "savitar", "godspeed", "red_death",
		"black_flash"]},
	"League of Assassins": {"color": "#7a5a2a", "side": "villain", "members": ["ras_al_ghul", "talia_al_ghul", "bronze_tiger", "deathstroke"]},
	"Star City Underworld": {"color": "#d8761a", "side": "villain", "members": ["deathstroke", "prometheus", "diaz", "count_vertigo",
		"deadshot", "black_siren", "dark_arrow", "vigilante", "anarky"]},
	"Kryptonian Threats": {"color": "#b81820", "side": "villain", "members": ["reign", "overgirl", "bizarro", "doomsday", "tal_rho",
		"astra_inze", "cyborg_superman", "metallo", "lex_luthor", "livewire", "red_daughter"]},
	"Gotham Underworld": {"color": "#8aff4a", "side": "villain", "members": ["alice", "poison_ivy", "hush", "black_mask", "mouse"]},
	"Freeland Syndicate": {"color": "#e8e8e8", "side": "villain", "members": ["tobias_whale", "painkiller"]},
	"Central City Metas": {"color": "#c47aff", "side": "villain", "members": ["grodd", "king_shark", "thinker", "cicada", "atom_smasher",
		"bloodwork", "deathstorm", "abra_kadabra", "chillblaine", "plastique"]},
	"National City Menaces": {"color": "#ff4ab8", "side": "villain", "members": ["psi", "nyxly", "red_daughter"]},
	"Bishop's Hybrids": {"color": "#6affc8", "side": "villain", "members": ["bishop"]},
}

## Each hero's archenemy (and back again).
const NEMESIS := {
	"flash": "reverse_flash", "kid_flash": "savitar", "jay_garrick": "zoom", "flash_90": "anti_monitor", "xs": "godspeed",
	"jesse_quick": "zoom", "vibe": "cicada", "killer_frost": "icicle", "elongated_man": "thinker",
	"green_arrow": "deathstroke", "black_canary": "black_siren", "speedy": "malcolm_merlyn", "spartan": "diaz",
	"arsenal": "prometheus", "wild_dog": "diaz", "huntress": "count_vertigo", "blackstar": "deadshot", "ragman": "damien_darhk",
	"nyssa": "talia_al_ghul", "mr_terrific": "diaz",
	"supergirl": "reign", "martian_manhunter": "cyborg_superman", "mon_el": "astra_inze", "dreamer": "brainwave",
	"brainiac_5": "lex_luthor", "guardian": "metallo", "sentinel": "astra_inze",
	"superman": "doomsday", "jordan_kent": "tal_rho", "steel": "bizarro",
	"batwoman": "alice", "ryan_wilder": "black_mask", "batwing": "hush",
	"black_lightning": "tobias_whale", "thunder": "painkiller", "lightning": "painkiller", "grace_choi": "tobias_whale",
	"white_canary": "vandal_savage", "atom": "damien_darhk", "firestorm": "mallus", "heat_wave_hero": "captain_cold",
	"vixen": "grodd", "hawkgirl": "vandal_savage", "hawkman": "vandal_savage", "citizen_steel": "solomon_grundy",
	"constantine": "neron", "zari": "mallus", "rip_hunter": "vandal_savage", "amaya": "mallus", "ava_sharpe": "mallus",
	"mona_wu": "neron", "charlie": "neron", "behrad": "neron", "astra_logue": "neron", "spooner": "mallus",
	"stargirl": "icicle", "wildcat": "tigress", "hourman": "solomon_grundy", "dr_midnite": "the_shade", "starman": "icicle",
	"dr_fate": "eclipso", "green_lantern": "solomon_grundy", "jade": "eclipso", "obsidian": "the_shade",
	"stripe": "dragon_king", "johnny_thunder": "brainwave",
	"the_ray": "overgirl", "the_monitor": "anti_monitor", "harbinger": "anti_monitor", "spectre": "anti_monitor",
	"joe_west": "mirror_master", "connor_hawke": "anarky", "overwatch": "prometheus", "iris_west": "bloodwork", "chester_runk": "chillblaine",
	"allegra": "deathstorm", "pariah": "anti_monitor", "nora_darhk": "bishop", "gideon": "bishop", "lena_luthor": "psi",
	"lois_lane": "red_daughter", "natalie_irons": "nyxly",
}


## Every team a character belongs to.
static func of(id: String) -> Array:
	var out := []
	for t in TEAMS:
		if TEAMS[t]["members"].has(id):
			out.append(t)
	return out


## The first (main) team, or "".
static func main_team(id: String) -> String:
	var t := of(id)
	return t[0] if not t.is_empty() else ""


static func color(team: String) -> Color:
	return Color(str(TEAMS.get(team, {}).get("color", "#ffffff")))


static func share_team(a: String, b: String) -> String:
	for t in of(a):
		if TEAMS[t]["members"].has(b):
			return t
	return ""


## Your archenemy, if you have one (villains are hunted by the hero who
## counts them as theirs).
static func nemesis(id: String) -> String:
	if NEMESIS.has(id):
		return NEMESIS[id]
	for h in NEMESIS:
		if NEMESIS[h] == id:
			return h
	return ""


## A random team on the given side with at least `n` members in the roster.
static func random_team(side: String, n := 3) -> String:
	var pool := []
	for t in TEAMS:
		if TEAMS[t]["side"] == side and members(t).size() >= n:
			pool.append(t)
	return pool[randi() % pool.size()] if not pool.is_empty() else ""


static func members(team: String) -> Array:
	return TEAMS.get(team, {}).get("members", []).filter(func(id) -> bool: return Game.by_id.has(id))
