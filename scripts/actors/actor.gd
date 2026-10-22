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
var gliding := false
var in_up := false
var in_down := false
var in_fly_toggle := false
var in_primary := false
var in_secondary := false
var in_special := false
var in_ability := false
var in_ultimate := false
var in_block := false
var blocking := false
var lock_target: Actor = null
var style_kind := ""
var _block_start := -10.0
var aim_point := Vector3.ZERO
var face_dir := Vector3.FORWARD

# State
var flying := false
var cooldowns := {"primary": 0.0, "secondary": 0.0, "special": 0.0, "power1": 0.0, "power2": 0.0, "power3": 0.0}
## Extra powers on keys 1-3 (see Loadout.extra_powers).
var powers: Array = []
var in_power := [false, false, false]
var ult := 0.0                 # ultimate meter, 0..100
var ult_active := false
var grudges: Dictionary = {}  # instance_id -> seconds remaining
var last_attacker: Actor = null
var follow_target: Actor = null
var event_tag := ""
var grapple_point = null
var grapple_line: MeshInstance3D = null
var held_prop: RigidBody3D = null
## Telekinesis: what's floating in front of a telekinetic (a prop in
## held_prop, or a person here).
var tk_hold := false
## A weapon picked up off the street: replaces the primary until the ammo runs out.
var pickup_ammo := 0
var _saved_primary: Dictionary = {}
var _saved_gear := ""
var tk_actor: Actor = null
var _tk_t := 0.0
var _tk_fx_t := 0.0
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

# Combat state for the upgraded kits.
var in_dodge := false
var combo_step := 0
var combo_window := 0.0
var combo_count := 0
var combo_timer := 0.0
var flurry_count := 0
var hand_flip := 1.0
var beams: Array[MeshInstance3D] = []
var beam_slot := ""
var stream: CPUParticles3D = null
var stream_t := 0.0
var stretch_t := 0.0
var eye_glow_t := 0.0
var dodge_t := 0.0
var dampened_t := 0.0
var shield_t := 0.0
var field_t := 0.0
var phase_t := 0.0
var storm_t := 0.0
var _storm_tick := 0.0
var t_spheres_t := 0.0
var _sphere_tick := 0.0
var _sphere_nodes: Array[Node3D] = []
var breath_t := 0.0
var breath_spec: Dictionary = {}
var blitz_queue: Array = []
var blitz_t := 0.0
var lift_t := 0.0
var lifter: Actor = null
var lift_damage := 0.0
var controlled_t := 0.0
var _orig_team := ""
var _orig_follow: Actor = null
var boss := false
var root_t := 0.0             # netted: can't move
var civilian := false         # out of costume: no powers
var changing := false         # mid-transformation
var suit_def: Dictionary = {} # the costumed character while in civilian clothes
var poison_t := 0.0
var whirl_t := 0.0
var _whirl_tick := 0.0
var disguise_t := 0.0
var trick_index := 0
var _true_look: Dictionary = {}
var hp_bar: Node3D = null
var hp_bar_t := 0.0
var _ice: Node3D = null
var _burn_fx: CPUParticles3D = null
var _ice_trail_t := 0.0


func setup(character: Dictionary, team_name: String) -> void:
	def = character
	team = team_name
	powers = Loadout.extra_powers(character) if character.has("special") and team_name != "civilian" else []
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
	cooldowns["utility"] = 0.0
	if movement == "hover":
		flying = true
	add_to_group("actors")
	if team == "civilian":
		add_to_group("civilians")


