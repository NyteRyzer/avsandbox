class_name Ultimate
extends Node
## Ultimates (R): each character's signature move, charged by fighting.
## Dealing and taking damage fills the meter; at 100 the ultimate is ready.
## An Ultimate node runs the move's timeline, then frees itself.

const KINDS := ["speed_storm", "kryptonian_fury", "barrage", "summon", "lightning_god", "quake", "inferno",
	"absolute_zero", "sonic_max", "breach_barrage", "giant", "mass_telekinesis", "psychic_storm",
	"dark_magic", "blade_dance", "antimatter_wave"]

## Signature ultimates. Characters not listed get one from their kit (see for_character).
const BY_ID := {
	"flash": {"kind": "speed_storm", "name": "Infinite Mass Punch"},
	"kid_flash": {"kind": "speed_storm", "name": "Speed Force Barrage"},
	"jay_garrick": {"kind": "speed_storm", "name": "Golden Age Blitz"},
	"jesse_quick": {"kind": "speed_storm", "name": "Quick Strike"},
	"xs": {"kind": "speed_storm", "name": "Pink Lightning Rush"},
	"reverse_flash": {"kind": "speed_storm", "name": "Negative Speed Force"},
	"zoom": {"kind": "speed_storm", "name": "Speed Demon"},
	"savitar": {"kind": "speed_storm", "name": "God of Speed"},
	"supergirl": {"kind": "kryptonian_fury", "name": "Solar Flare"},
	"superman": {"kind": "kryptonian_fury", "name": "Man of Steel"},
	"mon_el": {"kind": "kryptonian_fury", "name": "Daxamite Fury"},
	"reign": {"kind": "kryptonian_fury", "name": "Worldkiller's Judgment"},
	"overgirl": {"kind": "kryptonian_fury", "name": "Unstable Solar Flare"},
	"green_arrow": {"kind": "summon", "name": "Team Arrow", "allies": ["spartan", "black_canary", "speedy"]},
	"white_canary": {"kind": "summon", "name": "Legends, Assemble", "allies": ["atom", "firestorm", "heat_wave_hero"]},
	"ras_al_ghul": {"kind": "summon", "name": "The League of Assassins", "gang": "league"},
	"diaz": {"kind": "summon", "name": "The Longbow Hunters", "allies_villain": ["captain_boomerang", "prometheus"]},
	"tobias_whale": {"kind": "summon", "name": "The 100", "gang": "the100"},
	"speedy": {"kind": "barrage", "name": "Arrow Rain", "style": "arrow"},
	"arsenal": {"kind": "barrage", "name": "Arrow Rain", "style": "arrow"},
	"dark_arrow": {"kind": "barrage", "name": "Arrow Rain", "style": "explosive_arrow"},
	"malcolm_merlyn": {"kind": "barrage", "name": "Dark Archer's Volley", "style": "arrow"},
	"captain_boomerang": {"kind": "barrage", "name": "Boomerang Swarm", "style": "boomerang"},
	"batwoman": {"kind": "barrage", "name": "Batarang Storm", "style": "batarang"},
	"spartan": {"kind": "barrage", "name": "Suppressing Fire", "style": "bullet"},
	"wild_dog": {"kind": "barrage", "name": "Full Auto", "style": "bullet"},
	"lex_luthor": {"kind": "barrage", "name": "Warsuit Missile Storm", "style": "missile"},
	"brainiac_5": {"kind": "barrage", "name": "Coluan Drone Strike", "style": "missile"},
	"mr_terrific": {"kind": "barrage", "name": "T-Sphere Swarm", "style": "tsphere"},
	"prometheus": {"kind": "barrage", "name": "Shuriken Storm", "style": "shuriken"},
	"black_lightning": {"kind": "lightning_god", "name": "Lightning Storm", "color": "#9fd0ff"},
	"lightning": {"kind": "lightning_god", "name": "Overcharge", "color": "#c8f0ff"},
	"weather_wizard": {"kind": "lightning_god", "name": "Perfect Storm", "color": "#d8e8ff"},
	"stargirl": {"kind": "lightning_god", "name": "Cosmic Storm", "color": "#ffe8a0"},
	"thunder": {"kind": "quake", "name": "Thunderclap"},
	"citizen_steel": {"kind": "quake", "name": "Steel Meteor"},
	"guardian": {"kind": "quake", "name": "Shield Charge"},
	"vixen": {"kind": "quake", "name": "Rhino Stampede"},
	"hawkgirl": {"kind": "quake", "name": "Nth Metal Meteor"},
	"firestorm": {"kind": "inferno", "name": "Nuclear Fission"},
	"heat_wave": {"kind": "inferno", "name": "Burn It All"},
	"heat_wave_hero": {"kind": "inferno", "name": "Burn It All"},
	"killer_frost": {"kind": "absolute_zero", "name": "Absolute Zero"},
	"captain_cold": {"kind": "absolute_zero", "name": "Cold Snap"},
	"black_canary": {"kind": "sonic_max", "name": "Canary Cry"},
	"black_siren": {"kind": "sonic_max", "name": "Siren's Scream"},
	"vibe": {"kind": "breach_barrage", "name": "Breach Storm"},
	"atom": {"kind": "giant", "name": "Giant-Size Atom"},
	"martian_manhunter": {"kind": "giant", "name": "White Martian Form"},
	"elongated_man": {"kind": "giant", "name": "Stretch to the Max"},
	"grodd": {"kind": "mass_telekinesis", "name": "Telepathic Uprising"},
	"thinker": {"kind": "mass_telekinesis", "name": "The Enlightenment"},
	"dreamer": {"kind": "psychic_storm", "name": "Waking Nightmare"},
	"alice": {"kind": "psychic_storm", "name": "Through the Looking Glass"},
	"damien_darhk": {"kind": "dark_magic", "name": "Khushu Idol Ritual"},
	"deathstroke": {"kind": "blade_dance", "name": "Mirakuru Rampage"},
	"cicada": {"kind": "blade_dance", "name": "Dagger of Death"},
	"vandal_savage": {"kind": "blade_dance", "name": "Immortal Warlord"},
	"anti_monitor": {"kind": "antimatter_wave", "name": "Anti-Matter Wave"},
	"constantine": {"kind": "dark_magic", "name": "Exorcism"},
	"zari": {"kind": "sonic_max", "name": "Hurricane"},
	"nyssa": {"kind": "barrage", "name": "Heir to the Demon", "style": "arrow"},
	"hawkman": {"kind": "quake", "name": "Nth Metal Meteor"},
	"flash_90": {"kind": "speed_storm", "name": "Veteran's Blitz"},
	"spectre": {"kind": "antimatter_wave", "name": "Spectral Judgment", "color": "#9fffb0"},
	"jordan_kent": {"kind": "kryptonian_fury", "name": "Son of Superman"},
	"king_shark": {"kind": "blade_dance", "name": "Feeding Frenzy"},
	"mirror_master": {"kind": "breach_barrage", "name": "Through the Looking Glass"},
	"livewire": {"kind": "lightning_god", "name": "Overload", "color": "#cfefff"},
	"metallo": {"kind": "lightning_god", "name": "Kryptonite Storm", "color": "#6bff6b"},
	"godspeed": {"kind": "speed_storm", "name": "Clone Army Rush"},
	"red_death": {"kind": "speed_storm", "name": "Crimson Blitz"},
}

