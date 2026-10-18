class_name City
extends Node3D
## Procedurally builds a map from a "spec" (which Earth, which era).
##
## The present-day map is a bay with four separate city islands, each with its
## own architecture and landmarks, joined by suspension bridges:
##   Star City (NW): steel-and-glass towers, the rundown Glades, the docks.
##   Central City (NE): brick and sandstone, S.T.A.R. Labs, CCPD, Jitters.
##   National City (SW): white stone and blue glass, palm-lined beach, CatCo, the D.E.O.
##   Freeland (SE): low-rise brick neighbourhoods, Garfield High.
## plus Lian Yu (a jungle island far offshore) and Iron Heights prison.
## Other Earths and eras reuse the layout with a different look, or swap it
## for something else entirely (an Old West town, the Speed Force).
##
## Buildings are drawn with a handful of MultiMeshes and collide through one
## static body, so the whole map costs only a few dozen draw calls.

const CELL := 80.0
const ROAD := 16.0
const BLOCK := CELL - ROAD
const N := 8                              # blocks per island side
const HALF := N * CELL * 0.5              # half-size of an island's road grid
const SHORE := 50.0                       # land beyond the outer roads
const LAND := HALF + SHORE                # half-size of an island
const SEA := 4500.0
const FACADE_SHADER := preload("res://shaders/facade.gdshader")
const DISTRICTS := ["Star City", "Central City", "National City", "Freeland"]
const ISLAND_CENTERS := [Vector2(-560, -560), Vector2(560, -560), Vector2(-560, 560), Vector2(560, 560)]
const DISTRICT_CENTERS := ISLAND_CENTERS  # kept for older callers
const LIAN_YU := Vector2(-1560, -1400)
const IRON_HEIGHTS := Vector2(1280, -560)

## Per-island architecture.
const STYLES := [
	{"facades": ["#363d45", "#262d33", "#454842"], "glass": "#2a3c48", "min_h": 14.0, "max_h": 200.0, "towers": 0.55,
		"lights": 0.75, "trees": false, "fog": 0.0},
	{"facades": ["#7a3d2c", "#8f7d68", "#6a4434"], "glass": "#4c5a68", "min_h": 10.0, "max_h": 110.0, "towers": 0.25,
		"lights": 1.0, "trees": true, "fog": 0.0},
	{"facades": ["#d2dae2", "#7a9ab8", "#aab4be"], "glass": "#5a8ab0", "min_h": 16.0, "max_h": 180.0, "towers": 0.5,
		"lights": 1.0, "trees": true, "palms": true, "fog": 0.0},
	{"facades": ["#8a6a4a", "#6b5a4b", "#a28c6c"], "glass": "#5a5048", "min_h": 6.0, "max_h": 34.0, "towers": 0.0,
		"lights": 0.9, "trees": true, "fog": 0.0},
]

var spec: Dictionary = {}
var kind := "metro"
var city_seed := 1987
var rng := RandomNumberGenerator.new()
var buildings: Array = []        # {rect: Rect2 (x/z footprint), h: float}
var landmarks: Array = []        # {name, pos: Vector3, district}
var parked: Array = []           # {kind, xform: Transform3D}
var doors: Array = []            # {name, pos: Vector3, interior: String}
var islands: Array = []          # {name, center: Vector2, land: Rect2, grid: Rect2, style}
var bridges: Array[Rect2] = []
var extra_land: Array = []       # {rect: Rect2, name}
var waverider_dock := Vector3(0, 4.5, -500)
var facade_mats: Array = []
var lit_mats: Array[ShaderMaterial] = []
var _instances: Dictionary = {}
var _body: StaticBody3D
var _lamp_mat: StandardMaterial3D
var _window_albedo: ImageTexture
var _window_emission: ImageTexture


func generate(p_seed := 1987, p_spec: Dictionary = {}) -> void:
	city_seed = p_seed
	spec = p_spec
	kind = str(spec.get("kind", "metro"))
	rng.seed = city_seed + hash(str(spec.get("earth", ""))) % 1000
	_body = StaticBody3D.new()
	_body.name = "CityCollision"
	_body.collision_layer = Game.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_make_textures()
	_make_materials()
	match kind:
		"western":
			_build_western()
		"speedforce":
			_build_speed_force()
		_:
			_build_sea()
			for i in ISLAND_CENTERS.size():
				_build_island(i)
			_build_bridges()
			if not spec.get("ruined", false):
				_build_lian_yu()
				_build_iron_heights()
			_build_bay_landmarks()
	Interiors.build_all(self)
	_flush_instances()


func _tint(c: Color) -> Color:
	if spec.has("tint"):
		return c.lerp(Color(str(spec["tint"])), float(spec.get("tint_amount", 0.4)))
	return c


# --- Queries ----------------------------------------------------------------

func island_at(p: Vector3) -> Dictionary:
	for isl in islands:
		if isl["land"].has_point(Vector2(p.x, p.z)):
			return isl
	return {}


func is_water(p: Vector3) -> bool:
	if kind != "metro" or Interiors.is_inside(p):
		return false
	var q := Vector2(p.x, p.z)
	for isl in islands:
		if isl["land"].has_point(q):
			return false
	for b in bridges:
		if b.has_point(q):
			return false
	for e in extra_land:
		if e["rect"].has_point(q):
			return false
	return true


func district_at(p: Vector3) -> String:
	var room := Interiors.room_at(p)
	if room != "":
		return Interiors.NAMES[room]
	if kind == "western":
		return "Old West"
	if kind == "speedforce":
		return "The Speed Force"
	var q := Vector2(p.x, p.z)
	for e in extra_land:
		if e["rect"].has_point(q):
			return e["name"]
	for b in bridges:
		if b.has_point(q):
			return "Bridge"
	var isl := island_at(p)
	if isl.is_empty():
		return "The Bay"
	if isl["name"] == "Star City" and p.x > isl["center"].x + CELL and p.z > isl["center"].y + CELL:
		return "The Glades"
	return isl["name"]


