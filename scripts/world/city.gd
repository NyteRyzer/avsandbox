class_name City
extends Node3D
## Procedurally builds the open world: an island metropolis split into four
## districts (Star City, Central City, National City and Freeland) around a
## central park, ringed by sea. Buildings are drawn with a handful of
## MultiMeshes and collide through one static body, so the whole city costs
## only a few dozen draw calls.

const GRID := 14
const CELL := 80.0
const ROAD := 16.0
const BLOCK := CELL - ROAD
const HALF := GRID * CELL * 0.5
const LAND := HALF + 60.0
const SEA := 3000.0

const FACADE_SHADER := preload("res://shaders/facade.gdshader")
const DISTRICTS := ["Star City", "Central City", "National City", "Freeland"]
const DISTRICT_CENTERS := [Vector2(-280, -280), Vector2(280, -280), Vector2(-280, 280), Vector2(280, 280)]
const FACADES := [
	["#3c434b", "#2b3339", "#4b4c46"],   # Star City: steel and slate
	["#7a3d2c", "#8f7d68", "#4c5a68"],   # Central City: brick and sandstone
	["#c4ced8", "#6a8aaa", "#98a2ac"],   # National City: white stone and blue glass
	["#8a6a4a", "#6b5a4b", "#a28c6c"],   # Freeland: warm brick
]

var city_seed := 1987
var rng := RandomNumberGenerator.new()
var buildings: Array = []        # {rect: Rect2 (x/z footprint), h: float}
var landmarks: Array = []        # {name, pos: Vector3, district}
var parked: Array = []           # {kind, xform: Transform3D}
var facade_mats: Array = []      # Array of Array[StandardMaterial3D] by district
var lit_mats: Array[ShaderMaterial] = []
var _instances: Dictionary = {}  # Material -> Array[Transform3D]
var _body: StaticBody3D
var _lamp_mat: StandardMaterial3D
var _window_albedo: ImageTexture
var _window_emission: ImageTexture


func generate(p_seed := 1987) -> void:
	city_seed = p_seed
	rng.seed = city_seed
	_body = StaticBody3D.new()
	_body.name = "CityCollision"
	_body.collision_layer = Game.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_make_textures()
	_make_materials()
	_build_ground()
	for i in GRID:
		for j in GRID:
			_build_block(i, j)
	_build_landmarks()
	_build_streetlights()
	_flush_instances()


# --- Queries ----------------------------------------------------------------

func is_water(p: Vector3) -> bool:
	return absf(p.x) > LAND or absf(p.z) > LAND


func district_at(p: Vector3) -> String:
	if is_water(p):
		return "The Bay"
	if absf(p.x) < 80.0 and absf(p.z) < 80.0:
		return "Unity Park"
	return DISTRICTS[district_index(p)]


func district_index(p: Vector3) -> int:
	return (1 if p.x > 0.0 else 0) + (2 if p.z > 0.0 else 0)


func district_center(index: int) -> Vector3:
	var c: Vector2 = DISTRICT_CENTERS[index]
	return Vector3(c.x, 0.2, c.y)


## Snaps a point onto the nearest street (roads run along every multiple of CELL).
func snap_to_road(p: Vector3, lane_offset := 0.0) -> Vector3:
	var out := p
	out.x = clampf(out.x, -HALF, HALF)
	out.z = clampf(out.z, -HALF, HALF)
	var gx := roundf(out.x / CELL) * CELL
	var gz := roundf(out.z / CELL) * CELL
	if absf(out.x - gx) < absf(out.z - gz):
		out.x = gx + lane_offset
	else:
		out.z = gz + lane_offset
	out.y = 0.2
	return out


func nearest_road_point(p: Vector3) -> Vector3:
	return snap_to_road(p) + Vector3.UP * 0.5


