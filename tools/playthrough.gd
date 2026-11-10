extends Node
## Plays the game the way a new player would (title screen, Story Mode from
## the start, Mission 01 with real key presses, menus, the map) and saves a
## screenshot at each moment, plus a log of what happened. Needs a display
## (or xvfb):
##   godot --path . res://tools/playthrough.tscn -- <output dir>

var out_dir := "user://playthrough"
var main: Node
var world: World
var log_lines: PackedStringArray = []
var _t0 := 0


func _note(s: String) -> void:
	var line := "[%6.1fs] %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, s]
	print("PLAY " + line)
	log_lines.append(line)


func _snap(name: String, frames := 10) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.85)
	_note("shot %s  (fps %d, draw calls %d)" % [name, Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _face(target: Vector3) -> void:
	var to := target - world.player.global_position
	world.cam.yaw = atan2(-to.x, -to.z)
	world.cam.pitch = -0.12


## Walks toward a point with real input (sprinting), up to `limit` seconds.
func _walk_to(target: Vector3, limit: float, radius := 12.0) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var ok := false
	while Time.get_ticks_msec() < end:
		if world.player == null or not is_instance_valid(world.player):
			break
		_face(target)
		var p := world.player.global_position
		if Vector2(p.x - target.x, p.z - target.z).length() < radius:
			ok = true
			break
		await get_tree().process_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	return ok


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	# A brand-new player: no story progress, only Green Arrow unlocked.
	Game.progress["story"] = {}
	Game.progress["unlocked"] = ["green_arrow"]
	Game.no_cinematics = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _snap("01_title", 30)
	var t_load := Time.get_ticks_msec()
	main._on_play("story")
	while main.world == null:
		await get_tree().process_frame
	world = main.world
	_note("world loaded in %.1fs" % ((Time.get_ticks_msec() - t_load) / 1000.0))
	# The prologue cutscene.
	await _wait(1.0)
	await _snap("02_prologue_voiceover", 2)
	_note("cutscene active=%s speaker=%s" % [world.cutscene.active, world.cutscene._speaker.text])
	await _wait(9.0)
	await _snap("03_prologue_later", 2)
	# Watch some, then skip like an impatient player.
	var skipped := 0
	while world.cutscene.active and skipped < 30:
		await _wait(1.2)
		if world.cutscene.active:
			_note("cutscene shot %d: %s: %s" % [world.cutscene._index, world.cutscene._speaker.text, world.cutscene._line.text.left(60)])
		await _tap("jump")
		skipped += 1
	await _wait(1.0)
	await _snap("04_mission01_start", 2)
	_note("after prologue: mission=%s step=%d (%s) inside=%s pos=%s" % [world.missions.current().get("id", ""), world.missions.step,
		world.missions.current_step().get("do", ""), world.inside, world.player.global_position])
	_note("HUD tracker: " + world.hud.mission_label.text.replace("\n", " | ").left(300))
	_note("notifications on screen: %d" % world.hud.notes.get_child_count())
	# Mission 01: get down from the roof and reach the evacuation zone.
	var target: Vector3 = world.missions.target_pos()
	_note("objective at %s, %.0f m away" % [target, world.player.global_position.distance_to(target) if target != Vector3.INF else -1.0])
	_face(target)
	await _snap("05_rooftop_view", 3)
	var got := await _walk_to(target, 40.0)
	_note("walked to evacuation zone: %s (pos %s, y %.1f)" % [got, world.player.global_position, world.player.global_position.y])
	await _snap("06_evac_zone", 3)
	# Rescue: walk to each trapped civilian and mash G.
	await _wait(1.0)
	_note("step now: %s, trapped: %d" % [world.missions.current_step().get("do", ""), world.missions.trapped.size()])
	for k in 6:
		if world.missions.trapped.is_empty():
			break
		var c: Actor = world.missions.trapped[0]
		if not is_instance_valid(c):
			break
		await _walk_to(c.global_position, 15.0, 2.5)
		await _wait(0.4)
		if world.qte.active:
			await _snap("07_rescue_qte_%d" % k, 1)
			for m in 12:
				await _tap("interact")
		await _wait(0.6)
	_note("after rescue: step %s, saved %d" % [world.missions.current_step().get("do", ""), world.missions._saved])
	await _wait(1.0)
	await _snap("08_after_rescue", 2)
	# Fight the shadow creatures with real attacks.
	target = world.missions.target_pos()
	if target != Vector3.INF:
		await _walk_to(target, 30.0, 25.0)
	await _wait(1.5)
	_note("foes out: %d (step %s)" % [world.missions.foes.size(), world.missions.current_step().get("do", "")])
	await _snap("09_shadow_fight", 2)
	var hp0: float = world.player.hp
	for k in 400:
		var alive: Array = world.missions.foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead)
		if alive.is_empty():
			break
		var f: Actor = alive[0]
		if world.player.global_position.distance_to(f.global_position) > 18.0:
			await _walk_to(f.global_position, 4.0, 6.0)
		_face(f.global_position)
		Input.action_press("attack")
		await _wait(0.12)
		Input.action_release("attack")
		await _wait(0.05)
		if k == 60:
			await _snap("10_mid_fight", 1)
		if world.player.dead:
			_note("player knocked out during the shadow fight!")
			await _wait(5.0)
	_note("shadow fight over: hp %.0f -> %.0f, step now %s" % [hp0, world.player.hp, world.missions.current_step().get("do", "")])
	# On to Queen Consolidated and Malcolm.
	for leg in 2:
		target = world.missions.target_pos()
		if target == Vector3.INF:
			await _wait(1.0)
			continue
		var ok2 := await _walk_to(target, 60.0, 20.0)
		_note("walked to %s: %s" % [world.missions.current_step().get("label", ""), ok2])
		await _wait(1.0)
	await _wait(1.0)
	_note("boss cutscene active=%s, boss=%s" % [world.cutscene.active, world.boss_fight.boss.display_name if world.boss_fight.active() else "none"])
	if world.cutscene.active:
		await _wait(2.5)
		await _snap("11_malcolm_intro", 1)
		while world.cutscene.active:
			await _wait(2.0)
			await _tap("jump")
	await _wait(1.0)
	await _snap("12_boss_fight", 2)
	# Fight Malcolm properly: attack, dodge now and then, handle QTEs.
	var t_boss := Time.get_ticks_msec()
	var qtes_seen := 0
	while world.boss_fight.active() and Time.get_ticks_msec() - t_boss < 150000:
		var b: Actor = world.boss_fight.boss
		if world.qte.active:
			qtes_seen += 1
			await _snap("13_qte_%s_%d" % [world.qte.kind, qtes_seen], 1)
			var acts: Array = world.qte._actions.duplicate()
			if world.qte.kind == "mash":
				for m in 20:
					world.qte.press(acts[0])
					await _wait(0.06)
			else:
				for a in acts:
					await _wait(0.25)
					world.qte.press(a)
			await _wait(0.5)
			continue
		if world.cutscene.active:
			await _wait(1.0)
			continue
		if world.player.dead:
			_note("player knocked out by the boss")
			await _wait(5.0)
			continue
		if world.player.global_position.distance_to(b.global_position) > 10.0:
			await _walk_to(b.global_position, 3.0, 4.0)
		_face(b.global_position)
		Input.action_press("attack")
		await _wait(0.12)
		Input.action_release("attack")
		if randf() < 0.05:
			await _tap("dodge")
		await _wait(0.05)
	_note("boss fight: %.0fs, %d QTEs, boss active=%s, player hp %.0f" % [(Time.get_ticks_msec() - t_boss) / 1000.0, qtes_seen,
		world.boss_fight.active(), world.player.hp])
	await _wait(1.0)
	if world.cutscene.active:
		await _snap("14_malcolm_outro", 1)
		while world.cutscene.active:
			await _wait(2.0)
			await _tap("jump")
	await _wait(2.0)
	await _snap("15_mission_complete", 1)
	_note("after mission 01: mission=%s step=%d, unlocked=%s" % [world.missions.current().get("id", ""), world.missions.step, str(Game.progress["unlocked"])])
	_note("HUD tracker: " + world.hud.mission_label.text.replace("\n", " | ").left(300))
	# Menus: pause, story missions, map, character select.
	world.pause_menu.open()
	await _snap("16_pause", 3)
	world.pause_menu._open_story()
	await _snap("17_story_missions", 3)
	world.pause_menu.close()
	world.world_map.open()
	await _snap("18_map", 5)
	world.world_map.close()
	main._open_select(true)
	await _snap("19_character_select", 5)
	main.select.visible = false
	get_tree().paused = false
	# Night in the city, and a crisis.
	world.day_night.hour = 22.0
	await _snap("20_night", 10)
	world.crisis.start_crisis()
	await _wait(0.5)
	await _snap("21_crisis", 2)
	_note("crisis tracker: " + world.crisis.tracker().replace("\n", " | "))
	FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE).store_string("\n".join(log_lines))
	_note("done")
	get_tree().quit()