func district_index(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in ISLAND_CENTERS.size():
		var d: float = (ISLAND_CENTERS[i] as Vector2).distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = i
	return best


func district_center(index: int) -> Vector3:
	if kind != "metro":
		return Vector3(0, 0.2, 0)
	var c: Vector2 = ISLAND_CENTERS[clampi(index, 0, 3)]
	return Vector3(c.x, 0.2, c.y)


func _nearest_grid(p: Vector3) -> Rect2:
	if kind != "metro":
		return Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	var best := Rect2()
	var best_d := INF
	for isl in islands:
		var g: Rect2 = isl["grid"]
		var d := g.get_center().distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = g
	return best


## True when a point lies on (or inside) an island's street grid.
func on_grid(p: Vector3) -> bool:
	for isl in islands:
		if isl["grid"].grow(1.0).has_point(Vector2(p.x, p.z)):
			return true
	return kind != "metro" and absf(p.x) <= HALF and absf(p.z) <= HALF


## Snaps a point onto the nearest street (roads run along every multiple of CELL).
func snap_to_road(p: Vector3, lane_offset := 0.0) -> Vector3:
	var g := _nearest_grid(p)
	var out := p
	out.x = clampf(out.x, g.position.x, g.end.x)
	out.z = clampf(out.z, g.position.y, g.end.y)
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
	var lit := float(spec.get("lit", 1.0))
	for m in lit_mats:
		m.set_shader_parameter("night", f * lit * float(m.get_meta("lights", 1.0)))
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = (0.2 + f * 3.0) * lit


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
	var neon: bool = spec.get("neon", false)
	for wy in 8:
		for wx in 8:
			var rect := Rect2i(wx * cell + 10, wy * cell + 14, cell - 20, cell - 30)
			albedo.fill_rect(rect, Color(0.16, 0.19, 0.23))
			albedo.fill_rect(Rect2i(rect.position.x, rect.position.y + rect.size.y, rect.size.x, 3), Color(0.7, 0.7, 0.7))
			if r.randf() < 0.38:
				var warm := Color(1.0, 0.82, 0.5).lerp(Color(0.75, 0.88, 1.0), r.randf() * 0.5)
				if neon:
					warm = [Color("#3affff"), Color("#ff4fd8"), Color("#9a6aff")][r.randi() % 3]
				emission.fill_rect(rect, warm * r.randf_range(0.6, 1.0))
	albedo.generate_mipmaps()
	emission.generate_mipmaps()
	_window_albedo = ImageTexture.create_from_image(albedo)
	_window_emission = ImageTexture.create_from_image(emission)


func _facade(color: Color, roughness := 0.8, metallic := 0.0, lights := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FACADE_SHADER
	m.set_shader_parameter("tint", _tint(color))
	m.set_shader_parameter("facade", _window_albedo)
	m.set_shader_parameter("lights", _window_emission)
	m.set_shader_parameter("tile", 32.0)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("metallic_value", metallic)
	m.set_meta("lights", lights)
	lit_mats.append(m)
	return m


func _plain(color: Color, roughness := 0.9, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = _tint(color) if emission <= 0.0 else color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


var _roof_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _grass_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D
var _trunk_mat: StandardMaterial3D
var _leaf_mat: StandardMaterial3D
var _palm_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _steel_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _glass_mats: Array = []
var _glades_mats: Array = []


func _make_materials() -> void:
	for st in STYLES:
		var row := []
		for c in st["facades"]:
			row.append(_facade(Color(str(c)), 0.8, 0.0, float(st["lights"])))
		facade_mats.append(row)
		_glass_mats.append(_facade(Color(str(st["glass"])), 0.25, 0.6, float(st["lights"])))
	for c in ["#5a3a2c", "#4a443c", "#3a3430"]:
		_glades_mats.append(_facade(Color(c), 0.9, 0.0, 0.45))
	_roof_mat = _plain(Color("#3b3d40"))
	_sidewalk_mat = _plain(Color("#8d8f92"))
	_grass_mat = _plain(Color("#3f6b34"))
	_sand_mat = _plain(Color("#d8c89a"))
	_trunk_mat = _plain(Color("#4a3624"))
	_leaf_mat = _plain(Color("#2f5a2a"))
	_palm_mat = _plain(Color("#3f7a34"))
	_concrete_mat = _plain(Color("#9a9690"))
	_dark_mat = _plain(Color("#1c1f24"), 0.4)
	_steel_mat = _plain(Color("#8a2a22") if spec.get("earth", "") != "Earth-X" else Color("#2a2a2a"), 0.5)
	_lamp_mat = _plain(Color("#ffe2a0"), 0.5, 0.2)
	_road_mat = _make_road_material()


func _make_road_material() -> StandardMaterial3D:
	# One texel row of paint on each side of the tile seam = a 0.3 m line.
	var res := 512
	var road_img := Image.create(res, res, false, Image.FORMAT_RGB8)
	road_img.fill(Color(0.17, 0.17, 0.18))
	var paint := Color(0.8, 0.66, 0.2)
	var dash := 20
	for k in range(0, res, dash * 2):
		for t in range(k, k + dash):
			road_img.set_pixel(0, t, paint)
			road_img.set_pixel(res - 1, t, paint)
			road_img.set_pixel(t, 0, paint)
			road_img.set_pixel(t, res - 1, paint)
	road_img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(road_img)
	m.albedo_color = _tint(Color.WHITE)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / CELL
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


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


func add_cylinder_collision(center: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position = center
	_body.add_child(cs)


func _add_building(rect: Rect2, height: float, m: Material) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, height * 0.5, c.y), Vector3(rect.size.x, height, rect.size.y), m)
	add_box(Vector3(c.x, height + 0.3, c.y), Vector3(rect.size.x + 0.6, 0.6, rect.size.y + 0.6), _roof_mat, true)
	buildings.append({"rect": rect, "h": height})
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


func _add_landmark(name: String, pos: Vector3, district: String, door := "") -> void:
	landmarks.append({"name": name, "pos": pos, "district": district})
	if door != "":
		doors.append({"name": name, "pos": pos, "interior": door})


# --- Sea, islands and bridges ----------------------------------------------

func _build_sea() -> void:
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
	wm.albedo_color = _tint(Color(0.08, 0.25, 0.36))
	wm.albedo_color.a = 0.82
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.3
	wm.roughness = 0.12
	var water_mi := _mesh_instance(water, Transform3D(Basis(), Vector3(0, -0.25, 0)), wm)
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_island(index: int) -> void:
	var c: Vector2 = ISLAND_CENTERS[index]
	var st: Dictionary = STYLES[index]
	var name: String = DISTRICTS[index]
	var land := Rect2(c.x - LAND, c.y - LAND, LAND * 2.0, LAND * 2.0)
	var grid := Rect2(c.x - HALF, c.y - HALF, HALF * 2.0, HALF * 2.0)
	islands.append({"name": name, "center": c, "land": land, "grid": grid, "style": st, "index": index})
	# Land mass, a seawall, and the asphalt street grid with lane markings.
	add_box(Vector3(c.x, -1.5, c.y), Vector3(LAND * 2.0, 3.0, LAND * 2.0), _grass_mat)
	var asphalt := PlaneMesh.new()
	asphalt.size = Vector2(HALF * 2.0 + ROAD, HALF * 2.0 + ROAD)
	_mesh_instance(asphalt, Transform3D(Basis(), Vector3(c.x, 0.03, c.y)), _road_mat)
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x + side * (LAND + 0.5), 0.6, c.y), Vector3(1.0, 1.2, LAND * 2.0), _concrete_mat, false)
		add_box(Vector3(c.x, 0.6, c.y + side * (LAND + 0.5)), Vector3(LAND * 2.0, 1.2, 1.0), _concrete_mat, false)
	for i in N:
		for j in N:
			_build_block(index, i, j)
	_build_streetlights(c)
	_build_shore(index, c)
	_build_island_landmarks(index, c)
	landmarks.append({"name": name + " Downtown", "pos": snap_to_road(Vector3(c.x, 0, c.y)) + Vector3.UP * 0.5, "district": name})
	_label(name.to_upper() if not spec.has("label") else "%s %s" % [spec["label"], name.to_upper()],
		Vector3(c.x, 0, c.y - LAND - 8.0) + Vector3.UP * 14.0, 9.0, Color(1, 1, 1, 0.85))