func make_boss(mult := 2.5) -> void:
	boss = true
	max_hp *= mult
	hp = max_hp


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
	if model and model.hand_r:
		return model.hand_point(1.0) + forward() * 0.15 * _cur_scale()
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
	if o.civilian or civilian:
		# Nobody recognises a hero (or villain) in street clothes.
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
	in_dodge = false
	in_ultimate = false
	in_block = false
	if brain:
		brain.update(self, delta)
	if not can_act():
		in_move = Vector3.ZERO
		in_jump = false
		in_primary = false
		in_secondary = false
		in_special = false
		in_ability = false
		in_dodge = false
	# Blocking: hold to soak hits from the front; time it right to parry.
	var was_blocking := blocking
	blocking = in_block and can_act() and not flying and not civilian and grapple_point == null
	if blocking:
		if not was_blocking:
			_block_start = Time.get_ticks_msec() / 1000.0
		in_move *= 0.3
		in_sprint = false
		in_primary = false
		in_secondary = false
		if not model.is_busy():
			model.play("shield", 0.25)
	if root_t > 0.0:
		in_move = Vector3.ZERO
		in_jump = false
	if lift_t > 0.0:
		_lifted(delta)
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
	root_t = maxf(0.0, root_t - delta)
	if poison_t > 0.0:
		poison_t -= delta
		_raw_damage(5.0 * delta, null)
		if randf() < delta * 6.0 and world:
			FX.sparks(world, chest(), Color("#6aff4a"), 2, 1.0)
	if whirl_t > 0.0:
		whirl_t -= delta
		model.rotation.y += delta * 28.0
		_whirl_tick -= delta
		if _whirl_tick <= 0.0:
			_whirl_tick = 0.25
			Powers.whirl_tick(self)
		if whirl_t <= 0.0:
			model.rotation.y = 0.0
	if disguise_t > 0.0:
		disguise_t -= delta
		if disguise_t <= 0.0 or in_primary or in_secondary:
			_end_disguise()
	invuln_t = maxf(0.0, invuln_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	dampened_t = maxf(0.0, dampened_t - delta)
	shield_t = maxf(0.0, shield_t - delta)
	field_t = maxf(0.0, field_t - delta)
	eye_glow_t = maxf(0.0, eye_glow_t - delta)
	dodge_t = maxf(0.0, dodge_t - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_step = 0
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo_count = 0
	if stretch_t > 0.0:
		stretch_t -= delta
		if stretch_t <= 0.0:
			model.set_stretch(1.0)
	if phase_t > 0.0:
		phase_t -= delta
		collision_mask = Game.LAYER_WORLD if phase_t > 0.0 else Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	if stream_t > 0.0:
		stream_t -= delta
		if stream_t <= 0.0 and stream:
			stream.emitting = false
	if storm_t > 0.0:
		storm_t -= delta
		_storm_tick -= delta
		if _storm_tick <= 0.0:
			_storm_tick = 0.4
			Abilities.storm_tick(self)
	_tick_spheres(delta)
	if breath_t > 0.0:
		breath_t -= delta
		face_dir = Vector3(aim_dir(head_pos()).x, 0, aim_dir(head_pos()).z)
		Abilities.held_tick(self, breath_spec, delta, "special")
	if not blitz_queue.is_empty():
		blitz_t -= delta
		if blitz_t <= 0.0:
			blitz_t = 0.09
			Abilities.blitz_step(self)
	if controlled_t > 0.0:
		controlled_t -= delta
		if controlled_t <= 0.0:
			release_control()
	if hp_bar:
		hp_bar_t -= delta
		hp_bar.visible = hp_bar_t > 0.0 or boss
	if frozen_t > 0.0 and _ice == null:
		_ice = FX.ice_block(self, size)
	elif frozen_t <= 0.0 and _ice:
		FX.sparks(world, chest(), Color("#dff4ff"), 14, 5.0, 0.5)
		_ice.queue_free()
		_ice = null
	if burn_t > 0.0 and _burn_fx == null and world:
		_burn_fx = FX.stream_emitter("burn")
		add_child(_burn_fx)
		_burn_fx.position = Vector3(0, 1.0 * size, 0)
		_burn_fx.emitting = true
	elif burn_t <= 0.0 and _burn_fx:
		_burn_fx.emitting = false
		_burn_fx.queue_free()
		_burn_fx = null
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
	elif phase_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["ghost"], 0.4, true, 0.35))
	elif controlled_t > 0.0:
		model.set_override(CharacterModel.mat(Color("#c47aff"), 0.3, false, 0.9))
	elif invis_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["ghost"], 0.3, true, 0.18 if is_player else 0.06))
	elif invuln_t > 0.0:
		model.set_override(CharacterModel.mat(STATUS_COLORS["steel"], 0.2))
	elif rage_t > 0.0:
		model.set_override(null)
	else:
		model.set_override(null)


func _move(delta: float) -> void:
	var was_gliding := gliding
	var vy_before := velocity.y
	var air_before := not is_on_floor()
	gliding = false
	_move_body(delta)
	if air_before and is_on_floor() and vy_before < -26.0 and not civilian and not dead and not swimming:
		_hero_landing(-vy_before)
	model.gliding = gliding
	if gliding and not was_gliding and world:
		Sfx.play("whoosh", global_position, -6.0)


## A superhero landing: one knee down, fist to the ground, the street cracks.
func _hero_landing(speed: float) -> void:
	model.play("hero_land", 0.7)
	if world == null:
		return
	var col := Color(str(def["look"].get("trail", def["look"].get("accent", "#ffffff"))))
	var r := clampf(speed * 0.18, 4.0, 10.0) * size
	FX.shockwave(world, global_position, col.lerp(Color.WHITE, 0.4), r)
	if speed > 40.0:
		FX.ground_crack(world, global_position, col, r)
	Abilities.area_damage(self, global_position + Vector3.UP * 0.5, r * 0.6, minf(speed * 0.5, 30.0) * power, "push", 14.0, 8.0)
	world.shake_at(global_position, clampf(speed / 100.0, 0.15, 0.5))
	Sfx.play("slam", global_position, 0.0)
	if is_player:
		Game.record("hero_landings")


