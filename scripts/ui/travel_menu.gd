class_name TravelMenu
extends CanvasLayer
## Picks a destination: an Earth to breach to, an era for the Waverider, or
## the Speed Force for a speedster running fast enough.

const TITLES := {"breach": "OPEN A BREACH", "speed": "RUN BETWEEN WORLDS", "time": "GIDEON: SET A COURSE"}
const SUBTITLES := {"breach": "Vibe a doorway to another Earth.",
	"speed": "Fast enough, a speedster can vibrate into the Speed Force or onto another Earth.",
	"time": "The Waverider jumps through the Temporal Zone to any era."}

var world
var mode := "breach"
var _title: Label
var _sub: Label
var _list: VBoxContainer


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.get_theme()
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(700, 0)
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	_title = UITheme.label("", 30, UITheme.ACCENT)
	v.add_child(_title)
	_sub = UITheme.label("", 16, UITheme.DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sub)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)
	v.add_child(UITheme.button("Cancel  [Esc]", close, 200))


func open(p_mode: String) -> void:
	if world.pause_menu.visible or world.sandbox_menu.visible:
		return
	mode = p_mode
	_title.text = TITLES.get(mode, "TRAVEL")
	_sub.text = SUBTITLES.get(mode, "")
	for c in _list.get_children():
		c.queue_free()
	for id in Multiverse.list_for(mode):
		var d := Multiverse.dest(id)
		var here: bool = id == world.place_id
		var text := "%s   —   %s%s" % [d["name"], d["desc"], "   (you are here)" if here else ""]
		var dest_id: String = id
		var b := UITheme.button(text, func() -> void: _pick(dest_id), 680)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = here
		_list.add_child(b)
	visible = true
	get_tree().paused = true
	world.capture_mouse(false)


func close() -> void:
	visible = false
	get_tree().paused = false
	world.capture_mouse(true)


func _pick(id: String) -> void:
	close()
	if mode == "breach":
		world.open_breach(id)
	else:
		world.travel_to(id, mode)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
