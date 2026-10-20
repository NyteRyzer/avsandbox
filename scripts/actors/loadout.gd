class_name Loadout
extends RefCounted
## Loadouts: pick what each character takes into a fight. Every slot offers
## the character's own power first, then their alternate kit, powers that fit
## what they are (a speedster's tricks, a Kryptonian's, an archer's, a
## magician's...), and finally the armory: weapons anyone can carry, which
## also show up in the character's hands. Choices are saved per character.

const SLOTS := ["primary", "secondary", "special", "utility"]
const SLOT_NAMES := {"primary": "Primary (LMB)", "secondary": "Secondary (RMB)", "special": "Special (Q)", "utility": "Utility (E)"}

## The armory. "gear" is what appears in hand; "side" picks the hand.
const WEAPONS := {
	"primary": [
		{"kind": "gun", "name": "Pistol", "damage": 9, "cooldown": 0.2, "_gear": "pistol"},
		{"kind": "gun", "name": "Dual Pistols", "dual": true, "damage": 6, "cooldown": 0.14, "_gear": "pistol", "_gear_left": "pistol"},
		{"kind": "gun", "name": "Assault Rifle", "damage": 7, "cooldown": 0.09, "_gear": "pistol_big"},
		{"kind": "gun", "name": "Shotgun", "damage": 8, "cooldown": 0.6, "spread": 5, "_gear": "pistol_big"},
		{"kind": "melee", "name": "Bo Staff", "style": "staff", "damage": 14, "range": 3.0, "_gear": "staff"},
		{"kind": "melee", "name": "Katana", "style": "blade", "damage": 18, "range": 2.9, "_gear": "katana"},
		{"kind": "melee", "name": "Escrima Sticks", "style": "staff", "damage": 11, "cooldown": 0.2, "_gear": "staff"},
		{"kind": "melee", "name": "Nth Metal Mace", "style": "mace", "damage": 21, "range": 2.8, "_gear": "mace"},
		{"kind": "arrow", "name": "Recurve Bow", "damage": 22, "_gear_left": "bow", "_back": "quiver"},
		{"kind": "arrow", "name": "Crossbow", "damage": 20, "color": "#6a3a8a", "_gear": "crossbow"},
		{"kind": "beam", "name": "Cold Gun", "style": "cold", "color": "#a8e8ff", "element": "ice", "_gear": "cold_gun"},
		{"kind": "flame", "name": "Heat Gun", "color": "#ff7a1a", "element": "fire", "_gear": "heat_gun"},
	],
	"secondary": [
		{"kind": "throw", "name": "Batarangs", "model": "batarang", "ricochet": 2, "damage": 12},
		{"kind": "throw", "name": "Throwing Knives", "model": "knife", "spread": 3, "damage": 9},
		{"kind": "throw", "name": "Boomerang", "model": "boomerang", "returns": true, "damage": 16},
		{"kind": "explosive_arrow", "name": "Explosive Arrow"},
		{"kind": "gun", "name": "Sidearm", "damage": 10, "cooldown": 0.22},
		{"kind": "melee", "name": "Martial Arts", "style": "kick", "damage": 13},
	],
	"special": [
		{"kind": "frag_grenade", "name": "Frag Grenade"},
		{"kind": "flashbang", "name": "Flashbang"},
		{"kind": "smoke_bomb", "name": "Smoke Pellets"},
		{"kind": "missile_barrage", "name": "Shoulder Rockets"},
	],
	"utility": [
		{"kind": "grapple", "name": "Grapnel Gun"},
		{"kind": "dodge_flip", "name": "Acrobatics"},
		{"kind": "emp", "name": "EMP Charge"},
	],
}

