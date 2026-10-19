class_name Abilities
extends RefCounted
## Every attack and special power in the game. Characters reference these by
## "kind" in data/roster.json; per-character fields (damage, color, element,
## range...) override the defaults below.

const ATTACK_DEFAULTS := {
	"melee": {"damage": 12.0, "cooldown": 0.34, "energy": 0.0, "range": 2.4, "element": "", "style": "punch"},
	"arrow": {"damage": 22.0, "cooldown": 0.5, "energy": 0.0, "speed": 95.0, "color": "#c9b38a"},
	"explosive_arrow": {"damage": 32.0, "cooldown": 1.2, "energy": 18.0, "speed": 75.0, "radius": 5.5, "color": "#ff4a2a"},
	"throw": {"damage": 15.0, "cooldown": 0.42, "energy": 0.0, "speed": 65.0, "color": "#d0d0d0"},
	"bolt": {"damage": 16.0, "cooldown": 0.3, "energy": 7.0, "speed": 55.0, "color": "#ffffff", "style": "energy"},
	"beam": {"damage": 55.0, "cooldown": 0.0, "energy": 22.0, "range": 90.0, "color": "#ff3322", "style": "hands"},
	"sonic": {"damage": 10.0, "cooldown": 0.9, "energy": 16.0, "range": 15.0, "knock": 22.0, "color": "#dfe8ff"},
	"lightning": {"damage": 22.0, "cooldown": 0.6, "energy": 12.0, "range": 55.0, "chain": 2, "color": "#8fd0ff"},
	"gun": {"damage": 7.0, "cooldown": 0.16, "energy": 0.0, "range": 140.0},
	"dash": {"damage": 18.0, "cooldown": 1.0, "energy": 12.0, "distance": 12.0},
	"flame": {"damage": 40.0, "cooldown": 0.0, "energy": 16.0, "range": 11.0, "color": "#ff7a1a", "element": "fire"},
	"breath": {"damage": 22.0, "cooldown": 0.0, "energy": 20.0, "range": 13.0, "color": "#dff4ff", "element": "ice"},
	"missiles": {"damage": 14.0, "cooldown": 1.4, "energy": 18.0, "speed": 38.0, "color": "#ffaa33"},
	"telekinesis": {"damage": 30.0, "cooldown": 2.5, "energy": 22.0, "range": 26.0, "color": "#9b4dff"},
	"psychic": {"damage": 14.0, "cooldown": 1.0, "energy": 16.0, "range": 16.0, "knock": 14.0, "color": "#c47aff"},
}

## Kinds that fire continuously while the button is held.
const HELD_KINDS := ["beam", "flame", "breath"]

const SPECIAL_DEFAULTS := {
	"time_slow": {"energy": 50.0, "cooldown": 14.0},
	"tornado": {"energy": 40.0, "cooldown": 10.0},
	"ground_slam": {"energy": 30.0, "cooldown": 6.0},
	"smoke_bomb": {"energy": 30.0, "cooldown": 10.0},
	"nova": {"energy": 45.0, "cooldown": 9.0},
	"sonic_scream": {"energy": 40.0, "cooldown": 9.0},
	"rage": {"energy": 40.0, "cooldown": 16.0},
	"shrink": {"energy": 10.0, "cooldown": 1.0},
	"invisibility": {"energy": 40.0, "cooldown": 15.0},
	"invulnerable": {"energy": 40.0, "cooldown": 14.0},
	"teleport": {"energy": 25.0, "cooldown": 2.5},
	"drain": {"energy": 40.0, "cooldown": 10.0},
	"arrow_storm": {"energy": 35.0, "cooldown": 9.0},
	"boomerang_storm": {"energy": 35.0, "cooldown": 9.0},
	"breath": {"energy": 35.0, "cooldown": 8.0},
	"frag_grenade": {"energy": 25.0, "cooldown": 6.0},
	"t_spheres": {"energy": 40.0, "cooldown": 16.0},
	"animal_spirit": {"energy": 40.0, "cooldown": 16.0},
	"shield_wall": {"energy": 30.0, "cooldown": 10.0},
	"force_field": {"energy": 35.0, "cooldown": 12.0},
	"storm": {"energy": 50.0, "cooldown": 16.0},
	"missile_barrage": {"energy": 50.0, "cooldown": 14.0},
	"dampen": {"energy": 40.0, "cooldown": 14.0},
	"mind_control": {"energy": 55.0, "cooldown": 20.0},
	# Utilities (E)
	"blitz": {"energy": 30.0, "cooldown": 6.0},
	"grapple": {"energy": 0.0, "cooldown": 0.3},
	"dodge_flip": {"energy": 10.0, "cooldown": 1.2},
	"emp": {"energy": 30.0, "cooldown": 10.0},
	"foresight": {"energy": 35.0, "cooldown": 14.0},
	"ice_wall": {"energy": 25.0, "cooldown": 6.0},
	"phase": {"energy": 30.0, "cooldown": 8.0},
}

const ELEMENT_COLORS := {"fire": Color("#ff7a1a"), "ice": Color("#a8e8ff"), "shock": Color("#9fd0ff"), "push": Color("#e8f2ff"), "": Color("#ffffff")}


static func p(atk: Dictionary, key: String):
	if atk.has(key):
		return atk[key]
	if Powers.ATTACK_DEFAULTS.has(atk["kind"]):
		return Powers.ATTACK_DEFAULTS[atk["kind"]].get(key, 0.0)
	return ATTACK_DEFAULTS[atk["kind"]].get(key, 0.0)


static func energy_cost(atk: Dictionary) -> float:
	return float(p(atk, "energy"))


static func cooldown(atk: Dictionary) -> float:
	return float(p(atk, "cooldown"))


static func special_cost(sp: Dictionary) -> float:
	return float(sp.get("energy", _special_defaults(sp)["energy"]))


static func special_cooldown(sp: Dictionary) -> float:
	return float(sp.get("cooldown", _special_defaults(sp)["cooldown"]))


static func _special_defaults(sp: Dictionary) -> Dictionary:
	if Powers.SPECIAL_DEFAULTS.has(sp["kind"]):
		return Powers.SPECIAL_DEFAULTS[sp["kind"]]
	return SPECIAL_DEFAULTS[sp["kind"]]


static func describe(atk: Dictionary) -> String:
	return str(atk.get("name", str(atk["kind"]).capitalize()))


static func ray(a: Node3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ACTORS | Game.LAYER_PROPS, exclude)
	return a.get_world_3d().direct_space_state.intersect_ray(q)


