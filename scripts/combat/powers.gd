class_name Powers
extends RefCounted
## The second generation of powers, so characters that share an archetype
## still play differently: chain lightning, momentum punches, phasing
## strikes, trick arrows, ice spikes, stretchy grabs, sonic booms, speed
## clones, whirlwinds, shapeshifting, mirror traps, hazard fields, meteor
## dives, gravity wells, bat swarms, Lazarus healing, goons, sleep and
## lightning overloads.

const ATTACKS := ["chain_lightning", "ground_spikes", "grab"]
const SPECIALS := ["sonic_boom", "speed_clones", "whirlwind", "shapeshift", "mirror_trap", "hazard_field",
	"meteor_dash", "gravity_well", "bat_swarm", "lazarus", "summon_goons", "sleep", "overload", "flashbang"]
const ATTACK_DEFAULTS := {
	"chain_lightning": {"damage": 16.0, "cooldown": 0.75, "energy": 14.0, "range": 40.0, "chain": 4, "color": "#ff6ad0"},
	"ground_spikes": {"damage": 20.0, "cooldown": 1.1, "energy": 16.0, "range": 14.0, "color": "#bfeaff", "element": "ice"},
	"grab": {"damage": 12.0, "cooldown": 1.6, "energy": 14.0, "range": 16.0, "color": "#e8a0a0"},
}
const SPECIAL_DEFAULTS := {
	"sonic_boom": {"energy": 35.0, "cooldown": 8.0},
	"speed_clones": {"energy": 50.0, "cooldown": 22.0},
	"whirlwind": {"energy": 35.0, "cooldown": 9.0},
	"shapeshift": {"energy": 40.0, "cooldown": 18.0},
	"mirror_trap": {"energy": 40.0, "cooldown": 12.0},
	"hazard_field": {"energy": 40.0, "cooldown": 12.0},
	"meteor_dash": {"energy": 30.0, "cooldown": 6.0},
	"gravity_well": {"energy": 45.0, "cooldown": 13.0},
	"bat_swarm": {"energy": 35.0, "cooldown": 11.0},
	"lazarus": {"energy": 60.0, "cooldown": 30.0},
	"summon_goons": {"energy": 50.0, "cooldown": 30.0},
	"sleep": {"energy": 50.0, "cooldown": 18.0},
	"overload": {"energy": 50.0, "cooldown": 12.0},
	"flashbang": {"energy": 25.0, "cooldown": 7.0},
}

const KRYPTONIANS := ["supergirl", "superman", "mon_el", "reign", "overgirl", "jordan_kent"]


static func _col(a: Actor, d: Dictionary, fallback: String) -> Color:
	if d.has("color"):
		return Color(str(d["color"]))
	return Color(str(a.def["look"].get("trail", fallback)))


## The foe nearest the crosshair within reach (or null).
static func aimed_foe(a: Actor, reach: float, cone := 0.85) -> Actor:
	var from := a.chest()
	var dir := a.aim_dir(from)
	var best: Actor = null
	var best_score := cone
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.can_hurt(o) or o.team == "civilian" and not a.is_player:
			continue
		var to: Vector3 = o.chest() - from
		if to.length() > reach:
			continue
		var s := dir.dot(to.normalized())
		if s > best_score:
			best_score = s
			best = o
	return best


static func ground_at(a: Actor, p: Vector3) -> Vector3:
	var hit := Abilities.ray(a, p + Vector3.UP * 3.0, p + Vector3.DOWN * 40.0, [a.get_rid()])
	return hit["position"] if not hit.is_empty() else Vector3(p.x, a.global_position.y, p.z)


static func aim_ground(a: Actor, reach: float) -> Vector3:
	var from := a.head_pos()
	var hit := Abilities.attack_ray(a, from, from + a.aim_dir(from) * reach)
	var p: Vector3 = hit["position"] if not hit.is_empty() else from + a.aim_dir(from) * reach
	return ground_at(a, p)


# --- Attacks -------------------------------------------------------------------

static func fire(a: Actor, atk: Dictionary, dmg: float) -> void:
	match str(atk["kind"]):
		"chain_lightning":
			_chain_lightning(a, atk, dmg)
		"ground_spikes":
			_ground_spikes(a, atk, dmg)
		"grab":
			_grab(a, atk, dmg)