func random_road_point(near: Vector3, min_d: float, max_d: float, r: RandomNumberGenerator = null, sidewalk := false) -> Vector3:
	if r == null:
		r = rng
	for attempt in 16:
		var ang := r.randf() * TAU
		var d := r.randf_range(min_d, max_d)
		var lane := 0.0
		if sidewalk:
			lane = (ROAD * 0.5 + 2.0) * (1.0 if r.randf() < 0.5 else -1.0)
		else:
			lane = r.randf_range(-ROAD * 0.35, ROAD * 0.35)
		var pt := snap_to_road(near + Vector3(cos(ang) * d, 0, sin(ang) * d), lane)
		if pt.distance_to(Vector3(near.x, pt.y, near.z)) >= min_d * 0.6:
			return pt
	return snap_to_road(near)


func landmark(name: String) -> Dictionary:
	for l in landmarks:
		if l["name"] == name:
			return l
	return {}


func buildings_near(p: Vector3, radius: float) -> Array:
	var out := []
	var area := Rect2(p.x - radius, p.z - radius, radius * 2.0, radius * 2.0)
	for b in buildings:
		if area.intersects(b["rect"]):
			out.append(b)
	return out


## 0 = full daylight, 1 = deep night. Lights windows and streetlamps.
func set_night(f: float) -> void:
	for m in lit_mats:
		m.set_shader_parameter("night", f)
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = 0.2 + f * 3.0


# --- Materials --------------------------------------------------------------

func _make_textures() -> void:
	# One texture covers 32 m x 32 m of facade: 8 x 8 windows, 4 m apart.
	var size := 512
	var cell := size / 8
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var emission := Image.create(size, size, false, Image.FORMAT_RGB8)
	albedo.fill(Color(0.92, 0.92, 0.92))
	emission.fill(Color.BLACK)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for wy in 8:
		for wx in 8:
			var rect := Rect2i(wx * cell + 10, wy * cell + 14, cell - 20, cell - 30)
			albedo.fill_rect(rect, Color(0.16, 0.19, 0.23))
			albedo.fill_rect(Rect2i(rect.position.x, rect.position.y + rect.size.y, rect.size.x, 3), Color(0.7, 0.7, 0.7))
			if r.randf() < 0.38:
				var warm := Color(1.0, 0.82, 0.5).lerp(Color(0.75, 0.88, 1.0), r.randf() * 0.5)
				emission.fill_rect(rect, warm * r.randf_range(0.6, 1.0))
	albedo.generate_mipmaps()
	emission.generate_mipmaps()
	_window_albedo = ImageTexture.create_from_image(albedo)
	_window_emission = ImageTexture.create_from_image(emission)


func _facade(color: Color, roughness := 0.8, metallic := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FACADE_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("facade", _window_albedo)
	m.set_shader_parameter("lights", _window_emission)
	m.set_shader_parameter("tile", 32.0)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("metallic_value", metallic)
	lit_mats.append(m)
	return m


func _plain(color: Color, roughness := 0.9, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


var _roof_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _grass_mat: StandardMaterial3D
var _glass_mat: ShaderMaterial
var _trunk_mat: StandardMaterial3D
var _leaf_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D


func _make_materials() -> void:
	for d in FACADES:
		var row := []
		for c in d:
			row.append(_facade(Color(str(c))))
		facade_mats.append(row)
	_glass_mat = _facade(Color("#3a4a5a"), 0.25, 0.6)
	_roof_mat = _plain(Color("#3b3d40"))
	_sidewalk_mat = _plain(Color("#8d8f92"))
	_grass_mat = _plain(Color("#3f6b34"))
	_trunk_mat = _plain(Color("#4a3624"))
	_leaf_mat = _plain(Color("#2f5a2a"))
	_concrete_mat = _plain(Color("#9a9690"))
	_dark_mat = _plain(Color("#1c1f24"), 0.4)
	_lamp_mat = _plain(Color("#ffe2a0"), 0.5, 0.2)


# --- Geometry helpers -------------------------------------------------------

## Queues a box for instanced drawing and (optionally) adds it to collision.
func add_box(center: Vector3, size: Vector3, m: Material, collide := true, rot_y := 0.0) -> void:
	var basis := Basis(Vector3.UP, rot_y) * Basis.from_scale(size)
	if not _instances.has(m):
		_instances[m] = []
	_instances[m].append(Transform3D(basis, center))
	if collide:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
		_body.add_child(cs)


func _add_building(rect: Rect2, height: float, m: Material) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, height * 0.5, c.y), Vector3(rect.size.x, height, rect.size.y), m)
	add_box(Vector3(c.x, height + 0.3, c.y), Vector3(rect.size.x + 0.6, 0.6, rect.size.y + 0.6), _roof_mat, true)
	buildings.append({"rect": rect, "h": height})
	# Rooftop clutter
	var units := rng.randi_range(0, 3) if height < 120.0 else rng.randi_range(0, 1)
	for u in units:
		var s := Vector3(rng.randf_range(2, 5), rng.randf_range(1.5, 3), rng.randf_range(2, 5))
		var px := rng.randf_range(rect.position.x + s.x, rect.end.x - s.x)
		var pz := rng.randf_range(rect.position.y + s.z, rect.end.y - s.z)
		add_box(Vector3(px, height + 0.6 + s.y * 0.5, pz), s, _concrete_mat)