## A ray that passes through actors the shooter may not hurt (allies).
static func attack_ray(a: Actor, from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [a.get_rid()]
	for attempt in 4:
		var hit := ray(a, from, to, exclude)
		if hit.is_empty():
			return hit
		var col = hit["collider"]
		if col is Actor and not a.can_hurt(col):
			exclude.append(col.get_rid())
			continue
		return hit
	return {}


static func _color(atk: Dictionary) -> Color:
	return Color(str(p(atk, "color")))


## Where an attack leaves the body: alternating hands, the muzzle of a held
## gun or staff, the eyes, the mouth, or the bow.
static func origin(a: Actor, atk: Dictionary) -> Vector3:
	var o := str(atk.get("origin", ""))
	match atk["kind"]:
		"arrow", "explosive_arrow":
			if a.def["look"].get("gear", {}).get("left", "") == "bow":
				return a.model.hand_point(-1.0) + a.forward() * 0.2
		"gun":
			if a.model.muzzle:
				return a.model.muzzle_point()
		"flame":
			return a.model.muzzle_point() if a.model.muzzle else a.hand_pos()
		"breath", "sonic":
			if o == "" or o == "mouth":
				return a.head_pos() + a.forward() * 0.15 * a.size - Vector3.UP * 0.05
	match o:
		"hands":
			a.hand_flip = -a.hand_flip
			return a.model.hand_point(a.hand_flip) + a.forward() * 0.1
		"muzzle":
			return a.model.muzzle_point()
		"head":
			return a.head_pos() + Vector3.UP * 0.2
		"eyes":
			return a.head_pos() + a.forward() * 0.12
	return a.model.hand_point(1.0) + a.forward() * 0.1


## Player aim assist: nudges a shot onto an enemy close to the crosshair.
static func assist(a: Actor, from: Vector3, dir: Vector3, reach: float) -> Vector3:
	if not a.is_player:
		return dir
	var best_dot := 0.985
	var best := dir
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o) or o.team == "civilian":
			continue
		var to: Vector3 = o.chest() - from
		if to.length() > reach:
			continue
		var d := dir.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = to.normalized()
	return best


static func _pose_for(kind: String, atk: Dictionary) -> String:
	match kind:
		"arrow", "explosive_arrow":
			return "bow" if a_has_bow(atk) else "throw"
		"throw":
			return "throw"
		"gun":
			return "dual_guns" if atk.get("dual", false) else "gun"
		"sonic", "breath":
			return "scream" if str(atk.get("origin", "mouth")) == "mouth" else "two_hands"
		"psychic", "telekinesis":
			return "temples"
		"chain_lightning":
			return "two_hands"
		"ground_spikes":
			return "cast_up"
		"grab":
			return "stretch"
		"bolt", "lightning", "missiles":
			var o := str(atk.get("origin", ""))
			if o == "hands":
				return "two_hands"
			if o == "head":
				return "temples"
			if o == "sky":
				return "cast_up"
			return "point"
	return "point"


static func a_has_bow(atk: Dictionary) -> bool:
	return bool(atk.get("_bow", false))


# --- Attacks ----------------------------------------------------------------

static func fire(a: Actor, atk: Dictionary) -> void:
	var w = a.world
	var kind: String = atk["kind"]
	var dmg := float(p(atk, "damage")) * a.power
	var element := str(atk.get("element", ""))
	if a.dampened_t > 0.0 and kind != "melee":
		FX.sparks(w, a.chest(), Color("#ff3a2a"), 6, 3.0)
		return
	if kind in ["arrow", "explosive_arrow"]:
		atk["_bow"] = a.def["look"].get("gear", {}).get("left", "") == "bow"
	if kind != "melee" and kind != "dash":
		a.model.play(_pose_for(kind, atk), 0.45)
	match kind:
		"melee":
			_melee(a, atk, dmg, element)
		"arrow", "explosive_arrow", "throw", "bolt":
			var from := origin(a, atk)
			var speed := float(p(atk, "speed"))
			var dir := assist(a, from, a.aim_dir(from), speed * 2.5)
			var style := str(atk.get("style", "energy"))
			var model := str(atk.get("model", ""))
			if kind == "arrow":
				style = "arrow" if atk["_bow"] else "knife"
			elif kind == "explosive_arrow":
				style = "explosive_arrow" if atk["_bow"] else (model if model != "" else "grenade")
			elif kind == "throw":
				style = model if model != "" else "knife"
			var radius := float(p(atk, "radius")) if kind == "explosive_arrow" else 0.0
			var effect := str(atk.get("effect", ""))
			if effect == "cycle":
				# Green Arrow's trick quiver: net, flash, then a freeze arrow.
				effect = ["net", "flash", "freeze"][a.trick_index % 3]
				a.trick_index += 1
				if a.is_player:
					a.world.notify(effect.capitalize() + " arrow", Color("#c8ffc8"))
			var spread := int(atk.get("spread", 1))
			var tracer: Actor = Powers.aimed_foe(a, 80.0, 0.7) if bool(atk.get("tracer", false)) else null
			for k in spread:
				var d := dir
				if spread > 1:
					d = dir.rotated(Vector3.UP, (k - (spread - 1) * 0.5) * 0.09)
				var proj := Projectile.new()
				proj.returns = bool(atk.get("returns", style in ["boomerang", "helmet", "cicada_dagger"]))
				proj.effect = effect
				proj.ricochet = int(atk.get("ricochet", 0))
				if tracer:
					proj.homing = tracer
				proj.setup(w, a, from, d * speed, dmg, style, _color(atk), element, radius)
			var sound := "arrow"
			if kind == "bolt":
				sound = "lightning" if style == "lightning" else ("fire" if style == "fireball" else "zap")
			Sfx.play(sound, from, -4.0)
		"gun":
			var hands: Array = [1.0, -1.0] if atk.get("dual", false) else [1.0]
			# Shotguns fire a spread of pellets.
			var pellets := int(atk.get("spread", 1))
			var jitter := 0.012 if pellets <= 1 else 0.07
			for shot in pellets * hands.size():
				var side: float = hands[shot % hands.size()]
				var from: Vector3 = a.model.hand_point(side) + a.forward() * 0.25 if not a.model.muzzle or side < 0 else a.model.muzzle_point()
				var dir := assist(a, from, a.aim_dir(from), float(p(atk, "range")))
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter).normalized()
				var end := from + dir * float(p(atk, "range"))
				var hit := attack_ray(a, from, end)
				if not hit.is_empty():
					end = hit["position"]
					_apply_hit(a, hit["collider"], dmg, element, dir * 3.0)
				FX.line(w, from, end, Color("#fff0a0"), 0.02, 0.05)
				FX.flash(w, from, Color("#ffd27a"), 0.35, 0.06, 0.9)
				FX.sparks(w, end, Color("#ffd080"), 4, 3.0, 0.2)
			Sfx.play("gun", a.global_position, -6.0)
		"sonic", "psychic":
			var reach := float(p(atk, "range"))
			var from := origin(a, atk) if kind == "sonic" else a.head_pos()
			var dir := a.aim_dir(from)
			var hits := area_damage(a, from, reach, dmg, "shock" if kind == "psychic" else element, float(p(atk, "knock")), 5.0, dir, 0.72)
			FX.sonic_wave(w, from + dir, dir, _color(atk), reach)
			if kind == "psychic":
				FX.flash(w, a.head_pos(), _color(atk), 1.2, 0.3, 0.5)
			Sfx.play("sonic", from, -2.0)
			if hits > 0:
				a.combo_hit(hits)
		"lightning":
			_lightning(a, atk, dmg)
		"dash":
			var flat := Vector3(a.aim_dir(a.chest()).x, 0, a.aim_dir(a.chest()).z).normalized()
			if flat.length() < 0.1:
				flat = a.forward()
			a.dash_t = 0.28
			a.dash_hit.clear()
			a.set_meta("dash_damage", dmg)
			var style := str(atk.get("style", "charge"))
			a.velocity = flat * float(p(atk, "distance")) / 0.28
			if style == "pounce":
				a.velocity.y = 7.0
				a.model.play("kick", 0.3)
			elif style == "slingshot":
				a.velocity *= 1.5
				a.model.play("stretch", 0.3)
			else:
				a.model.play("shield" if a.def["look"].get("gear", {}).has("left_arm") else "punch", 0.3)
			a.face_dir = flat
			Sfx.play("whoosh", a.global_position, -2.0)
		"missiles":
			_missiles(a, 4, dmg, null)
		"telekinesis":
			_telekinesis(a, atk, dmg)
		"chain_lightning", "ground_spikes", "grab":
			Powers.fire(a, atk, dmg)


