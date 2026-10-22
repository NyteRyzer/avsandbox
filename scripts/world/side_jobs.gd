class_name SideJobs
extends Node
## Things to do between the big events:
##   Most Wanted - a named enemy with a price on their head roams the city.
##   Supply drops - A.R.G.U.S. crates parachute in with rare weapons.
##   Help requests - a worried owner's cat is stuck up on a roof.
##   Fans - civilians recognise heroes and ask for a selfie.
##   Krypto - Kryptonians whistle (K) for the Superdog, who fights at their side.
##   Target drill - a timed drone-smashing drill at the HQ armories.

var world
var enabled := true
var rng := RandomNumberGenerator.new()

# Most Wanted
var bounty: Actor
var bounty_reward := 0
var _bounty_t := 45.0
# Supply drops
var drop: Node3D
var _drop_landed := false
var _drop_t := 70.0
var _drop_flare: CPUParticles3D
# Help requests
var owner_npc: Actor
var cat: Node3D
var cat_carried := false
var _help_t := 50.0
var _help_age := 0.0
# Fans
var _fan_t := 20.0
# Krypto
var krypto: Node3D
var _krypto_attack_t := 0.0
var _krypto_target: Actor
var _krypto_lunge := 0.0
# Target drill
var drill_time := 0.0
var drill_score := 0
var drones: Array = []


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	_tick_drill(delta)
	_tick_krypto(delta)
	# Jobs already under way always run; `enabled` only stops new ones.
	var can_start: bool = enabled and world.city.kind == "metro" and world.inside == ""
	_tick_bounty(delta, can_start)
	_tick_drop(delta, can_start)
	_tick_help(delta, can_start)
	if enabled:
		_tick_fans(delta, can_start)


## Called when changing worlds: everything here belongs to the old Earth.
func reset() -> void:
	if is_instance_valid(bounty):
		bounty.queue_free()
	bounty = null
	_bounty_t = 60.0
	if is_instance_valid(drop):
		drop.queue_free()
	drop = null
	_drop_t = 80.0
	_end_help(false)
	_help_t = 60.0
	_stop_drill(false)


# --- Most Wanted --------------------------------------------------------------

func _tick_bounty(delta: float, metro: bool) -> void:
	if is_instance_valid(bounty):
		if bounty.dead:
			_bounty_claimed()
		elif bounty.global_position.distance_to(world.player.global_position) > 1100.0:
			bounty.queue_free()
			bounty = null
		return
	bounty = null
	if not metro:
		return
	_bounty_t -= delta
	if _bounty_t <= 0.0:
		_bounty_t = rng.randf_range(150.0, 220.0)
		start_bounty()


func start_bounty() -> Actor:
	var hero: bool = Game.player_side() == 1
	var c := Game.random_character("villain" if hero else "hero")
	if str(c["id"]) == str(world.player.def.get("id", "")):
		c = Game.random_character("villain" if hero else "hero")
	var pos: Vector3 = world.city.random_road_point(world.player.global_position, 160.0, 320.0) + Vector3.UP * 0.5
	bounty = world.population.spawn_character(c, "villain" if hero else "hero", pos)
	bounty.make_boss(1.7)
	bounty.set_meta("pinned", true)
	bounty.set_meta("bounty", true)
	bounty.display_name = "MOST WANTED: %s" % c["alias"]
	bounty.brain.home = pos
	bounty.brain.leash = 70.0
	bounty_reward = 300 + 40 * Game.rank()
	var tag := Label3D.new()
	tag.text = "WANTED  $%d" % bounty_reward
	tag.font_size = 56
	tag.pixel_size = 0.012
	tag.outline_size = 10
	tag.modulate = Color("#ff5ad0")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.9 * bounty.size, 0)
	bounty.add_child(tag)
	var verb := "A bounty is out on" if hero else "The cops put a price on"
	world.notify("MOST WANTED: %s %s, last seen in %s. Reward: %d" % [verb, c["alias"], world.city.district_at(pos), bounty_reward], Color("#ff5ad0"))
	if world.news:
		world.news.report("Most Wanted: %s spotted in %s." % [c["alias"], world.city.district_at(pos)])
	return bounty


