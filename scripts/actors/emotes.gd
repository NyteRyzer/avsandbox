class_name Emotes
extends RefCounted
## Emotes on 1-4: wave, cheer, taunt (with each character's line) and a
## victory pose. Nearby fans react.

const LINES := {
	"green_arrow": "You have failed this city!", "flash": "My name is Barry Allen, and I am the fastest man alive.",
	"supergirl": "I'm not just a hero. I'm Supergirl.", "superman": "Up, up and away.", "atom": "Ray Palmer, at your service.",
	"white_canary": "Legends, let's screw up history.", "black_canary": "Canary Cry incoming.", "spartan": "Don't make me say it twice.",
	"speedy": "Thea Queen. Remember the name.", "kid_flash": "Faster than you, Barry.", "vibe": "Vibe-ing you into next week.",
	"killer_frost": "Chill out.", "firestorm": "Firestorm, baby!", "martian_manhunter": "I am J'onn J'onzz, the last son of Mars.",
	"batwoman": "Gotham has a new protector.", "black_lightning": "Get off my streets.", "thunder": "Can't move me.",
	"lightning": "I'm the spark.", "mr_terrific": "Fair play.", "vixen": "The spirits of the animals are with me.",
	"hawkgirl": "Four thousand years of practice.", "stargirl": "The JSA is back!", "jay_garrick": "Hello, Barry.",
	"jesse_quick": "3X2(9YZ)4A!", "xs": "Hi, Dad! I'm from the future.", "guardian": "Stand behind me.",
	"mon_el": "Daxamites don't do lead. Everything else, though...", "dreamer": "I saw this coming.",
	"brainiac_5": "Twelfth-level intellect. Eleventh on weekends.", "constantine": "Bloody hell.",
	"zari": "Air Totem, don't fail me now.", "spectre": "I am the Spectre.", "malcolm_merlyn": "I'm the Dark Archer.",
	"deathstroke": "I'm going to take everything from you.", "damien_darhk": "Hope is a disease.",
	"reverse_flash": "It's always been me, Barry.", "zoom": "I am the fastest man alive.", "savitar": "I am the god of speed.",
	"thinker": "I am the smartest man alive.", "captain_cold": "Let's be cool.", "heat_wave": "Burn, baby, burn!",
	"heat_wave_hero": "Got any beer?", "weather_wizard": "Forecast: pain.", "reign": "Judgment is here.",
	"lex_luthor": "I'm the hero of this story.", "ras_al_ghul": "Join me, or die.", "grodd": "Grodd is hungry.",
	"vandal_savage": "I have lived for four thousand years.", "black_siren": "Hi, Ollie.", "alice": "Down the rabbit hole we go!",
	"captain_boomerang": "G'day, mate.", "anti_monitor": "All worlds will die.", "overgirl": "Earth-X sends its regards.",
	"dark_arrow": "My world. My rules.", "king_shark": "SHARK SMASH!", "livewire": "Turn it up!", "metallo": "Kryptonite heart, steel fists.",
	"rip_hunter": "Time Master Rip Hunter. The timeline needs protecting.", "amaya": "For Zambesi!",
	"ava_sharpe": "Time Bureau. You're under arrest.", "mona_wu": "Wolfie's hungry!", "charlie": "Oi! Who wants a go?",
	"behrad": "Chill. The wind's got this.", "astra_logue": "I run Hell, love.", "spooner": "I talk to aliens. You don't scare me.",
	"wildcat": "Here, kitty kitty.", "hourman": "One hour. That's all I need.", "dr_midnite": "Chuck, analyze.",
	"starman": "Starman is back in action!", "dr_fate": "I am Fate.", "green_lantern": "In brightest day, in blackest night...",
	"jade": "Green is my color.", "obsidian": "The shadows are mine.", "stripe": "S.T.R.I.P.E. is online!",
	"johnny_thunder": "Say you, Thunderbolt!", "huntress": "I hunt the guilty.", "blackstar": "The Green Arrow is back.",
	"ragman": "My rags remember every soul.", "sentinel": "I'm Sentinel. Back off.", "steel": "Man of Steel? I'm just Steel.",
	"ryan_wilder": "Gotham's got a new Batwoman.", "batwing": "Batwing, wheels up!", "grace_choi": "Meow.",
	"the_ray": "Let there be light!", "the_monitor": "The Crisis is coming.", "harbinger": "I am the herald.",
	"icicle": "America will be reborn.", "brainwave": "Your mind is mine.", "solomon_grundy": "Grundy SMASH!",
	"the_shade": "Darkness becomes you.", "sportsmaster": "Game on.", "tigress": "The hunt is on.",
	"eclipso": "Vengeance is mine.", "dragon_king": "Science demands sacrifice.", "cindy_burman": "Bow to your queen.",
	"bronze_tiger": "You want a fight? You got one.", "count_vertigo": "Feeling dizzy?", "deadshot": "I never miss.",
	"talia_al_ghul": "My father sends his regards.", "golden_glider": "Pretty as gold.", "pied_piper": "Dance to my tune.",
	"trickster": "Surprise!", "black_flash": "...", "atom_smasher": "Smash!", "bizarro": "Bizarro am hero!",
	"doomsday": "RAAAAGH!", "tal_rho": "Kneel before the House of Zod.", "astra_inze": "Kneel, Kara.",
	"cyborg_superman": "Kryptonians must die.", "poison_ivy": "Let Gotham bloom.", "hush": "Hush.",
	"black_mask": "Everybody wears a mask in Gotham.", "mallus": "Time belongs to me.", "neron": "Let's make a deal.",
	"painkiller": "Target acquired.",
}


static func play(a: Actor, which: int) -> void:
	if a.changing or a.dead or not a.is_on_floor():
		return
	var m := a.model
	match which:
		1:
			m.play("cast_up", 0.9)                      # wave
		2:
			m.play("cast_up", 1.4)                      # cheer
			a.velocity.y = 4.0
		3:
			m.play("point", 1.2)                        # taunt
			var line: String = LINES.get(a.def.get("id", ""), "%s strikes a pose." % a.display_name)
			if a.civilian:
				line = "%s waves." % a.display_name
			if a.is_player and a.world:
				a.world.notify("\"%s\"" % line if not a.civilian else line, Color("#ffe8b0"))
			for o in a.get_tree().get_nodes_in_group("actors"):
				if o != a and o.team != "civilian" and o.global_position.distance_to(a.global_position) < 15.0 and o.is_hostile_to(a):
					o.grudges[a.get_instance_id()] = 20.0     # it works
		4:
			m.play("two_hands", 1.6)                    # victory pose
			if a.world:
				FX.ring(a.world, a.global_position + Vector3.UP * 0.1, Color(str(a.def["look"].get("trail", a.def["look"].get("accent", "#ffffff")))), 2.0, 0.5)
	if a.is_player:
		Game.record("emotes")
