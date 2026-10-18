class_name Multiverse
extends RefCounted
## Places you can travel to: other Earths (by breach or by running), other
## eras (in the Waverider) and the Speed Force. Each one is a City spec.

const EARTHS := ["earth1", "earth2", "earth3", "earthx", "earth38", "earth19"]
const ERAS := ["1942", "old_west", "2046", "3030", "earth1"]
const DESTS := {
	"earth1": {"name": "Earth-1", "desc": "Home: the present day.", "spec": {}},
	"earth2": {"name": "Earth-2", "desc": "Zoom's Earth: taller, gold-tinted art-deco towers.",
		"spec": {"earth": "Earth-2", "label": "EARTH-2", "tint": "#d8b070", "tint_amount": 0.35, "height": 1.25}},
	"earth3": {"name": "Earth-3", "desc": "Jay Garrick's Earth: quiet and old-fashioned.",
		"spec": {"earth": "Earth-3", "label": "EARTH-3", "tint": "#9ab0c8", "tint_amount": 0.3, "height": 0.7}},
	"earthx": {"name": "Earth-X", "desc": "Ruled by Overgirl and Dark Arrow: red banners on dark streets.",
		"spec": {"earth": "Earth-X", "label": "EARTH-X", "tint": "#4a1010", "tint_amount": 0.45, "banners": true, "lit": 0.6}},
	"earth38": {"name": "Earth-38", "desc": "Kara's Earth: bright, sunny and hopeful.",
		"spec": {"earth": "Earth-38", "label": "EARTH-38", "tint": "#fff0c8", "tint_amount": 0.15}},
	"earth19": {"name": "Earth-19", "desc": "Gypsy's Earth: brass and soot, low steampunk skyline.",
		"spec": {"earth": "Earth-19", "label": "EARTH-19", "tint": "#8a6034", "tint_amount": 0.5, "height": 0.55}},
	"1942": {"name": "1942", "desc": "World War II: sepia streets and low brick blocks.",
		"spec": {"era": "1942", "label": "1942", "tint": "#a08a60", "tint_amount": 0.55, "height": 0.45, "lit": 0.5}},
	"old_west": {"name": "The Old West (1874)", "desc": "Jonah Hex territory: a dusty frontier town.",
		"spec": {"kind": "western", "era": "1874"}},
	"2046": {"name": "Star City 2046", "desc": "Grant Wilson's ruined future: broken towers, no lights.",
		"spec": {"era": "2046", "label": "2046", "ruined": true, "tint": "#4a4a40", "tint_amount": 0.4, "lit": 0.3}},
	"3030": {"name": "3030", "desc": "The far future: neon megatowers.",
		"spec": {"era": "3030", "label": "3030", "neon": true, "height": 1.6, "tint": "#2a2050", "tint_amount": 0.35}},
	"speedforce": {"name": "The Speed Force", "desc": "Where all speed comes from. Watch for Time Wraiths.",
		"spec": {"kind": "speedforce"}},
}


static func dest(id: String) -> Dictionary:
	return DESTS.get(id, DESTS["earth1"])


static func list_for(mode: String) -> Array:
	match mode:
		"time":
			return ERAS
		"speed":
			return ["speedforce"] + EARTHS
	return EARTHS