func _bounty_claimed() -> void:
	Game.add_score(bounty_reward)
	Game.record("bounties")
	world.notify("BOUNTY CLAIMED: %s  +%d" % [bounty.def["alias"], bounty_reward], Color("#ff5ad0"))
	if world.news:
		world.news.report("%s took down %s and claimed the bounty." % [world.player.def.get("alias", "Someone"), bounty.def["alias"]])
	bounty.remove_meta("pinned")
	bounty = null


func bounty_pos() -> Vector3:
	return bounty.global_position if is_instance_valid(bounty) and not bounty.dead else Vector3.INF


# --- Supply drops ---------------------------------------------------------------

func _tick_drop(delta: float, metro: bool) -> void:
	if is_instance_valid(drop):
		if not _drop_landed:
			drop.global_position.y -= 7.0 * delta
			drop.rotation.y += delta * 0.6
			if drop.global_position.y <= 0.6:
				drop.global_position.y = 0.6
				_drop_landed = true
				var chute := drop.get_node_or_null("Chute")
				if chute:
					chute.queue_free()
				FX.ring(world, drop.global_position, Color("#7aff7a"), 4.0, 0.4)
				# Scavengers want it too.
				for k in 2:
					var t: Actor = world.population.spawn_thug(drop.global_position + Vector3(rng.randf_range(-12, 12), 0.5, rng.randf_range(10, 16)))
					t.display_name = "Scavenger"
					t.grudges[world.player.get_instance_id()] = 40.0
		elif world.player.global_position.distance_to(drop.global_position) < 2.4 and not world.player.dead:
			open_drop()
		elif world.player.global_position.distance_to(drop.global_position) > 900.0:
			drop.queue_free()
			drop = null
		return
	drop = null
	if not metro:
		return
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = rng.randf_range(160.0, 240.0)
		start_drop()


func start_drop() -> Node3D:
	var pos: Vector3 = world.city.random_road_point(world.player.global_position, 60.0, 140.0)
	drop = Node3D.new()
	world.fx_root.add_child(drop)
	drop.global_position = pos + Vector3.UP * 110.0
	_drop_landed = false
	var mb := MeshBuilder.new()
	mb.box(Vector3.ZERO, Vector3(1.4, 1.0, 1.0), Transform3D(), Color("#3d4a32"))
	for x in [-0.55, 0.55]:
		mb.box(Vector3(x, 0, 0), Vector3(0.12, 1.06, 1.06), Transform3D(), Color("#22281c"))
	mb.box(Vector3(0, 0.0, -0.51), Vector3(0.7, 0.3, 0.02), Transform3D(), Color("#d8d2b8"))
	mb.make_instance(drop, "metal")
	var chute := Node3D.new()
	chute.name = "Chute"
	drop.add_child(chute)
	var cm := MeshBuilder.new()
	cm.loft([{"y": 4.0, "rx": 2.6, "rz": 2.6}, {"y": 5.0, "rx": 2.0, "rz": 2.0}, {"y": 5.5, "rx": 0.6, "rz": 0.6}, {"y": 5.6, "rx": 0.01, "rz": 0.01}],
		Transform3D(), func(_t: float, theta: float, _r: Dictionary) -> Color:
			return Color("#e8e2d0") if int(floor((theta + PI) / (TAU / 8.0))) % 2 == 0 else Color("#c83a2a"), 16, false, true)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		cm.tube(Vector3(0, 0.5, 0), Vector3(cos(a) * 2.5, 4.0, sin(a) * 2.5), 0.015, 0.015, Transform3D(), Color("#d0d0d0"), 4)
	cm.make_instance(chute, "cloth")
	var label := Label3D.new()
	label.text = "A.R.G.U.S. SUPPLY DROP"
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color("#9aff9a")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 1.6
	drop.add_child(label)
	# A green flare marks where it'll land.
	_drop_flare = CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.4
	s.height = 0.8
	_drop_flare.mesh = s
	_drop_flare.material_override = FX.glow_mat(Color("#7aff7a"), 0.5)
	_drop_flare.amount = 30
	_drop_flare.lifetime = 3.0
	_drop_flare.direction = Vector3.UP
	_drop_flare.spread = 12.0
	_drop_flare.initial_velocity_min = 3.0
	_drop_flare.initial_velocity_max = 5.0
	_drop_flare.gravity = Vector3(0.4, 0.5, 0)
	_drop_flare.scale_amount_min = 1.0
	_drop_flare.scale_amount_max = 3.0
	drop.add_child(_drop_flare)
	_drop_flare.top_level = true
	_drop_flare.global_position = pos + Vector3.UP * 0.3
	world.notify("A.R.G.U.S. supply drop incoming in %s. Get to it first!" % world.city.district_at(pos), Color("#9aff9a"))
	return drop


