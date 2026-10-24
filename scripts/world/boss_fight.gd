class_name BossFight
extends Node
## Boss fights in acts. When a mission boss shows up there's an intro
## cutscene (the boss's line, your answer), then the fight:
##   at 2/3 health - a CLASH: you lock up with the boss; mash to overpower them
##   at 1/3 health - the boss unleashes a combo; hit the keys in order to counter
##   at 1/10       - FINISH THEM: hit G in time for a cinematic finisher
## and an outro when they go down. The HUD shows the boss bar with its phases.

## What each boss says: intro, clash, rage (the 1/3 combo), defeat.
const LINES := {
	"zoom": {"intro": "I'm going to take your speed, and then I'm going to take everything else.", "clash": "You're not fast enough!",
		"rage": "I am the fastest man alive!", "defeat": "This... isn't... over..."},
	"reverse_flash": {"intro": "I've been waiting centuries for this. I'm always one step ahead.", "clash": "You'll never be faster than me!",
		"rage": "Let me show you what real speed looks like!", "defeat": "You... always win, don't you, Flash?"},
	"savitar": {"intro": "I am the god of speed. Kneel.", "clash": "I am the future!", "rage": "I will burn this city down!",
		"defeat": "I was... you..."},
	"overgirl": {"intro": "Earth-X sends its regards. Every Earth will bow to us.", "clash": "You're weak. Like your world.",
		"rage": "I'll tear this planet apart!", "defeat": "This isn't... how it ends..."},
	"dark_arrow": {"intro": "Look at you. That could have been me. Weak.", "clash": "You don't have what it takes!",
		"rage": "Your world will burn!", "defeat": "Impossible..."},
	"anti_monitor": {"intro": "I am the end of all things. Every Earth will be unmade.", "clash": "You cannot stop entropy!",
		"rage": "Witness the dawn of the anti-matter universe!", "defeat": "No... the multiverse... endures..."},
	"reign": {"intro": "I am Reign. I am the judge, and this world is guilty.", "clash": "You cannot stop judgement!",
		"rage": "Worldkillers do not fall!", "defeat": "My sisters... will come..."},
	"doomsday": {"intro": "RRRAAAAGH!", "clash": "GRRRAAAH!", "rage": "RRRAAAAAAAAGH!", "defeat": "...rrgh..."},
	"deathstroke": {"intro": "You took everything from me. Now I'll take everything from you.", "clash": "You've gotten soft, kid.",
		"rage": "I'll burn your city to the ground!", "defeat": "Well played..."},
	"alice": {"intro": "Ooh, a visitor! Let's play a game. You lose.", "clash": "Off with your head!",
		"rage": "We're all mad here!", "defeat": "Not... the ending I wanted..."},
	"black_mask": {"intro": "Gotham belongs to me. Nobody leaves my party.", "clash": "You don't scare me!",
		"rage": "False Face! Take them!", "defeat": "This city... will eat you alive..."},
	"icicle": {"intro": "The Injustice Society will remake this country. You're in our way.", "clash": "Freeze!",
		"rage": "Feel the cold, child!", "defeat": "The... cold... never..."},
	"vandal_savage": {"intro": "I have lived for four thousand years. You will not see tomorrow.", "clash": "I have killed better than you!",
		"rage": "I am immortal!", "defeat": "I will return... I always return..."},
	"mallus": {"intro": "The Time Demon is free. Time itself is mine.", "clash": "You are nothing!", "rage": "Darkness eternal!",
		"defeat": "No... NO!"},
	"neron": {"intro": "Your soul belongs to me. Let's make it official.", "clash": "Hell is patient!", "rage": "Burn!",
		"defeat": "I'll be waiting for you... downstairs..."},
	"tobias_whale": {"intro": "Freeland is mine. You're just a man in a suit.", "clash": "You're out of your league!",
		"rage": "I'll put you in the ground!", "defeat": "This... is my city..."},
	"cyborg_superman": {"intro": "Cadmus will purge every alien from this planet. Starting with you.", "clash": "I am Superman now!",
		"rage": "Full power!", "defeat": "Cadmus... will rise..."},
	"cicada": {"intro": "Every metahuman dies. You're next.", "clash": "Your powers mean nothing here!", "rage": "For my Grace!",
		"defeat": "Grace..."},
	"thinker": {"intro": "I've calculated every outcome. You lose in all of them.", "clash": "Predictable!", "rage": "Enlightenment!",
		"defeat": "I... miscalculated..."},
	"bloodwork": {"intro": "Death is a disease, and I am the cure.", "clash": "Join me!", "rage": "My blood is everywhere!",
		"defeat": "I didn't want... to die..."},
	"bishop": {"intro": "I'm saving humanity. You're just in the way of progress.", "clash": "Another me will finish this!",
		"rage": "Clones, now!", "defeat": "Back me up... somebody..."},
}