func _block_rect(c: Vector2, i: int, j: int) -> Rect2:
	return Rect2(c.x - HALF + i * CELL + ROAD * 0.5, c.y - HALF + j * CELL + ROAD * 0.5, BLOCK, BLOCK)


## Island blocks reserved for landmarks, keyed by island index.
const LANDMARK_BLOCKS := {
	0: {Vector2i(3, 3): "queen", Vector2i(5, 6): "verdant", Vector2i(4, 4): "park", Vector2i(1, 2): "scpd"},
	1: {Vector2i(6, 1): "star_labs", Vector2i(3, 3): "ccpd", Vector2i(4, 3): "jitters", Vector2i(3, 4): "park", Vector2i(4, 5): "picture_news"},
	2: {Vector2i(3, 3): "catco", Vector2i(5, 2): "deo", Vector2i(4, 5): "park", Vector2i(2, 5): "lcorp"},
	3: {Vector2i(3, 3): "garfield", Vector2i(5, 4): "court", Vector2i(2, 5): "clinic", Vector2i(4, 4): "park"},
}


func _build_block(index: int, i: int, j: int) -> void:
	var c: Vector2 = ISLAND_CENTERS[index]
	var st: Dictionary = STYLES[index]
	var rect := _block_rect(c, i, j)
	var bc := rect.get_center()
	add_box(Vector3(bc.x, 0.08, bc.y), Vector3(BLOCK, 0.16, BLOCK), _sidewalk_mat, false)
	var key := Vector2i(i, j)
	var reserved: Dictionary = LANDMARK_BLOCKS[index]
	if reserved.has(key):
		var what: String = reserved[key]
		if what == "park":
			_build_park(rect, true, st.get("palms", false))
		elif what == "court":
			_build_court(rect)
		return
	var glades := index == 0 and i >= 5 and j >= 5
	var edge := i == 0 or j == 0 or i == N - 1 or j == N - 1
	if not edge and rng.randf() < 0.05:
		_build_park(rect, false, st.get("palms", false))
		return
	var inner := rect.grow(-3.0)
	var mats: Array = _glades_mats if glades else facade_mats[index]
	# Downtown sits at the island centre; heights fall off toward the shore.
	var downtown := clampf(1.0 - bc.distance_to(c) / (HALF * 1.1), 0.0, 1.0)
	var min_h: float = st["min_h"]
	var max_h: float = st["max_h"] * float(spec.get("height", 1.0))
	if glades:
		max_h = 22.0
	var height_base := lerpf(min_h, max_h, pow(downtown, 1.5))
	if edge:
		height_base = minf(height_base, 18.0)
	if (index == 0 and edge and j == N - 1) or (index == 3 and edge and rng.randf() < 0.5):
		# Docks and warehouses
		var n := rng.randi_range(1, 2)
		for k in n:
			var r := Rect2(inner.position.x + k * inner.size.x / n + 2.0, inner.position.y + 4.0, inner.size.x / n - 4.0, inner.size.y - 8.0)
			_add_building(r, rng.randf_range(8, 14), mats[2])
		_scatter_crates(inner, 6)
		return
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
		if h > 70.0 and rng.randf() < float(st["towers"]):
			m = _glass_mats[index]
		var fr: Rect2 = r.grow(-rng.randf_range(0.0, 3.0))
		if spec.get("ruined", false):
			_ruin(fr, h * rng.randf_range(0.3, 0.8), m)
		elif h > 70.0 and rng.randf() < 0.6:
			var podium := h * rng.randf_range(0.25, 0.45)
			_add_building(fr, podium, m)
			var tower := fr.grow(-fr.size.x * 0.18)
			var tc := tower.get_center()
			add_box(Vector3(tc.x, podium + (h - podium) * 0.5, tc.y), Vector3(tower.size.x, h - podium, tower.size.y), m)
			add_box(Vector3(tc.x, h + 0.3, tc.y), Vector3(tower.size.x + 0.6, 0.6, tower.size.y + 0.6), _roof_mat)
			buildings.append({"rect": tower, "h": h})
			if spec.get("neon", false):
				add_box(Vector3(tc.x, h + 15.0, tc.y), Vector3(1.0, 30.0, 1.0), _plain(Color("#3affff"), 0.3, 3.0), false)
		else:
			_add_building(fr, h, m)
		if spec.get("banners", false) and h > 20.0 and rng.randf() < 0.4:
			# Earth-X: long red banners hang down the facades.
			var bcx := fr.get_center()
			add_box(Vector3(bcx.x, h * 0.55, fr.position.y - 0.3), Vector3(minf(6.0, fr.size.x * 0.4), h * 0.7, 0.2), _plain(Color("#8a0000"), 0.8), false)
		if glades and rng.randf() < 0.5:
			# Glades: fire escapes and boarded-up shopfronts
			add_box(Vector3(fr.get_center().x, h * 0.5, fr.position.y - 0.6), Vector3(3.0, h * 0.9, 1.0), _steel_mat, false)
	for side in 4:
		if not spec.get("ruined", false) and rng.randf() < 0.45:
			_park_car(rect, side)