## Bolts that jump from foe to foe, stunning each one for a moment.
static func _chain_lightning(a: Actor, atk: Dictionary, dmg: float) -> void:
	var w = a.world
	var color := _col(a, atk, "#ff6ad0")
	var from := Abilities.origin(a, atk)
	var first := aimed_foe(a, float(Abilities.p(atk, "range")), 0.9)
	if first == null:
		var end: Vector3 = from + a.aim_dir(from) * 25.0
		FX.lightning(w, from, end, color, 0.2, 0.8, 7, 2)
		Sfx.play("zap", from, -4.0)
		return
	var hit: Array = [first]
	var cur := first
	FX.lightning(w, from, first.chest(), color, 0.25, 0.7, 8, 2)
	first.take_damage(dmg, a, "shock", Vector3.UP * 3.0)
	first.stun_t = maxf(first.stun_t, 0.35)
	var n := int(Abilities.p(atk, "chain"))
	for i in n:
		var next: Actor = null
		var nd := 15.0
		for o in a.get_tree().get_nodes_in_group("actors"):
			if hit.has(o) or not a.can_hurt(o) or o.team == "civilian":
				continue
			var d: float = o.global_position.distance_to(cur.global_position)
			if d < nd:
				nd = d
				next = o
		if next == null:
			break
		FX.lightning(w, cur.chest(), next.chest(), color, 0.25, 0.6, 6, 1)
		next.take_damage(dmg * pow(0.85, i + 1), a, "shock", Vector3.UP * 3.0)
		next.stun_t = maxf(next.stun_t, 0.35)
		hit.append(next)
		cur = next
	a.combo_hit(hit.size())
	Sfx.play("lightning", from, -2.0)


## A line of spikes erupting from the ground toward the crosshair.
static func _ground_spikes(a: Actor, atk: Dictionary, dmg: float) -> void:
	var w = a.world
	var element := str(atk.get("element", "ice"))
	var color := _col(a, atk, "#bfeaff")
	var dir := a.aim_dir(a.chest())
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else a.forward()
	var m := CharacterModel.mat(color, 0.25 if element == "ice" else 0.0, false, 0.85 if element == "ice" else 1.0)
	var reach := float(Abilities.p(atk, "range"))
	var steps := int(reach / 2.2)
	for k in steps:
		var p := ground_at(a, a.global_position + dir * (2.0 + k * 2.2))
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.35, 0.6)
		cm.height = randf_range(1.6, 2.6)
		cm.radial_segments = 5
		spike.mesh = cm
		spike.material_override = m
		w.fx_root.add_child(spike)
		spike.global_position = p + Vector3.UP * cm.height * 0.4
		spike.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		spike.scale = Vector3(1, 0.05, 1)
		var t := spike.create_tween()
		t.tween_interval(k * 0.04)
		t.tween_property(spike, "scale", Vector3.ONE, 0.08)
		t.tween_interval(1.4)
		t.tween_property(spike, "scale", Vector3(1, 0.05, 1), 0.3)
		t.tween_callback(spike.queue_free)
		Abilities.area_damage(a, p + Vector3.UP, 1.8, dmg / 2.0, element, 4.0, 10.0)
	Sfx.play("freeze" if element == "ice" else "slam", a.global_position, 0.0)


## A stretching arm (or telekinetic lasso) that yanks a foe into reach.
static func _grab(a: Actor, atk: Dictionary, dmg: float) -> void:
	var w = a.world
	var o := aimed_foe(a, float(Abilities.p(atk, "range")), 0.9)
	var hand := a.model.hand_point(1.0)
	if o == null:
		FX.line(w, hand, hand + a.aim_dir(hand) * 10.0, _col(a, atk, "#e8a0a0"), 0.08, 0.15)
		return
	FX.line(w, hand, o.chest(), _col(a, atk, "#e8a0a0"), 0.1, 0.25)
	a.model.play("stretch", 0.3)
	a.model.set_stretch(2.6)
	a.stretch_t = 0.3
	o.global_position = a.global_position + a.forward() * 1.6 + Vector3.UP * 0.2
	o.velocity = Vector3.ZERO
	o.take_damage(dmg, a, "", Vector3.ZERO)
	o.stun_t = maxf(o.stun_t, 1.0)
	a.combo_hit(1)
	Sfx.play("whoosh", a.global_position, 0.0)