## Three-hit combos. The third hit of every combo is a finisher that launches,
## with hit-stop and camera shake. Styles change the animation and swing FX.
static func _melee(a: Actor, atk: Dictionary, dmg: float, element: String) -> void:
	var style := str(p(atk, "style"))
	var step := a.combo_step
	a.combo_step = (a.combo_step + 1) % 3
	a.combo_window = 0.9
	var finisher := step == 2
	if style == "flurry":
		finisher = a.flurry_count % 8 == 7
		a.flurry_count += 1
	var reach := float(p(atk, "range")) * a.size * (0.5 if a.shrunk else 1.0)
	if a.shrunk:
		dmg *= 1.4
	var speed_now := Vector3(a.velocity.x, 0, a.velocity.z).length()
	if style == "momentum":
		# Kid Flash / the Flash of Earth-90: the faster you run, the harder it lands.
		dmg *= 1.0 + speed_now / 16.0
		finisher = finisher or speed_now > 25.0
	if finisher:
		dmg *= 1.6
	# Animation
	var anim := "punch"
	var anim_len := 0.24
	match style:
		"kick":
			anim = ["punch", "kick", "spin_kick"][step]
		"staff":
			anim = "staff" if step < 2 else "spin_kick"
		"blade", "mace":
			anim = "blade" if step < 2 else "spin_kick"
			anim_len = 0.28
		"heavy":
			anim = "heavy"
			anim_len = 0.42
		"heavy_punch":
			anim = ["punch", "punch", "heavy"][step]
			anim_len = 0.26 if step < 2 else 0.4
		"flurry":
			anim = "flurry"
			anim_len = 0.16
		"claw":
			anim = "claw" if step < 2 else "spin_kick"
		"stretch":
			anim = "stretch"
			anim_len = 0.3
			a.model.set_stretch(3.2)
			a.stretch_t = 0.25
		"shield_bash":
			anim = "shield"
		"momentum":
			anim = "uppercut" if finisher else "punch"
			anim_len = 0.22
		"phase":
			anim = "claw"
			anim_len = 0.2
		_:
			anim = ["punch", "punch", "uppercut"][step]
	a.model.play(anim, anim_len, step)
	var fwd := a.forward()
	var targets := a.get_tree().get_nodes_in_group("actors")
	# Player assist: lunge at the nearest enemy in front.
	if a.is_player and style != "stretch":
		var best: Actor = null
		var best_d := 7.0 * a.size
		for o in targets:
			if not a.can_hurt(o) or o.team == "civilian":
				continue
			var to: Vector3 = o.global_position - a.global_position
			var d := to.length()
			if d < best_d and d > reach * 0.8 and fwd.dot(to.normalized()) > 0.5:
				best = o
				best_d = d
		if best:
			var lunge: Vector3 = (best.global_position - a.global_position)
			lunge.y = 0
			a.velocity = lunge.normalized() * 16.0 + Vector3.UP * minf(4.0, maxf(0.0, best.global_position.y - a.global_position.y) * 3.0)
	var hits := 0
	for o in targets:
		if not a.can_hurt(o):
			continue
		var to: Vector3 = o.global_position - a.global_position
		var flat := Vector3(to.x, 0, to.z)
		if absf(to.y) > 2.2 * a.size + 1.0:
			continue
		var d := flat.length()
		if d > reach + o.capsule.radius + 0.5:
			continue
		if d > 0.8 and fwd.dot(flat.normalized()) < 0.2:
			continue
		var dir := flat.normalized() if d > 0.01 else fwd
		var knock := dir * (4.0 + dmg * 0.4) + Vector3.UP * (2.0 + dmg * 0.15)
		if finisher:
			knock = dir * (10.0 + dmg * 0.5) + Vector3.UP * (9.0 + dmg * 0.12)
		if style == "phase":
			# Reverse-Flash: a vibrating hand passes straight through shields.
			o.invuln_t = 0.0
			o.shield_t = 0.0
			o.field_t = 0.0
			o.stun_t = maxf(o.stun_t, 0.45)
		o.take_damage(dmg, a, element, knock)
		if style == "momentum" and speed_now > 20.0:
			FX.sonic_boom(a.world, o.chest(), fwd)
		if finisher and o.size < 1.6:
			o.model.tumble(14.0)
		FX.sparks(a.world, o.chest(), ELEMENT_COLORS.get(element, Color(1, 0.95, 0.8)), 8 if finisher else 5, 5.0, 0.25)
		FX.flash(a.world, o.chest(), Color(1, 1, 1), 0.6 if finisher else 0.35, 0.12, 0.6)
		hits += 1
	if _hit_props(a, a.global_position + fwd * reach * 0.7 + Vector3.UP, reach, dmg, fwd):
		hits = maxi(hits, 1)
	# Swing FX
	var arc_col := Color(1, 1, 1)
	if element != "":
		arc_col = ELEMENT_COLORS[element]
	match style:
		"blade", "mace", "claw", "staff":
			var c := a.global_position + Vector3.UP * 1.25 * a.size
			var tilt := Basis(Vector3.FORWARD, 0.35 if step % 2 == 0 else -0.35)
			FX.slash_arc(a.world, c, Basis(Vector3.UP, a.rotation.y) * tilt, arc_col if style != "claw" else Color("#cfe8ff"), reach + 0.6, -1.3, 1.3)
		"flurry":
			var col := Color(str(a.def["look"].get("trail", "#ffcc22")))
			FX.lightning(a.world, a.model.hand_point(1.0), a.model.hand_point(1.0) + fwd * reach, col, 0.1, 0.25, 3, 0)
	if finisher and hits > 0:
		Game.hit_stop(0.07)
		a.world.shake_at(a.global_position, 0.35)
		var fcol: Color = arc_col if element != "" else Color(str(a.def["look"].get("trail", "#ffffff")))
		FX.burst_lines(a.world, a.chest() + fwd * reach * 0.8, fcol.lightened(0.3), 2.5 * a.size, 10)
		if style in ["heavy", "heavy_punch"]:
			FX.ring(a.world, a.global_position + Vector3.UP * 0.2, Color("#e8d8b0"), 5.0 * a.size, 0.35)
	if hits > 0:
		a.combo_hit(hits)
	Sfx.play("punch" if hits > 0 else "whoosh", a.global_position, (0.0 if finisher else -3.0) if hits > 0 else -10.0)