## Caped characters (Batwoman...) can glide; flyers, civvies and the shrunken can't.
func _can_glide() -> bool:
	return bool(def.get("glide", false)) and not civilian and not shrunk and movement != "flight"


func _move_body(delta: float) -> void:
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
		"ice":
			sprint = 26.0 * speed_mult
	if shrunk:
		base *= 0.55
		sprint *= 0.6
	if rage_t > 0.0:
		base *= 1.2
		sprint *= 1.2
	var target_speed := sprint if in_sprint else base

	if in_dodge and dodge_t <= 0.0 and can_act() and grapple_point == null:
		var dir := Vector3(in_move.x, 0, in_move.z)
		if dir.length() < 0.2:
			dir = -forward()
		dodge_t = 0.55
		invuln_t = maxf(invuln_t, 0.3)
		velocity = dir.normalized() * (22.0 if movement != "speed" else 45.0) + Vector3.UP * (2.0 if is_on_floor() else 0.0)
		model.play("dodge", 0.3)
		Sfx.play("whoosh", global_position, -4.0)
		if movement == "speed" and world:
			FX.lightning(world, chest(), chest() + dir.normalized() * 8.0, Color(str(def["look"].get("trail", "#ffcc22"))), 0.25, 0.4, 4, 0)
	if movement == "hover":
		flying = true
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
		fly_speed *= float(def.get("fly_speed", 1.0)) if in_sprint else 1.0
		if movement == "hover":
			fly_speed = 9.0 if not in_sprint else 18.0
		var was_fast := Vector3(velocity.x, 0, velocity.z).length() > 55.0
		var desired := in_move * fly_speed
		var vert := 0.0
		if in_up:
			vert += 1.0
		if in_down:
			vert -= 1.0
		desired.y += vert * 10.0 * speed_mult
		velocity = velocity.lerp(desired, clampf(delta * 3.5, 0.0, 1.0))
		if movement == "hover" and not in_up and not in_down:
			# The Thinker's chair floats a little above whatever is below it.
			var floor_hit := Abilities.ray(self, global_position + Vector3.UP, global_position + Vector3.DOWN * 4.0, [get_rid()])
			if not floor_hit.is_empty():
				velocity.y = lerpf(velocity.y, (floor_hit["position"].y + 1.2 - global_position.y) * 3.0, 0.2)
		if not was_fast and velocity.length() > 55.0 and world:
			FX.sonic_boom(world, chest(), velocity.normalized())
		if is_on_floor() and in_down and movement != "hover":
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
		elif not is_on_floor() and _can_glide() and in_up and velocity.y < 0.0 and _height_above_ground() > 2.5:
			# Cape glide: hold jump while falling. Sink slowly and sail forward;
			# hold descend (Ctrl) to dive.
			gliding = true
			var dive := in_down
			var glide_dir := in_move if in_move.length() > 0.1 else forward()
			var glide_speed := 34.0 if dive else 21.0
			var ghv := Vector3(velocity.x, 0, velocity.z).lerp(glide_dir.normalized() * glide_speed, clampf(delta * 1.8, 0.0, 1.0))
			velocity.x = ghv.x
			velocity.z = ghv.z
			velocity.y = lerpf(velocity.y, -11.0 if dive else -2.6, clampf(delta * 3.0, 0.0, 1.0))
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
		if movement == "ice" and in_sprint and hv.length() > 10.0 and world:
			_ice_trail_t -= delta
			if _ice_trail_t <= 0.0:
				_ice_trail_t = 0.05
				FX.sparks(world, global_position + Vector3.UP * 0.1, Color("#dff4ff"), 3, 1.5, 0.8)
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
	# Interiors are built far below the map, under their own floor.
	var floor_limit := Interiors.DEPTH - 40.0 if absf(global_position.z - 3000.0) < 80.0 else -40.0
	if global_position.y < floor_limit or global_position.y > 1500.0:
		global_position = world.city.nearest_road_point(global_position) if world else Vector3(0, 2, 0)
		velocity = Vector3.ZERO
	if held_prop and is_instance_valid(held_prop):
		if tk_hold:
			var hp := _tk_point()
			held_prop.global_position = held_prop.global_position.lerp(hp, clampf(delta * 8.0, 0.0, 1.0))
			held_prop.rotate_y(delta * 0.8)
		else:
			held_prop.global_position = global_position + Vector3.UP * (2.6 * _cur_scale() + 0.8)
			held_prop.global_rotation = Vector3(0, rotation.y, 0)
	_tk_tick(delta)