func open_drop() -> void:
	var p: Actor = world.player
	var weapons := ["Cold Gun", "Heat Gun", "Explosive Arrow", "Dual Pistols", "Assault Rifle", "Crossbow"]
	var w: String = weapons[rng.randi() % weapons.size()]
	world.pickups.spawn(drop.global_position + Vector3(0, 0.9, 1.6), w, 40)
	p.heal(p.max_hp)
	p.energy = p.max_energy
	p.ult = minf(100.0, p.ult + 25.0)
	FX.flash(world, drop.global_position, Color("#9aff9a"), 2.5, 0.4, 0.6)
	Game.add_score(50)
	Game.record("supply_drops")
	world.notify("Supply drop opened: full health and energy, ultimate +25, and a %s." % w, Color("#9aff9a"))
	drop.queue_free()
	drop = null


func drop_pos() -> Vector3:
	return drop.global_position if is_instance_valid(drop) else Vector3.INF


# --- Help requests: a cat up on a roof --------------------------------------------

func _tick_help(delta: float, metro: bool) -> void:
	if is_instance_valid(owner_npc):
		_help_age += delta
		if owner_npc.dead or _help_age > 240.0 or owner_npc.global_position.distance_to(world.player.global_position) > 600.0:
			_end_help(false)
			return
		if is_instance_valid(cat):
			if cat_carried:
				cat.global_position = world.player.chest() + world.player.forward() * 0.35 + Vector3.UP * 0.1
				cat.rotation.y = atan2(-world.player.forward().x, -world.player.forward().z)
				if world.player.global_position.distance_to(owner_npc.global_position) < 3.0:
					_end_help(true)
			else:
				cat.get_child(0).rotation.y += delta * 0.5
				if world.player.chest().distance_to(cat.global_position) < 2.2:
					cat_carried = true
					world.waypoint = owner_npc.global_position
					world.notify("Got the cat! Bring it back down to its owner.", Color("#ffe08a"))
					Sfx.play("click", cat.global_position, -4.0)
		return
	owner_npc = null
	if not metro or Game.player_side() != 1 or world.player.civilian:
		return
	_help_t -= delta
	if _help_t <= 0.0:
		_help_t = rng.randf_range(110.0, 170.0)
		start_help()