static func _lightning(a: Actor, atk: Dictionary, dmg: float) -> void:
	var w = a.world
	var sky := str(atk.get("origin", "")) == "sky"
	var from := origin(a, atk) if not sky else a.chest()
	var dir := a.aim_dir(from)
	var reach := float(p(atk, "range"))
	var color := _color(atk)
	var best: Actor = null
	var best_score := 0.94
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o) or o.team == "civilian" and not a.is_player:
			continue
		var to: Vector3 = o.chest() - from
		if to.length() > reach:
			continue
		var score := dir.dot(to.normalized())
		if score > best_score:
			var los := ray(a, from, o.chest(), [a.get_rid(), o.get_rid()])
			if los.is_empty() or not (los["collider"] is StaticBody3D):
				best = o
				best_score = score
	var end := from + dir * reach
	if best:
		end = best.chest()
	else:
		var hit := attack_ray(a, from, end)
		if not hit.is_empty():
			end = hit["position"]
			_apply_hit(a, hit["collider"], dmg, "shock", dir * 4.0)
	if sky:
		# Weather Wizard calls the bolt down from a cloud above the target.
		var top := end + Vector3(randf_range(-2, 2), 30.0, randf_range(-2, 2))
		FX.storm_cloud(w, top, 5.0, 0.4)
		FX.lightning(w, top, end, color, 0.3, 1.6, 10, 2)
		FX.ring(w, end, color, 3.0, 0.3)
		w.shake_at(end, 0.25)
	else:
		FX.lightning(w, from, end, color, 0.22, 0.7, 8, 2)
	FX.sparks(w, end, color, 12, 7.0, 0.35)
	Sfx.play("lightning", from, -2.0)
	if best == null:
		return
	var chained: Array = [best]
	var current := best
	best.take_damage(dmg * (1.3 if sky else 1.0), a, "shock", dir * 5.0 + Vector3.UP * 2.0)
	a.combo_hit(1)
	for i in int(p(atk, "chain")):
		var next: Actor = null
		var nd := 12.0
		for o in a.get_tree().get_nodes_in_group("actors"):
			if chained.has(o) or not a.can_hurt(o) or o.team == "civilian":
				continue
			var d: float = o.global_position.distance_to(current.global_position)
			if d < nd:
				nd = d
				next = o
		if next == null:
			break
		FX.lightning(w, current.chest(), next.chest(), color, 0.2, 0.6, 5, 1)
		next.take_damage(dmg * 0.6, a, "shock", Vector3.UP * 3.0)
		chained.append(next)
		current = next


static func _apply_hit(a: Actor, col, dmg: float, element: String, knock: Vector3) -> void:
	if col is Actor and a.can_hurt(col):
		col.take_damage(dmg, a, element, knock)
		a.combo_hit(1)
		Sfx.play("hit", col.global_position, -6.0)
	elif col is Prop:
		col.hit(dmg, knock * 2.0, a)


## Continuous attacks while the button is held: beams (eyes, hands, a gun or
## staff), flamethrowers and breath.
static func held_tick(a: Actor, atk: Dictionary, delta: float, slot: String) -> void:
	if a.dampened_t > 0.0:
		return
	if not (a.is_player and Game.cheats["infinite_energy"]):
		a.energy -= float(p(atk, "energy")) * delta
	match atk["kind"]:
		"beam":
			_beam(a, atk, delta, slot)
		"flame", "breath":
			_stream(a, atk, delta)
	a.beam_sound_t -= delta
	if a.beam_sound_t <= 0.0:
		a.beam_sound_t = 0.2
		Sfx.play("fire" if atk["kind"] == "flame" else ("freeze" if atk.get("element", "") == "ice" else "beam"), a.global_position, -8.0, 0.02)


static func _beam(a: Actor, atk: Dictionary, delta: float, slot: String) -> void:
	var w = a.world
	var style := str(p(atk, "style"))
	var color := _color(atk)
	var origins: Array[Vector3] = []
	match style:
		"eyes":
			origins = a.model.eyes()
			a.model.play("eyes", 0.3)
			a.eye_glow_t = 0.15
		"muzzle", "cold":
			origins = [a.model.muzzle_point()]
			a.model.play("gun", 0.3)
		_:
			origins = [a.model.hand_point(-1.0), a.model.hand_point(1.0)]
			a.model.play("two_hands", 0.3)
	if origins.is_empty():
		origins = [a.head_pos()]
	var center := Vector3.ZERO
	for o in origins:
		center += o
	center /= origins.size()
	var dir := assist(a, center, a.aim_dir(center), float(p(atk, "range")))
	var end := center + dir * float(p(atk, "range"))
	var hit := attack_ray(a, center, end)
	if not hit.is_empty():
		end = hit["position"]
		var col = hit["collider"]
		var element := str(atk.get("element", ""))
		var dmg := float(p(atk, "damage")) * a.power * delta
		if col is Actor and a.can_hurt(col):
			col.take_damage(dmg, a, element if randf() < 0.2 else "", dir * 0.6)
		elif col is Prop:
			col.hit(dmg, dir * 2.0, a)
		if randf() < 0.6:
			FX.sparks(w, end, color, 3, 5.0, 0.3)
		if style == "cold" and randf() < 0.3:
			FX.flash(w, end, Color("#e8f8ff"), 0.6, 0.2, 0.5)
	while a.beams.size() < origins.size() * 2:
		a.beams.append(FX.make_line(w, color, 0.95))
	for i in a.beams.size():
		a.beams[i].visible = i < origins.size() * 2
	var flicker := randf() * 0.03
	for i in origins.size():
		var core: MeshInstance3D = a.beams[i * 2]
		var glow: MeshInstance3D = a.beams[i * 2 + 1]
		core.material_override = CharacterModel.mat(color.lightened(0.5), 0.0, true)
		glow.material_override = CharacterModel.mat(color, 0.0, true, 0.35)
		var width := 0.035 if style == "eyes" else 0.07
		FX.place_line(core, origins[i], end, width + flicker)
		FX.place_line(glow, origins[i], end, width * 3.2 + flicker)
	a.beam_slot = slot
	a.face_dir = Vector3(dir.x, 0, dir.z)


static func _stream(a: Actor, atk: Dictionary, delta: float) -> void:
	var element := str(atk.get("element", "fire" if atk["kind"] == "flame" else "ice"))
	var from := origin(a, atk)
	var dir := a.aim_dir(from)
	var reach := float(p(atk, "range"))
	var kind := "flame" if atk["kind"] == "flame" else ("wind" if element == "push" else "frost")
	if a.stream == null or a.stream.get_meta("kind", "") != kind:
		if a.stream:
			a.stream.queue_free()
		a.stream = FX.stream_emitter(kind)
		a.stream.set_meta("kind", kind)
		a.world.fx_root.add_child(a.stream)
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	a.stream.global_transform = Transform3D(Basis.looking_at(dir, up), from)
	a.stream.emitting = true
	a.stream_t = 0.12
	a.model.play("gun" if atk["kind"] == "flame" else "breath", 0.3)
	a.face_dir = Vector3(dir.x, 0, dir.z)
	var dmg := float(p(atk, "damage")) * a.power * delta
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o) or o.team == "civilian" and not a.is_player:
			continue
		var to: Vector3 = o.chest() - from
		var d := to.length()
		if d > reach or (d > 0.5 and dir.dot(to / d) < 0.82):
			continue
		if element == "push":
			o.velocity += dir * 60.0 * delta + Vector3.UP * 10.0 * delta
			o.take_damage(dmg * 0.4, a, "", Vector3.ZERO)
		else:
			o.take_damage(dmg, a, element if randf() < 0.25 else "", Vector3.ZERO)
	for prop in a.get_tree().get_nodes_in_group("props"):
		var to: Vector3 = prop.global_position - from
		if to.length() < reach and dir.dot(to.normalized()) > 0.82:
			prop.hit(dmg * 2.0, dir * (40.0 if element == "push" else 2.0) * delta * 60.0, a)