## Powers that fit an archetype.
const ARCHETYPES := {
	"speedster": {
		"primary": [{"kind": "melee", "name": "Speed Punches", "style": "flurry", "damage": 7, "cooldown": 0.12},
			{"kind": "melee", "name": "Mach Kicks", "style": "kick", "damage": 11, "cooldown": 0.2},
			{"kind": "melee", "name": "Momentum Punch", "style": "momentum", "damage": 16, "cooldown": 0.5}],
		"secondary": [{"kind": "bolt", "name": "Lightning Throw", "style": "lightning", "element": "shock", "speed": 95, "damage": 18},
			{"kind": "chain_lightning", "name": "Chain Lightning"}],
		"special": [{"kind": "time_slow", "name": "Speed Force Slow-Mo"}, {"kind": "tornado", "name": "Speed Vortex"},
			{"kind": "sonic_boom", "name": "Sound Barrier"}, {"kind": "speed_clones", "name": "Time Remnants", "count": 3}],
		"utility": [{"kind": "blitz", "name": "Speed Blitz"}, {"kind": "phase", "name": "Phase Through"}],
	},
	"kryptonian": {
		"primary": [{"kind": "melee", "name": "Kryptonian Strikes", "style": "heavy_punch", "damage": 20},
			{"kind": "melee", "name": "Hammer Fists", "style": "heavy", "damage": 26, "range": 3.0}],
		"secondary": [{"kind": "beam", "name": "Heat Vision", "style": "eyes", "color": "#ff2a1a", "element": "fire"},
			{"kind": "breath", "name": "Freeze Breath", "element": "ice"}],
		"special": [{"kind": "ground_slam", "name": "Thunderclap Slam"}, {"kind": "breath", "name": "Freeze Breath", "element": "ice"},
			{"kind": "nova", "name": "Solar Flare", "element": "fire"}, {"kind": "rage", "name": "Fury"}],
		"utility": [{"kind": "breath", "name": "Super Breath", "element": "push"}, {"kind": "invulnerable", "name": "Man of Steel"}],
	},
	"archer": {
		"primary": [{"kind": "arrow", "name": "Arrow", "damage": 24}, {"kind": "arrow", "name": "Triple Shot", "spread": 3, "damage": 12, "cooldown": 0.6},
			{"kind": "arrow", "name": "Tracer Arrow", "tracer": true, "damage": 20}],
		"secondary": [{"kind": "arrow", "name": "Trick Arrow", "effect": "cycle", "damage": 14, "cooldown": 0.8},
			{"kind": "explosive_arrow", "name": "Explosive Arrow"}, {"kind": "arrow", "name": "Poison Arrow", "effect": "poison", "damage": 16}],
		"special": [{"kind": "arrow_storm", "name": "Arrow Volley"}, {"kind": "flashbang", "name": "Flash Arrow"}, {"kind": "smoke_bomb", "name": "Smoke Arrow"}],
		"utility": [{"kind": "grapple", "name": "Grappling Arrow"}, {"kind": "dodge_flip", "name": "Roll"}],
	},
	"mystic": {
		"primary": [{"kind": "bolt", "name": "Mystic Bolt", "style": "magic", "origin": "hands", "element": "shock"},
			{"kind": "bolt", "name": "Hellfire", "style": "fireball", "origin": "hands", "element": "fire", "speed": 60}],
		"secondary": [{"kind": "telekinesis", "name": "Telekinetic Throw"}, {"kind": "psychic", "name": "Psychic Blast"}],
		"special": [{"kind": "drain", "name": "Life Drain"}, {"kind": "sleep", "name": "Hex of Sleep"}, {"kind": "mirror_trap", "name": "Banishment"},
			{"kind": "shadows", "name": "Darkness"}],
		"utility": [{"kind": "teleport", "name": "Teleport"}, {"kind": "foresight", "name": "Foresight"}],
	},
	"elemental": {
		"primary": [{"kind": "bolt", "name": "Elemental Bolt", "style": "energy", "origin": "hands"}],
		"secondary": [{"kind": "beam", "name": "Energy Beam", "style": "hands"}, {"kind": "ground_spikes", "name": "Ground Spikes"},
			{"kind": "chain_lightning", "name": "Arc Lightning"}],
		"special": [{"kind": "nova", "name": "Nova Burst"}, {"kind": "storm", "name": "Storm Call"}, {"kind": "overload", "name": "Overload"},
			{"kind": "hazard_field", "name": "Hazard Field"}],
		"utility": [{"kind": "ice_wall", "name": "Ice Wall"}, {"kind": "phase", "name": "Phase"}],
	},
	"tech": {
		"primary": [{"kind": "bolt", "name": "Repulsor Blast", "style": "energy", "origin": "hands", "speed": 80}],
		"secondary": [{"kind": "missiles", "name": "Micro Missiles"}, {"kind": "grab", "name": "Tractor Beam"}],
		"special": [{"kind": "missile_barrage", "name": "Missile Barrage"}, {"kind": "t_spheres", "name": "Drone Swarm"},
			{"kind": "force_field", "name": "Force Field"}, {"kind": "emp", "name": "EMP Pulse"}],
		"utility": [{"kind": "emp", "name": "EMP"}, {"kind": "force_field", "name": "Shield Generator"}],
	},
	"brawler": {
		"primary": [{"kind": "melee", "name": "Boxing", "style": "punch", "damage": 14}, {"kind": "melee", "name": "Kickboxing", "style": "kick", "damage": 13}],
		"secondary": [{"kind": "dash", "name": "Shoulder Charge", "style": "charge"}, {"kind": "melee", "name": "Haymaker", "style": "heavy_punch", "damage": 17}],
		"special": [{"kind": "rage", "name": "Adrenaline"}, {"kind": "whirlwind", "name": "Spinning Strike"}],
		"utility": [{"kind": "dodge_flip", "name": "Acrobatics"}],
	},
}


