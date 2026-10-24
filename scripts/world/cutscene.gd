class_name Cutscene
extends CanvasLayer
## In-engine cutscenes: letterbox bars, a film camera that dollies between
## shots, and subtitled lines with the speaker's name. While one plays the
## player can't act, everyone else holds still, and the HUD hides. Space,
## Esc or G skips the rest.
##
## A shot is a Dictionary:
##   from, to     - camera positions at the start and end of the shot
##   look         - a Vector3, or a Node3D to keep framed (its chest/head)
##   dur          - seconds
##   speaker      - who's talking ("" for none), color - their name colour
##   line         - the subtitle
##   action       - optional [Actor, animation] played as the shot starts
##   black        - true for a black screen (voice-over)
##   title, sub   - a title card in the middle of the screen

signal finished(skipped: bool)

const BAR_H := 0.12          # letterbox bars, fraction of the screen height

var world
var active := false
var _shots: Array = []
var _index := -1
var _t := 0.0
var _done: Callable
var _cam: Camera3D
var _top: ColorRect
var _bottom: ColorRect
var _speaker: Label
var _line: Label
var _skip: Label
var _black: ColorRect
var _title: Label
var _sub: Label
var _shown_chars := 0.0
var _hud_was := true
var _age := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_title = _label(84)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.anchor_top = 0.36
	_title.anchor_bottom = 0.5
	_title.add_theme_constant_override("outline_size", 16)
	_title.add_theme_color_override("font_outline_color", Color("#a3111a"))
	add_child(_title)
	_sub = _label(22)
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.anchor_top = 0.52
	_sub.anchor_bottom = 0.62
	_sub.add_theme_color_override("font_color", Color("#ffd27a"))
	add_child(_sub)
	_top = _bar(true)
	_bottom = _bar(false)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.anchor_left = 0.12
	box.anchor_right = 0.88
	box.anchor_top = 1.0 - BAR_H - 0.13
	box.anchor_bottom = 1.0 - BAR_H - 0.01
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_speaker = _label(22)
	box.add_child(_speaker)
	_line = _label(26)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_skip = _label(14)
	_skip.text = "[Space]  Skip"
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.anchor_left = 1.0
	_skip.anchor_top = 1.0
	_skip.offset_left = -170
	_skip.offset_top = -34
	_skip.modulate = Color(1, 1, 1, 0.6)
	add_child(_skip)
	_set_visible(false)


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR_H
	r.anchor_bottom = BAR_H if top else 1.0
	add_child(r)
	return r


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _set_visible(on: bool) -> void:
	for n in [_top, _bottom, _speaker, _line, _skip]:
		n.visible = on
	if not on:
		_black.visible = false
		_title.visible = false
		_sub.visible = false


## Are cutscenes switched on? (Settings, and off for the automated tests.)
static func enabled() -> bool:
	return bool(Game.settings.get("cutscenes", true)) and not Game.no_cinematics


## Plays `shots`, then calls `done(skipped)`. With cutscenes switched off it
## calls `done` straight away.
func play(shots: Array, done := Callable()) -> void:
	if not enabled() or shots.is_empty() or world == null or world.player == null:
		if done.is_valid():
			done.call(true)
		return
	if active:
		_end(true)
	_shots = shots
	_done = done
	active = true
	world.cinematic = true
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.far = 3000.0
		world.add_child(_cam)
	_cam.fov = 55.0
	_cam.current = true
	_hud_was = world.hud.root.visible
	world.hud.root.visible = false
	_set_visible(true)
	_index = -1
	_age = 0.0
	_next()


func _next() -> void:
	_index += 1
	if _index >= _shots.size():
		_end(false)
		return
	_t = 0.0
	_shown_chars = 0.0
	var s: Dictionary = _shots[_index]
	_speaker.text = str(s.get("speaker", "")).to_upper()
	_speaker.add_theme_color_override("font_color", s.get("color", Color("#ffd27a")))
	_line.text = str(s.get("line", ""))
	_line.visible_characters = 0
	var act: Array = s.get("action", [])
	if act.size() == 2 and is_instance_valid(act[0]):
		act[0].model.play(str(act[1]), 0.8)
	if s.has("sfx"):
		Sfx.play(str(s["sfx"]), null, 0.0)
	_black.visible = bool(s.get("black", false))
	_title.text = str(s.get("title", ""))
	_title.visible = _title.text != ""
	_sub.text = str(s.get("sub", ""))
	_sub.visible = _sub.text != ""
	if not s.has("from") and world.player and is_instance_valid(world.player):
		# Black screens and title cards: park the camera looking at the sky.
		s["from"] = world.player.global_position + Vector3(0, 30, 20)
		s["look"] = world.player.global_position + Vector3(0, 60, -40)
	_frame(0.0)