var actor: Actor
var world
var spec: Dictionary = {}
var t := 0.0
var _step := 0
var _targets: Array = []
var _saved_size := 1.0
var _saved_power := 1.0
var _beat := 0.0


static func for_character(def: Dictionary) -> Dictionary:
	if def.has("ultimate"):
		return def["ultimate"]
	var id := str(def.get("id", ""))
	if BY_ID.has(id):
		return BY_ID[id]
	match str(def.get("movement", "")):
		"speed":
			return {"kind": "speed_storm", "name": "Speed Force Storm"}
		"flight":
			if def.get("strength", false):
				return {"kind": "kryptonian_fury", "name": "Fury"}
	match str(def["primary"].get("kind", "")):
		"arrow", "explosive_arrow":
			return {"kind": "barrage", "name": "Arrow Rain", "style": "arrow"}
		"gun":
			return {"kind": "barrage", "name": "Full Auto", "style": "bullet"}
		"lightning":
			return {"kind": "lightning_god", "name": "Lightning Storm"}
		"flame":
			return {"kind": "inferno", "name": "Inferno"}
	return {"kind": "quake", "name": "Finisher"}


## Starts the actor's ultimate. Returns false when it can't be used.
static func start(a: Actor) -> bool:
	if a.world == null or a.ult_active:
		return false
	var u := Ultimate.new()
	u.actor = a
	u.world = a.world
	u.spec = for_character(a.def)
	a.ult_active = true
	a.world.fx_root.add_child(u)
	u._begin()
	return true


