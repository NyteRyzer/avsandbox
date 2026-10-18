class_name Actor
extends CharacterBody3D
## Every character in the world (the player, heroes, villains, police, thugs
## and civilians) is an Actor. A "brain" (PlayerBrain or AIBrain) fills in the
## input fields each physics frame; the Actor turns them into movement,
## attacks and abilities defined by its character dictionary.

signal died(actor: Actor, source: Actor)
signal damaged(actor: Actor, amount: float)

const GRAVITY := 24.0
const SEA_FLOOR := -3.0
const STATUS_COLORS := {
	"frozen": Color("#6fb8e0"),
	"steel": Color("#b8c1cc"),
	"ghost": Color("#9fd6ff"),
}

var def: Dictionary = {}
var team := "civilian"
var is_player := false
var brain = null
var world = null  # World node (spawns effects, projectiles, KO bookkeeping)
var model: CharacterModel
var collider: CollisionShape3D
var capsule: CapsuleShape3D

var max_hp := 100.0
var hp := 100.0
var max_energy := 100.0
var energy := 100.0
var speed_mult := 1.0
var power := 1.0
var movement := "run"
var strength := false
var size := 1.0
var dead := false
var dead_time := 0.0
var display_name := ""

# Inputs written by the brain each frame.
var in_move := Vector3.ZERO
var in_sprint := false
var in_jump := false
var in_up := false
var in_down := false
var in_fly_toggle := false
var in_primary := false
var in_secondary := false
var in_special := false
var in_ability := false
var aim_point := Vector3.ZERO
var face_dir := Vector3.FORWARD

# State
var flying := false
var cooldowns := {"primary": 0.0, "secondary": 0.0, "special": 0.0}
var grudges: Dictionary = {}  # instance_id -> seconds remaining
var last_attacker: Actor = null
var follow_target: Actor = null
var event_tag := ""
var grapple_point = null
var grapple_line: MeshInstance3D = null
var held_prop: RigidBody3D = null
var beam_mesh: MeshInstance3D = null
var beam_sound_t := 0.0
var dash_t := 0.0
var dash_hit: Dictionary = {}
var slam_pending := false
var trail_t := 0.0
var last_trail_pos := Vector3.ZERO

var frozen_t := 0.0
var burn_t := 0.0
var stun_t := 0.0
var invuln_t := 0.0
var invis_t := 0.0
var rage_t := 0.0
var tornado_t := 0.0
var shrunk := false
var swimming := false
var _jump_buffer := 0.0
var _coyote := 0.0


func setup(character: Dictionary, team_name: String) -> void:
	def = character
	team = team_name
	display_name = character.get("alias", character.get("name", "Someone"))
	max_hp = float(character.get("health", 100))
	hp = max_hp
	speed_mult = float(character.get("speed", 1.0))
	power = float(character.get("power", 1.0))
	movement = character.get("movement", "run")
	strength = bool(character.get("strength", false))
	size = float(character.get("look", {}).get("scale", 1.0))

	collision_layer = Game.LAYER_ACTORS
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	capsule = CapsuleShape3D.new()
	collider = CollisionShape3D.new()
	collider.shape = capsule
	add_child(collider)
	_apply_size(size)

	model = CharacterModel.new()
	add_child(model)
	model.build(character.get("look", {}))
	if not is_player:
		for m in model.meshes:
			m.visibility_range_end = 180.0
	add_to_group("actors")
	if team == "civilian":
		add_to_group("civilians")


func _apply_size(s: float) -> void:
	capsule.radius = 0.38 * s
	capsule.height = 1.85 * s
	collider.position = Vector3(0, 0.925 * s, 0)


# --- Queries ----------------------------------------------------------------

func forward() -> Vector3:
	return -global_transform.basis.z


func chest() -> Vector3:
	return global_position + Vector3.UP * 1.3 * _cur_scale()


func head_pos() -> Vector3:
	return global_position + Vector3.UP * 1.75 * _cur_scale()


func hand_pos() -> Vector3:
	return global_position + Vector3.UP * 1.4 * _cur_scale() + forward() * 0.45 * _cur_scale()


func _cur_scale() -> float:
	return size * (0.3 if shrunk else 1.0)


func aim_dir(from: Vector3) -> Vector3:
	var d := aim_point - from
	if d.length() < 0.5:
		return forward()
	return d.normalized()


func side() -> int:
	return Game.side_of(team)


func is_ally_of_player() -> bool:
	return follow_target != null and is_instance_valid(follow_target) and follow_target.is_player