## Homing micro-missiles (the Atom, Lex Luthor's warsuit).
static func _missiles(a: Actor, count: int, dmg: float, targets) -> void:
	var foes: Array = targets if targets != null else _nearest_foes(a, 40.0, count)
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var from := a.chest() + a.global_transform.basis.x * side * 0.35 * a.size + Vector3.UP * 0.35 * a.size
		var dir := (a.aim_dir(from) + Vector3.UP * 0.35 + a.global_transform.basis.x * side * 0.25).normalized()
		var proj := Projectile.new()
		if not foes.is_empty():
			proj.homing = foes[i % foes.size()]
		proj.setup(a.world, a, from, dir * 34.0, dmg, "missile", Color("#ffaa33"), "", 2.2)
	Sfx.play("whoosh", a.global_position, -2.0)


static func _nearest_foes(a: Actor, radius: float, count: int) -> Array:
	var list := []
	for o in a.get_tree().get_nodes_in_group("actors"):
		if a.can_hurt(o) and o.team != "civilian" and o.global_position.distance_to(a.global_position) < radius:
			list.append(o)
	list.sort_custom(func(x, y): return x.global_position.distance_to(a.global_position) < y.global_position.distance_to(a.global_position))
	return list.slice(0, count)


## Damien Darhk / the Thinker: lift the target in a telekinetic grip, then fling it.
static func _telekinesis(a: Actor, atk: Dictionary, dmg: float) -> void:
	var from := a.head_pos()
	var dir := a.aim_dir(from)
	var best: Actor = null
	var best_dot := 0.9
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o):
			continue
		var to: Vector3 = o.chest() - from
		if to.length() > float(p(atk, "range")):
			continue
		var d := dir.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = o
	if best == null:
		FX.sonic_wave(a.world, from + dir, dir, _color(atk), 10.0)
		return
	best.lift_by(a, 1.4, dmg, _color(atk))
	Sfx.play("sonic", best.global_position, -2.0)


static func dash_tick(a: Actor) -> void:
	var dmg := float(a.get_meta("dash_damage", 15.0))
	for o in a.get_tree().get_nodes_in_group("actors"):
		if a.dash_hit.has(o) or not a.can_hurt(o):
			continue
		if o.global_position.distance_to(a.global_position) < 2.2 * a.size:
			a.dash_hit[o] = true
			var dir: Vector3 = (o.global_position - a.global_position).normalized()
			o.take_damage(dmg, a, "", dir * 14.0 + Vector3.UP * 7.0)
			Sfx.play("punch", o.global_position, -2.0)
	_hit_props(a, a.global_position + Vector3.UP, 2.5, dmg, a.velocity.normalized())


## Damages and knocks back everything `a` may hurt inside a sphere, or inside
## a cone when `cone_dir` is given. Civilians are spared unless a villain
## player is doing the damage.
static func area_damage(a: Actor, center: Vector3, radius: float, dmg: float, element: String,
		knock_out: float, knock_up: float, cone_dir := Vector3.ZERO, cone_dot := 0.0) -> int:
	var count := 0
	var spare_civilians := not (a.is_player and Game.player_side() == -1)
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o):
			continue
		if spare_civilians and o.team == "civilian":
			continue
		var to: Vector3 = o.chest() - center
		var d := to.length()
		if d > radius:
			continue
		if cone_dir != Vector3.ZERO and d > 1.0 and cone_dir.dot(to.normalized()) < cone_dot:
			continue
		var falloff := 1.0 - 0.5 * (d / radius)
		var flat := Vector3(to.x, 0, to.z).normalized()
		o.take_damage(dmg * falloff, a, element, flat * knock_out * falloff + Vector3.UP * knock_up)
		count += 1
	_hit_props(a, center, radius, dmg, cone_dir)
	return count


static func _hit_props(a: Actor, center: Vector3, radius: float, dmg: float, dir: Vector3) -> bool:
	var any := false
	for prop in a.get_tree().get_nodes_in_group("props"):
		if prop == a.held_prop:
			continue
		var to: Vector3 = prop.global_position - center
		if to.length() > radius + 1.0:
			continue
		var push := (to.normalized() if dir == Vector3.ZERO else dir.lerp(to.normalized(), 0.5).normalized())
		prop.hit(dmg, push * dmg * (2.0 if a.strength else 0.8) + Vector3.UP * dmg * 0.3, a)
		any = true
	return any


static func explode(world, pos: Vector3, radius: float, dmg: float, source: Actor, element := "", color := Color("#ffaa33")) -> void:
	var tree: SceneTree = world.get_tree()
	var spare_civilians := not (source != null and source.is_player and Game.player_side() == -1)
	for o in tree.get_nodes_in_group("actors"):
		if source != null and not source.can_hurt(o):
			continue
		if spare_civilians and source != null and source.is_player and o.team == "civilian":
			continue
		var to: Vector3 = o.chest() - pos
		var d := to.length()
		if d > radius:
			continue
		var falloff := 1.0 - 0.6 * (d / radius)
		o.take_damage(dmg * falloff, source, element, to.normalized() * 16.0 * falloff + Vector3.UP * 9.0)
	for prop in tree.get_nodes_in_group("props"):
		var to: Vector3 = prop.global_position - pos
		if to.length() < radius * 1.4:
			prop.hit(dmg * 0.8, to.normalized() * dmg * 3.0 + Vector3.UP * dmg * 2.0, source)
	FX.flash(world, pos, color, radius, 0.45, 0.8)
	FX.flash(world, pos, Color("#fff4c0"), radius * 0.5, 0.25, 0.9)
	FX.sparks(world, pos, color, 30, 14.0, 0.8)
	FX.smoke(world, pos, radius * 0.6, 1.8)
	Sfx.play("explosion", pos, 2.0)
	Game.report_combat(pos)
	world.shake_at(pos, 0.5)


# --- Specials ---------------------------------------------------------------