## Trick arrows and thrown weapons with an extra effect on hit.
static func on_projectile_hit(src: Actor, o: Actor, effect: String, color: Color) -> void:
	var w = o.world
	match effect:
		"net":
			o.root_t = maxf(o.root_t, 2.5)
			FX.ring(w, o.global_position + Vector3.UP * 0.6, Color("#c8c0a0"), 1.2, 1.0, Vector3.UP)
		"flash":
			o.stun_t = maxf(o.stun_t, 1.6)
			FX.flash(w, o.chest(), Color.WHITE, 3.0, 0.35, 0.9)
			FX.stun_stars(o, 2.0 * o.size, 1.6)
		"poison":
			o.poison_t = maxf(o.poison_t, 5.0)
			FX.sparks(w, o.chest(), Color("#6aff4a"), 8, 2.0, 0.5)
		"fire":
			o.burn_t = maxf(o.burn_t, 3.0)
		"freeze":
			o.frozen_t = maxf(o.frozen_t, 1.2)
		"drain":
			if src and is_instance_valid(src):
				src.heal(6.0)
				FX.line(w, o.chest(), src.chest(), color, 0.06, 0.2)


# --- Specials --------------------------------------------------------------------

static func special(a: Actor, sp: Dictionary) -> bool:
	var w = a.world
	var color := _col(a, sp, "#ffffff")
	match str(sp["kind"]):
		"sonic_boom":
			# Break the sound barrier in a straight line; everything in the way flies.
			var dir := a.aim_dir(a.chest())
			dir.y = 0
			dir = dir.normalized() if dir.length() > 0.1 else a.forward()
			var start := a.global_position
			var hit := Abilities.ray(a, start + Vector3.UP, start + Vector3.UP + dir * 32.0, [a.get_rid()])
			var dist := 32.0 if hit.is_empty() or not (hit["collider"] is StaticBody3D) else maxf(2.0, start.distance_to(hit["position"]) - 1.5)
			var end := start + dir * dist
			for k in 6:
				var p := start.lerp(end, (k + 0.5) / 6.0) + Vector3.UP
				Abilities.area_damage(a, p, 4.0, 18.0 * a.power, "push", 22.0, 12.0)
				FX.ring(w, p, color, 3.0, 0.3, dir)
			a.global_position = end
			a.velocity = dir * 30.0
			FX.lightning(w, start + Vector3.UP, end + Vector3.UP, color, 0.3, 0.8, 8, 2)
			FX.sonic_boom(w, end + Vector3.UP, dir)
			w.shake_at(end, 0.4)
			Sfx.play("sonic", end, 4.0)
			return true
		"speed_clones":
			var n := int(sp.get("count", 3))
			for k in n:
				var d: Dictionary = a.def.duplicate(true)
				d["health"] = float(d.get("health", 100)) * 0.35
				d["alias"] = str(sp.get("clone_name", "Speed Clone"))
				var ang := k * TAU / n
				var pos := a.global_position + Vector3(cos(ang), 0, sin(ang)) * 2.5
				var c: Actor = w.population.spawn_character(d, a.team, pos, a if a.is_player else a.follow_target)
				c.set_meta("pinned", true)
				c.brain.detect = 60.0
				if not a.is_player:
					c.follow_target = null
					c.grudges = a.grudges.duplicate()
				FX.lightning(w, a.chest(), c.chest(), color, 0.25, 0.4, 5, 0)
				var wr: WeakRef = weakref(c)
				var vanish := func() -> void:
					var ref = wr.get_ref()
					if ref and is_instance_valid(ref):
						FX.flash(ref.world, ref.chest(), color, 1.5, 0.3)
						ref.queue_free()
				w.get_tree().create_timer(float(sp.get("life", 14.0)), false).timeout.connect(vanish)
			Sfx.play("zap", a.global_position, 2.0)
			return true
		"whirlwind":
			a.whirl_t = float(sp.get("time", 2.4))
			a.set_meta("whirl_color", color)
			a.set_meta("whirl_element", str(sp.get("element", "push")))
			Sfx.play("whoosh", a.global_position, 4.0)
			return true
		"shapeshift":
			a.shapeshift(10.0)
			return true
		"mirror_trap":
			var o := aimed_foe(a, 30.0, 0.8)
			if o == null:
				return false
			trap(a, o, color, float(sp.get("time", 4.0)), 38.0 * a.power)
			return true
		"hazard_field":
			var center := aim_ground(a, 30.0)
			Hazard.spawn(a, center, str(sp.get("element", "fire")), color, float(sp.get("radius", 7.0)), float(sp.get("time", 8.0)))
			a.model.play("cast_up", 0.5)
			return true
		"meteor_dash":
			var o := aimed_foe(a, 45.0, 0.75)
			var target: Vector3 = o.chest() if o else a.chest() + a.aim_dir(a.chest()) * 25.0
			var dir := (target - a.chest()).normalized()
			a.dash_t = clampf(a.chest().distance_to(target) / 75.0, 0.15, 0.6)
			a.dash_hit.clear()
			a.set_meta("dash_damage", 40.0 * a.power)
			a.velocity = dir * 75.0
			a.face_dir = Vector3(dir.x, 0, dir.z).normalized()
			a.model.play("punch", 0.4)
			FX.flash(w, a.chest(), color, 2.0, 0.25)
			FX.lightning(w, a.chest(), target, color, 0.25, 0.3, 4, 0)
			Sfx.play("whoosh", a.global_position, 4.0)
			return true
		"gravity_well":
			var center := aim_ground(a, 40.0) + Vector3.UP * 1.5
			Hazard.spawn(a, center, "gravity", color, 14.0, 3.0)
			a.model.play("cast_up", 0.6)
			return true
		"bat_swarm":
			var origin := a.chest()
			var dir := a.aim_dir(origin)
			var bats := CPUParticles3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.35, 0.05, 0.18)
			bats.mesh = bm
			bats.material_override = CharacterModel.mat(color.darkened(0.6))
			bats.amount = 70
			bats.lifetime = 1.0
			bats.one_shot = true
			bats.explosiveness = 0.6
			bats.direction = dir
			bats.spread = 25.0
			bats.initial_velocity_min = 10.0
			bats.initial_velocity_max = 18.0
			bats.gravity = Vector3.ZERO
			bats.angular_velocity_min = -720.0
			bats.angular_velocity_max = 720.0
			bats.local_coords = false
			w.fx_root.add_child(bats)
			bats.global_position = origin
			bats.emitting = true
			w.get_tree().create_timer(1.6, false).timeout.connect(bats.queue_free)
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.team != "civilian":
					var to: Vector3 = o.chest() - origin
					if to.length() < 14.0 and dir.dot(to.normalized()) > 0.6:
						o.take_damage(10.0 * a.power, a, "", dir * 4.0)
						o.stun_t = maxf(o.stun_t, 2.2)
						FX.stun_stars(o, 2.0 * o.size, 2.2)
			Sfx.play("whoosh", origin, 4.0)
			return true
		"lazarus":
			a.heal(a.max_hp * 0.6)
			a.rage_t = maxf(a.rage_t, 6.0)
			a.burn_t = 0.0
			a.poison_t = 0.0
			a.frozen_t = 0.0
			FX.aura(a, Color("#6aff7a"), a.size * 1.3, 2.0)
			FX.flash(w, a.chest(), Color("#6aff7a"), 3.0, 0.5)
			Sfx.play("event", a.global_position, -2.0)
			return true
		"summon_goons":
			for k in int(sp.get("count", 3)):
				var d: Dictionary = w.population.thug_def(3)
				d["alias"] = str(sp.get("goon_name", "Goon"))
				var pos := a.global_position + Vector3(randf_range(-4, 4), 0.3, randf_range(-4, 4))
				var g: Actor = w.population.spawn_character(d, a.team, pos, a if a.is_player else null)
				g.set_meta("pinned", true)
				if not a.is_player:
					g.grudges = a.grudges.duplicate()
				var wr: WeakRef = weakref(g)
				var leave := func() -> void:
					var ref = wr.get_ref()
					if ref and is_instance_valid(ref):
						ref.queue_free()
				w.get_tree().create_timer(30.0, false).timeout.connect(leave)
				FX.smoke(w, pos + Vector3.UP, 1.5, 1.0)
			return true
		"sleep":
			var n := 0
			for o in a.get_tree().get_nodes_in_group("actors"):
				if a.can_hurt(o) and o.team != "civilian" and o.global_position.distance_to(a.global_position) < 18.0:
					o.stun_t = maxf(o.stun_t, 4.0)
					FX.stun_stars(o, 2.0 * o.size, 4.0)
					n += 1
			FX.ring(w, a.global_position + Vector3.UP, color, 18.0, 0.8)
			a.model.play("temples", 0.8)
			if a.is_player:
				w.notify("%d enemies fall into a dream." % n, color)
			Sfx.play("slowmo", a.global_position, 0.0)
			return true
		"overload":
			var foes := Abilities._nearest_foes(a, 22.0, 8)
			for o in foes:
				FX.lightning(w, a.chest(), o.chest(), color, 0.35, 0.9, 8, 1)
				o.take_damage(24.0 * a.power, a, "shock", Vector3.UP * 5.0)
				o.stun_t = maxf(o.stun_t, 0.8)
			FX.flash(w, a.chest(), color, 4.0, 0.4)
			a.model.play("cast_up", 0.5)
			Sfx.play("lightning", a.global_position, 4.0)
			return not foes.is_empty() or a.is_player
		"flashbang":
			var from := a.hand_pos()
			var proj := Projectile.new()
			proj.fuse = 1.0
			proj.setup(w, a, from, a.aim_dir(from) * 24.0 + Vector3.UP * 5.0, 6.0, "grenade", Color("#ffffff"), "shock", 7.0)
			a.model.play("throw", 0.4)
			return true
	return false


