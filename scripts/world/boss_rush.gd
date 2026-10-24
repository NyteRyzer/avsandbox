class_name BossRush
extends Node
## Boss Rush (Tab menu): five of the multiverse's worst, one after another,
## each with the full boss fight (intro, clash, counter, finisher). You get
## some health back between rounds. Beat all five for a big reward; your
## best time is saved.

const ROUNDS := 5
const POOL := ["reverse_flash", "zoom", "savitar", "reign", "doomsday", "deathstroke", "malcolm_merlyn", "vandal_savage",
	"damien_darhk", "alice", "tobias_whale", "cyborg_superman", "neron", "mallus", "icicle", "cicada", "bloodwork",
	"overgirl", "godspeed", "red_death", "black_mask", "prometheus"]

var world
var active := false
var stage := 0
var bosses: Array = []
var current: Actor = null
var time := 0.0
var _break := 0.0


func start() -> void:
	if active:
		return
	var pool := POOL.duplicate()
	pool.shuffle()
	bosses = pool.slice(0, ROUNDS)
	active = true
	stage = 0
	time = 0.0
	_break = 1.5
	current = null
	world.clear_npcs()
	world.population.enabled = false
	world.events.reset()
	world.hud.show_banner("BOSS RUSH", Color("#ff7a6a"))
	world.notify("Five bosses, back to back. Survive them all.", Color("#ffb0a0"))


func stop(reason := "") -> void:
	if not active:
		return
	active = false
	if is_instance_valid(current) and not current.dead:
		current.queue_free()
	current = null
	world.boss_fight.cancel()
	world.notify("Boss Rush over%s: %d / %d bosses beaten." % [reason, maxi(0, stage - 1), ROUNDS], Color("#ffb0a0"))
	world.population.enabled = true


func _process(delta: float) -> void:
	if not active or world.player == null or not is_instance_valid(world.player):
		return
	world.population.enabled = false
	if world.player.dead:
		stop(" (knocked out)")
		return
	if not world.cinematic and not world.qte.active:
		time += delta
	if current != null and is_instance_valid(current) and not current.dead:
		return
	if current != null and (not is_instance_valid(current) or current.dead) and _break <= 0.0:
		# A boss just went down.
		current = null
		_break = 3.0
		world.player.heal(world.player.max_hp * 0.4)
		world.player.energy = world.player.max_energy
		Game.add_score(150 * stage)
	if world.cinematic:
		return
	if _break > 0.0:
		_break -= delta
		return
	if stage >= ROUNDS:
		_win()
		return
	_next()


func _next() -> void:
	var id: String = bosses[stage]
	stage += 1
	var p: Actor = world.player
	var at := p.global_position + p.forward() * 10.0
	if world.city.kind == "metro":
		at = world.city.snap_to_road(at) + Vector3.UP * 0.5
	var b: Actor = world.missions._spawn(id, at)
	b.make_boss(2.2 + stage * 0.3)
	b.display_name = b.display_name + " (BOSS)"
	current = b
	world.hud.show_banner("ROUND %d / %d" % [stage, ROUNDS], Color("#ff7a6a"))
	world.boss_fight.begin(b)


func _win() -> void:
	active = false
	var best := Game.stat("boss_rush_best")
	var record := best <= 0.0 or time < best
	if record:
		Game.progress["stats"]["boss_rush_best"] = time
	Game.record("boss_rushes")
	Game.add_score(2500)
	world.hud.show_banner("BOSS RUSH CLEARED  ·  %d:%02d%s" % [int(time) / 60, int(time) % 60, "  ·  NEW BEST" if record else ""], Color("#ffd23a"))
	world.notify("You beat all five bosses! +2500", Color("#60ff90"))
	world.population.enabled = true


func tracker() -> String:
	if not active:
		return ""
	var who := ""
	if is_instance_valid(current) and not current.dead:
		who = "  ·  " + str(current.display_name).replace(" (BOSS)", "")
	return "BOSS RUSH  ·  stage %d / %d%s  ·  %d:%02d" % [maxi(1, stage), ROUNDS, who, int(time) / 60, int(time) % 60]
