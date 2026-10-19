class_name AIBrain
extends RefCounted
## NPC behaviour. Civilians wander the sidewalks and flee from fights.
## Fighters (police, gangs, heroes and villains) patrol near home, pick the
## nearest enemy, close to a range that suits their attacks, and use their
## powers, including specials, flight and super speed.

var role := "fighter"
var home := Vector3.ZERO
var leash := 70.0
var detect := 45.0
var target: Actor = null

var _think := 0.0
var _wander_dir := Vector3.ZERO
var _wander_t := 0.0
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _strafe := 1.0
var _strafe_t := 0.0
var _beam_t := 0.0
var _use_secondary := false
var _stuck_t := 0.0
var _block_t := 0.0
var _fan_t := 0.0


func update(a: Actor, delta: float) -> void:
	a.in_primary = false
	a.in_secondary = false
	a.in_sprint = false
	a.in_up = false
	a.in_down = false
	if role == "civilian":
		_civilian(a, delta)
		return
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(0.35, 0.6)
		target = _find_target(a)
	if target and (not is_instance_valid(target) or target.dead or not a.is_hostile_to(target)):
		target = null
	if target:
		_fight(a, delta)
	elif a.follow_target and is_instance_valid(a.follow_target):
		_follow(a, a.follow_target)
	else:
		_wander(a, delta, 0.55)
		if a.flying and a.global_position.y > 3.0:
			a.in_down = true


func _find_target(a: Actor) -> Actor:
	var best: Actor = null
	var best_d := detect
	for o in a.get_tree().get_nodes_in_group("actors"):
		if not a.is_hostile_to(o):
			continue
		var d: float = o.global_position.distance_to(a.global_position)
		if a.grudges.has(o.get_instance_id()):
			d *= 0.4
		if d < best_d:
			best_d = d
			best = o
	return best


func _range_for(atk: Dictionary) -> float:
	match atk["kind"]:
		"melee":
			return float(atk.get("range", 2.4)) * 0.85
		"dash":
			return 8.0
		"sonic":
			return 9.0
		"beam":
			return 22.0
		"lightning":
			return 20.0
		"flame", "breath":
			return 8.0
		"psychic":
			return 11.0
		"telekinesis":
			return 18.0
		"missiles":
			return 26.0
		"chain_lightning":
			return 22.0
		"ground_spikes":
			return 10.0
		"grab":
			return 12.0
	return 18.0


func _fight(a: Actor, delta: float) -> void:
	var to := target.global_position - a.global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.01 else a.forward()
	var primary: Dictionary = a.def["primary"]
	var secondary: Dictionary = a.def["secondary"]
	var pr := _range_for(primary)
	var sr := _range_for(secondary)
	var pref := minf(pr, sr) if dist < maxf(pr, sr) * 0.6 else maxf(pr, sr)
	if primary["kind"] == "melee" and secondary["kind"] == "melee":
		pref = pr
	if a.def.get("id", "") in ["thug", "police"]:
		pref = pr

	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 2.5)
		_strafe = -1.0 if randf() < 0.5 else 1.0
	var move := Vector3.ZERO
	if dist > pref + 1.0:
		move = dir
		a.in_sprint = dist > 25.0 or a.movement == "speed" and dist > 10.0
	elif dist < pref * 0.5 and pref > 5.0:
		move = -dir
	elif pref > 5.0:
		move = dir.cross(Vector3.UP) * _strafe * 0.6
	a.in_move = move

	# Leash: event guards and patrols don't chase forever.
	if leash > 0.0 and a.global_position.distance_to(home) > leash * 2.0 and not a.is_ally_of_player():
		target = null
		return

	if a.movement == "flight":
		var want_fly := absf(to.y) > 3.0 or dist > 30.0 or pref > 5.0
		if want_fly and not a.flying:
			a.in_fly_toggle = true
		if a.flying:
			var desired_y := target.global_position.y + (4.0 if pref > 5.0 else 0.5)
			a.in_up = a.global_position.y < desired_y - 1.0
			a.in_down = a.global_position.y > desired_y + 1.0
	elif a.is_on_floor() and (a.is_on_wall() or to.y > 2.5 and dist < 10.0):
		_stuck_t += delta
		if _stuck_t > 0.4:
			a.in_jump = true
			_stuck_t = 0.0
	if a.movement == "grapple" and to.y > 6.0 and dist < 40.0 and randf() < delta * 0.5:
		a.in_ability = true

	a.face_dir = dir
	var inaccuracy := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * clampf(dist * 0.025, 0.1, 1.5)
	a.aim_point = target.chest() + inaccuracy

	# Pick an attack.
	if randf() < delta * 0.5:
		_use_secondary = not _use_secondary
	var atk_slot := "secondary" if _use_secondary else "primary"
	var atk: Dictionary = secondary if _use_secondary else primary
	if dist > _range_for(atk) * 1.3:
		atk_slot = "primary" if atk_slot == "secondary" else "secondary"
		atk = a.def[atk_slot]
	var in_range := dist < _range_for(atk) * 1.3 + 1.0
	if atk["kind"] in Abilities.HELD_KINDS:
		if in_range and _beam_t <= 0.0 and randf() < delta * 1.5:
			_beam_t = randf_range(0.8, 1.6)
		if _beam_t > 0.0:
			_beam_t -= delta
			_press(a, atk_slot)
	elif in_range and randf() < delta * (6.0 if atk["kind"] == "melee" else 2.2):
		_press(a, atk_slot)
	if dist < 14.0 and a.energy > 70.0 and randf() < delta * 0.12:
		a.in_special = true
	# Utility powers: speedsters blitz crowds, others breach, flip or phase.
	if a.def.has("utility") and a.energy > 50.0 and randf() < delta * 0.15:
		var u: String = a.def["utility"]["kind"]
		if u == "blitz" and dist < 30.0:
			a.in_ability = true
		elif u in ["teleport"] and dist > 25.0:
			a.aim_point = target.global_position + Vector3.UP
			a.in_ability = true
		elif u in ["dodge_flip", "phase", "foresight", "invulnerable", "emp", "ice_wall"] and dist < 10.0:
			a.in_ability = true
	# Bosses and named characters unleash their ultimate when it is charged.
	if a.ult >= 100.0 and dist < 18.0 and a.def.get("id", "") not in ["thug", "police", "civilian"] and randf() < delta * 0.8:
		a.in_ultimate = true
	# Block the player's combos now and then (and sometimes parry them).
	if _block_t > 0.0:
		_block_t -= delta
		a.in_block = true
	elif target.is_player and dist < 3.5 and target.combo_window > 0.4 and a.def.get("id", "") not in ["civilian", "thug"] and randf() < delta * 1.2:
		_block_t = randf_range(0.4, 1.0)
	# Dodge when the player is swinging at us up close.
	if target.is_player and dist < 4.0 and target.combo_window > 0.6 and randf() < delta * 2.0:
		a.in_dodge = true


