class_name HitTarget
extends StaticBody3D
## Something that isn't a person or a prop but can still be hit: a hostile
## breach, a falling meteor, a training drone. Projectiles, melee and
## explosions all reach it. Only the player's side can damage it.

signal damaged(amount: float)
signal destroyed

var world
var hp := 100.0
var max_hp := 100.0
var radius := 1.0
var dead := false


func setup(w, health: float, r: float) -> HitTarget:
	world = w
	hp = health
	max_hp = health
	radius = r
	collision_layer = Game.LAYER_PROPS
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r
	shape.shape = sphere
	add_child(shape)
	add_to_group("hit_targets")
	return self


func hit(dmg: float, _push: Vector3, source) -> void:
	if dead or dmg <= 0.0:
		return
	if source == null or not is_instance_valid(source):
		return
	if world and world.player and is_instance_valid(world.player) and source.team != world.player.team:
		return
	hp -= dmg
	damaged.emit(dmg)
	FX.sparks(world, global_position, Color("#ffffff"), 5, 4.0, 0.25)
	if hp <= 0.0:
		dead = true
		destroyed.emit()