## How each special is performed: [pose, seconds, flourish]. The pose and
## flourish play on top of the power itself, so even powers that share a kind
## look like a move.
const SPECIAL_ANIM := {
	"time_slow": ["power_up", 0.6, "pillar"], "tornado": ["spin", 0.9, "shock"], "ground_slam": ["ground_pound", 0.7, "crack"],
	"nova": ["charge", 0.8, "burst"], "rage": ["power_up", 0.9, "burst"], "invisibility": ["levitate_cast", 0.5, ""],
	"invulnerable": ["power_up", 0.6, "shock"], "drain": ["levitate_cast", 0.8, "charge"], "t_spheres": ["summon", 0.6, "charge"],
	"animal_spirit": ["power_up", 0.8, "burst"], "force_field": ["palm_push", 0.5, "charge"], "storm": ["summon", 1.0, "pillar"],
	"dampen": ["stomp", 0.6, "shock"], "sonic_boom": ["charge", 0.4, "burst"], "speed_clones": ["power_up", 0.5, "burst"],
	"whirlwind": ["spin", 1.0, "shock"], "mirror_trap": ["palm_push", 0.5, "charge"], "hazard_field": ["stomp", 0.6, "crack"],
	"gravity_well": ["summon", 0.8, "charge"], "bat_swarm": ["palm_push", 0.5, ""], "lazarus": ["power_up", 1.0, "pillar"],
	"summon_goons": ["summon", 0.8, ""], "sleep": ["levitate_cast", 0.9, "shock"], "overload": ["charge", 0.8, "burst"],
	"construct": ["ring_raise", 0.8, "charge"], "miraclo": ["power_up", 1.0, "burst"], "shadows": ["levitate_cast", 0.9, ""],
	"ankh": ["levitate_cast", 1.0, "pillar"], "thunderbolt": ["summon", 1.0, "pillar"], "grow": ["power_up", 1.0, "crack"],
	"emp": ["stomp", 0.5, "shock"], "shrink": ["power_up", 0.3, ""], "phase": ["levitate_cast", 0.4, ""],
	"foresight": ["levitate_cast", 0.6, "charge"],
}


static func special(a: Actor, sp: Dictionary) -> bool:
	var ok := _special_impl(a, sp)
	if ok and a.world:
		flourish(a, str(sp["kind"]))
	return ok


## The pose and the extra flash of a power going off.
static func flourish(a: Actor, kind: String) -> void:
	if not SPECIAL_ANIM.has(kind):
		return
	var spec: Array = SPECIAL_ANIM[kind]
	var w = a.world
	var color := Color(str(a.def["look"].get("trail", a.def["look"].get("glow", a.def["look"]["accent"]))))
	if color.get_luminance() < 0.15:
		color = color.lightened(0.5)
	if spec[0] != "":
		a.model.play(str(spec[0]), float(spec[1]))
	match str(spec[2]):
		"pillar":
			FX.pillar(w, a.global_position, color, 30.0 * a.size, 1.6 * a.size)
		"shock":
			FX.shockwave(w, a.global_position, color, 7.0 * a.size)
		"crack":
			FX.shockwave(w, a.global_position, color, 9.0 * a.size)
			FX.ground_crack(w, a.global_position, color, 9.0 * a.size)
		"burst":
			FX.burst_lines(w, a.chest(), color.lightened(0.3), 3.5 * a.size, 14)
			FX.flash(w, a.chest(), color, 2.0 * a.size, 0.25, 0.5)
		"charge":
			FX.charge_up(a, color)
	if a.is_player and str(spec[2]) in ["crack", "pillar", "burst"]:
		w.shake_at(a.global_position, 0.25)