func _press(a: Actor, slot: String) -> void:
	if slot == "primary":
		a.in_primary = true
	else:
		a.in_secondary = true


func _follow(a: Actor, leader: Actor) -> void:
	var to := leader.global_position - a.global_position
	var flat := Vector3(to.x, 0, to.z)
	var d := flat.length()
	if d > 6.0:
		a.in_move = flat.normalized()
		a.in_sprint = d > 14.0
		a.face_dir = flat.normalized()
	if d > 120.0:
		a.global_position = leader.global_position + Vector3(randf_range(-4, 4), 1, randf_range(-4, 4))
	if a.movement == "flight":
		if (leader.flying or to.y > 4.0) and not a.flying:
			a.in_fly_toggle = true
		if a.flying:
			a.in_up = to.y > 1.5
			a.in_down = to.y < -1.5
			if not leader.flying and absf(to.y) < 2.0 and d < 8.0:
				a.in_down = true
	elif a.is_on_floor() and a.is_on_wall():
		a.in_jump = true
	home = leader.global_position


func _wander(a: Actor, delta: float, speed: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0 or a.is_on_wall():
		_wander_t = randf_range(3.0, 7.0)
		var ang := randf() * TAU
		_wander_dir = Vector3(cos(ang), 0, sin(ang))
		# Stick to the street grid most of the time.
		if randf() < 0.75:
			var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
			_wander_dir = axes[randi() % 4]
		var to_home := home - a.global_position
		to_home.y = 0
		if to_home.length() > leash:
			_wander_dir = to_home.normalized()
	if randf() < 0.3 and _wander_t > 5.0:
		a.in_move = Vector3.ZERO
		return
	a.in_move = _wander_dir * speed
	a.face_dir = _wander_dir
	if a.world and a.world.city.is_water(a.global_position + _wander_dir * 3.0):
		_wander_dir = -_wander_dir


func _civilian(a: Actor, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if a.last_attacker and is_instance_valid(a.last_attacker) and a.grudges.has(a.last_attacker.get_instance_id()):
		_flee_t = 6.0
		_flee_from = a.last_attacker.global_position
	elif now - Game.last_combat_time < 1.0 and a.global_position.distance_to(Game.last_combat_pos) < 30.0:
		_flee_t = 5.0
		_flee_from = Game.last_combat_pos
	if _flee_t > 0.0:
		_flee_t -= delta
		var away := a.global_position - _flee_from
		away.y = 0
		if away.length() < 0.1:
			away = Vector3.RIGHT
		var dir := away.normalized()
		if a.is_on_wall():
			dir = dir.rotated(Vector3.UP, PI * 0.5)
		a.in_move = dir
		a.in_sprint = true
		a.face_dir = dir
		return
	if _react_to_player(a, delta):
		return
	_wander(a, delta, 0.35)


## Crowds react to costumed characters: they cheer heroes and take photos,
## and run from villains.
func _react_to_player(a: Actor, delta: float) -> bool:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead or pl.civilian or pl.invis_t > 0.0:
		return false
	var to: Vector3 = pl.global_position - a.global_position
	to.y = 0
	var d := to.length()
	if d > 14.0 or Time.get_ticks_msec() / 1000.0 - Game.last_combat_time < 4.0:
		return false
	if Game.player_side() == -1 or Game.heat >= 2.0:
		if d < 10.0:
			_flee_t = 3.0
			_flee_from = pl.global_position
		return false
	a.in_move = Vector3.ZERO if d < 6.0 else to.normalized() * 0.3
	a.face_dir = to.normalized()
	_fan_t -= delta
	if _fan_t <= 0.0:
		_fan_t = randf_range(1.5, 4.0)
		if randf() < 0.5:
			a.model.play("cast_up", 0.8)    # cheering
		else:
			a.model.play("point", 0.9)      # a photo
			if a.world:
				FX.flash(a.world, a.model.hand_point(1.0), Color.WHITE, 0.25, 0.12, 0.9)
	return true
