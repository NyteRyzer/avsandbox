class_name Incident
extends Activity
## More events that aren't just "knock everyone out":
##   incursion - a hostile breach tears open and keeps sending doppelgangers
##               from other Earths through until you smash it shut.
##   falling   - people tumble off the rooftops; catch them (or be standing
##               where they land) before they hit the street.
##   meteors   - a meteor shower: smash the rocks before they crash down.
##   runaway   - a car with failed brakes careers through traffic; get in
##               front of it and stop it without wrecking it.

const KINDS := ["incursion", "falling", "meteors", "runaway"]

# incursion
var breach: BreachPortal
var breach_body: HitTarget
var invaders: Array = []
var _spawn_t := 2.0
# falling
var fallers: Array = []     # {actor, vel, state}
var _next_fall := 0.0
var _falls_left := 0
var caught := 0
var dropped := 0
# meteors
var meteors: Array = []     # {node, target, ring, vel}
var _meteors_left := 0
var smashed := 0
var landed := 0
# runaway
var runaway_car: Prop
var _was_driving := false
var stopped := false


func start(p_world, p_kind: String, near: Vector3) -> bool:
	world = p_world
	kind = p_kind
	match kind:
		"incursion":
			return _start_incursion(near)
		"falling":
			return _start_falling(near)
		"meteors":
			center = world.city.random_road_point(near, 70.0, 140.0)
			_meteors_left = 8
			total = 8
			return true
		"runaway":
			return _start_runaway(near)
	return false


func remaining() -> int:
	match kind:
		"incursion":
			var alive := invaders.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
			return alive + (1 if is_instance_valid(breach_body) and not breach_body.dead else 0)
		"falling":
			return total - caught - dropped
		"meteors":
			return total - smashed - landed
		"runaway":
			return 0 if stopped else 1
	return 0


func marker_pos() -> Vector3:
	match kind:
		"falling":
			for f in fallers:
				if f["state"] == "falling" and is_instance_valid(f["actor"]):
					return f["actor"].global_position
		"runaway":
			if is_instance_valid(runaway_car):
				return runaway_car.global_position
	return center


func _process(delta: float) -> void:
	if world == null or done or failed:
		return
	time += delta
	match kind:
		"incursion":
			_tick_incursion(delta)
		"falling":
			_tick_falling(delta)
		"meteors":
			_tick_meteors(delta)
		"runaway":
			_tick_runaway(delta)
	if time > 300.0 and not done:
		failed = true


func cleanup() -> void:
	if is_instance_valid(breach):
		breach.close()
	for a in invaders:
		if is_instance_valid(a) and not a.dead:
			a.event_tag = ""
	for f in fallers:
		if is_instance_valid(f["actor"]) and f["state"] == "falling":
			f["actor"].queue_free()
	for m in meteors:
		_free_meteor(m)
	if is_instance_valid(runaway_car) and runaway_car.driving:
		runaway_car.getaway = false
		runaway_car.stop_driving()
	queue_free()


# --- Breach incursion ----------------------------------------------------------

func _start_incursion(near: Vector3) -> bool:
	center = world.city.random_road_point(near, 80.0, 160.0)
	var color := Color("#ff4a6a")
	breach = BreachPortal.new().setup(world, "", color, "HOSTILE BREACH")
	breach.walkable = false
	breach.lifetime = 9999.0
	add_child(breach)
	breach.global_position = center + Vector3.UP * 2.2
	var face := Vector3(near.x, breach.global_position.y, near.z)
	if face.distance_to(breach.global_position) > 1.0:
		breach.look_at(face, Vector3.UP)
	breach_body = HitTarget.new().setup(world, 260.0 + 40.0 * Game.rank(), 1.9)
	add_child(breach_body)
	breach_body.global_position = breach.global_position
	breach_body.destroyed.connect(_breach_destroyed)
	total = 1
	return true