func _mesh_instance(mesh: Mesh, xform: Transform3D, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = xform
	add_child(mi)
	return mi


func _label(text: String, pos: Vector3, size := 2.5, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 256
	l.pixel_size = size / 256.0 * 2.0
	l.modulate = color
	l.outline_size = 24
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	add_child(l)


func _flush_instances() -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for m in _instances.keys():
		var list: Array = _instances[m]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		add_child(mmi)
	_instances.clear()


# --- Ground -----------------------------------------------------------------

func _build_ground() -> void:
	# Sea floor and sea
	var floor_shape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(SEA * 2.0, 2.0, SEA * 2.0)
	floor_shape.shape = fbox
	floor_shape.position = Vector3(0, -4.0, 0)
	_body.add_child(floor_shape)
	var sea_floor := PlaneMesh.new()
	sea_floor.size = Vector2(SEA * 2.0, SEA * 2.0)
	_mesh_instance(sea_floor, Transform3D(Basis(), Vector3(0, -3.0, 0)), _plain(Color("#6a6250")))
	var water := PlaneMesh.new()
	water.size = Vector2(SEA * 2.0, SEA * 2.0)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.25, 0.36, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.3
	wm.roughness = 0.12
	var water_mi := _mesh_instance(water, Transform3D(Basis(), Vector3(0, -0.25, 0)), wm)
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Island: grass edge and the asphalt street grid with lane markings.
	add_box(Vector3(0, -1.5, 0), Vector3(LAND * 2.0, 3.0, LAND * 2.0), _grass_mat)
	# One texel row of paint on each side of the tile seam = a 0.3 m line.
	var res := 512
	var road_img := Image.create(res, res, false, Image.FORMAT_RGB8)
	road_img.fill(Color(0.17, 0.17, 0.18))
	var paint := Color(0.8, 0.66, 0.2)
	var dash := 20  # ~3 m dashes with ~3 m gaps
	for k in range(0, res, dash * 2):
		for t in range(k, k + dash):
			road_img.set_pixel(0, t, paint)
			road_img.set_pixel(res - 1, t, paint)
			road_img.set_pixel(t, 0, paint)
			road_img.set_pixel(t, res - 1, paint)
	road_img.generate_mipmaps()
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_texture = ImageTexture.create_from_image(road_img)
	road_mat.uv1_triplanar = true
	road_mat.uv1_world_triplanar = true
	road_mat.uv1_scale = Vector3.ONE / CELL
	road_mat.roughness = 0.95
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var asphalt := PlaneMesh.new()
	asphalt.size = Vector2(HALF * 2.0 + ROAD, HALF * 2.0 + ROAD)
	_mesh_instance(asphalt, Transform3D(Basis(), Vector3(0, 0.03, 0)), road_mat)

	# Seawall and docks on the east shore.
	for side in [-1.0, 1.0]:
		add_box(Vector3(side * (LAND + 0.5), 0.6, 0), Vector3(1.0, 1.2, LAND * 2.0), _concrete_mat, false)
		add_box(Vector3(0, 0.6, side * (LAND + 0.5)), Vector3(LAND * 2.0, 1.2, 1.0), _concrete_mat, false)
	for k in 6:
		var z := -400.0 + k * 160.0
		add_box(Vector3(LAND + 40.0, -0.1, z), Vector3(80.0, 0.8, 14.0), _plain(Color("#5a4a3a")))
		for pz in [-6.0, 6.0]:
			for px in range(0, 80, 10):
				add_box(Vector3(LAND + 2.0 + px, -1.6, z + pz), Vector3(0.6, 3.0, 0.6), _trunk_mat, false)
	landmarks.append({"name": "The Docks", "pos": Vector3(LAND + 40.0, 0.5, -80.0), "district": "The Bay"})


# --- Blocks -----------------------------------------------------------------

func _block_rect(i: int, j: int) -> Rect2:
	return Rect2(-HALF + i * CELL + ROAD * 0.5, -HALF + j * CELL + ROAD * 0.5, BLOCK, BLOCK)


const LANDMARK_BLOCKS := {
	Vector2i(3, 3): "queen", Vector2i(2, 4): "verdant", Vector2i(10, 3): "star_labs",
	Vector2i(9, 4): "ccpd", Vector2i(10, 4): "jitters", Vector2i(3, 10): "catco",
	Vector2i(4, 9): "deo", Vector2i(10, 10): "garfield", Vector2i(12, 12): "iron_heights",
	Vector2i(6, 6): "park", Vector2i(7, 6): "park", Vector2i(6, 7): "park", Vector2i(7, 7): "park",
}


func _build_block(i: int, j: int) -> void:
	var rect := _block_rect(i, j)
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.08, c.y), Vector3(BLOCK, 0.16, BLOCK), _sidewalk_mat, false)
	var key := Vector2i(i, j)
	if LANDMARK_BLOCKS.has(key):
		if LANDMARK_BLOCKS[key] == "park":
			_build_park(rect, true)
		return
	var district := district_index(Vector3(c.x, 0, c.y))
	var center: Vector2 = DISTRICT_CENTERS[district]
	var downtown := clampf(1.0 - c.distance_to(center) / 300.0, 0.0, 1.0)
	var edge := i == 0 or j == 0 or i == GRID - 1 or j == GRID - 1
	if not edge and rng.randf() < 0.06:
		_build_park(rect, false)
		return
	var inner := rect.grow(-3.0)
	var mats: Array = facade_mats[district]
	if edge and (i == GRID - 1 or district == 3) and rng.randf() < 0.6:
		# Warehouses and industrial lots
		var n := rng.randi_range(1, 2)
		for k in n:
			var r := Rect2(inner.position.x + k * inner.size.x / n + 2.0, inner.position.y + 4.0, inner.size.x / n - 4.0, inner.size.y - 8.0)
			_add_building(r, rng.randf_range(8, 14), mats[2])
		_scatter_crates(inner, 6)
		return
	var height_base := lerpf(8.0, 150.0, pow(downtown, 1.6))
	if edge:
		height_base = minf(height_base, 14.0)
	var lots := 1
	if height_base < 30.0:
		lots = 4 if rng.randf() < 0.7 else 2
	elif height_base < 80.0:
		lots = 2 if rng.randf() < 0.6 else 1
	var rects: Array = []
	match lots:
		1:
			rects.append(inner.grow(-rng.randf_range(1.0, 6.0)))
		2:
			var half := inner.size.x * 0.5
			rects.append(Rect2(inner.position, Vector2(half - 2.0, inner.size.y)))
			rects.append(Rect2(inner.position + Vector2(half + 2.0, 0), Vector2(half - 2.0, inner.size.y)))
		4:
			var hx := inner.size.x * 0.5
			var hz := inner.size.y * 0.5
			for qx in 2:
				for qz in 2:
					rects.append(Rect2(inner.position + Vector2(qx * hx + 1.5, qz * hz + 1.5), Vector2(hx - 3.0, hz - 3.0)))
	for r in rects:
		var h := maxf(6.0, height_base * rng.randf_range(0.55, 1.35))
		var m: Material = mats[rng.randi() % mats.size()]
		if h > 90.0 and rng.randf() < 0.5:
			m = _glass_mat
		var shrink := rng.randf_range(0.0, 3.0)
		var fr: Rect2 = r.grow(-shrink)
		if h > 70.0 and rng.randf() < 0.6:
			# Setback tower: a podium with a slimmer tower on top.
			var podium := h * rng.randf_range(0.25, 0.45)
			_add_building(fr, podium, m)
			var tower := fr.grow(-fr.size.x * 0.18)
			var tc := tower.get_center()
			add_box(Vector3(tc.x, podium + (h - podium) * 0.5, tc.y), Vector3(tower.size.x, h - podium, tower.size.y), m)
			add_box(Vector3(tc.x, h + 0.3, tc.y), Vector3(tower.size.x + 0.6, 0.6, tower.size.y + 0.6), _roof_mat)
			buildings.append({"rect": tower, "h": h})
		else:
			_add_building(fr, h, m)
	# Parked cars along this block's kerbs.
	for side in 4:
		if rng.randf() < 0.45:
			_park_car(rect, side)


