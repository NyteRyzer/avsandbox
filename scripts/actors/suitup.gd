class_name Suitup
extends Node
## Changing in and out of costume (T). Every character with a secret identity
## has their own transformation (the Flash's suit shooting out of his ring,
## Superman ripping open his shirt, Killer Frost's frost spreading...). In
## civilian clothes you can only throw ordinary punches and kicks: no powers,
## flight, super speed or ultimates. Enemies don't recognise you until you
## start a fight.

const TIME := 1.0

var actor: Actor
var to_civilian := false
var t := 0.0
var _swapped := false
var _tick := 0.0


static func can_change(a: Actor) -> bool:
	var d: Dictionary = a.suit_def if a.civilian else a.def
	return d.has("civilian") and d.has("transform")


## Starts a change. Returns false (with a message) if it can't happen now.
static func toggle(a: Actor) -> bool:
	if a.changing or a.dead or a.world == null:
		return false
	if not can_change(a):
		if a.is_player:
			a.world.notify("%s has no secret identity." % a.display_name, Color("#ffd27a"))
		return false
	var s := Suitup.new()
	s.actor = a
	s.to_civilian = not a.civilian
	a.changing = true
	a.world.fx_root.add_child(s)
	s._begin()
	return true


func _style() -> String:
	var d: Dictionary = actor.suit_def if actor.civilian else actor.def
	return str(d["transform"]["style"])


func _color() -> Color:
	var d: Dictionary = actor.suit_def if actor.civilian else actor.def
	return Color(str(d["transform"]["color"]))


func _begin() -> void:
	var w = actor.world
	actor.velocity = Vector3(0, actor.velocity.y, 0)
	actor.flying = false
	var c := _color()
	match _style():
		"speed_ring", "speed_formula", "helmet_spin":
			Sfx.play("zap", actor.global_position, 2.0)
		"shirt_rip":
			actor.model.play("two_hands", 0.5)
			Sfx.play("whoosh", actor.global_position, 2.0)
		"nanites", "armor_up", "steel", "glitch":
			Sfx.play("beam", actor.global_position, 0.0)
		"smoke", "hood", "mask_on":
			FX.smoke(w, actor.chest(), 2.2, 1.4)
			Sfx.play("smoke", actor.global_position, 0.0)
		"lightning_strike", "electric":
			var top := actor.global_position + Vector3(0, 30, 0)
			FX.storm_cloud(w, top, 4.0, 0.5)
			Sfx.play("lightning", actor.global_position, 2.0)
		"fusion", "ignite":
			Sfx.play("fire", actor.global_position, 2.0)
		"frost", "cold_snap":
			Sfx.play("freeze", actor.global_position, 2.0)
		"magic_circle", "spectral", "dream", "dark_mist", "cosmic", "storm", "mirror", "breach", "totem", "martian", "wings", "density", "stretch":
			Sfx.play("teleport", actor.global_position, 0.0)
	if not to_civilian and actor.is_player:
		var d: Dictionary = actor.suit_def
		w.notify("%s %s" % [d["civilian"]["name"], d["transform"]["text"]], c.lightened(0.3))


func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.dead:
		if is_instance_valid(actor):
			actor.changing = false
		queue_free()
		return
	t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.06
		_effect(clampf(t / TIME, 0.0, 1.0))
	if not _swapped and t >= TIME * 0.55:
		_swapped = true
		actor.set_civilian(to_civilian)
		_reveal()
	if t >= TIME:
		actor.changing = false
		if is_instance_valid(actor.model):
			actor.model.rotation = Vector3.ZERO
			actor.model.scale = Vector3.ONE * actor._cur_scale()
		queue_free()