func _ruin(r: Rect2, h: float, m: Material) -> void:
	# 2046: shattered towers with jagged tops and rubble.
	_add_building(r, h, m)
	var c := r.get_center()
	for k in rng.randi_range(1, 3):
		var s := Vector3(rng.randf_range(4, r.size.x * 0.6), rng.randf_range(3, 10), rng.randf_range(4, r.size.y * 0.6))
		add_box(Vector3(c.x + rng.randf_range(-6, 6), h + s.y * 0.4, c.y + rng.randf_range(-6, 6)), s, m, true, rng.randf_range(-0.4, 0.4))
	add_box(Vector3(c.x + r.size.x * 0.6, 1.0, c.y), Vector3(6, 2, 6), _concrete_mat, true, rng.randf() * PI)


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


func _tree(p: Vector3, palm := false) -> void:
	if palm:
		var h := rng.randf_range(7.0, 10.0)
		for k in 5:
			var t0 := float(k) / 5.0
			add_box(p + Vector3(t0 * 0.6, h * (t0 + 0.1), 0), Vector3(0.45, h / 5.0 + 0.1, 0.45), _trunk_mat, k == 0)
		for f in 6:
			var ang := f * TAU / 6.0
			add_box(p + Vector3(0.6 + cos(ang) * 1.6, h + 0.2, sin(ang) * 1.6), Vector3(3.4, 0.15, 0.9), _palm_mat, false, -ang)
		return
	var h := rng.randf_range(3.0, 5.0)
	add_box(p + Vector3.UP * h * 0.5, Vector3(0.6, h, 0.6), _trunk_mat)
	var leaf := rng.randf_range(3.0, 4.5)
	add_box(p + Vector3.UP * (h + leaf * 0.35), Vector3(leaf, leaf * 0.8, leaf), _leaf_mat, false, rng.randf() * PI)
	add_box(p + Vector3.UP * (h + leaf * 0.85), Vector3(leaf * 0.65, leaf * 0.55, leaf * 0.65), _leaf_mat, false, rng.randf() * PI)


func _build_park(rect: Rect2, big: bool, palms := false) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.2, c.y), Vector3(rect.size.x - 4.0, 0.1, rect.size.y - 4.0), _grass_mat, false)
	var n := 12 if big else 7
	for k in n:
		var p := Vector3(rng.randf_range(rect.position.x + 5, rect.end.x - 5), 0, rng.randf_range(rect.position.y + 5, rect.end.y - 5))
		_tree(p, palms)
	if big:
		# A fountain in the middle
		var fountain := CylinderMesh.new()
		fountain.top_radius = 5.0
		fountain.bottom_radius = 5.4
		fountain.height = 0.8
		_mesh_instance(fountain, Transform3D(Basis(), Vector3(c.x, 0.4, c.y)), _concrete_mat)
		var pool := CylinderMesh.new()
		pool.top_radius = 4.5
		pool.bottom_radius = 4.5
		pool.height = 0.1
		var wm := _plain(Color("#3a7aa0"), 0.1)
		_mesh_instance(pool, Transform3D(Basis(), Vector3(c.x, 0.82, c.y)), wm)
		add_cylinder_collision(Vector3(c.x, 0.4, c.y), 5.2, 0.8)
	for k in 3:
		var bp := Vector3(rng.randf_range(rect.position.x + 6, rect.end.x - 6), 0.45, rng.randf_range(rect.position.y + 6, rect.end.y - 6))
		add_box(bp, Vector3(2.2, 0.5, 0.7), _trunk_mat, true, rng.randf() * PI)