func _color() -> Color:
	if spec.has("color"):
		return Color(str(spec["color"]))
	var look: Dictionary = actor.def["look"]
	return Color(str(look.get("trail", look.get("accent", "#ffffff"))))


func _foes(radius: float, count := 12) -> Array:
	return Abilities._nearest_foes(actor, radius, count)


func _begin() -> void:
	var c := _color()
	FX.flash(world, actor.chest(), c, 4.0, 0.5, 0.6)
	FX.ring(world, actor.global_position + Vector3.UP * 0.2, c, 8.0, 0.6)
	actor.invuln_t = maxf(actor.invuln_t, 1.5)
	if actor.is_player:
		world.hud.show_banner("ULTIMATE: " + str(spec.get("name", "")).to_upper(), c)
		world.shake_at(actor.global_position, 0.4)
		Game.hit_stop(0.12)
	Sfx.play("slowmo", actor.global_position, 0.0)
	match str(spec["kind"]):
		"speed_storm":
			_targets = _foes(70.0, 10)
			if actor.is_player:
				Game.start_slowmo(3.0)
		"kryptonian_fury":
			actor.rage_t = maxf(actor.rage_t, 10.0)
			actor.invuln_t = maxf(actor.invuln_t, 10.0)
			actor.heal(actor.max_hp * 0.3)
			FX.aura(actor, Color("#ffd27a"), 1.6, 10.0)
		"giant":
			_saved_size = actor.size
			_saved_power = actor.power
			actor.size = _saved_size * 2.6
			actor.power = _saved_power * 2.5
			actor.set_shrunk(false)
			actor.heal(actor.max_hp)
		"summon":
			_summon()
		"absolute_zero", "inferno", "sonic_max", "antimatter_wave":
			pass


func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.dead:
		_end()
		return
	t += delta
	_beat -= delta
	match str(spec["kind"]):
		"speed_storm": _speed_storm()
		"kryptonian_fury": _kryptonian_fury()
		"barrage": _barrage()
		"summon": _wait(1.0)
		"lightning_god": _lightning_god()
		"quake": _quake()
		"inferno": _inferno()
		"absolute_zero": _absolute_zero()
		"sonic_max": _sonic_max()
		"breach_barrage": _breach_barrage()
		"giant": _giant()
		"mass_telekinesis": _mass_telekinesis()
		"psychic_storm": _psychic_storm()
		"dark_magic": _dark_magic()
		"blade_dance": _blade_dance()
		"antimatter_wave": _antimatter_wave()
		_: _end()


func _wait(seconds: float) -> void:
	if t > seconds:
		_end()


func _end() -> void:
	if is_instance_valid(actor):
		actor.ult_active = false
		if str(spec.get("kind", "")) == "giant":
			actor.size = _saved_size
			actor.power = _saved_power
			actor.set_shrunk(false)
	queue_free()


func _hit(o: Actor, dmg: float, element := "", knock := 10.0) -> void:
	if not is_instance_valid(o) or o.dead:
		return
	var dir := (o.global_position - actor.global_position)
	dir.y = 0
	o.take_damage(dmg * actor.power, actor, element, dir.normalized() * knock + Vector3.UP * knock * 0.5)
	FX.sparks(world, o.chest(), _color(), 10, 8.0, 0.4)


# --- The moves ----------------------------------------------------------------

## Speedsters: zip from foe to foe, hitting each several times, with lightning.
func _speed_storm() -> void:
	if _beat > 0.0:
		return
	_beat = 0.09
	_targets = _targets.filter(func(o) -> bool: return is_instance_valid(o) and not o.dead)
	if _targets.is_empty() or _step > 40:
		FX.flash(world, actor.chest(), _color(), 6.0, 0.4, 0.5)
		area_finish(10.0, 30.0, "shock")
		_end()
		return
	var o: Actor = _targets[_step % _targets.size()]
	var from := actor.chest()
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.4
	actor.global_position = o.global_position + side
	actor.face_dir = -side
	actor.velocity = Vector3.ZERO
	FX.lightning(world, from, actor.chest(), _color(), 0.25, 0.8, 6, 1)
	_hit(o, 9.0, "shock", 4.0)
	if actor.model:
		actor.model.punch()
	Sfx.play("punch", actor.global_position, -4.0)
	_step += 1