func _park_car(rect: Rect2, side: int) -> void:
	var t := rng.randf_range(0.15, 0.85)
	var pos := Vector3.ZERO
	var rot := 0.0
	var kerb := ROAD * 0.5 - 2.2
	match side:
		0:
			pos = Vector3(rect.position.x + rect.size.x * t, 0.1, rect.position.y - (ROAD * 0.5 - kerb))
			rot = PI * 0.5
		1:
			pos = Vector3(rect.position.x + rect.size.x * t, 0.1, rect.end.y + (ROAD * 0.5 - kerb))
			rot = -PI * 0.5
		2:
			pos = Vector3(rect.position.x - (ROAD * 0.5 - kerb), 0.1, rect.position.y + rect.size.y * t)
			rot = 0.0
		3:
			pos = Vector3(rect.end.x + (ROAD * 0.5 - kerb), 0.1, rect.position.y + rect.size.y * t)
			rot = PI
	parked.append({"kind": "car", "xform": Transform3D(Basis(Vector3.UP, rot), pos)})


func _scatter_crates(rect: Rect2, count: int) -> void:
	for k in count:
		var p := Vector3(rng.randf_range(rect.position.x, rect.end.x), 0.2, rect.end.y - rng.randf_range(0.5, 3.5))
		parked.append({"kind": "crate", "xform": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)})