func _build_court(rect: Rect2) -> void:
	# Freeland's basketball court
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.2, c.y), Vector3(30, 0.1, 18), _plain(Color("#b05a2a")), false)
	add_box(Vector3(c.x, 0.26, c.y), Vector3(0.2, 0.02, 18), _plain(Color("#f0f0f0")), false)
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x + side * 14.0, 2.0, c.y), Vector3(0.3, 4.0, 0.3), _dark_mat)
		add_box(Vector3(c.x + side * 13.5, 3.6, c.y), Vector3(0.2, 1.2, 1.8), _plain(Color("#f0f0f0")), false)
	_label("FREELAND COURTS", Vector3(c.x, 6, c.y), 1.8, Color("#ffd27a"))


func _build_streetlights(c: Vector2) -> void:
	var pole := _plain(Color("#2a2c30"), 0.5)
	for i in range(N + 1):
		for j in range(N + 1):
			if (i + j) % 2 == 1:
				continue
			var x := c.x - HALF + i * CELL + ROAD * 0.5 + 1.0
			var z := c.y - HALF + j * CELL + ROAD * 0.5 + 1.0
			add_box(Vector3(x, 3.5, z), Vector3(0.25, 7.0, 0.25), pole, false)
			add_box(Vector3(x - 0.8, 7.0, z - 0.8), Vector3(1.8, 0.15, 0.3), pole, false, PI * 0.25)
			add_box(Vector3(x - 1.3, 6.85, z - 1.3), Vector3(0.6, 0.15, 0.6), _lamp_mat, false, PI * 0.25)


func _build_shore(index: int, c: Vector2) -> void:
	match index:
		0:
			# Star City docks on the south shore of the Glades
			for k in 4:
				var x := c.x - 200.0 + k * 130.0
				add_box(Vector3(x, -0.1, c.y + LAND + 35.0), Vector3(14.0, 0.8, 70.0), _plain(Color("#5a4a3a")))
				for pz in range(0, 70, 10):
					for px in [-6.0, 6.0]:
						add_box(Vector3(x + px, -1.6, c.y + LAND + 2.0 + pz), Vector3(0.6, 3.0, 0.6), _trunk_mat, false)
			extra_land.append({"rect": Rect2(c.x - 210.0, c.y + LAND, 420.0, 70.0), "name": "Star City Docks"})
			landmarks.append({"name": "Star City Docks", "pos": Vector3(c.x - 200.0, 0.5, c.y + LAND + 30.0), "district": "Star City"})
		2:
			# National City beach along the south and west shores
			add_box(Vector3(c.x, -0.2, c.y + LAND + 25.0), Vector3(LAND * 2.0, 0.6, 50.0), _sand_mat)
			extra_land.append({"rect": Rect2(c.x - LAND, c.y + LAND, LAND * 2.0, 50.0), "name": "National City Beach"})
			for k in 16:
				_tree(Vector3(c.x - LAND + 20.0 + k * 45.0, 0, c.y + LAND + 10.0), true)
			landmarks.append({"name": "National City Beach", "pos": Vector3(c.x, 0.5, c.y + LAND + 25.0), "district": "National City"})


func _build_bridges() -> void:
	# Four suspension bridges ring the bay along the islands' central avenues.
	var specs := [
		[Vector2(-560 + LAND, -560), Vector2(560 - LAND, -560)],
		[Vector2(-560 + LAND, 560), Vector2(560 - LAND, 560)],
		[Vector2(-560, -560 + LAND), Vector2(-560, 560 - LAND)],
		[Vector2(560, -560 + LAND), Vector2(560, 560 - LAND)],
	]
	for s in specs:
		_bridge(s[0], s[1], ROAD + 6.0)


func _bridge(a: Vector2, b: Vector2, width: float) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := a.distance_to(b) + 20.0
	var mid := (a + b) * 0.5
	var size := Vector3(length, 1.0, width) if along_x else Vector3(width, 1.0, length)
	add_box(Vector3(mid.x, -0.48, mid.y), size, _concrete_mat)
	var deck := PlaneMesh.new()
	deck.size = Vector2(size.x, size.z)
	_mesh_instance(deck, Transform3D(Basis(), Vector3(mid.x, 0.03, mid.y)), _road_mat)
	var rect := Rect2(mid.x - size.x * 0.5, mid.y - size.z * 0.5, size.x, size.z)
	bridges.append(rect)
	# Railings, two towers and cables
	var dir := Vector2(1, 0) if along_x else Vector2(0, 1)
	var perp := Vector2(0, 1) if along_x else Vector2(1, 0)
	for side in [-1.0, 1.0]:
		var off: Vector2 = perp * side * (width * 0.5 - 0.3)
		var rail_size := Vector3(length, 1.0, 0.3) if along_x else Vector3(0.3, 1.0, length)
		add_box(Vector3(mid.x + off.x, 0.5, mid.y + off.y), rail_size, _steel_mat)
	var tower_off := length * 0.28
	for t in [-1.0, 1.0]:
		var tp: Vector2 = mid + dir * t * tower_off
		for side in [-1.0, 1.0]:
			var p: Vector2 = tp + perp * side * (width * 0.5 + 0.6)
			add_box(Vector3(p.x, 22.0, p.y), Vector3(2.2, 44.0, 2.2), _steel_mat)
		var beam_size := Vector3(2.0, 2.0, width + 4.0) if along_x else Vector3(width + 4.0, 2.0, 2.0)
		add_box(Vector3(tp.x, 42.0, tp.y), beam_size, _steel_mat, false)
	# Main cables: deck end -> tower top -> sag at mid-span -> tower top -> deck end.
	for side in [-1.0, 1.0]:
		var off: Vector2 = perp * side * (width * 0.5 + 0.6)
		var t1: Vector2 = mid - dir * tower_off + off
		var t2: Vector2 = mid + dir * tower_off + off
		var span_pts := [Vector3(a.x + off.x, 1.5, a.y + off.y), Vector3(t1.x, 43.0, t1.y)]
		for k in range(1, 8):
			var u := float(k) / 8.0
			var q: Vector2 = t1.lerp(t2, u)
			span_pts.append(Vector3(q.x, 43.0 - 34.0 * sin(u * PI), q.y))
		span_pts.append(Vector3(t2.x, 43.0, t2.y))
		span_pts.append(Vector3(b.x + off.x, 1.5, b.y + off.y))
		for k in span_pts.size() - 1:
			var p0: Vector3 = span_pts[k]
			var p1: Vector3 = span_pts[k + 1]
			var seg := p1 - p0
			var basis := Basis.looking_at(seg.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.3, 0.3, seg.length()))
			if not _instances.has(_steel_mat):
				_instances[_steel_mat] = []
			_instances[_steel_mat].append(Transform3D(basis, (p0 + p1) * 0.5))