func is_hostile_to(o: Actor) -> bool:
	if o == null or o == self or o.dead or dead or not is_instance_valid(o):
		return false
	if follow_target == o or o.follow_target == self:
		return false
	if is_ally_of_player() and o.is_ally_of_player():
		return false
	if grudges.has(o.get_instance_id()):
		return true
	if team == "civilian" or o.team == "civilian":
		return false
	if o.invis_t > 0.0:
		return false
	var a := side()
	var b := o.side()
	if a != 0 and b != 0 and a != b:
		return true
	# Heroes and police turn on a player hero who racks up heat.
	if o.is_player and a == 1 and b == 1 and Game.heat >= 2.0 and not is_ally_of_player():
		return true
	if is_player and b == 1 and a == 1 and Game.heat >= 2.0 and not o.is_ally_of_player():
		return true
	return false


## Whether this actor's attacks may damage `o`. The player can hit anyone but
## their own allies; AI only hurts what it is hostile to.
func can_hurt(o) -> bool:
	if not (o is Actor) or o == self or o.dead:
		return false
	if is_player:
		return not (o.follow_target == self)
	if o.is_player and Game.cheats["god_mode"]:
		return false
	return is_hostile_to(o)


func can_act() -> bool:
	return not dead and stun_t <= 0.0 and frozen_t <= 0.0


# --- Main loop --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		dead_time += delta
		velocity.x = move_toward(velocity.x, 0, delta * 20)
		velocity.z = move_toward(velocity.z, 0, delta * 20)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		model.animate(delta, 0, true, false, 0, true)
		if dead_time > 12.0 and not is_player:
			queue_free()
		return
	_tick_status(delta)
	in_move = Vector3.ZERO
	in_jump = false
	in_fly_toggle = false
	in_special = false
	in_ability = false
	if brain:
		brain.update(self, delta)
	if not can_act():
		in_move = Vector3.ZERO
		in_jump = false
		in_primary = false
		in_secondary = false
		in_special = false
		in_ability = false
	_move(delta)
	_abilities(delta)
	var hv := Vector3(velocity.x, 0, velocity.z)
	model.animate(delta, hv.length(), is_on_floor() or swimming, flying, velocity.y, false)
	_speed_trail(delta, hv.length())


func _tick_status(delta: float) -> void:
	for slot in cooldowns:
		cooldowns[slot] = maxf(0.0, cooldowns[slot] - delta)
	var regen := 14.0 if not Game.cheats["infinite_energy"] or not is_player else 1000.0
	energy = minf(max_energy, energy + regen * delta)
	if grudges.size() > 0:
		for id in grudges.keys():
			grudges[id] -= delta
			if grudges[id] <= 0.0:
				grudges.erase(id)
	if burn_t > 0.0:
		burn_t -= delta
		_raw_damage(6.0 * delta, null)
		if randf() < delta * 10.0 and world:
			FX.sparks(world, chest(), Color("#ff7a1a"), 3, 1.5)
	stun_t = maxf(0.0, stun_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	if frozen_t > 0.0:
		frozen_t -= delta
	if invis_t > 0.0:
		invis_t -= delta
	if tornado_t > 0.0:
		tornado_t -= delta
		Abilities.tornado_tick(self, delta)
	# Visual state, most important first.
	if frozen_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["frozen"], 0.15, false, 0.9))
	elif invis_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["ghost"], 0.3, true, 0.18 if is_player else 0.06))
	elif invuln_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["steel"], 0.2))
	elif rage_t > 0.0:
		model.set_override(null)
	else:
		model.set_override(null)


