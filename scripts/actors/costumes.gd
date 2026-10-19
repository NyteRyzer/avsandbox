class_name Costumes
extends RefCounted
## Alternate suits. Every five Crisis Fragments unlock the next one; once
## unlocked, pick it in character select (or the Bunker's display cases still
## give you the classic look). Each variant is a set of look overrides.

const VARIANTS := [
	["flash", "Season 1 Suit", {"suit": "#5a0a0e", "boots": "#5a0a0e", "gloves": "#5a0a0e", "trim": "#a07a2a", "belt": "#a07a2a"}],
	["supergirl", "Pants Suit (Season 5)", {"suit": "#18286a", "extras": ["cape"], "boots": "#18286a", "belt": "#a01820", "pants": "#18286a"}],
	["green_arrow", "Season 1 Hood", {"suit": "#3e5a2c", "coat_color": "#3e5a2c", "extras": ["hood", "leather", "jacket"], "facial": "stubble"}],
	["superman", "Black Suit", {"suit": "#16161a", "cape": "#16161a", "boots": "#16161a", "belt": "#2a2a2e", "gloves": "#16161a",
		"emblem": {"kind": "s_shield", "c1": "#9a9aa2", "c2": "#2a2a2e", "size": 0.19}}],
	["batwoman", "Ryan Wilder's Suit", {"suit": "#141416", "gloves": "#c8102e", "boots": "#c8102e", "skin": "#8d5a3b", "hair": "#16110e"}],
	["killer_frost", "Season 3 Frost", {"suit": "#20305a", "coat_color": "#2a3a6a"}],
	["kid_flash", "Wally's Season 4 Suit", {"suit": "#d8b018", "boots": "#a01818", "gloves": "#a01818", "trim": "#a01818"}],
	["reverse_flash", "Thawne 2049", {"suit": "#e8c018", "trim": "#701010", "boots": "#701010"}],
	["atom", "Mk. II Exosuit", {"suit": "#3a4a6a", "accent": "#e8e8f0", "boots": "#e8e8f0"}],
	["white_canary", "Captain Lance (Waverider)", {"suit": "#e8e8ee", "coat_color": "#3a3a40", "extras": ["coat"]}],
	["black_canary", "Dinah Drake", {"suit": "#141414", "skin": "#c99a74", "hair": "#16110e"}],
	["mon_el", "Valor (Legion)", {"suit": "#18286a", "cape": "#a01820", "emblem": {"kind": "glyph", "c1": "#a01820", "c2": "#18286a", "size": 0.14}}],
	["zoom", "Hunter Zolomon (Earth-2)", {"suit": "#060608", "eye_glow": "#ffffff"}],
	["vibe", "Season 2 Hood", {"suit": "#3a2a22", "coat_color": "#3a2a22", "extras": ["goggles", "hood", "leather", "jacket"]}],
	["stargirl", "Pat's Starman Suit", {"suit": "#1d3fa8", "skirt_color": "#1d3fa8", "boots": "#c8102e"}],
	["martian_manhunter", "White Martian Form", {"suit": "#e8e8e8", "skin": "#d8d8d8", "cape": "#c8c8c8"}],
	["black_lightning", "Classic Gold", {"suit": "#1a2440", "trim": "#e6b422", "gloves": "#e6b422", "boots": "#e6b422"}],
	["spectre", "Crisis Hood", {"suit": "#0e2a12", "cape": "#0e2a12", "eye_glow": "#ffffff"}],
]


static func unlocked(id: String) -> Array:
	var out := []
	for v in VARIANTS:
		if v[0] == id and Game.progress["suits"].has("%s:%s" % [v[0], v[1]]):
			out.append(v)
	return out


## Unlocks the next suit in order. Returns its description, or "" if none left.
static func unlock_next() -> String:
	for v in VARIANTS:
		var key := "%s:%s" % [v[0], v[1]]
		if not Game.progress["suits"].has(key):
			Game.progress["suits"].append(key)
			var c := Game.get_character(v[0])
			return "%s: %s" % [c.get("alias", v[0]), v[1]]
	return ""


## The character's definition wearing the chosen suit ("" = classic).
static func apply(c: Dictionary, variant: String) -> Dictionary:
	if variant == "":
		return c
	for v in VARIANTS:
		if v[0] == c["id"] and v[1] == variant:
			var d := c.duplicate(true)
			var look: Dictionary = d["look"]
			for k in v[2]:
				look[k] = v[2][k]
			return d
	return c