## Which archetypes a character fits.
static func archetypes(def: Dictionary) -> Array:
	var out := []
	var kinds := []
	for slot in SLOTS:
		if def.has(slot):
			kinds.append(str(def[slot].get("kind", "")))
			kinds.append(str(def[slot].get("style", "")))
	var mv := str(def.get("movement", ""))
	if mv == "speed":
		out.append("speedster")
	if Powers.KRYPTONIANS.has(str(def.get("id", ""))) or (mv == "flight" and def.get("strength", false)):
		out.append("kryptonian")
	if kinds.has("arrow") or kinds.has("explosive_arrow"):
		out.append("archer")
	if kinds.has("magic") or kinds.has("telekinesis") or kinds.has("psychic") or def.get("telekinetic", false):
		out.append("mystic")
	if kinds.has("ice") or kinds.has("fireball") or kinds.has("lightning") or kinds.has("chain_lightning") or mv == "ice":
		out.append("elemental")
	if kinds.has("missiles") or kinds.has("energy") or kinds.has("tsphere") or str(def.get("look", {}).get("build", "")) == "armored":
		out.append("tech")
	if out.is_empty() or kinds.has("melee"):
		out.append("brawler")
	return out


## All the options for a slot, the character's own first.
static func options(def: Dictionary, slot: String) -> Array:
	var out := []
	var names := {}
	var add := func(o: Dictionary, tag: String) -> void:
		var n := str(o.get("name", o.get("kind", "")))
		if names.has(n) or not _valid(slot, o):
			return
		names[n] = true
		var copy := o.duplicate(true)
		copy["_source"] = tag
		out.append(copy)
	if def.has(slot):
		add.call(def[slot], "Signature")
	elif slot == "utility" and str(def.get("movement", "")) == "grapple":
		add.call({"kind": "grapple", "name": "Grappling line"}, "Signature")
	elif slot == "utility":
		out.append({"kind": "", "name": "None", "_source": "Signature"})
		names["None"] = true
	var alt: Dictionary = def.get("alt_kit", {})
	if alt.has(slot):
		add.call(alt[slot], "Alternate")
	for arch in archetypes(def):
		for o in ARCHETYPES[arch].get(slot, []):
			var copy: Dictionary = o.duplicate(true)
			# Tint borrowed powers with the character's own colour.
			if not copy.has("color") and copy["kind"] in ["bolt", "beam", "chain_lightning", "grab", "telekinesis", "psychic", "ground_spikes", "hazard_field"]:
				copy["color"] = str(def["look"].get("trail", def["look"].get("glow", def["look"].get("accent", "#ffffff"))))
			add.call(copy, str(arch).capitalize())
	for o in WEAPONS.get(slot, []):
		add.call(o, "Armory")
	return out


