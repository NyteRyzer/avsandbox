class_name SpeedForceFX
extends Node3D
## Keeps the Speed Force alive: the time vortex turns, memories drift and
## spin, and blue and gold lightning crackles all around whoever is there.

var rings: Array = []          # MeshInstance3D, each with a spin speed in meta
var drifting: Array = []       # Node3D memories that bob and turn
var _t := 0.0
var _bolt_t := 0.0


func _process(delta: float) -> void:
	_t += delta
	for r in rings:
		if is_instance_valid(r):
			r.rotate_object_local(Vector3.UP, float(r.get_meta("spin", 0.3)) * delta)
	for m in drifting:
		if is_instance_valid(m):
			var base: Vector3 = m.get_meta("base", m.position)
			m.position = base + Vector3(0, sin(_t * 0.4 + float(m.get_meta("phase", 0.0))) * 3.0, 0)
			m.rotation.y += delta * float(m.get_meta("turn", 0.05))
	var world = get_parent().get_parent()
	if world == null or not ("fx_root" in world) or world.player == null or not is_instance_valid(world.player):
		return
	if DisplayServer.get_name() == "headless":
		return
	_bolt_t -= delta
	if _bolt_t > 0.0:
		return
	_bolt_t = randf_range(0.06, 0.18)
	var p: Vector3 = world.player.global_position
	# Arcs of blue and gold lightning across the void, some close, some far.
	var color := Color("#4fa8ff") if randf() < 0.55 else Color("#ffd23a")
	var center := p + Vector3(randf_range(-60, 60), randf_range(4, 50), randf_range(-60, 60))
	var a := center + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)).normalized() * randf_range(8.0, 30.0)
	var b := center - (a - center)
	FX.lightning(world, a, b, color, randf_range(0.15, 0.35), randf_range(1.5, 4.0), 9, 2)