const HERO_REPLIES := ["Not today.", "You picked the wrong city.", "This ends now.", "I've beaten worse than you.", "Let's do this."]
const VILLAIN_REPLIES := ["Get out of my way.", "You should have stayed home.", "Your heroics end here.", "Let's see you try."]
const BOSS_COLOR := Color("#ff7a6a")
const PLAYER_COLOR := Color("#9fd8ff")

var world
var boss: Actor = null
var phase := 1
var _clash_done := false
var _combo_done := false
var _finisher_t := 0.0
var _busy := false
var _outro_pending := false
var _last_boss_id := ""


static func lines_for(id: String) -> Dictionary:
	return LINES.get(id, {"intro": "So you're the one they sent. This ends now.", "clash": "Is that all you've got?",
		"rage": "Enough games!", "defeat": "How... did you..."})


## The show a character comes from, for the boss bar's subtitle.
static func title_for(a: Actor) -> String:
	return str(a.def.get("show", "")).to_upper()


func active() -> bool:
	return boss != null and is_instance_valid(boss) and not boss.dead


## A mission boss enters: intro cutscene, then the fight.
func begin(b: Actor, intro := true) -> void:
	if b == null or not is_instance_valid(b):
		return
	boss = b
	phase = 1
	_clash_done = false
	_combo_done = false
	_finisher_t = 0.0
	_busy = false
	_outro_pending = true
	_last_boss_id = str(b.def.get("id", ""))
	if intro and world.player and is_instance_valid(world.player):
		_face_off()
		world.cutscene.play(_intro_shots(), func(_skipped: bool) -> void:
			if active():
				world.hud.show_banner("%s  ·  %s" % [str(boss.display_name).to_upper(), title_for(boss)], BOSS_COLOR))


func _face_off() -> void:
	var p: Actor = world.player
	var to := boss.global_position - p.global_position
	to.y = 0.0
	if to.length() < 0.5:
		to = -p.forward()
	# Put them a dramatic distance apart, facing each other.
	if to.length() > 14.0 or to.length() < 6.0:
		var spot := p.global_position + to.normalized() * 9.0
		boss.global_position = Vector3(spot.x, boss.global_position.y, spot.z)
		to = boss.global_position - p.global_position
		to.y = 0.0
	var d := to.normalized()
	p.rotation.y = atan2(-d.x, -d.z)
	p.face_dir = d
	boss.rotation.y = atan2(d.x, d.z)
	boss.face_dir = -d


func _reply() -> String:
	var pool := HERO_REPLIES if world.player.side() == 1 else VILLAIN_REPLIES
	return pool[randi() % pool.size()]


func _intro_shots() -> Array:
	var p: Actor = world.player
	var l := lines_for(_last_boss_id)
	return [
		Cutscene.two_shot(p, boss, 2.4),
		Cutscene.close_up(boss, 3.6, str(l["intro"]), BOSS_COLOR, "power_up"),
		Cutscene.over_shoulder(p, boss, 2.6, _reply(), PLAYER_COLOR),
		Cutscene.two_shot(boss, p, 1.4, "", ""),
	]


func _process(delta: float) -> void:
	if world == null:
		return
	if boss != null and (not is_instance_valid(boss) or boss.dead):
		var was := boss
		boss = null
		if _outro_pending and is_instance_valid(was) and was.dead:
			_outro(was)
		_outro_pending = false
		return
	if not active() or _busy or world.cinematic or world.qte.active:
		return
	var p: Actor = world.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var dist := boss.global_position.distance_to(p.global_position)
	var r := boss.hp / boss.max_hp
	if not _clash_done and r < 0.66 and dist < 30.0:
		_clash()
	elif not _combo_done and r < 0.33 and dist < 30.0:
		_combo()
	elif r < 0.1 and dist < 14.0:
		_finisher_t -= delta
		if _finisher_t <= 0.0:
			_finisher()


func _bark(who: Actor, line: String, color: Color) -> void:
	if line != "" and is_instance_valid(who):
		world.notify("%s: \"%s\"" % [who.display_name, line], color)