func start_help() -> Actor:
	var pos: Vector3 = world.city.random_road_point(world.player.global_position, 20.0, 50.0) + Vector3.UP * 0.5
	owner_npc = world.population.spawn_civilian(pos)
	owner_npc.brain = null
	owner_npc.set_meta("pinned", true)
	owner_npc.set_meta("help_request", true)
	owner_npc.display_name = "Worried cat owner"
	_help_age = 0.0
	var l := Label3D.new()
	l.name = "HelpTag"
	l.text = "HELP!"
	l.font_size = 64
	l.pixel_size = 0.012
	l.outline_size = 10
	l.modulate = Color("#ffe08a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position.y = 2.4
	owner_npc.add_child(l)
	world.notify("Someone nearby is calling for help.", Color("#ffe08a"))
	return owner_npc


## The player talked to the owner: put the cat up on a nearby roof.
func accept_help(o: Actor) -> void:
	if o != owner_npc or is_instance_valid(cat):
		return
	var tag := o.get_node_or_null("HelpTag")
	if tag:
		tag.text = "My cat!"
	var options: Array = world.city.buildings_near(o.global_position, 90.0).filter(func(b) -> bool: return b["h"] > 8.0 and b["h"] < 45.0)
	if options.is_empty():
		options = world.city.buildings_near(o.global_position, 160.0).filter(func(b) -> bool: return b["h"] > 0.0)
	if options.is_empty():
		_end_help(false)
		return
	var b: Dictionary = options[rng.randi() % options.size()]
	var r: Rect2 = b["rect"]
	cat = _make_cat()
	world.fx_root.add_child(cat)
	cat.global_position = Vector3(r.get_center().x, float(b["h"]) + 0.25, r.get_center().y)
	cat_carried = false
	world.waypoint = cat.global_position
	world.notify("\"My cat's stuck up on that roof! Please get her down!\"", Color("#ffe08a"))


func _make_cat() -> Node3D:
	var n := Node3D.new()
	var body := Node3D.new()
	n.add_child(body)
	var mb := MeshBuilder.new()
	var fur := MeshBuilder.tagged(Color(["#d88a3a", "#2a2a2a", "#8a8a8a", "#f0ece4"][rng.randi() % 4]), "hair")
	mb.ellipsoid(Vector3(0, 0.18, 0), Vector3(0.11, 0.1, 0.2), Transform3D(), fur, 10, 6)
	mb.ellipsoid(Vector3(0, 0.3, -0.2), Vector3(0.08, 0.075, 0.075), Transform3D(), fur, 10, 6)
	for s in [-1.0, 1.0]:
		mb.tube(Vector3(s * 0.04, 0.35, -0.21), Vector3(s * 0.05, 0.42, -0.2), 0.025, 0.002, Transform3D(), fur, 5)
		mb.ellipsoid(Vector3(s * 0.03, 0.31, -0.27), Vector3(0.012, 0.01, 0.006), Transform3D(), Color("#7ad04a"), 6, 3)
		for fz in [-0.12, 0.12]:
			mb.tube(Vector3(s * 0.06, 0.12, fz), Vector3(s * 0.06, 0.0, fz), 0.022, 0.018, Transform3D(), fur, 5)
	mb.tube(Vector3(0, 0.2, 0.18), Vector3(0, 0.38, 0.32), 0.022, 0.012, Transform3D(), fur, 5)
	mb.make_instance(body, "skin", true)
	var l := Label3D.new()
	l.text = "meow?"
	l.font_size = 40
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 0.7
	l.modulate = Color("#ffe08a")
	n.add_child(l)
	return n


func _end_help(success: bool) -> void:
	if success and is_instance_valid(owner_npc):
		Game.add_score(80)
		Game.record("cats_rescued")
		FX.flash(world, owner_npc.chest(), Color("#ffe08a"), 1.2, 0.3, 0.4)
		world.notify("\"Thank you! You're my hero!\"  +80", Color("#ffe08a"))
		var tag := owner_npc.get_node_or_null("HelpTag")
		if tag:
			tag.text = "<3"
		owner_npc.model.play("cast_up", 1.0)
	if is_instance_valid(cat):
		cat.queue_free()
	cat = null
	cat_carried = false
	if is_instance_valid(owner_npc):
		owner_npc.remove_meta("help_request")
		owner_npc.remove_meta("pinned")
		var o := owner_npc
		var t := o.create_tween()
		t.tween_interval(6.0)
		t.tween_callback(func() -> void:
			if is_instance_valid(o):
				var tag2 := o.get_node_or_null("HelpTag")
				if tag2:
					tag2.queue_free())
	owner_npc = null
	if world and world.waypoint != Vector3.INF and not success:
		world.waypoint = Vector3.INF
	elif world:
		world.waypoint = Vector3.INF


# --- Fans --------------------------------------------------------------------

func _tick_fans(delta: float, metro: bool) -> void:
	_fan_t -= delta
	if _fan_t > 0.0:
		return
	_fan_t = rng.randf_range(25.0, 40.0)
	var p: Actor = world.player
	if not metro or Game.player_side() != 1 or p.civilian or not world.events.active.is_empty():
		return
	for a in get_tree().get_nodes_in_group("actors"):
		if a.team != "civilian" or a.dead or a.has_meta("fan") or a.has_meta("pinned") or a.brain == null:
			continue
		var d: float = a.global_position.distance_to(p.global_position)
		if d < 14.0 and d > 3.0:
			a.set_meta("fan", true)
			var l := Label3D.new()
			l.name = "FanTag"
			l.text = "It's %s! Selfie?" % p.def.get("alias", "you")
			l.font_size = 44
			l.pixel_size = 0.01
			l.outline_size = 8
			l.modulate = Color("#ffd0f0")
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.position.y = 2.3
			a.add_child(l)
			a.model.play("cast_up", 0.8)
			var t := a.create_tween()
			t.tween_interval(30.0)
			t.tween_callback(func() -> void:
				if is_instance_valid(a) and a.has_meta("fan"):
					a.remove_meta("fan")
					var tag := a.get_node_or_null("FanTag")
					if tag:
						tag.queue_free())
			return


func selfie(fan: Actor) -> void:
	if not is_instance_valid(fan) or not fan.has_meta("fan"):
		return
	fan.remove_meta("fan")
	var p: Actor = world.player
	var to := fan.global_position - p.global_position
	to.y = 0.0
	if to.length() > 0.1:
		p.face_dir = to.normalized()
	fan.model.play("point", 0.8)
	p.model.play("power_up", 0.8)
	FX.flash(world, (p.chest() + fan.chest()) * 0.5, Color.WHITE, 2.5, 0.2, 0.9)
	Sfx.play("click", fan.global_position, -2.0)
	var tag := fan.get_node_or_null("FanTag")
	if tag:
		tag.text = "Best day ever!"
		var t := tag.create_tween()
		t.tween_interval(3.0)
		t.tween_callback(tag.queue_free)
	Game.add_score(15)
	Game.record("selfies")
	world.notify("Selfie with a fan! Your fame grows.  +15", Color("#ffd0f0"))


# --- Krypto the Superdog ----------------------------------------------------------

func can_have_krypto() -> bool:
	var p: Actor = world.player
	return Powers.KRYPTONIANS.has(str(p.def.get("id", ""))) and not p.civilian


func toggle_krypto() -> void:
	if is_instance_valid(krypto):
		dismiss_krypto()
		world.notify("Krypto flies off.", Color("#9fd0ff"))
		return
	if not can_have_krypto():
		world.notify("Only Kryptonians (in costume) can whistle for Krypto.", Color("#a0a0a0"))
		return
	krypto = _make_dog()
	world.fx_root.add_child(krypto)
	krypto.global_position = world.player.global_position + Vector3(0, 30, 10)
	Sfx.play("whoosh", world.player.global_position, -2.0)
	world.notify("Krypto the Superdog answers your whistle!", Color("#9fd0ff"))
	Game.record("krypto_called")


func dismiss_krypto() -> void:
	if is_instance_valid(krypto):
		var k := krypto
		var t := k.create_tween()
		t.tween_property(k, "global_position", k.global_position + Vector3(0, 60, 0), 1.2)
		t.tween_callback(k.queue_free)
	krypto = null
	_krypto_target = null


func _make_dog() -> Node3D:
	var n := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	var mb := MeshBuilder.new()
	var fur := MeshBuilder.tagged(Color("#f2eee4"), "hair")
	mb.ellipsoid(Vector3(0, 0.45, 0), Vector3(0.2, 0.2, 0.42), Transform3D(), fur, 14, 8)
	mb.ellipsoid(Vector3(0, 0.66, -0.42), Vector3(0.14, 0.14, 0.16), Transform3D(), fur, 12, 7)
	mb.ellipsoid(Vector3(0, 0.6, -0.58), Vector3(0.08, 0.07, 0.1), Transform3D(), fur, 10, 6)
	mb.ellipsoid(Vector3(0, 0.63, -0.68), Vector3(0.03, 0.025, 0.02), Transform3D(), Color("#141414"), 6, 4)
	for s in [-1.0, 1.0]:
		mb.ellipsoid(Vector3(s * 0.1, 0.76, -0.38), Vector3(0.05, 0.1, 0.03), Transform3D(Basis(Vector3.BACK, s * 0.4)), Color("#e4dccb"), 8, 5)
		mb.ellipsoid(Vector3(s * 0.06, 0.7, -0.55), Vector3(0.018, 0.018, 0.012), Transform3D(), Color("#1a1a1a"), 6, 4)
		for fz in [-0.28, 0.28]:
			mb.tube(Vector3(s * 0.12, 0.35, fz), Vector3(s * 0.12, 0.0, fz), 0.055, 0.045, Transform3D(), fur, 7)
	mb.tube(Vector3(0, 0.55, 0.38), Vector3(0, 0.75, 0.6), 0.05, 0.02, Transform3D(), fur, 6)
	# Red collar and cape, gold S tag.
	mb.tube(Vector3(0, 0.6, -0.32), Vector3(0, 0.62, -0.3), 0.15, 0.15, Transform3D(), Color("#b81820"), 12)
	mb.ellipsoid(Vector3(0, 0.5, -0.47), Vector3(0.04, 0.04, 0.012), Transform3D(), Color("#e6b422"), 8, 4)
	mb.make_instance(body, "skin", true)
	var cape := MeshBuilder.new()
	cape.loft([{"y": -0.38, "rx": 0.3, "rz": 0.08, "cz": 0.0}, {"y": 0.0, "rx": 0.2, "rz": 0.05}],
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.42), Vector3(0, 0.62, -0.25)), MeshBuilder.tagged(Color("#b81820"), "weave"), 10, false, false, 0.5)
	cape.make_instance(body, "cloth", true)
	n.scale = Vector3.ONE * 1.1
	return n