func _tick_incursion(delta: float) -> void:
	if not is_instance_valid(breach_body) or breach_body.dead:
		if invaders.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).is_empty():
			done = true
		return
	# The breach flickers harder as it weakens.
	if is_instance_valid(breach):
		breach.scale = Vector3.ONE * lerpf(0.75, 1.0, breach_body.hp / breach_body.max_hp)
	_spawn_t -= delta
	var alive := invaders.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead).size()
	if _spawn_t <= 0.0 and alive < 3:
		_spawn_t = 9.0
		var hero: bool = Game.player_side() == 1
		var c := Game.random_character("villain" if hero else "hero")
		var a: Actor = world.population.spawn_character(c, "villain" if hero else "hero", center + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)))
		a.display_name = "Earth-%d %s" % [randi_range(2, 52), c["alias"]]
		a.event_tag = "incursion"
		a.set_meta("pinned", true)
		a.grudges[world.player.get_instance_id()] = 60.0
		a.brain.home = center
		a.brain.leash = 40.0
		a.brain.detect = 45.0
		invaders.append(a)
		total = maxi(total, invaders.size() + 1)
		FX.flash(world, center + Vector3.UP * 1.5, Color("#ff4a6a"), 2.0, 0.3, 0.6)
		world.notify("%s comes through the breach!" % a.display_name, Color("#ff7a8a"))


func _breach_destroyed() -> void:
	if is_instance_valid(breach):
		breach.close()
	FX.flash(world, center + Vector3.UP * 2.2, Color.WHITE, 5.0, 0.5, 0.9)
	FX.ring(world, center + Vector3.UP * 0.3, Color("#ff7a8a"), 12.0, 0.6)
	world.shake_at(center, 0.6)
	Sfx.play("explosion", center, 0.0)
	Game.add_score(150)
	Game.record("breaches_closed")
	world.notify("Breach sealed! Mop up whoever got through.", Color("#60ff90"))


# --- Falling civilians -----------------------------------------------------------

func _start_falling(near: Vector3) -> bool:
	var options: Array = world.city.buildings_near(near, 200.0).filter(func(b) -> bool:
		return b["h"] > 25.0 and b["rect"].get_center().distance_to(Vector2(near.x, near.z)) > 30.0)
	if options.is_empty():
		return false
	var b: Dictionary = options[randi() % options.size()]
	var r: Rect2 = b["rect"]
	center = Vector3(r.get_center().x, 0.0, r.position.y - 2.0)
	set_meta("roof_h", minf(float(b["h"]), 90.0))
	set_meta("rect", r)
	total = 3
	_falls_left = 3
	_next_fall = 3.0
	return true


func _tick_falling(delta: float) -> void:
	_next_fall -= delta
	if _falls_left > 0 and _next_fall <= 0.0:
		_falls_left -= 1
		_next_fall = 9.0
		var r: Rect2 = get_meta("rect")
		var h: float = get_meta("roof_h")
		var pos := Vector3(r.position.x + r.size.x * randf_range(0.2, 0.8), h + 0.5, r.position.y - 1.2)
		var c: Actor = world.population.spawn_civilian(pos)
		c.brain = null
		c.set_meta("pinned", true)
		c.collision_layer = 0
		c.set_physics_process(false)
		c.display_name = "Falling civilian"
		fallers.append({"actor": c, "vel": 0.0, "state": "falling"})
		world.notify("Someone's falling from the roof! Catch them!", Color("#ffd23a"))
		Sfx.play("event", pos, -6.0)
	var p: Actor = world.player
	for f in fallers:
		if f["state"] != "falling":
			continue
		var c: Actor = f["actor"]
		if not is_instance_valid(c):
			f["state"] = "gone"
			dropped += 1
			continue
		# Air drag keeps it survivable: they fall at most 16 m/s.
		f["vel"] = minf(float(f["vel"]) + 9.0 * delta, 16.0)
		c.global_position.y -= float(f["vel"]) * delta
		c.model.rotation.x += delta * 1.5
		c.model.rotation.z = sin(time * 6.0) * 0.4
		if randf() < delta * 2.0:
			c.model.play("cast_up", 0.5)
		if p and is_instance_valid(p) and not p.dead and p.chest().distance_to(c.chest()) < 2.6:
			_land(f, true)
		elif c.global_position.y <= 0.15:
			_land(f, false)
	if _falls_left == 0 and caught + dropped >= total:
		if caught > 0:
			done = true
		else:
			failed = true