## Where telekinesis holds things: up and out in front, bobbing a little.
func _tk_point() -> Vector3:
	return chest() + forward() * 4.5 * size + Vector3.UP * (1.6 + sin(Time.get_ticks_msec() * 0.003) * 0.25)


func _tk_tick(delta: float) -> void:
	var holding := (tk_hold and held_prop and is_instance_valid(held_prop)) or (tk_actor and is_instance_valid(tk_actor))
	if not holding:
		if tk_actor and not is_instance_valid(tk_actor):
			tk_actor = null
		return
	_tk_t += delta
	if tk_actor and is_instance_valid(tk_actor):
		if tk_actor.dead or _tk_t > 8.0:
			tk_release(false)
			return
		tk_actor.global_position = tk_actor.global_position.lerp(_tk_point() - Vector3.UP * 0.9, clampf(delta * 8.0, 0.0, 1.0))
		tk_actor.velocity = Vector3.ZERO
		tk_actor.stun_t = maxf(tk_actor.stun_t, 0.3)
	elif _tk_t > 12.0:
		tk_release(false)
		return
	_tk_fx_t -= delta
	if _tk_fx_t <= 0.0 and world:
		_tk_fx_t = 0.12
		var col := Color(str(def["look"].get("trail", def["look"].get("glow", "#c47aff"))))
		var obj: Vector3 = tk_actor.chest() if tk_actor and is_instance_valid(tk_actor) else held_prop.global_position
		FX.lightning(world, model.hand_point(1.0), obj, col, 0.12, 0.25, 5, 0)
		FX.sparks(world, obj, col, 3, 2.0, 0.3)


## Swap powers and weapons on the spot (the weapon wheel).
func set_kit(d: Dictionary) -> void:
	if disguise_t > 0.0:
		_end_disguise()
	if pickup_ammo > 0:
		pickup_ammo = 0
		_saved_primary = {}
	def = def.duplicate(true)
	for slot in ["primary", "secondary", "special"]:
		def[slot] = d[slot]
	if d.has("utility"):
		def["utility"] = d["utility"]
	else:
		def.erase("utility")
	def["look"]["gear"] = d["look"].get("gear", {})
	if d["look"].has("back"):
		def["look"]["back"] = d["look"]["back"]
	powers = Loadout.extra_powers(def)
	if not civilian:
		_rebuild_model(def["look"])
		model.scale = Vector3.ONE * _cur_scale()


func equip_pickup(weapon: Dictionary, ammo: int) -> void:
	if pickup_ammo <= 0:
		def = def.duplicate(true)
		_saved_primary = def["primary"]
		_saved_gear = str(def["look"].get("gear", {}).get("right", ""))
	var w := weapon.duplicate(true)
	var gear := str(w.get("_gear", ""))
	for key in ["_gear", "_gear_left", "_back", "_source"]:
		w.erase(key)
	def["primary"] = w
	pickup_ammo = ammo
	if gear != "":
		var look: Dictionary = def["look"]
		var g: Dictionary = look.get("gear", {}).duplicate()
		g["right"] = gear
		look["gear"] = g
		_rebuild_model(def["look"])


func drop_pickup() -> void:
	pickup_ammo = 0
	if _saved_primary.is_empty():
		return
	def["primary"] = _saved_primary
	_saved_primary = {}
	var g: Dictionary = def["look"].get("gear", {}).duplicate()
	if _saved_gear == "":
		g.erase("right")
	else:
		g["right"] = _saved_gear
	def["look"]["gear"] = g
	_rebuild_model(def["look"])
	if is_player and world:
		world.notify("Out of ammo. Back to your own moves.", Color("#ffe8a0"))


## Telekinesis: lift the prop or person under the crosshair.
func tk_grab() -> bool:
	var from := head_pos()
	var dir := aim_dir(from)
	var best = null
	var best_score := 0.9
	for prop in get_tree().get_nodes_in_group("props"):
		var to: Vector3 = prop.global_position - from
		if to.length() > 40.0 or to.length() < 1.0:
			continue
		var sc := dir.dot(to.normalized())
		if sc > best_score:
			best_score = sc
			best = prop
	var foe := Powers.aimed_foe(self, 30.0, 0.92)
	if foe and (best == null or foe.global_position.distance_to(from) < best.global_position.distance_to(from)):
		if foe.size < 1.8 and not foe.boss:
			tk_actor = foe
			_tk_t = 0.0
			foe.grudges[get_instance_id()] = 20.0
			FX.aura(foe, Color(str(def["look"].get("trail", "#c47aff"))), foe.size, 1.0)
			model.play("levitate_cast", 0.6)
			Sfx.play("teleport", global_position, -4.0)
			return true
	if best:
		held_prop = best
		best.pick_up(self)
		tk_hold = true
		_tk_t = 0.0
		model.play("levitate_cast", 0.6)
		Sfx.play("teleport", global_position, -4.0)
		return true
	return false