func _tick_krypto(delta: float) -> void:
	if not is_instance_valid(krypto):
		krypto = null
		return
	var p: Actor = world.player
	if not can_have_krypto():
		dismiss_krypto()
		return
	var body := krypto.get_node("Body") as Node3D
	_krypto_attack_t -= delta
	if _krypto_target == null or not is_instance_valid(_krypto_target) or _krypto_target.dead:
		_krypto_target = null
		if _krypto_attack_t <= 0.0:
			var best_d := 20.0
			for a in get_tree().get_nodes_in_group("actors"):
				if a == p or a.dead or not (a.is_hostile_to(p) or p.is_hostile_to(a)) or a.team == "civilian":
					continue
				var d: float = a.global_position.distance_to(p.global_position)
				if d < best_d:
					best_d = d
					_krypto_target = a
	var goal: Vector3
	if _krypto_target:
		goal = _krypto_target.chest() + Vector3.UP * 0.2
		if krypto.global_position.distance_to(goal) < 1.4:
			_krypto_target.take_damage(16.0 * p.power, p, "", (goal - krypto.global_position).normalized() * 8.0 + Vector3.UP * 4.0)
			FX.sparks(world, goal, Color("#ffffff"), 8, 5.0, 0.3)
			Sfx.play("hit", goal, -4.0)
			_krypto_target = null
			_krypto_attack_t = 1.6
	else:
		var side := p.forward().cross(Vector3.UP).normalized()
		goal = p.global_position + side * 1.6 - p.forward() * 1.2 + Vector3.UP * (1.6 if p.flying else 0.0)
		goal.y += sin(Time.get_ticks_msec() * 0.003) * 0.12 + (0.0 if p.flying else 0.25)
	var speed := 26.0 if _krypto_target else 14.0
	var to := goal - krypto.global_position
	var step := to.normalized() * minf(to.length(), speed * delta * maxf(1.0, to.length() * 0.2))
	krypto.global_position += step
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.3:
		krypto.rotation.y = lerp_angle(krypto.rotation.y, atan2(-flat.x, -flat.z), clampf(delta * 8.0, 0.0, 1.0))
	body.rotation.x = clampf(-to.y * 0.3, -0.6, 0.6) if to.length() > 1.0 else 0.0
	if krypto.global_position.distance_to(p.global_position) > 120.0:
		krypto.global_position = p.global_position + Vector3(0, 6, 4)