func _land(f: Dictionary, saved: bool) -> void:
	var c: Actor = f["actor"]
	f["state"] = "landed"
	c.model.rotation = Vector3.ZERO
	if saved:
		var pp: Vector3 = world.player.global_position
		c.global_position = Vector3(pp.x + 1.0, maxf(pp.y, 0.0) + 0.1, pp.z)
	else:
		c.global_position.y = 0.1
	c.collision_layer = Game.LAYER_ACTORS
	c.set_physics_process(true)
	if saved:
		caught += 1
		FX.flash(world, c.chest(), Color("#60ff90"), 1.4, 0.35, 0.5)
		world.notify("Caught! %d / %d" % [caught, total], Color("#60ff90"))
		Game.add_score(60)
		Game.record("catches")
	else:
		dropped += 1
		c.take_damage(c.hp * 0.8, null)
		FX.flash(world, c.global_position + Vector3.UP * 0.3, Color("#ff6a4a"), 1.6, 0.3, 0.5)
		world.shake_at(c.global_position, 0.25)
		world.notify("They hit the street. Paramedics are on the way.", Color("#ff8a6a"))
	var t := c.create_tween()
	t.tween_interval(8.0)
	t.tween_callback(func() -> void:
		if is_instance_valid(c):
			c.remove_meta("pinned"))


# --- Meteor shower ---------------------------------------------------------------

func _tick_meteors(delta: float) -> void:
	if _meteors_left > 0 and (meteors.is_empty() or time > float(total - _meteors_left) * 2.6):
		_meteors_left -= 1
		_spawn_meteor()
	for m in meteors.duplicate():
		var body: HitTarget = m["body"]
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			meteors.erase(m)
			continue
		node.global_position += m["vel"] * delta
		node.rotate_object_local(Vector3(1, 0.4, 0.2).normalized(), delta * 2.0)
		if is_instance_valid(body):
			body.global_position = node.global_position
		if randf() < 0.6:
			FX.smoke(world, node.global_position - (m["vel"] as Vector3).normalized() * 1.2, 1.0, 0.8)
		if node.global_position.y <= (m["target"] as Vector3).y + 0.8:
			landed += 1
			Abilities.explode(world, m["target"] + Vector3.UP * 0.5, 7.0, 45.0, null, "fire", Color("#ff7a2a"))
			world.notify("A meteor hit the street!", Color("#ff8a5a"))
			_free_meteor(m)
			meteors.erase(m)
	if _meteors_left == 0 and meteors.is_empty():
		if smashed >= landed:
			done = true
		else:
			failed = true
		Game.record("meteors_smashed", smashed)