## Phase 2: the two of you lock up. Mash attack to overpower them.
func _clash() -> void:
	_clash_done = true
	phase = 2
	if not qte_enabled():
		return
	_busy = true
	var p: Actor = world.player
	var to := boss.global_position - p.global_position
	to.y = 0.0
	var d := to.normalized() if to.length() > 0.1 else p.forward()
	var mid := p.global_position + d * minf(to.length(), 2.4)
	boss.global_position = Vector3(mid.x, boss.global_position.y, mid.z)
	p.rotation.y = atan2(-d.x, -d.z)
	boss.rotation.y = atan2(d.x, d.z)
	p.model.play("heavy", 0.6)
	boss.model.play("heavy", 0.6)
	p.velocity = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	FX.burst_lines(world, (p.chest() + boss.chest()) * 0.5, Color("#ffd23a"), 2.5, 14)
	world.shake_at(p.global_position, 0.4)
	_bark(boss, str(lines_for(_last_boss_id)["clash"]), BOSS_COLOR)
	world.qte.start("mash", {"action": "attack", "presses": 12, "time": 3.6, "title": "CLASH!  Overpower %s" % boss.display_name},
		func(ok: bool) -> void:
			_busy = false
			if not active():
				return
			if ok:
				var push: Vector3 = (boss.global_position - world.player.global_position).normalized()
				boss.take_damage(boss.max_hp * 0.1, world.player, "", push * 18.0 + Vector3.UP * 8.0)
				boss.model.tumble(12.0)
				boss._stagger_now()
				FX.shockwave(world, boss.global_position, Color("#ffd23a"), 8.0)
				world.shake_at(boss.global_position, 0.6)
				Game.record("boss_clashes_won")
			else:
				var back: Vector3 = (world.player.global_position - boss.global_position).normalized()
				world.player.take_damage(world.player.max_hp * 0.18, boss, "", back * 16.0 + Vector3.UP * 7.0)
				world.player.model.tumble(-10.0))


## Phase 3: the boss lets loose. Hit the keys in order to counter.
func _combo() -> void:
	_combo_done = true
	phase = 3
	if not boss.has_meta("enraged"):
		boss._enrage()
	if not qte_enabled():
		return
	_busy = true
	var keys: Array = []
	var pool := ["dodge", "jump", "attack", "block", "dodge", "ability"]
	for k in 4:
		keys.append(pool[randi() % pool.size()])
	boss.model.play("flurry", 0.8)
	_bark(boss, str(lines_for(_last_boss_id)["rage"]), BOSS_COLOR)
	world.qte.start("sequence", {"actions": keys, "time": 1.3, "title": "%s UNLEASHES A COMBO!  Counter it" % str(boss.display_name).to_upper()},
		func(ok: bool) -> void:
			_busy = false
			if not active():
				return
			if ok:
				world.player.model.play("uppercut", 0.4)
				boss.take_damage(boss.max_hp * 0.1, world.player, "", Vector3.UP * 12.0)
				boss.stun_t = maxf(boss.stun_t, 2.0)
				FX.flash(world, boss.chest(), Color("#9fd8ff"), 2.5, 0.3)
				Game.record("boss_counters")
			else:
				world.player.take_damage(world.player.max_hp * 0.22, boss, "", -world.player.forward() * 14.0 + Vector3.UP * 6.0))


## The end: hit G in time for a cinematic finisher.
func _finisher() -> void:
	_finisher_t = 8.0
	if not qte_enabled():
		return
	_busy = true
	world.qte.start("press", {"action": "interact", "time": 2.2, "title": "FINISH %s!" % str(boss.display_name).to_upper()},
		func(ok: bool) -> void:
			_busy = false
			if not active():
				return
			if ok:
				_finish_them()
			else:
				world.notify("Missed it! Wear them down and try again.", Color("#ffb0a0")))


func _finish_them() -> void:
	var p: Actor = world.player
	var b := boss
	_face_off()
	var shots := [Cutscene.two_shot(p, b, 1.6, "", "", PLAYER_COLOR)]
	shots[0]["action"] = [p, "heavy"]
	shots[0]["sfx"] = "slam"
	var done := func(_skipped: bool) -> void:
		if is_instance_valid(b) and not b.dead:
			var dir := (b.global_position - p.global_position).normalized()
			b.take_damage(b.hp + 10.0, p, "", dir * 20.0 + Vector3.UP * 12.0)
			b.model.tumble(16.0)
			FX.burst_lines(world, b.chest(), Color("#ffd23a"), 4.0, 20)
			FX.shockwave(world, b.global_position, Color("#ffffff"), 10.0)
			world.shake_at(b.global_position, 0.8)
			Game.record("boss_finishers")
	if Cutscene.enabled():
		world.cutscene.play(shots, done)
	else:
		done.call(true)


func _outro(b: Actor) -> void:
	var p: Actor = world.player
	world.hud.show_banner("%s DEFEATED" % str(b.display_name).to_upper(), Color("#ffd23a"))
	Game.record("bosses_beaten")
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var l := lines_for(_last_boss_id)
	var shots := [
		Cutscene.close_up(b, 2.8, str(l["defeat"]), BOSS_COLOR),
		Cutscene.close_up(p, 2.4, ["Who's next?", "That's how it's done.", "Stay down.", "It's over."][randi() % 4], PLAYER_COLOR, "power_up"),
	]
	world.cutscene.play(shots)


func qte_enabled() -> bool:
	return Cutscene.enabled() and bool(Game.settings.get("qte", true))


func cancel() -> void:
	boss = null
	_busy = false
	_outro_pending = false
	if world and world.qte:
		world.qte.cancel()