func area_finish(radius: float, dmg: float, element: String) -> void:
	Abilities.area_damage(actor, actor.chest(), radius, dmg * actor.power, element, 20.0, 9.0)
	FX.ring(world, actor.global_position + Vector3.UP * 0.3, _color(), radius, 0.5)
	world.shake_at(actor.global_position, 0.5)


## Kryptonians: invulnerable rage, auto heat-vision sweeps on everyone nearby,
## ending in a shockwave.
func _kryptonian_fury() -> void:
	if t > 10.0:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.35
	for o in _foes(45.0, 4):
		var eyes := actor.head_pos() + actor.forward() * 0.2
		FX.line(world, eyes, o.chest(), Color("#ff3a1a"), 0.18, 0.2)
		FX.flash(world, o.chest(), Color("#ff7a1a"), 1.2, 0.2)
		_hit(o, 8.0, "fire", 6.0)
	if _step % 6 == 5:
		area_finish(12.0, 25.0, "push")
		Sfx.play("slam", actor.global_position, 0.0)
	_step += 1


## A rain of projectiles over the aim point.
func _barrage() -> void:
	if t > 3.0:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.06
	var style := str(spec.get("style", "arrow"))
	var center: Vector3 = actor.aim_point
	var foes := _foes(50.0, 8)
	if not foes.is_empty():
		center = foes[_step % foes.size()].global_position
	var p := Projectile.new()
	var target := center + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	var dmg := 14.0 * actor.power
	match style:
		"bullet":
			var from := actor.hand_pos()
			p.setup(world, actor, from, (target + Vector3.UP - from).normalized() * 140.0, dmg * 0.6, "orb", Color("#ffd27a"), "", 0.0)
			Sfx.play("gun", from, -6.0)
		"missile", "tsphere":
			var from := actor.chest() + Vector3.UP * 1.5
			if not foes.is_empty():
				p.homing = foes[_step % foes.size()]
			p.setup(world, actor, from, (Vector3.UP * 2.0 + (target - from).normalized()).normalized() * 40.0, dmg * 1.4, "missile" if style == "missile" else "tsphere", _color(), "fire" if style == "missile" else "", 3.0)
		_:
			var from := target + Vector3(randf_range(-4, 4), 32.0, randf_range(-4, 4))
			p.setup(world, actor, from, (target - from).normalized() * 70.0, dmg, style, _color(), "fire" if style == "explosive_arrow" else "", 2.5 if style == "explosive_arrow" else 0.0)
	_step += 1


## Allies who fight beside you for 40 seconds.
func _summon() -> void:
	var list: Array = []
	if spec.has("allies"):
		list = spec["allies"]
	elif spec.has("allies_villain"):
		list = spec["allies_villain"]
	var spawned: Array = []
	for id in list:
		var c := Game.get_character(str(id))
		if c.is_empty():
			continue
		var pos := actor.global_position + Vector3(randf_range(-5, 5), 0.3, randf_range(-5, 5))
		spawned.append(world.population.spawn_character(c, actor.team, pos, actor if actor.is_player else null))
	if spec.has("gang"):
		for k in 5:
			var pos := actor.global_position + Vector3(randf_range(-6, 6), 0.3, randf_range(-6, 6))
			var d: Dictionary = world.population.thug_def(0)
			if spec["gang"] == "league":
				d["alias"] = "League Assassin"
				d["look"] = {"suit": "#1a1a1a", "legs": "#141414", "accent": "#5a1010", "skin": "#c99a78", "hair": "#16110e",
					"extras": ["hood", "mask_bandana"], "gear": {"right": "katana"}}
				d["primary"] = {"kind": "melee", "damage": 12, "style": "blade"}
			else:
				d["alias"] = "The 100"
			spawned.append(world.population.spawn_character(d, actor.team, pos, actor if actor.is_player else null))
	for a in spawned:
		FX.portal(world, a.chest(), _color())
		a.set_meta("pinned", true)
		var wr: WeakRef = weakref(a)
		var expire := func() -> void:
			var ref = wr.get_ref()
			if ref and is_instance_valid(ref):
				FX.portal(ref.world, ref.chest(), Color.WHITE)
				ref.queue_free()
		world.get_tree().create_timer(40.0, false).timeout.connect(expire)
	if actor.is_player:
		world.notify("%s arrive to help!" % spec.get("name", "Allies"), Color("#a0d0ff"))


