class_name PlayerBrain
extends RefCounted
## Reads keyboard, mouse and gamepad input and steers the player's Actor
## relative to the camera.

var cam_rig: CameraRig


## The hostile nearest the crosshair, within 50 m.
func _pick_lock(a: Actor) -> Actor:
	var cam: Camera3D = cam_rig.camera
	var dir := -cam.global_basis.z
	var best: Actor = null
	var best_score := 0.0
	for o in a.get_tree().get_nodes_in_group("actors"):
		if o == a or o.dead or o.team == "civilian" or not (o.is_hostile_to(a) or a.is_hostile_to(o) or o.grudges.has(a.get_instance_id())):
			continue
		var to: Vector3 = o.chest() - cam.global_position
		var d := to.length()
		if d > 50.0:
			continue
		var score := dir.dot(to.normalized()) - d / 400.0
		if score > best_score:
			best_score = score
			best = o
	return best
var _aim_hold := 0.0
var enabled := true


func update(a: Actor, delta: float) -> void:
	a.in_primary = false
	a.in_secondary = false
	if not enabled or cam_rig == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, cam_rig.yaw)
	var fwd := -yaw_basis.z
	var right := yaw_basis.x
	var move := right * input.x + fwd * -input.y
	a.in_sprint = Input.is_action_pressed("sprint")
	if a.flying:
		# Flying follows the camera's pitch so you can dive and climb.
		var cam_fwd := -cam_rig.camera.global_basis.z
		move = right * input.x + cam_fwd * -input.y
	a.in_move = move.limit_length(1.0)
	a.in_jump = Input.is_action_just_pressed("jump")
	a.in_up = Input.is_action_pressed("jump")
	a.in_down = Input.is_action_pressed("descend")
	a.in_fly_toggle = Input.is_action_just_pressed("fly")
	a.in_primary = Input.is_action_pressed("attack")
	a.in_secondary = Input.is_action_pressed("secondary")
	a.in_special = Input.is_action_just_pressed("special")
	a.in_ability = Input.is_action_just_pressed("ability")
	a.in_dodge = Input.is_action_just_pressed("dodge")
	a.in_ultimate = Input.is_action_just_pressed("ultimate")
	a.in_block = Input.is_action_pressed("block")
	a.aim_point = cam_rig.aim_point(a)
	# Lock-on: the camera tracks the target and every attack aims at it.
	if Input.is_action_just_pressed("lock_on"):
		a.lock_target = null if a.lock_target else _pick_lock(a)
	var lt := a.lock_target
	if lt and (not is_instance_valid(lt) or lt.dead or lt.global_position.distance_to(a.global_position) > 70.0):
		a.lock_target = null
		lt = null
	if lt:
		a.aim_point = lt.chest()
		var to := lt.global_position - a.global_position
		if Vector2(to.x, to.z).length() > 1.0:
			cam_rig.yaw = lerp_angle(cam_rig.yaw, atan2(-to.x, -to.z), clampf(delta * 5.0, 0.0, 1.0))
			_aim_hold = 0.3
	if a.in_primary or a.in_secondary:
		_aim_hold = 0.6
	_aim_hold = maxf(0.0, _aim_hold - delta)
	var flat_move := Vector3(a.in_move.x, 0, a.in_move.z)
	if _aim_hold > 0.0 or (a.flying and flat_move.length() < 0.1):
		a.face_dir = fwd
	elif flat_move.length() > 0.1:
		a.face_dir = flat_move.normalized()