## Let go: thrown at the crosshair, or just dropped.
func tk_release(throw := true) -> void:
	var dir := aim_dir(_tk_point())
	if tk_actor and is_instance_valid(tk_actor):
		var o := tk_actor
		tk_actor = null
		if throw:
			o.take_damage(28.0 * power, self, "", dir * 32.0 + Vector3.UP * 5.0)
			if o.size < 1.6:
				o.model.tumble(12.0)
		model.play("palm_push", 0.4)
	elif tk_hold and held_prop and is_instance_valid(held_prop):
		var prop: Prop = held_prop
		held_prop = null
		tk_hold = false
		prop.throw_from(self, dir * 55.0 + Vector3.UP * 2.0 if throw else Vector3.ZERO)
		model.play("palm_push", 0.4)
	tk_hold = false
	if throw:
		Sfx.play("whoosh", global_position, 2.0)


func _abilities(delta: float) -> void:
	if changing or blocking:
		return
	if civilian:
		_civilian_abilities()
		return
	if (tk_hold or tk_actor) and (in_primary or in_ability):
		tk_release(true)
		cooldowns["primary"] = 0.4
		cooldowns["utility"] = 0.4
		return
	if held_prop and (in_primary or in_ability):
		Abilities.throw_prop(self)
		cooldowns["primary"] = 0.4
		return
	if in_ability and cooldowns["utility"] <= 0.0 and can_act():
		style_kind = "utility"
		_use_utility()
	# Dive slam: attack while falling from a height to crash down on everyone.
	if in_primary and not is_on_floor() and not flying and not slam_pending and velocity.y < -1.0 and cooldowns["primary"] <= 0.0 \
			and def["primary"]["kind"] == "melee" and grapple_point == null and _height_above_ground() > 3.5:
		slam_pending = true
		velocity = Vector3(0, -55.0, 0) + forward() * 6.0
		cooldowns["primary"] = 0.8
		model.play("heavy", 0.5)
		style_kind = "slam"
		Sfx.play("whoosh", global_position, 2.0)
		return
	var any_beam := false
	for slot in ["primary", "secondary"]:
		var atk: Dictionary = def[slot]
		var held := in_primary if slot == "primary" else in_secondary
		if atk["kind"] in Abilities.HELD_KINDS:
			if held and energy > 2.0 and can_act():
				Abilities.held_tick(self, atk, delta, slot)
				if atk["kind"] == "beam":
					any_beam = true
			continue
		if held and cooldowns[slot] <= 0.0 and can_act():
			var cost := Abilities.energy_cost(atk)
			if energy >= cost or (is_player and Game.cheats["infinite_energy"]):
				energy -= cost
				cooldowns[slot] = Abilities.cooldown(atk)
				style_kind = str(atk["kind"]) + str(atk.get("style", ""))
				Abilities.fire(self, atk)
				if slot == "primary" and pickup_ammo > 0:
					pickup_ammo -= 1
					if pickup_ammo <= 0:
						drop_pickup()
	if not any_beam:
		for b in beams:
			if is_instance_valid(b):
				b.visible = false
	if in_ultimate and (ult >= 100.0 or is_player and Game.cheats["infinite_energy"]) and dampened_t <= 0.0:
		if Ultimate.start(self):
			ult = 0.0
	for i in powers.size():
		var key := "power%d" % (i + 1)
		if in_power[i] and cooldowns.get(key, 0.0) <= 0.0 and dampened_t <= 0.0 and can_act():
			var pw: Dictionary = powers[i]
			var pcost := Abilities.special_cost(pw)
			if energy >= pcost or (is_player and Game.cheats["infinite_energy"]):
				style_kind = str(pw["kind"])
				if Abilities.special(self, pw):
					energy -= pcost
					cooldowns[key] = Abilities.special_cooldown(pw)
	if in_special and cooldowns["special"] <= 0.0 and dampened_t <= 0.0:
		var sp: Dictionary = def["special"]
		var cost := Abilities.special_cost(sp)
		if energy >= cost or (is_player and Game.cheats["infinite_energy"]):
			style_kind = str(sp["kind"])
			if Abilities.special(self, sp):
				energy -= cost
				cooldowns["special"] = Abilities.special_cooldown(sp)


func _height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 60.0, Game.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return 60.0 if hit.is_empty() else global_position.y - hit["position"].y


## In street clothes: ordinary punches and kicks, nothing else.
func _civilian_abilities() -> void:
	for slot in ["primary", "secondary"]:
		var held := in_primary if slot == "primary" else in_secondary
		if held and cooldowns[slot] <= 0.0 and can_act():
			var atk: Dictionary = def[slot]
			cooldowns[slot] = Abilities.cooldown(atk)
			Abilities.fire(self, atk)
	if (in_special or in_ability or in_ultimate or in_fly_toggle) and is_player and world and cooldowns["special"] <= 0.0:
		cooldowns["special"] = 1.5
		world.notify("No powers in civilian clothes. Suit up with [T].", Color("#ffd27a"))