static func _special_impl(a: Actor, sp: Dictionary) -> bool:
	var w = a.world
	var color := Color(str(a.def["look"].get("trail", a.def["look"]["accent"])))
	match sp["kind"]:
		"time_slow":
			if a.is_player:
				if Game.slowmo_left > 0.0:
					Game.end_slowmo()
					return false
				Game.start_slowmo(5.0)
				Sfx.play("slowmo", null, -2.0)
				FX.flash(w, a.chest(), color, 4.0, 0.4, 0.4)
			else:
				a.tornado_t = 3.0
				FX.tornado(w, a, 3.0, color)
			return true
		"tornado":
			a.tornado_t = 4.0
			FX.tornado(w, a, 4.0, color)
			Sfx.play("whoosh", a.global_position, 4.0)
			return true
		"ground_slam":
			if not a.is_on_floor() and a.global_position.y > 2.0:
				a.flying = false
				a.slam_pending = true
				a.velocity = Vector3(0, -75.0, 0)
			else:
				ground_slam_impact(a)
			return true
		"smoke_bomb":
			FX.smoke(w, a.chest(), 8.0, 3.0)
			Sfx.play("smoke", a.global_position, 0.0)
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.global_position.distance_to(a.global_position) < 9.0:
					o.stun_t = maxf(o.stun_t, 2.5)
					o.grudges.erase(a.get_instance_id())
			a.invis_t = 3.5
			return true
		"nova":
			var element := str(sp.get("element", ""))
			var c: Color = ELEMENT_COLORS.get(element, color)
			area_damage(a, a.chest(), 12.0 * a.size, 26.0 * a.power, element, 18.0, 8.0)
			FX.flash(w, a.chest(), c, 12.0 * a.size, 0.5, 0.55)
			FX.ring(w, a.global_position + Vector3.UP * 0.3, c, 12.0 * a.size, 0.5)
			FX.sparks(w, a.chest(), c, 40, 18.0, 0.7)
			Sfx.play("freeze" if element == "ice" else ("fire" if element == "fire" else "lightning"), a.global_position, 4.0)
			w.shake_at(a.global_position, 0.35)
			return true
		"sonic_scream":
			var origin := a.head_pos()
			var dir := a.aim_dir(origin)
			area_damage(a, origin, 28.0, 22.0 * a.power, "", 38.0, 9.0, dir, 0.55)
			FX.sonic_wave(w, origin + dir, dir, Color("#dfe8ff"), 28.0)
			FX.sonic_wave(w, origin + dir * 6.0, dir, Color("#ffffff"), 22.0)
			Sfx.play("sonic", origin, 6.0)
			w.shake_at(origin, 0.3)
			return true
		"rage":
			a.rage_t = 8.0
			FX.flash(w, a.chest(), Color("#ff3030"), 3.0, 0.5, 0.5)
			Sfx.play("slam", a.global_position, -4.0)
			if a.is_player:
				w.notify("%s: damage and speed up!" % describe(sp), Color("#ff6060"))
			return true
		"shrink":
			a.set_shrunk(not a.shrunk)
			FX.sparks(w, a.chest(), Color("#4fc3ff"), 20, 4.0)
			Sfx.play("teleport", a.global_position, -6.0)
			return true
		"invisibility":
			a.invis_t = 8.0
			FX.flash(w, a.chest(), Color("#9fd6ff"), 2.0, 0.4, 0.4)
			for o in a.get_tree().get_nodes_in_group("actors"):
				o.grudges.erase(a.get_instance_id())
			return true
		"invulnerable":
			a.invuln_t = 6.0
			FX.flash(w, a.chest(), Color("#c8d0d8"), 2.0, 0.4, 0.6)
			Sfx.play("slam", a.global_position, -8.0)
			return true
		"teleport":
			var origin := a.head_pos()
			var dir := a.aim_dir(origin)
			var hit := ray(a, origin, origin + dir * 70.0, [a.get_rid()])
			var target: Vector3 = origin + dir * 70.0
			if not hit.is_empty():
				target = hit["position"] - dir * 1.5 + hit["normal"] * 0.5
			target.y = maxf(target.y - 1.0, 0.2)
			var breach_col := Color("#4fa8ff") if a.def.get("id", "") != "dreamer" else Color("#b8e6ff")
			FX.breach(w, a.chest(), breach_col, 0.8)
			a.global_position = target
			a.velocity = Vector3.ZERO
			FX.breach(w, a.chest(), breach_col, 0.8)
			Sfx.play("teleport", target, 0.0)
			return true
		"drain":
			var total := 0.0
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.team != "civilian" and o.global_position.distance_to(a.global_position) < 11.0:
					o.take_damage(18.0 * a.power, a, "", Vector3.UP * 3.0)
					FX.lightning(w, o.chest(), a.chest(), Color("#9b4dff"), 0.4, 0.4, 6)
					total += 18.0
			a.heal(total * 0.8 + 10.0)
			FX.flash(w, a.chest(), Color("#9b4dff"), 3.0, 0.5, 0.5)
			Sfx.play("sonic", a.global_position, -4.0)
			return true
		"arrow_storm", "boomerang_storm":
			var boomer: bool = sp["kind"] == "boomerang_storm"
			var foes := _nearest_foes(a, 35.0, 8)
			for i in 8:
				var from := a.chest() + Vector3.UP * 0.3
				var dir: Vector3
				if not foes.is_empty():
					dir = (foes[i % foes.size()].chest() - from).normalized()
				else:
					dir = (a.forward() + a.global_transform.basis.x * (i - 3.5) * 0.12 + Vector3.UP * 0.05).normalized()
				var proj := Projectile.new()
				proj.returns = boomer
				proj.setup(w, a, from, dir * (60.0 if boomer else 90.0), 16.0 * a.power, "boomerang" if boomer else "arrow", Color("#d8d8d8"), "", 0.0)
			a.model.play("throw" if boomer else "bow", 0.6)
			Sfx.play("arrow", a.global_position, 2.0)
			return true
		"frag_grenade":
			var from := a.hand_pos()
			var dir := (a.aim_dir(from) + Vector3.UP * 0.35).normalized()
			var proj := Projectile.new()
			proj.fuse = 1.3
			var flashbang: bool = a.def["look"]["extras"].has("mask_hockey")
			proj.setup(w, a, from, dir * 24.0, 40.0 * a.power, "grenade", Color("#ffffff") if flashbang else Color("#ffaa33"), "shock" if flashbang else "", 6.5)
			a.model.play("throw", 0.4)
			return true
		"t_spheres":
			a.t_spheres_t = 14.0
			FX.flash(w, a.chest(), Color("#ff4040"), 1.5, 0.3, 0.5)
			Sfx.play("teleport", a.global_position, -4.0)
			return true
		"animal_spirit":
			a.rage_t = 9.0
			a.invuln_t = maxf(a.invuln_t, 2.0)
			FX.aura(a, Color("#ffb23a"), a.size, 9.0)
			Sfx.play("slam", a.global_position, -2.0)
			if a.is_player:
				w.notify("The spirit of the gorilla flows through you!", Color("#ffb23a"))
			return true
		"shield_wall":
			a.shield_t = 5.0
			a.model.play("shield", 5.0)
			area_damage(a, a.chest(), 6.0, 15.0 * a.power, "", 24.0, 5.0, a.forward(), 0.4)
			FX.ring(w, a.chest() + a.forward(), Color("#cfd8e0"), 3.0, 0.35, a.forward())
			Sfx.play("slam", a.global_position, -2.0)
			return true
		"force_field":
			a.field_t = 6.0
			FX.bubble(a, Color("#5ce07a"), a.size, 6.0)
			Sfx.play("teleport", a.global_position, -4.0)
			return true
		"storm":
			a.storm_t = 6.0
			FX.storm_cloud(w, a.global_position + Vector3.UP * 32.0, 18.0, 6.0)
			w.shake_at(a.global_position, 0.3)
			Sfx.play("lightning", a.global_position, 4.0)
			return true
		"missile_barrage":
			_missiles(a, 12, 14.0 * a.power, null)
			a.model.play("cast_up", 0.6)
			return true
		"dampen":
			FX.ring(w, a.global_position + Vector3.UP * 0.5, Color("#ff3a2a"), 15.0, 0.6)
			FX.flash(w, a.chest(), Color("#ff3a2a"), 4.0, 0.4, 0.4)
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.global_position.distance_to(a.global_position) < 15.0:
					o.dampened_t = 6.0
					o.take_damage(15.0 * a.power, a, "shock", Vector3.UP * 3.0)
					if o.is_player:
						w.notify("Your powers are dampened!", Color("#ff6040"))
			Sfx.play("lightning", a.global_position, 2.0)
			return true
		"mind_control":
			var count := 0
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and not o.is_player and o.team != "civilian" and o.global_position.distance_to(a.global_position) < 18.0:
					o.mind_control(a, 12.0)
					FX.lightning(w, a.head_pos(), o.head_pos(), Color("#c47aff"), 0.4, 0.3, 6, 0)
					count += 1
			FX.sonic_wave(w, a.head_pos(), Vector3.UP, Color("#c47aff"), 18.0)
			a.model.play("temples", 1.0)
			if a.is_player:
				w.notify("%d minds bend to your will." % count, Color("#c47aff"))
			Sfx.play("sonic", a.global_position, 2.0)
			return true
		"breath":
			a.breath_t = 2.2
			a.breath_spec = {"kind": "breath", "element": str(sp.get("element", "ice")), "damage": 30.0, "range": 16.0, "energy": 0.0}
			return true
	if sp["kind"] in Powers.SPECIALS:
		return Powers.special(a, sp)
	return utility(a, sp)


## E-key powers. Shares the special() cooldown table but has its own slot.
static func utility(a: Actor, sp: Dictionary) -> bool:
	var w = a.world
	match sp["kind"]:
		"grapple":
			if a.grapple_point != null:
				a._release_grapple()
			else:
				fire_grapple(a)
			return true
		"blitz":
			var foes := _nearest_foes(a, 38.0, 7)
			if foes.is_empty():
				return false
			a.blitz_queue = foes
			a.blitz_t = 0.0
			a.invuln_t = maxf(a.invuln_t, 0.8)
			Sfx.play("zap", a.global_position, 2.0)
			return true
		"dodge_flip":
			a.velocity = -a.forward() * 12.0 + Vector3.UP * 8.0
			a.invuln_t = maxf(a.invuln_t, 0.5)
			a.model.tumble(-14.0)
			Sfx.play("whoosh", a.global_position, -2.0)
			return true
		"emp":
			FX.ring(w, a.global_position + Vector3.UP * 0.5, Color("#ff4040"), 12.0, 0.4)
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.global_position.distance_to(a.global_position) < 12.0:
					o.stun_t = maxf(o.stun_t, 2.5)
					FX.stun_stars(o, 2.0 * o.size, 2.5)
			for car in a.get_tree().get_nodes_in_group("traffic"):
				if car.global_position.distance_to(a.global_position) < 20.0:
					car.stop_driving()
			Sfx.play("lightning", a.global_position, 0.0)
			return true
		"foresight":
			a.invuln_t = maxf(a.invuln_t, 5.0)
			a.eye_glow_t = 5.0
			FX.aura(a, Color("#8fd8ff"), a.size, 5.0)
			if a.is_player:
				w.notify("You dream a few seconds ahead...", Color("#8fd8ff"))
			return true
		"ice_wall":
			_ice_wall(a)
			return true
		"force_field":
			a.field_t = 5.0
			FX.bubble(a, Color(str(a.def["look"].get("glow", "#5ce07a"))), a.size, 5.0)
			Sfx.play("teleport", a.global_position, -4.0)
			return true
		"phase":
			a.phase_t = 3.5
			a.invuln_t = maxf(a.invuln_t, 3.5)
			FX.flash(w, a.chest(), Color("#9fd6ff"), 2.0, 0.3, 0.4)
			Sfx.play("teleport", a.global_position, -4.0)
			return true
	return false


