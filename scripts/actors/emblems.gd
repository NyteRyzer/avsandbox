class_name Emblems
extends RefCounted
## Paints costume emblems (the Flash's lightning bolt, the House of El shield,
## bat symbols, stars...) into small textures at runtime, and builds the decal
## quads that sit on a character's chest.

const SIZE := 128

static var _cache: Dictionary = {}
static var _quad: QuadMesh


## Returns a MeshInstance3D decal showing the emblem, or null if unknown.
static func decal(kind: String, c1: Color, c2: Color, size_m: float) -> MeshInstance3D:
	var tex := texture(kind, c1, c2)
	if tex == null:
		return null
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.scale = Vector3(size_m, size_m, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh faces +Z; the model faces -Z.
	mi.rotation.y = PI
	return mi


static func texture(kind: String, c1: Color, c2: Color) -> Texture2D:
	var key := "%s|%s|%s" % [kind, c1.to_html(), c2.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"bolt":
			_circle(img, 0.5, 0.5, 0.47, c2.darkened(0.25))
			_circle(img, 0.5, 0.5, 0.42, c1)
			_poly(img, _bolt_points(), c2)
		"bolt_plain":
			_poly(img, _bolt_points(), c2)
		"s_shield":
			var shield := [Vector2(0.5, 0.97), Vector2(0.02, 0.36), Vector2(0.22, 0.06), Vector2(0.78, 0.06), Vector2(0.98, 0.36)]
			_poly(img, shield, c1)
			_poly(img, _shrink(shield, Vector2(0.5, 0.45), 0.84), c2)
			_stroke(img, [Vector2(0.7, 0.24), Vector2(0.4, 0.2), Vector2(0.3, 0.3), Vector2(0.38, 0.4), Vector2(0.62, 0.46),
				Vector2(0.68, 0.56), Vector2(0.56, 0.68), Vector2(0.3, 0.64)], 0.075, c1)
		"bat":
			_poly(img, _bat_points(), c1)
		"star":
			_poly(img, _star_points(0.5, 0.52, 0.48, 0.2), c1)
		"star_ring":
			_circle(img, 0.5, 0.5, 0.48, c2)
			_poly(img, _star_points(0.5, 0.52, 0.4, 0.17), c1)
		"atom":
			_circle(img, 0.5, 0.5, 0.48, c2)
			_circle(img, 0.5, 0.5, 0.4, c1)
			_circle(img, 0.5, 0.5, 0.12, c2)
			for a in [0.0, PI / 3.0, -PI / 3.0]:
				_ellipse_stroke(img, 0.5, 0.5, 0.34, 0.12, a, 0.035, c2)
		"t":
			_poly(img, [Vector2(0.1, 0.12), Vector2(0.9, 0.12), Vector2(0.9, 0.32), Vector2(0.62, 0.32), Vector2(0.62, 0.92),
				Vector2(0.38, 0.92), Vector2(0.38, 0.32), Vector2(0.1, 0.32)], c1)
		"circle":
			_circle(img, 0.5, 0.5, 0.47, c2)
			_circle(img, 0.5, 0.5, 0.36, c1)
		"glyph":
			_poly(img, [Vector2(0.5, 0.04), Vector2(0.92, 0.5), Vector2(0.5, 0.96), Vector2(0.08, 0.5)], c2)
			_poly(img, [Vector2(0.5, 0.2), Vector2(0.76, 0.5), Vector2(0.5, 0.8), Vector2(0.24, 0.5)], c1)
		"lightning_x":
			_poly(img, _bolt_points(), c1)
			_poly(img, _mirror(_bolt_points()), c1)
		"diamond_l":
			_poly(img, [Vector2(0.5, 0.04), Vector2(0.92, 0.5), Vector2(0.5, 0.96), Vector2(0.08, 0.5)], c2)
			_poly(img, [Vector2(0.38, 0.25), Vector2(0.48, 0.25), Vector2(0.48, 0.62), Vector2(0.66, 0.62), Vector2(0.66, 0.72), Vector2(0.38, 0.72)], c1)
		"bird":
			_poly(img, [Vector2(0.5, 0.35), Vector2(0.95, 0.15), Vector2(0.75, 0.45), Vector2(0.6, 0.5), Vector2(0.55, 0.85),
				Vector2(0.45, 0.85), Vector2(0.4, 0.5), Vector2(0.25, 0.45), Vector2(0.05, 0.15)], c1)
		_:
			return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _bolt_points() -> Array:
	return [Vector2(0.62, 0.06), Vector2(0.28, 0.54), Vector2(0.47, 0.54), Vector2(0.36, 0.94), Vector2(0.74, 0.42), Vector2(0.54, 0.42), Vector2(0.7, 0.06)]


static func _mirror(points: Array) -> Array:
	return points.map(func(p): return Vector2(1.0 - p.x, p.y))


static func _bat_points() -> Array:
	return [Vector2(0.5, 0.62), Vector2(0.44, 0.42), Vector2(0.41, 0.3), Vector2(0.46, 0.36), Vector2(0.5, 0.34),
		Vector2(0.54, 0.36), Vector2(0.59, 0.3), Vector2(0.56, 0.42), Vector2(0.98, 0.32), Vector2(0.86, 0.48),
		Vector2(0.8, 0.62), Vector2(0.7, 0.56), Vector2(0.6, 0.72), Vector2(0.5, 0.86), Vector2(0.4, 0.72),
		Vector2(0.3, 0.56), Vector2(0.2, 0.62), Vector2(0.14, 0.48), Vector2(0.02, 0.32), Vector2(0.44, 0.42)]


static func _star_points(cx: float, cy: float, outer: float, inner: float) -> Array:
	var pts := []
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts


static func _shrink(points: Array, center: Vector2, f: float) -> Array:
	return points.map(func(p): return center + (p - center) * f)


static func _to_px(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * SIZE)
	return out


static func _poly(img: Image, points: Array, color: Color) -> void:
	var poly := _to_px(points)
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for y in range(maxi(0, int(r.position.y)), mini(SIZE, int(r.end.y) + 1)):
		for x in range(maxi(0, int(r.position.x)), mini(SIZE, int(r.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, color)


static func _circle(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var c := Vector2(cx, cy) * SIZE
	var rr := radius * SIZE
	for y in SIZE:
		for x in SIZE:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= rr:
				img.set_pixel(x, y, color)


static func _stroke(img: Image, points: Array, width: float, color: Color) -> void:
	var pts := _to_px(points)
	var w := width * SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			for i in pts.size() - 1:
				if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) <= w:
					img.set_pixel(x, y, color)
					break


static func _ellipse_stroke(img: Image, cx: float, cy: float, rx: float, ry: float, angle: float, width: float, color: Color) -> void:
	var pts := []
	for i in 33:
		var t := TAU * i / 32.0
		var p := Vector2(cos(t) * rx, sin(t) * ry).rotated(angle)
		pts.append(Vector2(cx, cy) + p)
	_stroke(img, pts, width, color)