## Swaps between the costumed character and their everyday self.
func set_civilian(on: bool) -> void:
	if on == civilian:
		return
	if disguise_t > 0.0:
		_end_disguise()   # drop the Martian's borrowed shape first
	if on:
		suit_def = def
		var civ: Dictionary = def["civilian"]
		def = def.duplicate(true)
		def["look"] = civ["look"]
		def["primary"] = {"kind": "melee", "name": "Punch", "damage": 6.0, "style": "punch"}
		def["secondary"] = {"kind": "melee", "name": "Kick", "damage": 7.0, "style": "kick", "cooldown": 0.5}
		def.erase("utility")
		display_name = str(civ.get("name", display_name))
		def["alias"] = display_name
		movement = "run"
		strength = false
		flying = false
		power = 0.6
		speed_mult = 1.0
		civilian = true
		_release_grapple()
		if tk_hold or tk_actor:
			tk_release(false)
		if held_prop:
			Abilities.drop_prop(self)
		for b in beams:
			if is_instance_valid(b):
				b.visible = false
	else:
		def = suit_def
		suit_def = {}
		display_name = str(def.get("alias", def.get("name", display_name)))
		movement = def.get("movement", "run")
		strength = bool(def.get("strength", false))
		power = float(def.get("power", 1.0))
		speed_mult = float(def.get("speed", 1.0))
		civilian = false
		if is_player:
			power *= Game.rank_bonus()
	_rebuild_model(def["look"])
	model.scale = Vector3.ONE * _cur_scale()
	if movement == "hover":
		flying = true
	if on and is_player and world:
		# Changing out of sight shakes off the police and anyone hunting you.
		var watched := false
		for o in get_tree().get_nodes_in_group("actors"):
			if o != self and not o.dead and o.grudges.has(get_instance_id()) and o.global_position.distance_to(global_position) < 30.0:
				watched = true
		if not watched:
			for o in get_tree().get_nodes_in_group("actors"):
				o.grudges.erase(get_instance_id())
			if Game.heat > 0.0:
				Game.clear_heat()
				world.notify("Secret identity: nobody's looking for %s." % display_name, Color("#a0d0ff"))
	if world and is_player and world.hud:
		world.hud.on_player_changed()


## E: lift something heavy if there is something to lift, otherwise use the
## character's utility power (grapple, blitz, breach, phase...).
func _use_utility() -> void:
	if def.get("telekinetic", false) and held_prop == null and tk_actor == null:
		if tk_grab():
			cooldowns["utility"] = 0.4
			return
	if strength and held_prop == null:
		for prop in get_tree().get_nodes_in_group("props"):
			if prop.global_position.distance_to(global_position) < 5.0 * size:
				Abilities.pick_up(self)
				cooldowns["utility"] = 0.3
				return
	var util: Dictionary = def.get("utility", {})
	if util.is_empty():
		if movement == "grapple":
			util = {"kind": "grapple"}
		else:
			return
	if dampened_t > 0.0 and util["kind"] != "grapple":
		return
	var cost := Abilities.special_cost(util)
	if energy < cost and not (is_player and Game.cheats["infinite_energy"]):
		return
	if Abilities.special(self, util):
		energy -= cost
		cooldowns["utility"] = Abilities.special_cooldown(util)


func utility_name() -> String:
	if def.has("utility"):
		return str(def["utility"].get("name", def["utility"]["kind"]))
	if movement == "grapple":
		return "Grappling line"
	return ""


func combo_hit(n: int) -> void:
	combo_count += n
	combo_timer = 2.5
	if is_player and world and world.style:
		world.style.add(n, style_kind)


## Bosses get a second wind at half health: faster, angrier, with backup.
func _enrage() -> void:
	set_meta("enraged", true)
	rage_t = maxf(rage_t, 30.0)
	speed_mult *= 1.2
	stun_t = 0.0
	model.play("power_up", 0.9)
	if world == null:
		return
	var col := Color("#ff3a3a")
	FX.pillar(world, global_position, col, 40.0, 2.5, 1.0)
	FX.burst_lines(world, chest(), col, 5.0, 18)
	FX.shockwave(world, global_position, col, 10.0)
	world.notify("%s is enraged!" % display_name, Color("#ff6a6a"))
	for k in 2:
		var g: Actor = world.population.spawn_thug(global_position + Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6)))
		g.team = team
		g.set_meta("pinned", true)
		g.grudges = grudges.duplicate()


