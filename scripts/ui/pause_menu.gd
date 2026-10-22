class_name PauseMenu
extends CanvasLayer
## Esc menu.

var world
var _panel: PanelContainer
var _main: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.get_theme()
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	_main.custom_minimum_size = Vector2(360, 0)
	_panel.add_child(_main)
	var title := UITheme.label("PAUSED", 34, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(title)
	_main.add_child(UITheme.button("Resume", close))
	_main.add_child(UITheme.button("Sandbox Tools  [Tab]", _open_sandbox))
	_main.add_child(UITheme.button("Change Character", _change_character))
	_main.add_child(UITheme.button("Settings & Controls", _open_settings))
	_main.add_child(UITheme.button("Achievements & Stats", _open_progress))
	_main.add_child(UITheme.button("Restart the Crisis Campaign", _restart_campaign))
	_main.add_child(UITheme.button("Quit to Title", _quit_to_title))
	_main.add_child(UITheme.button("Quit Game", func() -> void: get_tree().quit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	_panel.add_child(_settings)


func open() -> void:
	visible = true
	_main.visible = true
	_settings.visible = false
	if _progress:
		_progress.visible = false
	get_tree().paused = true
	world.capture_mouse(false)


func close() -> void:
	visible = false
	get_tree().paused = false
	world.capture_mouse(true)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		if _settings.visible:
			_close_settings()
		elif _progress and _progress.visible:
			_progress.visible = false
			_main.visible = true
		else:
			close()
		get_viewport().set_input_as_handled()


func _open_sandbox() -> void:
	visible = false
	world.sandbox_menu.open()


func _change_character() -> void:
	visible = false
	world.change_character_requested.emit()


var _progress: VBoxContainer
var _progress_text: Label


func _open_progress() -> void:
	if _progress == null:
		_progress = VBoxContainer.new()
		_progress.custom_minimum_size = Vector2(760, 560)
		_progress.add_child(UITheme.label("ACHIEVEMENTS & STATS", 26, UITheme.ACCENT))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_progress_text = UITheme.label("", 15)
		scroll.add_child(_progress_text)
		_progress.add_child(scroll)
		_progress.add_child(UITheme.button("Back", func() -> void:
			_progress.visible = false
			_main.visible = true, 200))
		_panel.add_child(_progress)
	var s: Dictionary = Game.progress["stats"]
	var stats := PackedStringArray()
	for k in ["kos", "supers_defeated", "bosses", "takedowns", "parries", "events", "ultimates", "fragments", "discovered",
			"races", "rescues", "chases", "waves_best", "drives", "travels", "changes", "photos",
			"bounties", "breaches_closed", "catches", "runaways_stopped", "supply_drops", "cats_rescued", "selfies", "drills"]:
		stats.append("%s: %d" % [k.replace("_", " ").capitalize(), int(s.get(k, 0))])
	stats.append("Distance on foot: %.1f km" % (float(s.get("distance", 0)) / 1000.0))
	stats.append("Rank %d (%s), %d lifetime points" % [Game.rank(), Game.rank_title(Game.player_side()), int(Game.settings["xp"])])
	_progress_text.text = "%d / %d achievements\n\n%s\n\nSTATS\n%s\n\nCURRENT CHALLENGES\n%s" % [
		Game.progress["achievements"].size(), Achievements.LIST.size(), Achievements.describe(), "\n".join(stats), world.challenges.tracker()]
	_main.visible = false
	_progress.visible = true


func _open_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_main.visible = true


func _quit_to_title() -> void:
	visible = false
	get_tree().paused = false
	world.quit_to_title.emit()


func _restart_campaign() -> void:
	close()
	world.missions.restart()