## Bolts from the sky onto every foe in range.
func _lightning_god() -> void:
	if t > 4.0:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.15
	var foes := _foes(45.0, 10)
	if foes.is_empty():
		var p := actor.global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		FX.lightning(world, p + Vector3.UP * 40.0, p, _color(), 0.25, 2.0, 8, 2)
		return
	var o: Actor = foes[_step % foes.size()]
	FX.lightning(world, o.global_position + Vector3(randf_range(-3, 3), 40.0, randf_range(-3, 3)), o.global_position, _color(), 0.3, 2.0, 8, 2)
	_hit(o, 12.0, "shock", 5.0)
	o.stun_t = maxf(o.stun_t, 0.6)
	Sfx.play("lightning", o.global_position, 0.0)
	_step += 1


## Leap high and come down with a shockwave, three times.
func _quake() -> void:
	if _step >= 3:
		_end()
		return
	if _beat > 0.0:
		return
	if _step % 1 == 0 and t > 0.0:
		var r := 14.0 + _step * 4.0
		Abilities.area_damage(actor, actor.global_position + Vector3.UP, r, 30.0 * actor.power, "push", 30.0, 16.0)
		FX.ring(world, actor.global_position + Vector3.UP * 0.2, Color("#c8b090"), r, 0.6)
		FX.smoke(world, actor.global_position, r * 0.4, 1.2)
		world.shake_at(actor.global_position, 0.7)
		Sfx.play("slam", actor.global_position, 4.0)
		_beat = 0.7
		_step += 1


## A nuclear fireball: rings of explosions spreading out.
func _inferno() -> void:
	if _step >= 4:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.35
	var r := 6.0 + _step * 6.0
	for k in 8:
		var ang := k * TAU / 8.0 + _step * 0.4
		var p := actor.global_position + Vector3(cos(ang) * r, 1.0, sin(ang) * r)
		Abilities.explode(world, p, 5.0, 22.0 * actor.power, actor, "fire", Color("#ff8a2a"))
	FX.flash(world, actor.chest(), Color("#ffb04a"), r, 0.4, 0.5)
	_step += 1


## Freeze everything near you solid, then shatter the ice.
func _absolute_zero() -> void:
	if _step == 0:
		for o in _foes(32.0, 14):
			_hit(o, 18.0, "ice", 2.0)
			o.frozen_t = maxf(o.frozen_t, 4.0)
		FX.flash(world, actor.chest(), Color("#a8e8ff"), 30.0, 0.6, 0.5)
		FX.ring(world, actor.global_position + Vector3.UP * 0.2, Color("#cff4ff"), 32.0, 0.8)
		Sfx.play("freeze", actor.global_position, 6.0)
		_step = 1
	elif t > 3.5 and _step == 1:
		for o in _foes(34.0, 14):
			_hit(o, 30.0, "", 14.0)
			FX.sparks(world, o.chest(), Color("#dff6ff"), 24, 10.0, 0.6)
		Sfx.play("punch", actor.global_position, 4.0)
		_end()


## A 360° sonic blast that flings everyone away.
func _sonic_max() -> void:
	if _step >= 3:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.4
	Abilities.area_damage(actor, actor.head_pos(), 26.0, 22.0 * actor.power, "", 40.0, 12.0)
	for k in 6:
		var d := Vector3(cos(k * TAU / 6.0), 0, sin(k * TAU / 6.0))
		FX.sonic_wave(world, actor.head_pos() + d, d, Color("#dfe8ff"), 26.0)
	if actor.model:
		actor.model.play("scream", 0.5)
	Sfx.play("sonic", actor.global_position, 8.0)
	world.shake_at(actor.global_position, 0.4)
	_step += 1


## Breaches open under every foe and drop them back in from the sky.
func _breach_barrage() -> void:
	if _step == 0:
		_targets = _foes(50.0, 8)
		for o in _targets:
			FX.breach(world, o.chest(), Color("#4fa8ff"), 1.2, 1.6)
			o.global_position += Vector3.UP * 30.0
			o.velocity = Vector3.DOWN * 10.0
			o.stun_t = maxf(o.stun_t, 2.0)
		Sfx.play("teleport", actor.global_position, 4.0)
		_step = 1
	elif t > 1.4 and _step == 1:
		for o in _targets:
			if is_instance_valid(o) and not o.dead:
				_hit(o, 35.0, "push", 12.0)
				FX.breach(world, o.chest(), Color("#4fa8ff"), 0.6, 1.2)
		_end()


