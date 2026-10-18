class_name CameraRig
extends Node3D
## Third-person orbit camera with mouse / right-stick look, scroll zoom,
## collision against buildings, speed-based FOV and screen shake.

var target: Actor
var yaw := 0.0
var pitch := -0.2
var zoom := 5.5
var spring: SpringArm3D
var camera: Camera3D
var _shake := 0.0
var look_enabled := true
var _excluded := RID()


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = zoom
	spring.collision_mask = Game.LAYER_WORLD
	spring.margin = 0.3
	spring.position = Vector3(0.7, 0.0, 0.0)
	add_child(spring)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 2600.0
	camera.near = 0.08
	spring.add_child(camera)
	add_to_group("settings_listeners")
	on_settings_changed()
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Game.settings["mouse_sensitivity"] * 0.01
		yaw -= event.relative.x * sens
		var dy: float = event.relative.y * sens
		pitch += dy if Game.settings["invert_y"] else -dy
		pitch = clampf(pitch, -1.45, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(2.0, zoom - 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(18.0, zoom + 0.6)


func on_settings_changed() -> void:
	camera.far = float(Game.settings["view_distance"]) + 1400.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if look_enabled:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.15:
			yaw -= stick.x * real * 2.6
			pitch = clampf(pitch - stick.y * real * 2.0 * (-1.0 if Game.settings["invert_y"] else 1.0), -1.45, 1.2)
	rotation = Vector3(pitch, yaw, 0)
	if target == null or not is_instance_valid(target):
		return
	var s := target._cur_scale()
	var focus := target.global_position + Vector3.UP * 1.65 * s
	global_position = global_position.lerp(focus, clampf(real * 18.0, 0.0, 1.0))
	if global_position.distance_to(focus) > 8.0:
		global_position = focus
	spring.spring_length = lerpf(spring.spring_length, zoom * maxf(0.5, s), clampf(real * 6.0, 0.0, 1.0))
	spring.position.x = 0.7 * maxf(0.4, s)
	if target.get_rid() != _excluded:
		spring.clear_excluded_objects()
		_excluded = target.get_rid()
		spring.add_excluded_object(_excluded)
	var speed := Vector3(target.velocity.x, 0, target.velocity.z).length()
	var base_fov: float = Game.settings["fov"]
	camera.fov = lerpf(camera.fov, base_fov + clampf((speed - 12.0) * 0.35, 0.0, 22.0), clampf(real * 4.0, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - real * 1.8)
		camera.h_offset = randf_range(-1, 1) * _shake * 0.3
		camera.v_offset = randf_range(-1, 1) * _shake * 0.3
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## The world point under the crosshair (ignores the player).
func aim_point(player: Actor) -> Vector3:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var to := from + dir * 400.0
	var exclude: Array[RID] = [player.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ACTORS | Game.LAYER_PROPS, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	# Ignore hits between the camera and the player.
	var hp: Vector3 = hit["position"]
	if (hp - from).length() < (player.global_position - from).length() - 0.5:
		return to
	return hp