func _spawn_meteor() -> void:
	var target: Vector3 = world.city.random_road_point(center, 0.0, 60.0) + Vector3.UP * 0.05
	var dir := Vector3(randf_range(-0.35, 0.35), -1.0, randf_range(-0.35, 0.35)).normalized()
	var start := target - dir * 140.0
	var node := Node3D.new()
	add_child(node)
	node.global_position = start
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.4
	sm.radial_segments = 10
	sm.rings = 6
	rock.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a2a22")
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color("#ff5a1a")
	mat.emission_energy_multiplier = 0.6
	rock.material_override = mat
	node.add_child(rock)
	var glow := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 2.0
	gs.height = 4.0
	glow.mesh = gs
	glow.material_override = FX.glow_mat(Color("#ff8a2a"), 0.3)
	node.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff7a2a")
	light.omni_range = 18.0
	light.light_energy = 2.5
	node.add_child(light)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.6
	tm.outer_radius = 6.2
	ring.mesh = tm
	ring.material_override = FX.glow_mat(Color("#ff4a2a"), 0.7)
	add_child(ring)
	ring.global_position = target + Vector3.UP * 0.1
	var body := HitTarget.new().setup(world, 55.0, 2.2)
	add_child(body)
	body.global_position = start
	var m := {"node": node, "body": body, "ring": ring, "target": target, "vel": dir * 15.0}
	body.destroyed.connect(func() -> void:
		if not meteors.has(m):
			return
		smashed += 1
		FX.flash(world, node.global_position, Color("#ffb060"), 3.0, 0.35, 0.8)
		FX.sparks(world, node.global_position, Color("#ff9a3a"), 24, 12.0, 0.7)
		Sfx.play("explosion", node.global_position, -4.0)
		Game.add_score(25)
		world.notify("Meteor smashed! %d / %d" % [smashed, total], Color("#ffc080"))
		_free_meteor(m)
		meteors.erase(m))
	meteors.append(m)


func _free_meteor(m: Dictionary) -> void:
	for key in ["node", "body", "ring"]:
		if is_instance_valid(m[key]):
			m[key].queue_free()


# --- Runaway car -----------------------------------------------------------------

func _start_runaway(near: Vector3) -> bool:
	var start: Vector3 = world.city.random_road_point(near, 70.0, 130.0)
	runaway_car = world.population.spawn_traffic(start)
	if runaway_car == null:
		return false
	runaway_car.getaway = true          # ploughs on through traffic
	runaway_car.drive_speed = 24.0
	runaway_car.max_hp = 400.0
	runaway_car.hp = runaway_car.max_hp
	runaway_car.set_meta("runaway", true)
	var l := Label3D.new()
	l.text = "NO BRAKES!"
	l.font_size = 64
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("#ffd23a")
	l.outline_size = 10
	l.position.y = 3.0
	l.no_depth_test = true
	runaway_car.add_child(l)
	center = start
	total = 1
	return true


func _tick_runaway(delta: float) -> void:
	if not is_instance_valid(runaway_car) or runaway_car.exploded:
		failed = true
		world.notify("The runaway car was wrecked.", Color("#ff8a6a"))
		return
	if not runaway_car.driving:
		# Knocked off its wheels: that's a wreck, not a rescue.
		if not stopped:
			failed = true
			world.notify("The runaway car crashed.", Color("#ff8a6a"))
		return
	var p: Actor = world.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var to := p.global_position - runaway_car.global_position
	var ahead := to.dot(runaway_car.heading)
	var side := (to - runaway_car.heading * ahead).length()
	if ahead > 0.0 and ahead < 4.5 and side < 2.2 and absf(to.y) < 2.5:
		# Brace against the bonnet and dig in.
		var grip := 14.0 if (p.strength or p.movement in ["flight", "speed"]) else 5.0
		runaway_car.drive_speed = maxf(0.0, runaway_car.drive_speed - grip * delta)
		runaway_car._speed = minf(runaway_car._speed, runaway_car.drive_speed)
		p.global_position = runaway_car.global_position + runaway_car.heading * 3.0 + Vector3(0, p.global_position.y - runaway_car.global_position.y, 0)
		p.velocity = runaway_car.heading * runaway_car._speed
		if randf() < 0.5:
			FX.sparks(world, p.global_position + Vector3.UP * 0.1, Color("#ffd080"), 3, 4.0, 0.3)
		if not p.strength and p.movement not in ["flight", "speed"] and randf() < delta:
			p.take_damage(4.0, null)
		if runaway_car.drive_speed <= 0.5:
			stopped = true
			runaway_car.getaway = false
			runaway_car.stop_driving()
			runaway_car.linear_velocity = Vector3.ZERO
			done = true
			Game.record("runaways_stopped")
			world.notify("You stopped the runaway car!", Color("#60ff90"))
	if runaway_car.global_position.distance_to(p.global_position) > 650.0:
		failed = true