func _move(delta: float) -> void:
	var base := 6.5 * speed_mult
	var sprint := base * 1.75
	var jump := 8.5
	match movement:
		"speed":
			sprint = 62.0 * speed_mult
			base = 8.0
			jump = 10.0
		"flight":
			jump = 9.0
		"superjump":
			jump = 21.0
			sprint = base * 1.9
		"grapple":
			jump = 9.5
	if shrunk:
		base *= 0.55
		sprint *= 0.6
	if rage_t > 0.0:
		base *= 1.2
		sprint *= 1.2
	var target_speed := sprint if in_sprint else base

	if in_fly_toggle and movement == "flight":
		flying = not flying
		if flying:
			velocity.y = maxf(velocity.y, 7.0)
			Sfx.play("whoosh", global_position, -6.0)
	if in_jump and not is_on_floor() and movement == "flight" and not flying:
		flying = true
		velocity.y = maxf(velocity.y, 6.0)

	# Water: the sea is open water above the sea floor.
	swimming = world != null and world.city.is_water(global_position) and global_position.y < -0.4 and not flying

	if dash_t > 0.0:
		dash_t -= delta
		Abilities.dash_tick(self)
	elif flying:
		var fly_speed := 42.0 * speed_mult if in_sprint else 13.0 * speed_mult
		if def.get("id", "") in ["superman", "supergirl", "reign", "overgirl", "mon_el"]:
			fly_speed *= 1.6 if in_sprint else 1.0
		var desired := in_move * fly_speed
		var vert := 0.0
		if in_up:
			vert += 1.0
		if in_down:
			vert -= 1.0
		desired.y += vert * 10.0 * speed_mult
		velocity = velocity.lerp(desired, clampf(delta * 3.5, 0.0, 1.0))
		if is_on_floor() and in_down:
			flying = false
	elif grapple_point != null:
		var gp: Vector3 = grapple_point
		var to := gp - global_position
		if to.length() < 2.2 or in_jump or not in_ability and to.length() > 160.0:
			_release_grapple()
			velocity.y = 9.0
		else:
			velocity = to.normalized() * 42.0
			_update_grapple_line()
	else:
		var desired := in_move * target_speed
		var accel := 10.0 if is_on_floor() else 2.5
		if movement == "speed":
			accel = 14.0 if is_on_floor() else 4.0
		if swimming:
			desired *= 0.45
			accel = 4.0
		var hv := Vector3(velocity.x, 0, velocity.z).lerp(desired, clampf(accel * delta, 0.0, 1.0))
		velocity.x = hv.x
		velocity.z = hv.z
		# Jumps pressed slightly early (buffer) or late (coyote time) still count.
		if in_jump:
			_jump_buffer = 0.15
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
		_coyote = 0.12 if is_on_floor() else maxf(0.0, _coyote - delta)
		if swimming:
			velocity.y = lerpf(velocity.y, (-0.9 - global_position.y) * 4.0, clampf(delta * 5.0, 0.0, 1.0))
			if in_jump:
				velocity.y = 6.0
		elif _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = jump
			_jump_buffer = 0.0
			_coyote = 0.0
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta * (world.gravity_scale if world else 1.0)
		# Speedsters run up walls and across water.
		if movement == "speed" and in_sprint and in_move.length() > 0.5:
			if is_on_wall():
				velocity.y = maxf(velocity.y, 22.0)
			if world and world.city.is_water(global_position) and hv.length() > 25.0 and global_position.y < 0.3:
				velocity.y = maxf(velocity.y, (0.05 - global_position.y) * 20.0)
				if randf() < 0.3:
					FX.sparks(world, global_position, Color("#cfe8ff"), 2, 3.0)
		if slam_pending and is_on_floor():
			slam_pending = false
			Abilities.ground_slam_impact(self)

	# Time slow: the player keeps moving at full speed while the world crawls.
	var comp := 1.0
	if is_player and Engine.time_scale < 0.99:
		comp = 1.0 / Engine.time_scale
	velocity *= comp
	move_and_slide()
	velocity /= comp

	if face_dir.length() > 0.1:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 14.0 * comp, 0.0, 1.0))
	if global_position.y < -40.0 or global_position.y > 1500.0:
		global_position = world.city.nearest_road_point(global_position) if world else Vector3(0, 2, 0)
		velocity = Vector3.ZERO
	if held_prop and is_instance_valid(held_prop):
		held_prop.global_position = global_position + Vector3.UP * (2.6 * _cur_scale() + 0.8)
		held_prop.global_rotation = Vector3(0, rotation.y, 0)


func _abilities(delta: float) -> void:
	if held_prop and (in_primary or in_ability):
		Abilities.throw_prop(self)
		cooldowns["primary"] = 0.4
		return
	if in_ability:
		if movement == "grapple":
			if grapple_point != null:
				_release_grapple()
			else:
				Abilities.fire_grapple(self)
		elif strength:
			Abilities.pick_up(self)
	for slot in ["primary", "secondary"]:
		var atk: Dictionary = def[slot]
		var held := in_primary if slot == "primary" else in_secondary
		if atk["kind"] == "beam":
			if held and energy > 2.0 and can_act():
				Abilities.beam_tick(self, atk, delta, slot)
			elif beam_mesh and beam_mesh.get_meta("slot", "") == slot:
				beam_mesh.visible = false
			continue
		if held and cooldowns[slot] <= 0.0 and can_act():
			var cost := Abilities.energy_cost(atk)
			if energy >= cost or (is_player and Game.cheats["infinite_energy"]):
				energy -= cost
				cooldowns[slot] = Abilities.cooldown(atk)
				Abilities.fire(self, atk)
	if in_special and cooldowns["special"] <= 0.0:
		var sp: Dictionary = def["special"]
		var cost := Abilities.special_cost(sp)
		if energy >= cost or (is_player and Game.cheats["infinite_energy"]):
			if Abilities.special(self, sp):
				energy -= cost
				cooldowns["special"] = Abilities.special_cooldown(sp)