static func _valid(slot: String, o: Dictionary) -> bool:
	var k := str(o.get("kind", ""))
	if slot in ["primary", "secondary"]:
		return k in Game.ATTACK_KINDS
	if slot == "special":
		return k in Game.SPECIAL_KINDS
	return k in Game.UTILITY_KINDS or k == ""


static func saved(id: String) -> Dictionary:
	if not Game.progress.has("loadouts"):
		Game.progress["loadouts"] = {}
	return Game.progress["loadouts"].get(id, {})


static func choose(id: String, slot: String, index: int) -> void:
	if not Game.progress.has("loadouts"):
		Game.progress["loadouts"] = {}
	var d: Dictionary = Game.progress["loadouts"].get(id, {})
	if index <= 0:
		d.erase(slot)
	else:
		d[slot] = index
	Game.progress["loadouts"][id] = d
	Game.save_settings()


static func reset(id: String) -> void:
	if Game.progress.has("loadouts"):
		Game.progress["loadouts"].erase(id)
		Game.save_settings()


## The character with their saved loadout applied (a copy).
static func apply(def: Dictionary) -> Dictionary:
	var id := str(def.get("id", ""))
	var choice := saved(id)
	if choice.is_empty():
		return def
	var c: Dictionary = def.duplicate(true)
	var gear: Dictionary = c["look"].get("gear", {}).duplicate()
	for slot in SLOTS:
		if not choice.has(slot):
			continue
		var opts := options(def, slot)
		var i := int(choice[slot])
		if i <= 0 or i >= opts.size():
			continue
		var o: Dictionary = opts[i].duplicate(true)
		if o.has("_gear"):
			gear["right"] = o["_gear"]
		if o.has("_gear_left"):
			gear["left"] = o["_gear_left"]
		if o.has("_back"):
			c["look"]["back"] = o["_back"]
		for key in ["_gear", "_gear_left", "_back", "_source"]:
			o.erase(key)
		if slot == "utility" and str(o.get("kind", "")) == "":
			c.erase("utility")
		else:
			c[slot] = o
	c["look"]["gear"] = gear
	return c


## Three more powers for keys 1, 2 and 3: the character's alternate special
## and utility first, then specials that fit their archetype, then a few that
## suit anyone. Never repeats what's already on Q or E.
const FALLBACK_POWERS := [{"kind": "rage", "name": "Adrenaline Rush"}, {"kind": "smoke_bomb", "name": "Smoke Pellet"},
	{"kind": "flashbang", "name": "Flashbang"}, {"kind": "frag_grenade", "name": "Grenade"}, {"kind": "invulnerable", "name": "Brace"}]


static func extra_powers(def: Dictionary) -> Array:
	var used := {}
	for slot in ["special", "utility"]:
		if def.has(slot):
			used[str(def[slot].get("kind", ""))] = true
	var out := []
	var take := func(o: Dictionary) -> void:
		var k := str(o.get("kind", ""))
		if out.size() >= 3 or used.has(k) or k == "" or k in ["grapple", "blitz", "dodge_flip", "phase", "ice_wall"]:
			return
		if not (k in Game.SPECIAL_KINDS or k in Game.UTILITY_KINDS):
			return
		used[k] = true
		var c: Dictionary = o.duplicate(true)
		c.erase("_source")
		if not c.has("color") and def.has("look"):
			c["color"] = str(def["look"].get("trail", def["look"].get("glow", def["look"].get("accent", "#ffffff"))))
		out.append(c)
	var alt: Dictionary = def.get("alt_kit", {})
	for slot in ["special", "utility"]:
		if alt.has(slot):
			take.call(alt[slot])
	for arch in archetypes(def):
		for o in ARCHETYPES[arch].get("special", []) + ARCHETYPES[arch].get("utility", []):
			take.call(o)
	for o in FALLBACK_POWERS:
		take.call(o)
	return out


## A one-line summary for the HUD and menus.
static func describe(def: Dictionary) -> String:
	var parts := []
	for slot in SLOTS:
		if def.has(slot):
			parts.append(str(def[slot].get("name", def[slot]["kind"])))
	return " · ".join(parts)