# --- Landmarks --------------------------------------------------------------

func _build_island_landmarks(index: int, c: Vector2) -> void:
	var reserved: Dictionary = LANDMARK_BLOCKS[index]
	for key in reserved.keys():
		var what: String = reserved[key]
		var rect := _block_rect(c, key.x, key.y)
		var bc := rect.get_center()
		var base := Vector3(bc.x, 0, bc.y)
		var front := Vector3(bc.x, 0.5, rect.position.y - 4.0)
		var district: String = DISTRICTS[index]
		match what:
			"queen":
				_tower(rect.grow(-14.0), 210.0 * float(spec.get("height", 1.0)), _glass_mats[0], Color("#3aff6a"))
				_label("QUEEN CONSOLIDATED", base + Vector3(0, 32, 0), 4.0, Color("#d8ffe0"))
				_add_landmark("Queen Consolidated", front, district)
			"verdant":
				_add_building(rect.grow(-12.0), 10.0, _dark_mat)
				_label("VERDANT", base + Vector3(0, 13, 0), 3.0, Color("#3aff6a"))
				add_box(Vector3(bc.x, 4.5, rect.position.y + 11.5), Vector3(12.0, 1.0, 0.4), _plain(Color("#3aff6a"), 0.4, 3.0), false)
				_add_landmark("Verdant", front, "The Glades", "bunker")
			"scpd":
				_add_building(rect.grow(-8.0), 26.0, facade_mats[0][2])
				_label("SCPD", base + Vector3(0, 30, 0), 3.5, Color("#bcd4ff"))
				_add_landmark("SCPD", front, district)
			"star_labs":
				_star_labs(base)
				_add_landmark("S.T.A.R. Labs", Vector3(bc.x, 0.5, bc.y - 30.0), district, "star_labs")
			"ccpd":
				_add_building(rect.grow(-8.0), 24.0, facade_mats[1][1])
				_label("CCPD", base + Vector3(0, 28, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("CCPD", front, district)
			"jitters":
				var r := rect.grow(-6.0)
				_add_building(Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(r.size.x, r.size.y * 0.55)), 30.0, facade_mats[1][0])
				_add_building(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), 7.0, _plain(Color("#6a3a22")))
				add_box(Vector3(bc.x, 3.5, r.position.y - 0.3), Vector3(16.0, 1.2, 0.3), _plain(Color("#ffd27a"), 0.4, 2.0), false)
				_label("JITTERS", Vector3(bc.x, 9.5, r.position.y), 2.5, Color("#ffd27a"))
				_add_landmark("Jitters", Vector3(bc.x, 0.5, r.position.y - 3.0), district, "jitters")
			"picture_news":
				_add_building(rect.grow(-8.0), 45.0, facade_mats[1][2])
				_label("PICTURE NEWS", base + Vector3(0, 49, 0), 3.0, Color("#ffffff"))
				_add_landmark("Picture News", front, district)
			"catco":
				_tower(rect.grow(-12.0), 180.0 * float(spec.get("height", 1.0)), facade_mats[2][0], Color("#ffffff"))
				add_box(base + Vector3(0, 120, -(rect.size.y * 0.5 - 12.0) - 2.5), Vector3(14, 0.6, 5), _concrete_mat)
				_label("CATCO", base + Vector3(0, 188, 0), 8.0, Color("#ffffff"))
				_add_landmark("CatCo Worldwide", front, district, "catco")
			"deo":
				_tower(rect.grow(-14.0), 120.0, _dark_mat, Color("#4fa8ff"))
				add_box(base + Vector3(0, 121.0, 0), Vector3(16, 0.4, 16), _plain(Color("#3a3a3a")))
				_label("D.E.O.", base + Vector3(0, 130, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("The D.E.O.", front, district, "deo")
			"lcorp":
				_tower(rect.grow(-14.0), 150.0, _glass_mats[2], Color("#c8d8e8"))
				_label("L-CORP", base + Vector3(0, 158, 0), 4.0, Color("#e8f0f8"))
				_add_landmark("L-Corp", front, district)
			"garfield":
				_add_building(rect.grow(-6.0), 12.0, facade_mats[3][0])
				_label("GARFIELD HIGH", base + Vector3(0, 15, 0), 3.0, Color("#ffe0a0"))
				_add_landmark("Garfield High", front, district)
			"clinic":
				_add_building(rect.grow(-10.0), 14.0, _plain(Color("#d8d0c4")))
				add_box(Vector3(bc.x, 9.0, rect.position.y + 9.7), Vector3(3.0, 3.0, 0.3), _plain(Color("#e03030"), 0.4, 2.0), false)
				_label("FREELAND CLINIC", base + Vector3(0, 17, 0), 2.5, Color("#ffffff"))
				_add_landmark("Freeland Clinic", front, district)


func _build_bay_landmarks() -> void:
	# The Waverider's landing pad, off the Star City - Central City bridge.
	var pad := Rect2(-45, -549, 90, 110)
	add_box(Vector3(0, -0.45, pad.get_center().y), Vector3(pad.size.x, 1.0, pad.size.y), _concrete_mat)
	var stripe := _plain(Color("#ffd23a"), 0.6, 0.8)
	for side in [-1.0, 1.0]:
		add_box(Vector3(side * 20.0, 0.06, pad.get_center().y), Vector3(1.0, 0.1, 90.0), stripe, false)
	for k in 6:
		add_box(Vector3(-40 + k * 16.0, 0.3, pad.end.y - 1.0), Vector3(0.4, 0.6, 0.4), _plain(Color("#6ad0ff"), 0.2, 3.0), false)
	extra_land.append({"rect": pad, "name": "Waverider Landing Pad"})
	_label("TIME BUREAU PAD", Vector3(0, 3.0, pad.end.y - 2.0), 1.6, Color("#bfe8ff"))
	landmarks.append({"name": "The Waverider", "pos": Vector3(0, 0.5, -462), "district": "Waverider Landing Pad"})


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
	add_cylinder_collision(base + Vector3(0, 9, 0), 25.0, 18.0)
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
	# Entrance canopy facing the road
	add_box(base + Vector3(0, 4.5, -27.0), Vector3(12.0, 0.5, 6.0), _plain(Color("#cfd6dd")), false)
	add_box(base + Vector3(0, 2.0, -25.2), Vector3(7.0, 4.0, 0.3), _plain(Color("#6ab0e0"), 0.1, 0.6), false)
	buildings.append({"rect": Rect2(base.x - 25, base.z - 25, 50, 50), "h": 18.0})
	_label("S.T.A.R. LABS", base + Vector3(0, 30, 0), 4.0, Color("#e0f0ff"))


func _build_iron_heights() -> void:
	var c := IRON_HEIGHTS
	var half := 110.0
	add_box(Vector3(c.x, -1.5, c.y), Vector3(half * 2.0, 3.0, half * 2.0), _concrete_mat)
	extra_land.append({"rect": Rect2(c.x - half, c.y - half, half * 2.0, half * 2.0), "name": "Iron Heights"})
	var wall := _concrete_mat
	var s := 150.0
	var h := 11.0
	add_box(Vector3(c.x, h * 0.5, c.y - s * 0.5), Vector3(s, h, 1.5), wall)
	add_box(Vector3(c.x, h * 0.5, c.y + s * 0.5), Vector3(s, h, 1.5), wall)
	add_box(Vector3(c.x + s * 0.5, h * 0.5, c.y), Vector3(1.5, h, s), wall)
	add_box(Vector3(c.x - s * 0.5, h * 0.5, c.y - 40.0), Vector3(1.5, h, s - 80.0), wall)
	add_box(Vector3(c.x - s * 0.5, h * 0.5, c.y + 40.0), Vector3(1.5, h, s - 80.0), wall)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			add_box(Vector3(c.x + cx * s * 0.5, 9.0, c.y + cz * s * 0.5), Vector3(5, 18, 5), _plain(Color("#6a6a6a")))
	_add_building(Rect2(c.x - 40, c.y - 25, 80, 50), 18.0, _plain(Color("#7a7a74")))
	_label("IRON HEIGHTS", Vector3(c.x, 26, c.y), 4.0, Color("#ffb0a0"))
	_bridge(Vector2(560 + LAND, c.y), Vector2(c.x - half, c.y), ROAD)
	landmarks.append({"name": "Iron Heights", "pos": Vector3(c.x - 90.0, 0.5, c.y), "district": "Iron Heights"})


## Lian Yu: a jungle island far offshore, with hills, a plane wreck and the
## bunker Oliver hid in. Only reachable by flying, swimming or teleporting.
func _build_lian_yu() -> void:
	var c := LIAN_YU
	var half := 230.0
	add_box(Vector3(c.x, -1.5, c.y), Vector3(half * 2.0, 3.0, half * 2.0), _plain(Color("#4a6a34")))
	add_box(Vector3(c.x, -0.2, c.y), Vector3(half * 2.0 + 30.0, 0.6, half * 2.0 + 30.0), _sand_mat, false)
	extra_land.append({"rect": Rect2(c.x - half - 15.0, c.y - half - 15.0, half * 2.0 + 30.0, half * 2.0 + 30.0), "name": "Lian Yu"})
	var hill_mat := _plain(Color("#3a5a2c"))
	for k in 6:
		var hp := Vector3(c.x + rng.randf_range(-150, 150), 0, c.y + rng.randf_range(-150, 150))
		var r := rng.randf_range(30.0, 60.0)
		var hh := rng.randf_range(18.0, 45.0)
		var cone := CylinderMesh.new()
		cone.top_radius = r * 0.15
		cone.bottom_radius = r
		cone.height = hh
		cone.radial_segments = 12
		_mesh_instance(cone, Transform3D(Basis(), hp + Vector3.UP * hh * 0.5), hill_mat)
		for step in 4:
			var t := (step + 0.5) / 4.0
			add_cylinder_collision(hp + Vector3.UP * hh * t, lerpf(r, r * 0.15, t), hh / 4.0)
	for k in 160:
		var p := Vector3(c.x + rng.randf_range(-half + 10, half - 10), 0, c.y + rng.randf_range(-half + 10, half - 10))
		_tree(p, rng.randf() < 0.3)
	# The crashed plane
	var wreck := Vector3(c.x + 60, 0, c.y + 90)
	add_box(wreck + Vector3(0, 2.0, 0), Vector3(3.5, 3.5, 22.0), _plain(Color("#c8c8c0")), true, 0.4)
	add_box(wreck + Vector3(4, 1.2, 2), Vector3(18.0, 0.6, 4.0), _plain(Color("#b8b8b0")), true, 0.6)
	_label("LIAN YU", Vector3(c.x, 40, c.y), 8.0, Color("#d8ffd0"))
	landmarks.append({"name": "Lian Yu", "pos": Vector3(c.x + 40, 0.5, c.y + 120), "district": "Lian Yu"})


# --- Other places -------------------------------------------------------------

## The Old West (Legends of Tomorrow's 1870s): a dusty main street in a desert
## with mesas. One "island" with a single long street so traffic code and
## spawning still work.
func _build_western() -> void:
	var sand := _plain(Color("#c8a874"))
	add_box(Vector3(0, -1.5, 0), Vector3(SEA * 0.6, 3.0, SEA * 0.6), sand)
	var grid := Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	islands.append({"name": "Old West", "center": Vector2.ZERO, "land": Rect2(-SEA, -SEA, SEA * 2.0, SEA * 2.0), "grid": grid, "style": STYLES[3], "index": 3})
	var dirt := PlaneMesh.new()
	dirt.size = Vector2(ROAD * 1.5, HALF * 2.0)
	_mesh_instance(dirt, Transform3D(Basis(), Vector3(0, 0.02, 0)), _plain(Color("#a88a5a")))
	var wood := [_plain(Color("#7a5a3a")), _plain(Color("#8a6a44")), _plain(Color("#6a4a2e"))]
	var names := ["SALOON", "SHERIFF", "BANK", "GENERAL STORE", "HOTEL", "STABLES", "TELEGRAPH"]
	for side in [-1.0, 1.0]:
		for k in 9:
			var z := -260.0 + k * 62.0
			var w := rng.randf_range(16.0, 26.0)
			var h := rng.randf_range(7.0, 12.0)
			var r := Rect2(side * 22.0 - w * 0.5 + side * w * 0.5 - (w * 0.5 if side < 0 else 0.0), z, w, 22.0)
			r.position.x = (14.0 if side > 0 else -14.0 - w)
			_add_building(r, h, wood[rng.randi() % 3])
			add_box(Vector3(r.get_center().x - side * (w * 0.5 + 1.5), 3.2, r.get_center().y), Vector3(3.0, 0.3, 22.0), wood[0], false)
			if k < names.size() and side > 0 or k % 3 == 0:
				_label(names[(k + (0 if side > 0 else 3)) % names.size()], Vector3(r.get_center().x - side * w * 0.5, h + 2.0, r.get_center().y), 1.8, Color("#f0e0b0"))
	var rock := _plain(Color("#a86a44"))
	for k in 14:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(450.0, 1100.0)
		var p := Vector3(cos(ang) * d, 0, sin(ang) * d)
		var s := Vector3(rng.randf_range(60, 160), rng.randf_range(40, 120), rng.randf_range(60, 160))
		add_box(p + Vector3.UP * s.y * 0.5, s, rock)
	for k in 60:
		var p := Vector3(rng.randf_range(-600, 600), 0, rng.randf_range(-600, 600))
		if absf(p.x) < 60.0:
			continue
		add_box(p + Vector3.UP * 1.6, Vector3(0.5, 3.2, 0.5), _palm_mat)
		add_box(p + Vector3(0.6, 2.2, 0), Vector3(1.2, 0.4, 0.4), _palm_mat, false)
	landmarks.append({"name": "Main Street", "pos": Vector3(0, 0.5, 0), "district": "Old West"})
	landmarks.append({"name": "The Saloon", "pos": Vector3(10, 0.5, -250), "district": "Old West"})


## The Speed Force: a glowing plain under a storm of lightning, with
## fragments of memories (pieces of the city) floating in the haze.
func _build_speed_force() -> void:
	var floor_mat := _plain(Color("#cfe6ff"), 0.2, 0.6)
	add_box(Vector3(0, -1.0, 0), Vector3(1600, 2.0, 1600), floor_mat)
	var grid := Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	islands.append({"name": "The Speed Force", "center": Vector2.ZERO, "land": Rect2(-800, -800, 1600, 1600), "grid": grid, "style": STYLES[1], "index": 1})
	var shard_mats := [_plain(Color("#9ac8ff"), 0.2, 1.5), _plain(Color("#ffe48a"), 0.2, 1.5), facade_mats[1][0], facade_mats[0][0]]
	for k in 70:
		var p := Vector3(rng.randf_range(-600, 600), rng.randf_range(15, 160), rng.randf_range(-600, 600))
		var s := Vector3(rng.randf_range(6, 30), rng.randf_range(6, 40), rng.randf_range(6, 30))
		add_box(p, s, shard_mats[rng.randi() % shard_mats.size()], k % 3 == 0, rng.randf() * TAU)
	for k in 30:
		var p := Vector3(rng.randf_range(-500, 500), 0, rng.randf_range(-500, 500))
		add_box(p + Vector3.UP * 2.0, Vector3(1.0, 4.0, 1.0), _plain(Color("#ffffff"), 0.2, 3.0), false)
	_label("THE SPEED FORCE", Vector3(0, 40, -120), 10.0, Color("#fff2a0"))
	landmarks.append({"name": "Speed Force Heart", "pos": Vector3(0, 0.5, 0), "district": "The Speed Force"})
	doors.append({"name": "Way home", "pos": Vector3(0, 0.5, 60), "interior": "exit_speedforce"})