func _look_point(s: Dictionary) -> Vector3:
	var l = s.get("look", Vector3.ZERO)
	if l is Actor and is_instance_valid(l):
		return l.head_pos() - Vector3.UP * 0.15
	if l is Node3D and is_instance_valid(l):
		return l.global_position
	return l if l is Vector3 else Vector3.ZERO


func _frame(k: float) -> void:
	var s: Dictionary = _shots[_index]
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector3 = s.get("from", Vector3.ZERO)
	var to: Vector3 = s.get("to", from)
	_cam.global_position = from.lerp(to, e)
	var at := _look_point(s)
	if at.distance_to(_cam.global_position) > 0.05:
		_cam.look_at(at, Vector3.UP)


func _process(delta: float) -> void:
	if not active:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	_age += real
	# A short grace period, so the key press that started it doesn't skip it.
	if _age > 0.35 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("interact")):
		skip()
		return
	_t += real
	var s: Dictionary = _shots[_index]
	var dur := float(s.get("dur", 3.0))
	_shown_chars += real * 45.0
	_line.visible_characters = int(_shown_chars)
	_frame(clampf(_t / dur, 0.0, 1.0))
	if _t >= dur:
		_next()


func skip() -> void:
	if active:
		_end(true)


func _end(skipped: bool) -> void:
	active = false
	_set_visible(false)
	if world:
		world.cinematic = false
		if world.hud:
			world.hud.root.visible = _hud_was
		if world.cam and world.cam.camera:
			world.cam.camera.current = true
	var cb := _done
	_done = Callable()
	finished.emit(skipped)
	if cb.is_valid():
		cb.call(skipped)


# --- Ready-made shots ---------------------------------------------------------

## A slow aerial sweep around `center`, for chapter openings.
static func aerial(center: Vector3, dur: float, speaker: String, line: String, color := Color("#ffd27a")) -> Dictionary:
	var a := randf() * TAU
	return {"from": center + Vector3(cos(a) * 60.0, 40.0, sin(a) * 60.0), "to": center + Vector3(cos(a + 0.7) * 45.0, 25.0, sin(a + 0.7) * 45.0),
		"look": center + Vector3.UP * 2.0, "dur": dur, "speaker": speaker, "line": line, "color": color}


## A push-in on someone's face from in front of them.
static func close_up(who: Actor, dur: float, line: String, color := Color("#ffd27a"), action := "") -> Dictionary:
	var fwd := who.forward()
	var head := who.head_pos()
	var side := fwd.cross(Vector3.UP).normalized()
	var s := {"from": head + fwd * 4.2 + side * 1.2 + Vector3.UP * 0.3, "to": head + fwd * 2.4 + side * 0.6 + Vector3.UP * 0.1,
		"look": who, "dur": dur, "speaker": str(who.display_name).replace(" (BOSS)", ""), "line": line, "color": color}
	if action != "":
		s["action"] = [who, action]
	return s


## Over `a`'s shoulder, looking at `b`.
static func over_shoulder(a: Actor, b: Actor, dur: float, line: String, color := Color("#9fd8ff")) -> Dictionary:
	var to := b.global_position - a.global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.1 else a.forward()
	var side := dir.cross(Vector3.UP).normalized()
	var eye := a.head_pos() - dir * 2.6 + side * 0.9 + Vector3.UP * 0.35
	return {"from": eye, "to": eye + dir * 0.8, "look": b, "dur": dur, "speaker": str(a.display_name).replace(" (BOSS)", ""), "line": line, "color": color}


## Both fighters in frame, side on.
static func two_shot(a: Actor, b: Actor, dur: float, speaker := "", line := "", color := Color("#ffd27a")) -> Dictionary:
	var mid := (a.chest() + b.chest()) * 0.5
	var to := b.global_position - a.global_position
	to.y = 0.0
	var side := to.normalized().cross(Vector3.UP).normalized() if to.length() > 0.1 else Vector3.RIGHT
	var dist := clampf(to.length() * 0.9 + 5.0, 7.0, 30.0)
	return {"from": mid + side * dist + Vector3.UP * 2.0, "to": mid + side * (dist * 0.8) + Vector3.UP * 1.2,
		"look": mid, "dur": dur, "speaker": speaker, "line": line, "color": color}