# --- Target drill ----------------------------------------------------------------

func start_drill() -> void:
	if drill_time > 0.0:
		return
	drill_time = 45.0
	drill_score = 0
	for k in 4:
		_spawn_drone()
	world.notify("TARGET DRILL: smash as many drones as you can in 45 seconds!", Color("#3affd0"))
	Sfx.play("event", null, -2.0)


func _spawn_drone() -> void:
	var p: Actor = world.player
	var ang := rng.randf() * TAU
	var r := rng.randf_range(3.0, 6.0)
	var pos := p.global_position + Vector3(cos(ang) * r, rng.randf_range(1.0, 3.0), sin(ang) * r)
	var d := HitTarget.new().setup(world, 1.0, 0.45)
	world.fx_root.add_child(d)
	d.global_position = pos
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	mi.mesh = sm
	mi.material_override = FX.glow_mat(Color("#3affd0"), 0.75)
	d.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.48
	ring.mesh = tm
	ring.material_override = FX.glow_mat(Color("#a0fff0"), 0.9)
	d.add_child(ring)
	d.set_meta("home", pos)
	d.set_meta("phase", rng.randf() * TAU)
	d.destroyed.connect(func() -> void:
		drill_score += 1
		FX.sparks(world, d.global_position, Color("#3affd0"), 12, 6.0, 0.35)
		Sfx.play("hit", d.global_position, -6.0)
		drones.erase(d)
		d.queue_free()
		if drill_time > 0.0:
			_spawn_drone())
	drones.append(d)


