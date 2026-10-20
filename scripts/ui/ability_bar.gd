class_name AbilityBar
extends Control
## The ability bar along the bottom of the screen: one tile per power (LMB,
## RMB, Q, E, 1-3, R) with its key, its name, a cooldown sweep, and a glow
## when it's ready. Tiles dim when you can't afford them.

const TILE := Vector2(92, 74)
const GAP := 8.0

var slots: Array = []   # {key, name, cd, cd_max, ready, color, wide}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_slots(s: Array) -> void:
	slots = s
	custom_minimum_size = Vector2(slots.size() * (TILE.x + GAP), TILE.y + 4)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var x := 0.0
	for s in slots:
		var r := Rect2(Vector2(x, 2), TILE)
		var col: Color = s.get("color", UITheme.ACCENT)
		var ready: bool = s.get("ready", true)
		var cd: float = s.get("cd", 0.0)
		var cd_max: float = maxf(0.01, s.get("cd_max", 1.0))
		_rounded(r, Color(0.05, 0.06, 0.1, 0.88))
		# Cooldown sweep: a dark curtain that drains as the power recharges.
		if cd > 0.05:
			var f := clampf(cd / cd_max, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - f)), Vector2(r.size.x, r.size.y * f)), Color(0, 0, 0, 0.55))
			draw_string(font, r.position + Vector2(0, r.size.y * 0.5 + 6), "%.1f" % cd, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1, 1, 1, 0.9))
		# Border: coloured and bright when ready, faint otherwise.
		var bc := col if ready and cd <= 0.05 else Color(1, 1, 1, 0.12)
		draw_rect(r, bc, false, 2.0 if ready and cd <= 0.05 else 1.0)
		if ready and cd <= 0.05:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), col)
		# Key badge
		var key: String = s.get("key", "")
		var kw := maxf(22.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0)
		var kb := Rect2(r.position + Vector2(5, 6), Vector2(kw, 18))
		_rounded(kb, col.darkened(0.55) if ready else Color(0.15, 0.15, 0.18))
		draw_string(font, kb.position + Vector2(0, 13), key, HORIZONTAL_ALIGNMENT_CENTER, kb.size.x, 12, Color.WHITE)
		# Name, up to two lines
		var name: String = s.get("name", "")
		var words := name.split(" ")
		var lines := ["", ""]
		for w in words:
			var li := 0 if font.get_string_size(lines[0] + " " + w, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x < r.size.x - 10 or lines[0] == "" else 1
			lines[li] = (lines[li] + " " + w).strip_edges()
		var tc := Color(1, 1, 1, 0.95) if ready else Color(1, 1, 1, 0.45)
		draw_string(font, r.position + Vector2(5, r.size.y - 22), lines[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 12, tc)
		draw_string(font, r.position + Vector2(5, r.size.y - 8), lines[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 12, tc)
		# Extra: "READY" pulse for the ultimate, ammo count for pickups
		var extra: String = s.get("extra", "")
		if extra != "":
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
			draw_string(font, r.position + Vector2(kb.size.x + 8, 20), extra, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - kb.size.x - 12, 12, Color(col, pulse))
		x += TILE.x + GAP


func _rounded(r: Rect2, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	draw_style_box(sb, r)
