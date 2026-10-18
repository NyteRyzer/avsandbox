class_name Abilities
extends RefCounted
## Every attack and special power in the game. Characters reference these by
## "kind" in data/roster.json; per-character fields (damage, color, element,
## range...) override the defaults below.

const ATTACK_DEFAULTS := {
	"melee": {"damage": 12.0, "cooldown": 0.36, "energy": 0.0, "range": 2.4, "element": ""},
	"arrow": {"damage": 22.0, "cooldown": 0.5, "energy": 0.0, "speed": 90.0, "color": "#c9b38a"},
	"explosive_arrow": {"damage": 32.0, "cooldown": 1.2, "energy": 18.0, "speed": 70.0, "radius": 5.5, "color": "#ffaa33"},
	"throw": {"damage": 15.0, "cooldown": 0.42, "energy": 0.0, "speed": 65.0, "color": "#d0d0d0"},
	"bolt": {"damage": 16.0, "cooldown": 0.3, "energy": 7.0, "speed": 55.0, "color": "#ffffff"},
	"beam": {"damage": 55.0, "cooldown": 0.0, "energy": 22.0, "range": 90.0, "color": "#ff3322"},
	"sonic": {"damage": 10.0, "cooldown": 0.9, "energy": 16.0, "range": 15.0, "knock": 22.0, "color": "#dfe8ff"},
	"lightning": {"damage": 22.0, "cooldown": 0.6, "energy": 12.0, "range": 55.0, "chain": 2, "color": "#8fd0ff"},
	"gun": {"damage": 7.0, "cooldown": 0.16, "energy": 0.0, "range": 140.0},
	"dash": {"damage": 18.0, "cooldown": 1.0, "energy": 12.0, "distance": 12.0},
}

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
}

const ELEMENT_COLORS := {"fire": Color("#ff7a1a"), "ice": Color("#a8e8ff"), "shock": Color("#9fd0ff"), "": Color("#ffffff")}


static func p(atk: Dictionary, key: String):
	if atk.has(key):
		return atk[key]
	return ATTACK_DEFAULTS[atk["kind"]].get(key, 0.0)


static func energy_cost(atk: Dictionary) -> float:
	return float(p(atk, "energy"))


static func cooldown(atk: Dictionary) -> float:
	return float(p(atk, "cooldown"))


static func special_cost(sp: Dictionary) -> float:
	return float(sp.get("energy", SPECIAL_DEFAULTS[sp["kind"]]["energy"]))


static func special_cooldown(sp: Dictionary) -> float:
	return float(sp.get("cooldown", SPECIAL_DEFAULTS[sp["kind"]]["cooldown"]))


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


# --- Attacks ----------------------------------------------------------------

static func fire(a: Actor, atk: Dictionary) -> void:
	var w = a.world
	var kind: String = atk["kind"]
	var dmg := float(p(atk, "damage")) * a.power
	var element := str(atk.get("element", ""))
	match kind:
		"melee":
			_melee(a, atk, dmg, element)
		"arrow", "explosive_arrow", "throw", "bolt":
			a.model.aim()
			var from := a.hand_pos()
			var dir := a.aim_dir(from)
			var style := "bolt"
			if kind == "arrow" or kind == "explosive_arrow":
				style = "arrow" if a.def["look"]["extras"].has("bow") else "throw"
			elif kind == "throw":
				style = "throw"
			var radius := float(p(atk, "radius")) if kind == "explosive_arrow" else 0.0
			var proj := Projectile.new()
			proj.setup(w, a, from, dir * float(p(atk, "speed")), dmg, style, _color(atk), element, radius)
			Sfx.play("zap" if kind == "bolt" else "arrow", from, -4.0)
		"gun":
			a.model.aim()
			var from := a.hand_pos()
			var dir := (a.aim_dir(from) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.015).normalized()
			var end := from + dir * float(p(atk, "range"))
			var hit := attack_ray(a, from, end)
			if not hit.is_empty():
				end = hit["position"]
				_apply_hit(a, hit["collider"], dmg, element, dir * 3.0)
			FX.line(w, from, end, Color("#fff0a0"), 0.025, 0.05)
			FX.sparks(w, end, Color("#ffd080"), 4, 3.0, 0.2)
			Sfx.play("gun", from, -6.0)
		"sonic":
			var reach := float(p(atk, "range"))
			var origin := a.head_pos()
			var dir := a.aim_dir(origin)
			area_damage(a, origin, reach, dmg, element, float(p(atk, "knock")), 5.0, dir, 0.75)
			FX.sonic_wave(w, origin + dir, dir, _color(atk), reach)
			Sfx.play("sonic", origin, -2.0)
			a.model.aim()
		"lightning":
			_lightning(a, atk, dmg)
		"dash":
			var flat := Vector3(a.aim_dir(a.chest()).x, 0, a.aim_dir(a.chest()).z).normalized()
			if flat.length() < 0.1:
				flat = a.forward()
			a.dash_t = 0.28
			a.dash_hit.clear()
			a.set_meta("dash_damage", dmg)
			a.velocity = flat * float(p(atk, "distance")) / 0.28
			a.face_dir = flat
			Sfx.play("whoosh", a.global_position, -2.0)