func _build_park(rect: Rect2, big: bool) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.2, c.y), Vector3(rect.size.x - 4.0, 0.1, rect.size.y - 4.0), _grass_mat, false)
	var n := 14 if big else 8
	for k in n:
		var p := Vector3(rng.randf_range(rect.position.x + 5, rect.end.x - 5), 0, rng.randf_range(rect.position.y + 5, rect.end.y - 5))
		if big and absf(p.x) < 14.0 and absf(p.z) < 14.0:
			continue
		var h := rng.randf_range(3.0, 5.0)
		add_box(p + Vector3.UP * h * 0.5, Vector3(0.6, h, 0.6), _trunk_mat)
		var leaf := rng.randf_range(3.5, 5.5)
		add_box(p + Vector3.UP * (h + leaf * 0.35), Vector3(leaf, leaf * 0.8, leaf), _leaf_mat, false, rng.randf() * PI)
	for k in 3:
		var bp := Vector3(rng.randf_range(rect.position.x + 6, rect.end.x - 6), 0.45, rng.randf_range(rect.position.y + 6, rect.end.y - 6))
		add_box(bp, Vector3(2.2, 0.5, 0.7), _trunk_mat, true, rng.randf() * PI)


func _build_streetlights() -> void:
	var pole := _plain(Color("#2a2c30"), 0.5)
	for i in range(GRID + 1):
		for j in range(GRID + 1):
			if (i + j) % 2 == 1:
				continue
			var x := -HALF + i * CELL + ROAD * 0.5 + 1.0
			var z := -HALF + j * CELL + ROAD * 0.5 + 1.0
			add_box(Vector3(x, 3.5, z), Vector3(0.25, 7.0, 0.25), pole, false)
			add_box(Vector3(x - 0.8, 7.0, z - 0.8), Vector3(1.8, 0.15, 0.3), pole, false, PI * 0.25)
			add_box(Vector3(x - 1.3, 6.85, z - 1.3), Vector3(0.6, 0.15, 0.6), _lamp_mat, false, PI * 0.25)