## The look of each transformation, frame by frame (u: 0 -> 1).
func _effect(u: float) -> void:
	var w = actor.world
	var c := _color()
	var p := actor.global_position
	var chest := actor.chest()
	var m := actor.model
	match _style():
		"speed_ring":
			# A spiral of lightning, then a blur.
			var ang := u * TAU * 3.0
			var r := 1.1
			var a := p + Vector3(cos(ang) * r, 0.2 + u * 1.8, sin(ang) * r)
			var b := p + Vector3(cos(ang + 1.2) * r, 0.4 + u * 1.8, sin(ang + 1.2) * r)
			FX.lightning(w, a, b, c, 0.15, 0.4, 4, 0)
			m.rotation.y = u * TAU * 4.0
		"speed_formula":
			FX.ring(w, p + Vector3.UP * (0.2 + u * 2.0), c, 1.0 + u, 0.2)
			if randf() < 0.5:
				FX.lightning(w, chest, chest + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), c, 0.12, 0.3, 3, 0)
		"helmet_spin":
			m.rotation.y = sin(u * PI) * TAU
			FX.sparks(w, actor.head_pos() + Vector3.UP * 0.2, c, 3, 3.0, 0.3)
		"shirt_rip":
			if u > 0.4 and u < 0.65:
				FX.flash(w, chest + actor.forward() * 0.3, c, 1.4, 0.15, 0.6)
				FX.sparks(w, chest + actor.forward() * 0.3, c, 6, 5.0, 0.3)
			m.rotation.y = maxf(0.0, u - 0.5) * TAU * 2.0
		"nanites", "armor_up", "glitch":
			# Plates assemble from the feet up.
			var y := lerpf(0.0, 2.0 * actor.size, u)
			FX.ring(w, p + Vector3.UP * y, c, 0.6 * actor.size, 0.12)
			FX.sparks(w, p + Vector3.UP * y, c, 4, 2.0, 0.2)
			if _style() == "glitch" and randf() < 0.4:
				m.visible = not m.visible
			else:
				m.visible = true
		"steel":
			FX.ring(w, p + Vector3.UP * lerpf(2.0, 0.0, u) * actor.size, c, 0.7 * actor.size, 0.15)
		"smoke", "hood", "mask_on":
			if u < 0.6:
				m.visible = u < 0.15 or u > 0.5
			else:
				m.visible = true
			if _style() == "hood" and u > 0.5 and u < 0.6:
				FX.flash(w, actor.head_pos(), c, 0.6, 0.15, 0.4)
		"lightning_strike":
			if u > 0.45 and u < 0.6:
				FX.lightning(w, p + Vector3(0, 30, 0), p, c, 0.3, 1.5, 10, 2)
				FX.flash(w, chest, c, 1.2, 0.2, 0.45)
		"electric":
			FX.lightning(w, chest, chest + Vector3(randf_range(-1.5, 1.5), randf_range(-1, 1.5), randf_range(-1.5, 1.5)), c, 0.12, 0.4, 4, 0)
		"fusion", "ignite":
			FX.sparks(w, chest, c, 8, 4.0, 0.4)
			if u > 0.5 and u < 0.62:
				FX.flash(w, chest, c, 1.4 if _style() == "fusion" else 0.9, 0.25, 0.5)
		"frost", "cold_snap":
			FX.ring(w, p + Vector3.UP * 0.1, c, u * 3.0, 0.2)
			FX.sparks(w, chest, Color("#ffffff"), 4, 2.0, 0.6)
		"breach":
			FX.ring(w, chest, c, 0.5 + u * 1.5, 0.15, actor.forward())
			if u > 0.5 and u < 0.6:
				FX.breach(w, chest + actor.forward() * 0.8, c, 0.4, 1.2)
		"totem":
			FX.ring(w, p + Vector3.UP * 0.1, c, 1.6, 0.2)
			if u > 0.5 and u < 0.6:
				FX.aura(actor, c, actor.size, 0.6)
		"wings":
			if u > 0.45 and u < 0.6:
				FX.flash(w, chest - actor.forward() * 0.3, c, 1.1, 0.25, 0.5)
				FX.sparks(w, chest - actor.forward() * 0.3, c, 14, 6.0, 0.5)
		"cosmic":
			FX.sparks(w, chest + Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2)), c, 2, 1.0, 0.4)
			if u > 0.5 and u < 0.6:
				FX.flash(w, actor.hand_pos(), c, 0.7, 0.25, 0.6)
		"martian":
			m.scale = Vector3.ONE * actor._cur_scale() * (1.0 + sin(u * PI * 6.0) * 0.06)
			FX.sparks(w, chest, c, 3, 1.5, 0.4)
		"stretch":
			m.scale = Vector3(1.0 - sin(u * PI) * 0.3, 1.0 + sin(u * PI) * 0.9, 1.0 - sin(u * PI) * 0.3) * actor._cur_scale()
		"magic_circle":
			FX.ring(w, p + Vector3.UP * 0.05, c, 1.8, 0.2)
			FX.sparks(w, actor.hand_pos(), c, 2, 1.0, 0.4)
		"spectral", "dream", "dark_mist":
			FX.ring(w, p + Vector3.UP * (u * 2.0), c, 1.2, 0.2)
			if u > 0.5 and u < 0.6:
				FX.flash(w, chest, c, 1.2, 0.25, 0.45)
		"storm":
			if randf() < 0.4:
				var q := p + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
				FX.lightning(w, q + Vector3.UP * 25.0, q, c, 0.2, 1.0, 6, 1)
		"mirror":
			FX.sparks(w, chest, c, 6, 4.0, 0.4)
			m.visible = u < 0.3 or u > 0.55
		"density":
			m.scale = Vector3.ONE * actor._cur_scale() * (1.0 + sin(u * PI) * 0.08)
			FX.ring(w, p + Vector3.UP * 0.1, c, 1.5, 0.15)


func _reveal() -> void:
	var w = actor.world
	var c := _color()
	actor.model.visible = true
	FX.flash(w, actor.chest(), c, 0.8, 0.2, 0.35)
	if to_civilian and actor.is_player:
		w.notify("Back to %s. Powers off: suit up with [T]." % actor.def["name"], Color("#c8d0e0"))
