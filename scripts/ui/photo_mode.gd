class_name PhotoMode
extends CanvasLayer
## Photo mode (P): the world freezes, the HUD hides, and a free camera flies
## around the scene. F cycles filters, Space (or Enter) saves a photo to
## user://photos, P or Esc returns to the game.

const FILTERS := ["None", "Noir", "Sepia", "Vivid", "Speed Force"]

var world
var active := false
var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _filter := 0
var _label: Label
var _tint: ColorRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0, 0, 0, 0)
	add_child(_tint)
	_label = UITheme.label("", 16, Color(1, 1, 1, 0.85))
	_label.position = Vector2(20, 20)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)
	visible = false


func toggle() -> void:
	if active:
		close()
	elif not get_tree().paused:
		open()


func open() -> void:
	active = true
	visible = true
	get_tree().paused = true
	world.hud.visible = false
	var src: Camera3D = world.cam.camera
	_cam = Camera3D.new()
	_cam.fov = src.fov
	_cam.far = src.far
	world.add_child(_cam)
	_cam.global_transform = src.global_transform
	_yaw = world.cam.yaw
	_pitch = world.cam.pitch
	_cam.current = true
	_apply_filter()
	_update_label("")


func close() -> void:
	active = false
	visible = false
	get_tree().paused = false
	world.hud.visible = true
	world.cam.camera.current = true
	if _cam:
		_cam.queue_free()
		_cam = null
	_filter = 0
	_apply_filter()


func _update_label(extra: String) -> void:
	_label.text = "PHOTO MODE   WASD/QE fly · mouse look · Shift fast · F filter (%s) · Space save · P exit%s" % [FILTERS[_filter], extra]


func _apply_filter() -> void:
	var env: Environment = world.day_night.env
	env.adjustment_enabled = _filter != 0
	env.adjustment_saturation = [1.0, 0.0, 0.25, 1.6, 0.6][_filter]
	env.adjustment_contrast = [1.0, 1.25, 1.05, 1.15, 1.2][_filter]
	env.adjustment_brightness = [1.0, 1.0, 1.05, 1.0, 1.1][_filter]
	_tint.color = [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.55, 0.35, 0.1, 0.22), Color(0, 0, 0, 0), Color(1.0, 0.85, 0.2, 0.12)][_filter]


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.004
		_pitch = clampf(_pitch - event.relative.y * 0.004, -1.5, 1.5)
	elif event.is_action_pressed("photo") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F:
				_filter = (_filter + 1) % FILTERS.size()
				_apply_filter()
				_update_label("")
			KEY_SPACE, KEY_ENTER:
				_save()


func _process(delta: float) -> void:
	if not active or _cam == null:
		return
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.z -= 1
	if Input.is_physical_key_pressed(KEY_S):
		move.z += 1
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1
	if Input.is_physical_key_pressed(KEY_E):
		move.y += 1
	if Input.is_physical_key_pressed(KEY_Q):
		move.y -= 1
	var speed := 30.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 8.0
	var basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	_cam.global_position += basis * move * speed * delta
	_cam.global_basis = basis


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("user://photos")
	_label.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://photos/photo_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	_label.visible = true
	Game.record("photos")
	_update_label("   ·   Saved " + ProjectSettings.globalize_path(path))