# --- Landmarks --------------------------------------------------------------

func _build_landmarks() -> void:
	for key in LANDMARK_BLOCKS.keys():
		var kind: String = LANDMARK_BLOCKS[key]
		var rect := _block_rect(key.x, key.y)
		var c := rect.get_center()
		var base := Vector3(c.x, 0, c.y)
		match kind:
			"queen":
				_tower(rect.grow(-14.0), 190.0, _glass_mat, Color("#3aff6a"))
				_label("QUEEN CONSOLIDATED", base + Vector3(0, 30, 0), 4.0, Color("#d8ffe0"))
				_add_landmark("Queen Consolidated", rect, base)
			"verdant":
				_add_building(rect.grow(-12.0), 10.0, _dark_mat)
				_label("VERDANT", base + Vector3(0, 13, 0), 3.0, Color("#3aff6a"))
				_add_landmark("Verdant", rect, base)
			"star_labs":
				_star_labs(base)
				_add_landmark("S.T.A.R. Labs", rect, base)
			"ccpd":
				_add_building(rect.grow(-8.0), 24.0, facade_mats[1][1])
				_label("CCPD", base + Vector3(0, 28, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("CCPD", rect, base)
			"jitters":
				var r := rect.grow(-6.0)
				_add_building(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), 30.0, facade_mats[1][0])
				_add_building(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45)), 8.0, _plain(Color("#6a3a22")))
				_label("JITTERS", base + Vector3(0, 11, r.size.y * 0.27), 2.5, Color("#ffd27a"))
				_add_landmark("Jitters", rect, base)
			"catco":
				_tower(rect.grow(-12.0), 175.0, facade_mats[2][0], Color("#ffffff"))
				add_box(base + Vector3(0, 120, -(rect.size.y * 0.5 - 12.0) - 2.5), Vector3(14, 0.6, 5), _concrete_mat)
				_label("CATCO", base + Vector3(0, 182, 0), 8.0, Color("#ffffff"))
				_add_landmark("CatCo Worldwide", rect, base)
			"deo":
				_tower(rect.grow(-14.0), 115.0, _dark_mat, Color("#4fa8ff"))
				add_box(base + Vector3(0, 116.0, 0), Vector3(16, 0.4, 16), _plain(Color("#3a3a3a")))
				_label("D.E.O.", base + Vector3(0, 124, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("The D.E.O.", rect, base)
			"garfield":
				_add_building(rect.grow(-6.0), 12.0, facade_mats[3][0])
				_label("GARFIELD HIGH", base + Vector3(0, 15, 0), 3.0, Color("#ffe0a0"))
				_add_landmark("Garfield High", rect, base)
			"iron_heights":
				_iron_heights(rect)
				_add_landmark("Iron Heights", rect, base)
	_waverider(Vector3(0, 140, 0))
	landmarks.append({"name": "Unity Park", "pos": Vector3(20, 0.5, 20), "district": "Unity Park"})
	landmarks.append({"name": "The Waverider", "pos": Vector3(0, 146, 10), "district": "Unity Park"})
	for k in 4:
		landmarks.append({"name": DISTRICTS[k] + " Downtown", "pos": snap_to_road(district_center(k)) + Vector3.UP * 0.5, "district": DISTRICTS[k]})


func _add_landmark(name: String, rect: Rect2, base: Vector3) -> void:
	var street := Vector3(base.x, 0.5, rect.position.y - ROAD * 0.5 + 2.0)
	landmarks.append({"name": name, "pos": street, "district": district_at(base)})


func _tower(r: Rect2, h: float, m: Material, crown: Color) -> void:
	_add_building(r, h, m)
	var c := r.get_center()
	add_box(Vector3(c.x, h - 4.0, c.y), Vector3(r.size.x + 0.4, 1.2, r.size.y + 0.4), _plain(crown, 0.5, 2.0), false)
	add_box(Vector3(c.x, h + 12.0, c.y), Vector3(0.6, 24.0, 0.6), _plain(Color("#aaaaaa")), false)


func _star_labs(base: Vector3) -> void:
	var drum := CylinderMesh.new()
	drum.top_radius = 24.0
	drum.bottom_radius = 26.0
	drum.height = 18.0
	drum.radial_segments = 48
	_mesh_instance(drum, Transform3D(Basis(), base + Vector3(0, 9, 0)), facade_mats[2][0])
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 25.0
	cyl.height = 18.0
	cs.shape = cyl
	cs.position = base + Vector3(0, 9, 0)
	_body.add_child(cs)
	var ring := TorusMesh.new()
	ring.inner_radius = 22.0
	ring.outer_radius = 26.5
	ring.rings = 48
	_mesh_instance(ring, Transform3D(Basis(), base + Vector3(0, 19, 0)), _plain(Color("#cfd6dd"), 0.3))
	var dome := SphereMesh.new()
	dome.radius = 18.0
	dome.height = 18.0
	dome.is_hemisphere = true
	var glass := _plain(Color("#6ab0e0"), 0.1, 0.4)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.55
	_mesh_instance(dome, Transform3D(Basis(), base + Vector3(0, 18, 0)), glass)
	var top := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(26, 1, 26)
	top.shape = tb
	top.position = base + Vector3(0, 18.5, 0)
	_body.add_child(top)
	buildings.append({"rect": Rect2(base.x - 25, base.z - 25, 50, 50), "h": 18.0})
	_label("S.T.A.R. LABS", base + Vector3(0, 30, 0), 4.0, Color("#e0f0ff"))


func _iron_heights(rect: Rect2) -> void:
	var wall := _concrete_mat
	var c := rect.get_center()
	var s := rect.size.x - 2.0
	var h := 9.0
	add_box(Vector3(c.x, h * 0.5, rect.position.y + 1.0), Vector3(s, h, 1.2), wall)
	add_box(Vector3(c.x, h * 0.5, rect.end.y - 1.0), Vector3(s, h, 1.2), wall)
	add_box(Vector3(rect.position.x + 1.0, h * 0.5, c.y), Vector3(1.2, h, s), wall)
	add_box(Vector3(rect.end.x - 1.0, h * 0.5, c.y + 6.0), Vector3(1.2, h, s - 12.0), wall)
	for cx in [rect.position.x + 2.0, rect.end.x - 2.0]:
		for cz in [rect.position.y + 2.0, rect.end.y - 2.0]:
			add_box(Vector3(cx, 7.0, cz), Vector3(4, 14, 4), _plain(Color("#6a6a6a")))
	_add_building(rect.grow(-16.0), 16.0, _plain(Color("#7a7a74")))
	_label("IRON HEIGHTS", Vector3(c.x, 22, c.y), 3.5, Color("#ffb0a0"))


func _waverider(pos: Vector3) -> void:
	var hull := _plain(Color("#9aa3ad"), 0.4)
	var dark := _plain(Color("#2a3038"), 0.5)
	var glow := _plain(Color("#6ad0ff"), 0.2, 3.0)
	add_box(pos, Vector3(14, 6, 60), hull)
	add_box(pos + Vector3(0, 3.5, -4), Vector3(10, 2, 36), dark)
	add_box(pos + Vector3(0, -0.5, -36), Vector3(8, 4, 14), hull)
	add_box(pos + Vector3(0, 1.0, -42), Vector3(5, 2, 4), dark)
	add_box(pos + Vector3(-15, 0, 12), Vector3(18, 1.2, 16), hull, true, -0.2)
	add_box(pos + Vector3(15, 0, 12), Vector3(18, 1.2, 16), hull, true, 0.2)
	for sx in [-5.0, 5.0]:
		add_box(pos + Vector3(sx, 0, 31), Vector3(4, 4, 2), glow, false)
	add_box(pos + Vector3(0, 3.1, 10), Vector3(12, 0.2, 24), _plain(Color("#5a6470")))
	_label("WAVERIDER", pos + Vector3(0, 12, 0), 3.0, Color("#bfe8ff"))
	buildings.append({"rect": Rect2(pos.x - 7, pos.z - 30, 14, 60), "h": -1.0})
