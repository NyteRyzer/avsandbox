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
	if DisplayServer.get_name() == "headless":
		_note("(moment: %s)" % name)
		return
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
	if DisplayServer.get_name() != "headless":
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
	# Play the story with real input: whatever the current step asks for.
	await _play_story(5, 1200.0)
	_note("after the story run: mission=%s step=%d, unlocked=%s" % [world.missions.current().get("id", ""), world.missions.step, str(Game.progress["unlocked"])])
	_note("HUD tracker: " + world.hud.mission_label.text.replace("\n", " | ").left(300))
	await _snap("15_after_story_run", 1)
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


## Plays story steps until mission index `until` is reached or time runs out.
func _play_story(until: int, limit: float) -> void:
	var t_end := Time.get_ticks_msec() + int(limit * 1000.0)
	var last := ""
	var step_t := Time.get_ticks_msec()
	var deaths := 0
	var shots := {}
	while world.missions.chapter < until and Time.get_ticks_msec() < t_end:
		var st: Dictionary = world.missions.current_step()
		var key := "%s/%d %s" % [world.missions.current().get("id", ""), world.missions.step, st.get("do", "")]
		if key != last:
			if last != "":
				_note("step %s took %.1fs" % [last, (Time.get_ticks_msec() - step_t) / 1000.0])
			last = key
			step_t = Time.get_ticks_msec()
			_note("STEP %s: %s" % [key, st.get("label", "")])
			if not shots.has(key):
				shots[key] = true
				await _snap("step_" + key.replace("/", "_").replace(" ", "_"), 3)
		if world.player.dead:
			deaths += 1
			_note("knocked out (%d)" % deaths)
			while world.player.dead:
				await _wait(0.5)
			continue
		if world.cutscene.active:
			await _wait(1.0)
			await _tap("jump")
			continue
		if world.qte.active:
			var acts: Array = world.qte._actions.duplicate()
			_note("QTE %s %s" % [world.qte.kind, acts])
			await _snap("qte_%s" % world.qte.kind, 1)
			if world.qte.kind == "mash":
				for m in 20:
					if not world.qte.active:
						break
					await _tap(acts[0])
			else:
				for a in acts:
					await _wait(0.2)
					await _tap(a)
			await _wait(0.3)
			continue
		match str(st.get("do", "")):
			"goto", "liberate":
				var t: Vector3 = world.missions.target_pos()
				if t != Vector3.INF and world.player.global_position.distance_to(t) > 700.0:
					_note("far objective (%.0f m): fast travel" % world.player.global_position.distance_to(t))
					world.world_map.travel_to_objective(t)
					await _wait(0.5)
				elif t != Vector3.INF:
					await _walk_to(t, 3.0, 10.0)
				else:
					await _wait(0.5)
			"interior":
				var t2: Vector3 = world.missions.target_pos()
				if t2 != Vector3.INF and world.player.global_position.distance_to(t2) > 700.0:
					_note("far objective (%.0f m): fast travel" % world.player.global_position.distance_to(t2))
					world.world_map.travel_to_objective(t2)
					await _wait(0.5)
				elif t2 != Vector3.INF:
					if world.player.global_position.distance_to(t2) < 4.0:
						# At the door: walk on in, like a player would.
						await _walk_to(Interiors.origin(str(st["target"])), 3.0, 3.0)
					else:
						await _walk_to(t2, 3.0, 2.0)
				else:
					await _wait(0.5)
			"rescue":
				if world.missions.trapped.is_empty():
					var t3: Vector3 = world.missions.target_pos()
					await _walk_to(t3, 3.0, 20.0)
				else:
					var c: Actor = world.missions.trapped[0]
					if is_instance_valid(c):
						await _walk_to(c.global_position, 3.0, 2.0)
						await _wait(0.4)
			"defeat":
				var alive: Array = world.missions.foes.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead)
				if alive.is_empty() and Time.get_ticks_msec() - step_t > 20000 and Time.get_ticks_msec() % 5000 < 40:
					var bf = world.boss_fight
					_note("STUCK? foes=%d spawned_for=%d step=%d seen_dead=%d boss_gone=%s bf.boss=%s escaping=%s busy=%s cinematic=%s qte=%s cutscene=%s" % [
						world.missions.foes.size(), world.missions._spawned_for, world.missions.step, world.missions._seen_dead.size(),
						world.missions._boss_gone, bf.boss, bf._escaping, bf._busy, world.cinematic, world.qte.active, world.cutscene.active])
				if alive.is_empty():
					var t4: Vector3 = world.missions.target_pos()
					if t4 != Vector3.INF:
						await _walk_to(t4, 3.0, 30.0)
					else:
						await _wait(0.5)
				else:
					var f: Actor = alive[0]
					for a in alive:
						if a.global_position.distance_to(world.player.global_position) < f.global_position.distance_to(world.player.global_position):
							f = a
					if world.player.global_position.distance_to(f.global_position) > 14.0:
						await _walk_to(f.global_position, 2.0, 8.0)
					_face(f.global_position)
					Input.action_press("attack")
					await _wait(0.15)
					Input.action_release("attack")
					if randf() < 0.08:
						await _tap("dodge")
					await _wait(0.05)
			"travel":
				# Use the travel menu's breach, like Vibe or the Waverider would.
				_note("travelling to %s" % st["place"])
				world.travel_to(str(st["place"]), "time" if str(st["place"]) in ["1942", "2046", "3030", "old_west"] else "breach")
				await _wait(2.0)
			_:
				await _wait(0.3)
	if last != "":
		_note("step %s took %.1fs (stopped)" % [last, (Time.get_ticks_msec() - step_t) / 1000.0])
	_note("deaths: %d" % deaths)