## Grow huge for 12 seconds: tougher, stronger, ground-shaking steps.
func _giant() -> void:
	if t > 12.0:
		FX.flash(world, actor.chest(), _color(), 3.0, 0.3)
		_end()
		return
	if _beat <= 0.0 and actor.velocity.length() > 2.0 and actor.is_on_floor():
		_beat = 0.6
		Abilities.area_damage(actor, actor.global_position, 6.0, 10.0 * _saved_power, "push", 10.0, 6.0)
		world.shake_at(actor.global_position, 0.25)


## Lift every foe nearby, then slam them all down.
func _mass_telekinesis() -> void:
	if _step == 0:
		_targets = _foes(40.0, 10)
		for o in _targets:
			o.lift_by(actor, 2.0, 0.0, Color("#c47aff"))
		FX.flash(world, actor.head_pos(), Color("#c47aff"), 3.0, 0.4)
		if actor.model:
			actor.model.play("temples", 2.0)
		_step = 1
	elif t > 2.0 and _step == 1:
		for o in _targets:
			if is_instance_valid(o) and not o.dead:
				o.velocity = Vector3.DOWN * 40.0
				_hit(o, 40.0, "", 6.0)
		world.shake_at(actor.global_position, 0.5)
		Sfx.play("slam", actor.global_position, 2.0)
		_end()


## Stun everyone with visions, draining them over time.
func _psychic_storm() -> void:
	if t > 5.0:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.5
	for o in _foes(35.0, 12):
		o.stun_t = maxf(o.stun_t, 0.7)
		_hit(o, 6.0, "shock", 0.5)
		if _step == 0:
			FX.stun_stars(o, 2.0, 5.0)
	FX.ring(world, actor.global_position + Vector3.UP * 1.0, Color("#c47aff"), 35.0, 0.5)
	_step += 1


## Darhk's ritual: drain the life from everyone nearby into yourself.
func _dark_magic() -> void:
	if t > 4.0:
		_end()
		return
	if _beat > 0.0:
		return
	_beat = 0.25
	for o in _foes(30.0, 8):
		FX.line(world, o.chest(), actor.chest(), Color("#6a2a9a"), 0.08, 0.2)
		_hit(o, 7.0, "", 0.0)
		actor.heal(4.0)
		o.stun_t = maxf(o.stun_t, 0.3)
	if actor.model:
		actor.model.play("cast_up", 0.3)


## Dash through every foe in a chain of slashes.
func _blade_dance() -> void:
	if _step == 0:
		_targets = _foes(30.0, 8)
	if _beat > 0.0:
		return
	_beat = 0.16
	_targets = _targets.filter(func(o) -> bool: return is_instance_valid(o) and not o.dead)
	if _targets.is_empty() or _step > 16:
		_end()
		return
	var o: Actor = _targets[_step % _targets.size()]
	var from := actor.global_position
	var to := o.global_position + (o.global_position - from).normalized() * 1.5
	actor.global_position = to
	actor.face_dir = (o.global_position - to).normalized()
	FX.line(world, from + Vector3.UP, to + Vector3.UP, Color("#e8e8f0"), 0.12, 0.2)
	FX.slash_arc(world, o.chest(), actor.global_basis, Color("#ffffff"), 1.6, -1.2, 1.2)
	_hit(o, 14.0, "", 6.0)
	if actor.model:
		actor.model.play("blade", 0.15)
	Sfx.play("whoosh", to, 0.0)
	_step += 1


## The Anti-Monitor erases everything in a widening white wave.
func _antimatter_wave() -> void:
	if t > 3.0:
		_end()
		return
	var r := t * 30.0
	if _beat <= 0.0:
		_beat = 0.25
		FX.ring(world, actor.global_position + Vector3.UP * 0.5, _color() if spec.has("color") else Color("#ffffff"), r, 0.35)
		for o in _foes(r + 2.0, 30):
			if o.global_position.distance_to(actor.global_position) > r - 8.0:
				_hit(o, 30.0, "", 20.0)
		world.shake_at(actor.global_position, 0.3)