static func _melee(a: Actor, atk: Dictionary, dmg: float, element: String) -> void:
	a.model.punch()
	var reach := float(p(atk, "range")) * a.size * (0.5 if a.shrunk else 1.0)
	if a.shrunk:
		dmg *= 1.4
	var fwd := a.forward()
	var hit_any := false
	var targets := a.get_tree().get_nodes_in_group("actors")
	# Player assist: lunge at the nearest enemy in front.
	if a.is_player:
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
		o.take_damage(dmg, a, element, knock)
		FX.sparks(a.world, o.chest(), ELEMENT_COLORS.get(element, Color.WHITE), 6, 4.0, 0.25)
		hit_any = true
	if _hit_props(a, a.global_position + fwd * reach * 0.7 + Vector3.UP, reach, dmg, fwd):
		hit_any = true
	Sfx.play("punch" if hit_any else "whoosh", a.global_position, -3.0 if hit_any else -10.0)


static func _lightning(a: Actor, atk: Dictionary, dmg: float) -> void:
	var w = a.world
	var from := a.hand_pos()
	var dir := a.aim_dir(from)
	var reach := float(p(atk, "range"))
	var color := _color(atk)
	a.model.aim()
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
	FX.lightning(w, from, end, color, 0.22, 0.8, 8)
	FX.sparks(w, end, color, 10, 6.0, 0.3)
	Sfx.play("lightning", from, -2.0)
	if best == null:
		return
	var chained: Array = [best]
	var current := best
	best.take_damage(dmg, a, "shock", dir * 5.0 + Vector3.UP * 2.0)
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
		FX.lightning(w, current.chest(), next.chest(), color, 0.2, 0.6, 5)
		next.take_damage(dmg * 0.6, a, "shock", Vector3.UP * 3.0)
		chained.append(next)
		current = next


static func _apply_hit(a: Actor, col, dmg: float, element: String, knock: Vector3) -> void:
	if col is Actor and a.can_hurt(col):
		col.take_damage(dmg, a, element, knock)
		Sfx.play("hit", col.global_position, -6.0)
	elif col is Prop:
		col.hit(dmg, knock * 2.0, a)


static func beam_tick(a: Actor, atk: Dictionary, delta: float, slot: String) -> void:
	var w = a.world
	if not (a.is_player and Game.cheats["infinite_energy"]):
		a.energy -= float(p(atk, "energy")) * delta
	var from := a.head_pos() + a.forward() * 0.15 * a.size
	var dir := a.aim_dir(from)
	var reach := float(p(atk, "range"))
	var end := from + dir * reach
	var hit := attack_ray(a, from, end)
	var color := _color(atk)
	if a.beam_mesh == null or not is_instance_valid(a.beam_mesh):
		a.beam_mesh = FX.make_line(w, color, 0.9)
	a.beam_mesh.set_meta("slot", slot)
	if not hit.is_empty():
		end = hit["position"]
		var col = hit["collider"]
		var element := str(atk.get("element", ""))
		if col is Actor and a.can_hurt(col):
			col.take_damage(float(p(atk, "damage")) * a.power * delta, a, element if randf() < 0.15 else "", dir * 0.6)
		elif col is Prop:
			col.hit(float(p(atk, "damage")) * a.power * delta, dir * 2.0, a)
		if randf() < 0.5:
			FX.sparks(w, end, color, 2, 5.0, 0.3)
	FX.place_line(a.beam_mesh, from, end, 0.09 + randf() * 0.04)
	a.model.aim()
	a.face_dir = Vector3(dir.x, 0, dir.z)
	a.beam_sound_t -= delta
	if a.beam_sound_t <= 0.0:
		a.beam_sound_t = 0.2
		Sfx.play("beam", from, -8.0, 0.02)


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

static func special(a: Actor, sp: Dictionary) -> bool:
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
			FX.portal(w, a.chest(), Color("#4fa8ff"))
			a.global_position = target
			a.velocity = Vector3.ZERO
			FX.portal(w, a.chest(), Color("#4fa8ff"))
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
	return false


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
