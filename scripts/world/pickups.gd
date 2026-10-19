class_name Pickups
extends Node3D
## Weapons dropped by knocked-out thugs and police. Walk over one to grab it:
## it replaces your primary attack until the ammo runs out.

const DROPS := {
	"thug": [["Pistol", 24], ["Assault Rifle", 40], ["Katana", 30], ["Shotgun", 10]],
	"police": [["Pistol", 24], ["Shotgun", 10], ["Assault Rifle", 40]],
}

var world
var items: Array = []    # {node, weapon, ammo}
var _spin := 0.0


func drop_from(a: Actor) -> void:
	var team := str(a.team)
	if not DROPS.has(team) or randf() > 0.3:
		return
	var pick: Array = DROPS[team][randi() % DROPS[team].size()]
	spawn(a.global_position + Vector3(0, 0.6, 0), str(pick[0]), int(pick[1]))


func spawn(pos: Vector3, weapon_name: String, ammo: int) -> void:
	var weapon := {}
	for w in Loadout.WEAPONS["primary"]:
		if w["name"] == weapon_name:
			weapon = w.duplicate(true)
	if weapon.is_empty():
		return
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.22, 0.75) if weapon["kind"] != "melee" else Vector3(0.08, 0.08, 1.1)
	body.mesh = bm
	body.material_override = CharacterModel.mat(Color("#3a3d42") if weapon["kind"] != "melee" else Color("#c9ced4"), 0.6)
	n.add_child(body)
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.65
	halo.mesh = tm
	halo.material_override = FX.glow_mat(Color("#ffd23a"), 0.7)
	halo.position.y = -0.5
	n.add_child(halo)
	var l := Label3D.new()
	l.text = "%s (%d)" % [weapon_name, ammo]
	l.font_size = 48
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 0.6
	l.modulate = Color("#ffe8a0")
	n.add_child(l)
	items.append({"node": n, "weapon": weapon, "ammo": ammo, "life": 40.0})


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	_spin += delta
	var p: Actor = world.player
	for it in items.duplicate():
		var n: Node3D = it["node"]
		it["life"] -= delta
		if not is_instance_valid(n) or it["life"] <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			items.erase(it)
			continue
		n.rotation.y = _spin * 2.0
		if not p.civilian and not p.dead and n.global_position.distance_to(p.global_position + Vector3.UP * 0.6) < 1.8:
			p.equip_pickup(it["weapon"], int(it["ammo"]))
			world.notify("Picked up a %s (%d)" % [it["weapon"]["name"], it["ammo"]], Color("#ffe8a0"))
			Game.record("pickups")
			n.queue_free()
			items.erase(it)


func clear() -> void:
	for it in items:
		if is_instance_valid(it["node"]):
			it["node"].queue_free()
	items.clear()