## A perfectly timed block: the attacker is staggered and time slows.
func _parry(source: Actor) -> void:
	source.stun_t = maxf(source.stun_t, 1.5)
	source.velocity = (source.global_position - global_position).normalized() * 8.0 + Vector3.UP * 3.0
	if world:
		FX.ring(world, chest(), Color("#ffe48a"), 2.5, 0.3, forward())
		FX.flash(world, chest() + forward() * 0.5, Color("#ffffff"), 1.0, 0.15, 0.7)
		Sfx.play("hit", global_position, 4.0, 0.0)
		if is_player:
			Game.hit_stop(0.18)
			world.notify("PERFECT PARRY!", Color("#ffe48a"))
			add_ult(12.0)
			if world.style:
				world.style.add(6, "parry")
			Game.record("parries")


func _tick_spheres(delta: float) -> void:
	if t_spheres_t <= 0.0:
		if not _sphere_nodes.is_empty():
			for n in _sphere_nodes:
				n.queue_free()
			_sphere_nodes.clear()
		return
	t_spheres_t -= delta
	if _sphere_nodes.is_empty():
		for i in 3:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.11
			sm.height = 0.22
			mi.mesh = sm
			mi.material_override = CharacterModel.mat(Color("#d02020"), 1.5)
			add_child(mi)
			_sphere_nodes.append(mi)
	var t := Time.get_ticks_msec() * 0.003
	for i in _sphere_nodes.size():
		var a := t + i * TAU / 3.0
		_sphere_nodes[i].position = Vector3(cos(a) * 0.9, 1.9 + sin(t * 2.0 + i) * 0.15, sin(a) * 0.9)
	_sphere_tick -= delta
	if _sphere_tick <= 0.0:
		_sphere_tick = 0.8
		Abilities.t_sphere_tick(self)


## Held in someone's telekinetic grip: float up, take damage, then get thrown.
func lift_by(holder: Actor, seconds: float, damage: float, color: Color) -> void:
	lifter = holder
	lift_t = seconds
	lift_damage = damage
	flying = false
	FX.aura(self, color, size, seconds)


func _lifted(delta: float) -> void:
	lift_t -= delta
	stun_t = maxf(stun_t, 0.1)
	if lifter == null or not is_instance_valid(lifter):
		lift_t = 0.0
		return
	var hold := lifter.global_position + lifter.forward() * 5.0 + Vector3.UP * 3.0
	velocity = (hold - global_position) * 5.0
	_raw_damage(lift_damage * 0.3 * delta / 1.4, lifter)
	if lift_t <= 0.0 and not dead:
		take_damage(lift_damage, lifter, "", lifter.aim_dir(chest()) * 26.0 + Vector3.UP * 6.0)
		model.tumble(14.0)
		lifter = null


func mind_control(controller: Actor, seconds: float) -> void:
	if controlled_t <= 0.0:
		_orig_team = team
		_orig_follow = follow_target
	controlled_t = seconds
	team = controller.team
	follow_target = controller
	grudges.clear()
	if brain:
		brain.target = null


func release_control() -> void:
	controlled_t = 0.0
	if _orig_team != "":
		team = _orig_team
	follow_target = _orig_follow
	_orig_team = ""


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
	if dead or changing:
		return
	if source and is_instance_valid(source) and source != self:
		last_attacker = source
		if not source.ult_active:
			source.add_ult(amount * (0.9 if source.is_player else 0.35))
		add_ult(amount * 0.4)
		if not is_player:
			grudges[source.get_instance_id()] = 10.0
		if source.is_player:
			if world and world.team_bonus != "":
				amount *= 1.2
			if Game.cheats["one_hit_ko"]:
				amount = hp + 1.0
			_player_hit_side_effects(amount)
		elif is_player:
			amount *= 0.5 * Game.damage_to_player()
		if source.rage_t > 0.0:
			amount *= 1.8
	if boss and not has_meta("enraged") and hp - amount < max_hp * 0.5 and hp > max_hp * 0.5:
		_enrage()
	if blocking and is_instance_valid(source):
		var to_src := source.global_position - global_position
		to_src.y = 0.0
		if to_src.length() < 0.2 or to_src.normalized().dot(forward()) > -0.1:
			if Time.get_ticks_msec() / 1000.0 - _block_start < 0.3:
				_parry(source)
				return
			amount *= 0.3
			knock *= 0.15
			if world:
				FX.sparks(world, chest() + forward() * 0.4, Color("#e8eef4"), 6, 4.0, 0.25)
	if invuln_t > 0.0:
		amount *= 0.1
		knock *= 0.2
	if is_player and world and world.style and amount > 2.0:
		world.style.hurt()
	if field_t > 0.0:
		amount = 0.0
		knock = Vector3.ZERO
		if world:
			FX.flash(world, chest(), Color("#5ce07a"), 1.2 * size, 0.15, 0.3)
	if shield_t > 0.0 and source and is_instance_valid(source):
		var to_src := (source.global_position - global_position).normalized()
		if to_src.dot(forward()) > 0.2:
			amount *= 0.1
			knock *= 0.1
			if world:
				FX.sparks(world, chest() + forward() * 0.5, Color("#e8eef4"), 6, 4.0)
	if not is_player and world and amount > 0.5:
		if hp_bar == null:
			hp_bar = FX.health_bar()
			add_child(hp_bar)
			hp_bar.position = Vector3(0, 2.25 * size, 0)
		hp_bar_t = 4.0
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
	if hp_bar:
		var fill: MeshInstance3D = hp_bar.get_node("Fill")
		var q: QuadMesh = fill.mesh
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		q.size.x = 0.86 * maxf(ratio, 0.001)
		q.center_offset.x = -0.43 + 0.43 * ratio
	damaged.emit(self, amount)
	if hp <= 0.0:
		var killer: Actor = source if is_instance_valid(source) else null
		if killer == null and is_instance_valid(last_attacker):
			killer = last_attacker
		die(killer)