## Killer Frost raises a wall of ice that blocks shots and freezes anyone caught in it.
static func _ice_wall(a: Actor) -> void:
	var w = a.world
	var center := a.global_position + a.forward() * 5.0
	var wall := StaticBody3D.new()
	wall.collision_layer = Game.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 4.0, 1.2)
	cs.shape = box
	cs.position = Vector3(0, 2.0, 0)
	wall.add_child(cs)
	var m := CharacterModel.mat(Color("#bfeaff"), 0.25, false, 0.7)
	for i in 14:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.35, 0.7)
		cm.height = randf_range(2.5, 4.6)
		cm.radial_segments = 5
		mi.mesh = cm
		mi.material_override = m
		mi.position = Vector3(randf_range(-3.3, 3.3), cm.height * 0.45, randf_range(-0.4, 0.4))
		mi.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
		wall.add_child(mi)
	w.fx_root.add_child(wall)
	wall.global_position = Vector3(center.x, a.global_position.y - 0.3, center.z)
	wall.rotation.y = a.rotation.y
	for o in a.get_tree().get_nodes_in_group("actors"):
		if a.can_hurt(o) and o.global_position.distance_to(center) < 4.5:
			o.take_damage(18.0 * a.power, a, "ice", Vector3.UP * 4.0)
	FX.sparks(w, center + Vector3.UP, Color("#e8f8ff"), 30, 8.0, 0.6)
	Sfx.play("freeze", center, 4.0)
	var t := wall.create_tween()
	t.tween_interval(10.0)
	t.tween_property(wall, "scale", Vector3(1, 0.01, 1), 0.6)
	t.tween_callback(wall.queue_free)


## One step of a speedster's Blitz: zip to the next enemy and hit it.
static func blitz_step(a: Actor) -> void:
	while not a.blitz_queue.is_empty() and (not is_instance_valid(a.blitz_queue[0]) or a.blitz_queue[0].dead):
		a.blitz_queue.pop_front()
	if a.blitz_queue.is_empty():
		return
	var o: Actor = a.blitz_queue.pop_front()
	var col := Color(str(a.def["look"].get("trail", "#ffcc22")))
	var from := a.chest()
	var dir: Vector3 = (o.global_position - a.global_position)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else a.forward()
	a.global_position = o.global_position - dir * 1.3
	a.face_dir = dir
	FX.lightning(a.world, from, a.chest(), col, 0.35, 0.5, 8, 1)
	o.take_damage(20.0 * a.power, a, "shock", dir * 12.0 + Vector3.UP * 8.0)
	o.model.tumble(12.0)
	a.model.play("punch", 0.12, randi() % 2)
	a.combo_hit(1)
	Sfx.play("punch", o.global_position, 0.0)


static func storm_tick(a: Actor) -> void:
	var foes := _nearest_foes(a, 35.0, 6)
	if foes.is_empty():
		return
	var o: Actor = foes[randi() % foes.size()]
	var top := o.global_position + Vector3(randf_range(-3, 3), 30.0, randf_range(-3, 3))
	FX.lightning(a.world, top, o.chest(), Color("#d6e6ff"), 0.3, 1.5, 10, 2)
	o.take_damage(16.0 * a.power, a, "shock", Vector3.UP * 4.0)
	Sfx.play("lightning", o.global_position, 0.0)


static func t_sphere_tick(a: Actor) -> void:
	var foes := _nearest_foes(a, 25.0, 1)
	if foes.is_empty():
		return
	var from := a.chest() + Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1))
	var proj := Projectile.new()
	proj.setup(a.world, a, from, (foes[0].chest() - from).normalized() * 50.0, 9.0 * a.power, "tsphere", Color("#ff4040"), "shock", 0.0)


static func tornado_tick(a: Actor, delta: float) -> void:
	var center := a.global_position
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o) or o.team == "civilian" and not (a.is_player and Game.player_side() == -1):
			continue
		var to: Vector3 = o.global_position - center
		var d := Vector3(to.x, 0, to.z).length()
		if d > 14.0 or d < 0.1:
			continue
		var tangent := Vector3(-to.z, 0, to.x).normalized()
		var inward := -Vector3(to.x, 0, to.z).normalized()
		o.velocity = o.velocity.lerp(tangent * 18.0 + inward * 6.0 + Vector3.UP * 7.0, clampf(delta * 4.0, 0.0, 1.0))
		o.take_damage(9.0 * delta, a, "", Vector3.ZERO)
	for prop in a.get_tree().get_nodes_in_group("props"):
		var to: Vector3 = prop.global_position - center
		if to.length() < 12.0:
			prop.apply_central_force(Vector3(-to.z, 0, to.x).normalized() * prop.mass * 25.0 + Vector3.UP * prop.mass * 30.0)


static func ground_slam_impact(a: Actor) -> void:
	var w = a.world
	var center := a.global_position + Vector3.UP * 0.5
	area_damage(a, center, 10.0 * a.size, 35.0 * a.power, "", 22.0, 13.0)
	FX.ring(w, a.global_position + Vector3.UP * 0.2, Color("#e8d8b0"), 11.0 * a.size, 0.5)
	FX.ring(w, a.global_position + Vector3.UP * 0.2, Color("#ffffff"), 6.0 * a.size, 0.35)
	FX.smoke(w, a.global_position, 3.0 * a.size, 1.2)
	FX.sparks(w, a.global_position, Color("#c8b890"), 30, 12.0, 0.8)
	Sfx.play("slam", a.global_position, 6.0)
	w.shake_at(a.global_position, 0.8)


# --- Grapple and carrying ---------------------------------------------------

static func fire_grapple(a: Actor) -> void:
	var from := a.hand_pos()
	var dir := a.aim_dir(from)
	var hit := ray(a, from, from + dir * 150.0, [a.get_rid()])
	if hit.is_empty() or not (hit["collider"] is StaticBody3D):
		Sfx.play("whoosh", from, -8.0)
		return
	a.grapple_point = hit["position"] + hit["normal"] * 0.6
	a.grapple_line = FX.make_line(a.world, Color("#2a2a2a"))
	a.flying = false
	Sfx.play("arrow", from, -2.0)


static func pick_up(a: Actor) -> void:
	var best: Prop = null
	var best_d := 5.0 * a.size
	for prop in a.get_tree().get_nodes_in_group("props"):
		var d: float = prop.global_position.distance_to(a.global_position)
		if d < best_d:
			best = prop
			best_d = d
	if best == null:
		return
	a.held_prop = best
	best.pick_up(a)
	Sfx.play("whoosh", a.global_position, -4.0)


static func throw_prop(a: Actor) -> void:
	var prop: Prop = a.held_prop
	a.held_prop = null
	if not is_instance_valid(prop):
		return
	var dir := a.aim_dir(prop.global_position)
	prop.throw_from(a, dir * 42.0 + Vector3.UP * 3.0)
	a.model.punch()
	Sfx.play("whoosh", a.global_position, 0.0)


static func drop_prop(a: Actor) -> void:
	var prop: Prop = a.held_prop
	a.held_prop = null
	if is_instance_valid(prop):
		prop.throw_from(a, Vector3.ZERO)
