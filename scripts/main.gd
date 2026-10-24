extends Node
## Top-level flow: title screen -> character select -> open world, plus the
## in-game "change character" overlay.

var world: World
var title: TitleScreen
var select: CharacterSelect
var loading: CanvasLayer


func _ready() -> void:
	show_title()


func show_title() -> void:
	if world:
		world.queue_free()
		world = null
	get_tree().paused = false
	Game.reset_session()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if select:
		select.visible = false
	title = TitleScreen.new()
	add_child(title)
	title.play.connect(_on_play)
	title.quit.connect(func() -> void: get_tree().quit())


func _on_play(mode: String) -> void:
	title.queue_free()
	title = null
	Game.mode = mode
	# A brand-new story starts straight away as Green Arrow, on a rooftop.
	var story: Dictionary = Game.progress.get("story", {}) if typeof(Game.progress.get("story")) == TYPE_DICTIONARY else {}
	if mode == "story" and int(story.get("mission", 0)) == 0 and int(story.get("step", 0)) == 0:
		Game.unlock("green_arrow")
		await _start_world("green_arrow")
		return
	_open_select(false)


func _open_select(swap: bool) -> void:
	if select == null:
		select = CharacterSelect.new()
		add_child(select)
		select.picked.connect(_on_picked)
		select.back.connect(_on_select_back)
	select.open(swap)


func _on_select_back() -> void:
	select.visible = false
	if world:
		world.pause_menu.open()
	else:
		show_title()


func _on_picked(id: String) -> void:
	select.visible = false
	if world == null:
		await _start_world(id)
	else:
		get_tree().paused = false
		world.spawn_player(id)
		world.capture_mouse(true)


func _start_world(id: String) -> void:
	loading = CanvasLayer.new()
	loading.layer = 30
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var l := UITheme.label("Building the city...", 32, UITheme.ACCENT)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading.add_child(l)
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	add_child(world)
	world.quit_to_title.connect(show_title)
	world.change_character_requested.connect(func() -> void: _open_select(true))
	world.spawn_player(id)
	world.capture_mouse(true)
	loading.queue_free()
	loading = null