func _speed_trail(delta: float, hspeed: float) -> void:
	if movement != "speed" or world == null:
		return
	trail_t -= delta
	var fast := hspeed > 20.0 or dash_t > 0.0
	if fast and trail_t <= 0.0:
		trail_t = 0.03
		var col := Color(str(def.get("look", {}).get("trail", "#ffcc22")))
		var a := last_trail_pos
		var b := global_position + Vector3.UP * randf_range(0.4, 1.6) * size
		if a.distance_to(b) < 25.0:
			FX.lightning(world, a, b, col, 0.3, 0.35, 3)
			FX.lightning(world, a + Vector3.UP * 0.5 * size, b + Vector3.UP * randf_range(-0.4, 0.4) * size, col.lightened(0.3), 0.22, 0.45, 3)
		last_trail_pos = b
		if randf() < 0.15:
			Sfx.play("zap", global_position, -14.0, 0.3)
	elif not fast:
		last_trail_pos = global_position + Vector3.UP


func _release_grapple() -> void:
	grapple_point = null
	if grapple_line:
		grapple_line.queue_free()
		grapple_line = null


func _update_grapple_line() -> void:
	if grapple_line == null or grapple_point == null:
		return
	FX.place_line(grapple_line, hand_pos(), grapple_point, 0.025)


# --- Damage -----------------------------------------------------------------

func take_damage(amount: float, source: Actor, element := "", knock := Vector3.ZERO) -> void:
	if dead:
		return
	if source and is_instance_valid(source) and source != self:
		last_attacker = source
		if not is_player:
			grudges[source.get_instance_id()] = 10.0
		if source.is_player:
			if Game.cheats["one_hit_ko"]:
				amount = hp + 1.0
			_player_hit_side_effects(amount)
		elif is_player:
			amount *= 0.5
		if source.rage_t > 0.0:
			amount *= 1.8
	if invuln_t > 0.0:
		amount *= 0.1
		knock *= 0.2
	if is_player and Game.cheats["god_mode"]:
		amount = 0.0
	if size > 1.5:
		knock /= size
	velocity += knock
	if knock.y > 4.0 and movement != "flight":
		flying = false
	match element:
		"fire":
			burn_t = 3.0
		"ice":
			frozen_t = maxf(frozen_t, 1.8 / maxf(1.0, size))
			Sfx.play("freeze", global_position, -6.0)
		"shock":
			stun_t = maxf(stun_t, 0.5)
	model.flash_hit()
	if world:
		Game.report_combat(global_position)
		if amount >= 1.0:
			FX.damage_number(world, head_pos() + Vector3.UP * 0.4, amount, is_player)
	_raw_damage(amount, source)


func _raw_damage(amount: float, source: Actor) -> void:
	if dead:
		return
	hp -= amount
	damaged.emit(self, amount)
	if hp <= 0.0:
		die(source if source else last_attacker)


func _player_hit_side_effects(amount: float) -> void:
	if team == "civilian":
		Game.add_heat(0.35)
	elif side() == 1 and Game.player_side() == 1 and not is_ally_of_player():
		Game.add_heat(0.25)
	elif side() == 1 and Game.player_side() == -1:
		Game.add_heat(0.08)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func die(source: Actor) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	flying = false
	_release_grapple()
	if held_prop and is_instance_valid(held_prop):
		Abilities.drop_prop(self)
	if beam_mesh:
		beam_mesh.visible = false
	collision_layer = 0
	collision_mask = Game.LAYER_WORLD
	model.set_override(null)
	Sfx.play("ko", global_position, -4.0)
	died.emit(self, source)
	if world:
		world.on_actor_ko(self, source)


func revive() -> void:
	dead = false
	dead_time = 0.0
	hp = max_hp
	energy = max_energy
	frozen_t = 0.0
	burn_t = 0.0
	stun_t = 0.0
	invuln_t = 2.0
	collision_layer = Game.LAYER_ACTORS
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	model.body.rotation = Vector3.ZERO
	model.body.position = Vector3.ZERO


func set_shrunk(value: bool) -> void:
	shrunk = value
	var s := _cur_scale()
	_apply_size(s)
	model.scale = Vector3.ONE * s


func _exit_tree() -> void:
	if grapple_line and is_instance_valid(grapple_line):
		grapple_line.queue_free()
	if beam_mesh and is_instance_valid(beam_mesh):
		beam_mesh.queue_free()