func _tick_drill(delta: float) -> void:
	if drill_time <= 0.0:
		return
	var before := drill_time
	drill_time -= delta
	for d in drones:
		if is_instance_valid(d):
			var home: Vector3 = d.get_meta("home")
			var ph: float = d.get_meta("phase")
			d.global_position = home + Vector3(sin(drill_time * 1.3 + ph) * 1.2, sin(drill_time * 2.1 + ph) * 0.4, cos(drill_time * 1.1 + ph) * 1.2)
			d.get_child(1).rotation.x += delta * 3.0
	for mark in [30.0, 15.0, 5.0]:
		if before > mark and drill_time <= mark:
			world.notify("%d seconds left  ·  %d drones" % [int(mark), drill_score], Color("#3affd0"))
	if drill_time <= 0.0:
		_stop_drill(true)


func _stop_drill(finished: bool) -> void:
	drill_time = 0.0
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()
	if not finished or world == null:
		return
	var key := "drill_best_%s" % str(world.player.def.get("id", ""))
	var best := int(Game.stat(key))
	var msg := "DRILL OVER: %d drones." % drill_score
	if drill_score > best:
		Game.progress["stats"][key] = float(drill_score)
		msg += " New personal best!"
	else:
		msg += " Best: %d" % best
	Game.add_score(drill_score * 5)
	Game.record("drills")
	world.notify(msg, Color("#3affd0"))