func _player_hit_side_effects(amount: float) -> void:
	if team == "civilian":
		Game.add_heat(0.35)
	elif side() == 1 and Game.player_side() == 1 and not is_ally_of_player():
		Game.add_heat(0.25)
	elif side() == 1 and Game.player_side() == -1:
		Game.add_heat(0.08)


func add_ult(amount: float) -> void:
	if ult_active or dead:
		return
	var was := ult
	ult = minf(100.0, ult + amount)
	if is_player and was < 100.0 and ult >= 100.0 and world:
		world.notify("ULTIMATE READY  [R]  " + str(Ultimate.for_character(def).get("name", "")), Color("#ffd23a"))
		Sfx.play("event", null, -4.0)


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
	if tk_hold or (tk_actor and is_instance_valid(tk_actor)):
		tk_release(false)
	tk_hold = false
	for b in beams:
		if is_instance_valid(b):
			b.visible = false
	if stream:
		stream.emitting = false
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
	# Nothing from before the knockout carries over: being lifted, poison,
	# roots, dampening, a queued blitz or slam...
	lift_t = 0.0
	lifter = null
	poison_t = 0.0
	root_t = 0.0
	dampened_t = 0.0
	whirl_t = 0.0
	breath_t = 0.0
	dash_t = 0.0
	slam_pending = false
	blitz_queue.clear()
	tk_hold = false
	invuln_t = 2.0
	collision_layer = Game.LAYER_ACTORS
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PROPS | Game.LAYER_ACTORS
	model.hips.rotation = Vector3.ZERO


## The Martian Manhunter takes the shape of a passer-by: enemies lose you
## until you attack.
func shapeshift(seconds: float) -> void:
	if disguise_t > 0.0:
		return
	_true_look = def["look"]
	var civ: Dictionary = world.population.civilian_def() if world else {}
	_rebuild_model(civ.get("look", _true_look))
	disguise_t = seconds
	invis_t = maxf(invis_t, seconds)
	for o in get_tree().get_nodes_in_group("actors"):
		o.grudges.erase(get_instance_id())
	if world:
		FX.flash(world, chest(), Color("#5aff8a"), 2.0, 0.4)
		if is_player:
			world.notify("You look like just another civilian.", Color("#a0ffb0"))


func _end_disguise() -> void:
	disguise_t = 0.0
	invis_t = 0.0
	if not _true_look.is_empty():
		_rebuild_model(_true_look)
		_true_look = {}
	if world:
		FX.flash(world, chest(), Color("#5aff8a"), 2.0, 0.4)


func _rebuild_model(look: Dictionary) -> void:
	var old := model
	model = CharacterModel.new()
	add_child(model)
	model.build(look)
	model.scale = old.scale
	if old:
		old.queue_free()


func set_shrunk(value: bool) -> void:
	shrunk = value
	var s := _cur_scale()
	_apply_size(s)
	model.scale = Vector3.ONE * s


## Lets go of effect nodes that live in the world's fx root (beams, a flame
## stream, a grappling line), which is cleared when changing worlds.
func drop_fx_refs() -> void:
	for b in beams:
		if is_instance_valid(b):
			b.queue_free()
	beams.clear()
	beam_slot = ""
	if stream and is_instance_valid(stream):
		stream.queue_free()
	stream = null
	_release_grapple()


func _exit_tree() -> void:
	if grapple_line and is_instance_valid(grapple_line):
		grapple_line.queue_free()
	for b in beams:
		if is_instance_valid(b):
			b.queue_free()
	if stream and is_instance_valid(stream):
		stream.queue_free()