## Mirror Master / Constantine / Vibe: shove a foe out of the world for a few
## seconds, then drop them back in, hurt and dazed.
static func trap(a: Actor, o: Actor, color: Color, seconds: float, dmg: float) -> void:
	var w = a.world
	FX.breach(w, o.chest(), color, 0.6, 1.3)
	FX.sparks(w, o.chest(), color, 30, 8.0, 0.6)
	var pos := o.global_position
	var layer := o.collision_layer
	o.visible = false
	o.collision_layer = 0
	o.process_mode = Node.PROCESS_MODE_DISABLED
	var wr: WeakRef = weakref(o)
	var src: WeakRef = weakref(a)
	var back := func() -> void:
		var ref = wr.get_ref()
		if ref == null or not is_instance_valid(ref):
			return
		ref.process_mode = Node.PROCESS_MODE_INHERIT
		ref.visible = true
		ref.collision_layer = layer
		ref.global_position = pos + Vector3.UP * 0.5
		FX.breach(ref.world, ref.chest(), color, 0.6, 1.3)
		var s = src.get_ref()
		ref.take_damage(dmg, s if s and is_instance_valid(s) else null, "", Vector3.UP * 6.0)
		ref.stun_t = maxf(ref.stun_t, 1.5)
	w.get_tree().create_timer(seconds, false).timeout.connect(back)
	Sfx.play("teleport", pos, 2.0)


## Called by the actor each step while a whirlwind spins.
static func whirl_tick(a: Actor) -> void:
	var color: Color = a.get_meta("whirl_color", Color.WHITE)
	var element: String = a.get_meta("whirl_element", "push")
	for o in a.get_tree().get_nodes_in_group("actors"):
		if a.can_hurt(o) and o.global_position.distance_to(a.global_position) < 5.0 * a.size:
			var out: Vector3 = o.global_position - a.global_position
			out.y = 0
			o.take_damage(7.0 * a.power, a, element if element != "push" else "", out.normalized() * 9.0 + Vector3.UP * 5.0)
	FX.ring(a.world, a.global_position + Vector3.UP * randf_range(0.4, 1.6), color, 4.5 * a.size, 0.25)
