class_name PlayerBrain
extends RefCounted
## Reads keyboard, mouse and gamepad input and steers the player's Actor
## relative to the camera.

var cam_rig: CameraRig
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
	a.aim_point = cam_rig.aim_point(a)
	if a.in_primary or a.in_secondary:
		_aim_hold = 0.6
	_aim_hold = maxf(0.0, _aim_hold - delta)
	var flat_move := Vector3(a.in_move.x, 0, a.in_move.z)
	if _aim_hold > 0.0 or (a.flying and flat_move.length() < 0.1):
		a.face_dir = fwd
	elif flat_move.length() > 0.1:
		a.face_dir = flat_move.normalized()
