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
const N := 14                             # blocks per island side
const LM_OFF := 3                         # landmark block layout is centred in the bigger grid
const REALM_HALF := 320.0                 # road grid of the smaller realms (Speed Force, Argo...)
const HALF := N * CELL * 0.5              # half-size of an island's road grid
const SHORE := 50.0                       # land beyond the outer roads
const LAND := HALF + SHORE                # half-size of an island
const SEA := 9000.0
const FACADE_SHADER := preload("res://shaders/facade.gdshader")
const DISTRICTS := ["Star City", "Central City", "National City", "Freeland", "Gotham City", "Smallville"]
const ISLAND_CENTERS := [Vector2(-1440, -560), Vector2(560, -560), Vector2(-1440, 1440), Vector2(560, 1440),
	Vector2(-1440, 3440), Vector2(2560, 1440)]
## Bridges between islands (index pairs), along their central avenues.
const BRIDGE_PAIRS := [[0, 1], [2, 3], [0, 2], [1, 3], [2, 4], [3, 5]]
const BAY_X := -440.0                     # middle of the Star City - Central City channel
const REALM_NAMES := {"western": "Old West", "speedforce": "The Speed Force", "antimatter": "The Anti-Matter Universe",
	"vanishing_point": "Vanishing Point", "argo": "Argo City"}
const DISTRICT_CENTERS := ISLAND_CENTERS  # kept for older callers
const LIAN_YU := Vector2(-2900, -1900)
const IRON_HEIGHTS := Vector2(1700, -560)

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
	# Gotham: soot-black gothic towers under a permanent overcast.
	{"facades": ["#3a3634", "#2e2c2e", "#4a4038"], "glass": "#22303a", "min_h": 18.0, "max_h": 230.0, "towers": 0.5,
		"lights": 0.55, "trees": false, "fog": 0.0, "gothic": true, "sky": ["#14161c", "#3a3c46", 0.8], "haze": 3.0, "weather": "rain"},
	# Smallville: farmland around a small Main Street.
	{"facades": ["#c8b89a", "#a8402a", "#e8e0d0"], "glass": "#5a6a78", "min_h": 5.0, "max_h": 12.0, "towers": 0.0,
		"lights": 0.9, "trees": true, "fog": 0.0, "rural": true, "sky": ["#4a9aff", "#ffe8c0", 0.3]},
]

var spec: Dictionary = {}
var kind := "metro"
var city_seed := 1987
var rng := RandomNumberGenerator.new()
var buildings: Array = []        # {rect: Rect2 (x/z footprint), h: float}
var landmarks: Array = []        # {name, pos: Vector3, district}
var parked: Array = []           # {kind, xform: Transform3D}
var doors: Array = []            # {name, pos: Vector3, interior: String}
var roofs: Dictionary = {}
var subways: Array = []          # {name, pos, island}
var points: Array = []           # interactive street things, for the map: {kind, pos}       # room id -> where its elevator comes out on the roof
var interior_slots: Dictionary = {}  # room id -> {origin, yaw}: rooms built inside their buildings
var islands: Array = []          # {name, center: Vector2, land: Rect2, grid: Rect2, style}
var bridges: Array[Rect2] = []
var extra_land: Array = []       # {rect: Rect2, name}
var waverider_dock := Vector3(BAY_X, 4.5, -500)
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
		"antimatter":
			_build_antimatter()
		"vanishing_point":
			_build_vanishing_point()
		"argo":
			_build_argo()
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
	if REALM_NAMES.has(kind):
		return REALM_NAMES[kind]
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
	var c: Vector2 = ISLAND_CENTERS[clampi(index, 0, ISLAND_CENTERS.size() - 1)]
	return Vector3(c.x, 0.2, c.y)


func _nearest_grid(p: Vector3) -> Rect2:
	if kind != "metro":
		return Rect2(-REALM_HALF, -REALM_HALF, REALM_HALF * 2.0, REALM_HALF * 2.0)
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
	return kind != "metro" and absf(p.x) <= REALM_HALF and absf(p.z) <= REALM_HALF


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

static var _tex_cache: Dictionary = {}


func _make_textures() -> void:
	# One texture covers 32 m x 32 m of facade: 8 x 8 windows, 4 m apart.
	# Each window has a frame, two panes of glass with a sky reflection, and
	# a sill; floors are banded and the wall has a little grain to it.
	var neon: bool = spec.get("neon", false)
	if _tex_cache.has(neon):
		_window_albedo = _tex_cache[neon][0]
		_window_emission = _tex_cache[neon][1]
		return
	var size := 512
	var cell := size / 8
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var emission := Image.create(size, size, false, Image.FORMAT_RGB8)
	emission.fill(Color.BLACK)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	# Wall grain and faint courses of brick or stone.
	for y in size:
		var course := 0.97 if y % 8 == 0 else 1.0
		for x in size:
			var g := 0.9 + r.randf() * 0.06
			albedo.set_pixel(x, y, Color(g, g, g) * course)
	for wy in 8:
		# Floor band
		albedo.fill_rect(Rect2i(0, wy * cell, size, 3), Color(0.78, 0.78, 0.78))
		for wx in 8:
			var fr := Rect2i(wx * cell + 9, wy * cell + 12, cell - 18, cell - 26)
			albedo.fill_rect(fr, Color(0.72, 0.72, 0.74))
			var glass := Rect2i(fr.position.x + 3, fr.position.y + 3, fr.size.x - 6, fr.size.y - 6)
			for gy in glass.size.y:
				var t := float(gy) / glass.size.y
				var base := Color(0.3, 0.36, 0.44).lerp(Color(0.1, 0.12, 0.15), t)
				for gx in glass.size.x:
					var streak := 1.0 if absi((gx - gy) - 6) < 3 else 0.0
					albedo.set_pixel(glass.position.x + gx, glass.position.y + gy, base.lerp(Color(0.55, 0.62, 0.7), streak * 0.35))
			# Mullion and transom
			albedo.fill_rect(Rect2i(glass.position.x + glass.size.x / 2 - 1, glass.position.y, 2, glass.size.y), Color(0.7, 0.7, 0.72))
			albedo.fill_rect(Rect2i(glass.position.x, glass.position.y + glass.size.y / 3, glass.size.x, 2), Color(0.7, 0.7, 0.72))
			# Sill
			albedo.fill_rect(Rect2i(fr.position.x - 3, fr.position.y + fr.size.y, fr.size.x + 6, 4), Color(0.84, 0.84, 0.82))
			if r.randf() < 0.42:
				var warm := Color(1.0, 0.82, 0.5).lerp(Color(0.75, 0.88, 1.0), r.randf() * 0.5)
				if neon:
					warm = [Color("#3affff"), Color("#ff4fd8"), Color("#9a6aff")][r.randi() % 3]
				var e := warm * r.randf_range(0.55, 1.0)
				emission.fill_rect(glass, e)
				if r.randf() < 0.4:
					# Blinds half down
					for k in range(0, glass.size.y / 2, 3):
						emission.fill_rect(Rect2i(glass.position.x, glass.position.y + k, glass.size.x, 1), e * 0.35)
				emission.fill_rect(Rect2i(glass.position.x + glass.size.x / 2 - 1, glass.position.y, 2, glass.size.y), Color.BLACK)
	albedo.generate_mipmaps()
	emission.generate_mipmaps()
	_window_albedo = ImageTexture.create_from_image(albedo)
	_window_emission = ImageTexture.create_from_image(emission)
	_tex_cache[neon] = [_window_albedo, _window_emission]


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
var _shop_glass: StandardMaterial3D
var _ledge_mat: StandardMaterial3D
var _awning_mats: Array = []
var _sign_mats: Array = []
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


## A box with any orientation (ramps), drawn and (optionally) solid.
func add_box_xf(xf: Transform3D, size: Vector3, m: Material, collide := true) -> void:
	if not _instances.has(m):
		_instances[m] = []
	_instances[m].append(xf * Transform3D(Basis.from_scale(size), Vector3.ZERO))
	if collide:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.transform = xf
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
	_building_details(rect, height, m)


func _init_detail_mats() -> void:
	if _shop_glass != null:
		return
	_shop_glass = _plain(Color("#1a2a34"), 0.1, 0.25)
	_shop_glass.metallic = 0.5
	_ledge_mat = _plain(Color("#b8b2a6"), 0.8)
	for col in ["#a8241e", "#1e5a2e", "#1d3f8a", "#d8a514", "#5a2a6a", "#2a2a2a", "#c86a1e"]:
		_awning_mats.append(_plain(Color(col), 0.8))
	for col in ["#ff5a4a", "#4affd0", "#ffd23a", "#ff6ad0", "#6ab0ff"]:
		_sign_mats.append(_plain(Color(col), 0.4, 1.6))


## Street-level shopfronts with awnings and signs, stone ledges between
## floors, a parapet round the roof, and rooftop clutter: AC units, a water
## tank on legs, a stair hut, antennas.
func _building_details(rect: Rect2, height: float, m: Material) -> void:
	var c := rect.get_center()
	_init_detail_mats()
	var rural: bool = kind == "metro" and bool(spec.get("ruined", false))

	# Shopfronts: a glass band on each face of buildings that front a street.
	if height >= 8.0 and height <= 160.0 and not rural and rect.size.x > 10.0 and rect.size.y > 10.0:
		var shop_h := 3.6
		for face in 4:
			if rng.randf() < 0.25:
				continue
			var along_x := face < 2
			var sgn := -1.0 if face % 2 == 0 else 1.0
			var length: float = (rect.size.x if along_x else rect.size.y) - 2.0
			var pos := Vector3(c.x, shop_h * 0.5, c.y + sgn * (rect.size.y * 0.5 + 0.06)) if along_x else Vector3(c.x + sgn * (rect.size.x * 0.5 + 0.06), shop_h * 0.5, c.y)
			var size := Vector3(length, shop_h, 0.12) if along_x else Vector3(0.12, shop_h, length)
			add_box(pos, size, _shop_glass, false)
			# Mullions every few metres
			var n := int(length / 4.0)
			for k in n + 1:
				var t := -length * 0.5 + k * length / maxf(1.0, n)
				var mp := pos + (Vector3(t, 0, sgn * 0.04) if along_x else Vector3(sgn * 0.04, 0, t))
				add_box(mp, Vector3(0.18, shop_h, 0.18), _dark_mat, false)
			# Awning and a lit sign above it
			var out := Vector3(0, 0, sgn * 0.9) if along_x else Vector3(sgn * 0.9, 0, 0)
			var aw: Material = _awning_mats[rng.randi() % _awning_mats.size()]
			add_box(pos + out + Vector3.UP * (shop_h * 0.5 + 0.15), Vector3(length * 0.6, 0.15, 1.8) if along_x else Vector3(1.8, 0.15, length * 0.6), aw, false)
			add_box(pos + out * 0.2 + Vector3.UP * (shop_h * 0.5 + 0.75), Vector3(length * 0.35, 0.7, 0.12) if along_x else Vector3(0.12, 0.7, length * 0.35),
				_sign_mats[rng.randi() % _sign_mats.size()], false)
		# A ledge where the shops meet the floors above
		add_box(Vector3(c.x, shop_h + 0.2, c.y), Vector3(rect.size.x + 0.5, 0.4, rect.size.y + 0.5), _ledge_mat, false)
	# Stone ledges between floors on brick and stone buildings
	if height > 24.0 and height < 140.0 and rng.randf() < 0.6:
		var step := rng.randf_range(12.0, 20.0)
		var y := step + 4.0
		while y < height - 4.0:
			add_box(Vector3(c.x, y, c.y), Vector3(rect.size.x + 0.3, 0.3, rect.size.y + 0.3), _ledge_mat, false)
			y += step
	# Parapet
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x, height + 1.0, c.y + side * (rect.size.y * 0.5 + 0.15)), Vector3(rect.size.x + 0.6, 0.8, 0.3), _roof_mat, false)
		add_box(Vector3(c.x + side * (rect.size.x * 0.5 + 0.15), height + 1.0, c.y), Vector3(0.3, 0.8, rect.size.y + 0.6), _roof_mat, false)
	# Rooftop clutter
	var units := rng.randi_range(1, 4) if height < 120.0 else rng.randi_range(0, 2)
	for u in units:
		var s := Vector3(rng.randf_range(2, 4.5), rng.randf_range(1.2, 2.4), rng.randf_range(2, 4.5))
		var px := rng.randf_range(rect.position.x + s.x, rect.end.x - s.x)
		var pz := rng.randf_range(rect.position.y + s.z, rect.end.y - s.z)
		add_box(Vector3(px, height + 0.6 + s.y * 0.5, pz), s, _concrete_mat)
		add_box(Vector3(px, height + 0.62 + s.y, pz), Vector3(s.x * 0.5, 0.12, s.z * 0.5), _dark_mat, false)
	if height > 20.0 and height < 90.0 and rng.randf() < 0.35 and rect.size.x > 14.0:
		# A wooden water tank on legs, New York style
		var tp := Vector3(rect.position.x + 5.0, height + 0.6, rect.position.y + 5.0)
		for k in 4:
			var off := Vector3(-1.2 if k % 2 == 0 else 1.2, 0, -1.2 if k < 2 else 1.2)
			add_box(tp + off + Vector3.UP * 1.5, Vector3(0.25, 3.0, 0.25), _dark_mat, false)
		var tank := CylinderMesh.new()
		tank.top_radius = 1.5
		tank.bottom_radius = 1.8
		tank.height = 3.2
		tank.radial_segments = 10
		_mesh_instance(tank, Transform3D(Basis(), tp + Vector3.UP * 4.6), _trunk_mat)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 1.6
		cone.height = 1.0
		cone.radial_segments = 10
		_mesh_instance(cone, Transform3D(Basis(), tp + Vector3.UP * 6.7), _roof_mat)
	if rect.size.x > 12.0 and rng.randf() < 0.5:
		add_box(Vector3(rect.end.x - 3.0, height + 2.0, rect.end.y - 3.0), Vector3(3.0, 2.8, 3.4), _roof_mat)
	if height > 60.0 and rng.randf() < 0.5:
		add_box(Vector3(c.x + rng.randf_range(-3, 3), height + 6.0, c.y + rng.randf_range(-3, 3)), Vector3(0.25, 12.0, 0.25), _steel_mat, false)


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
	if door != "" and not interior_slots.has(door):
		doors.append({"name": name, "pos": pos, "interior": door})


# --- Plazas, lots, building sites, courts and gas stations --------------------

func _interactable(name: String, pos: Vector3, what: String, data := "") -> void:
	doors.append({"name": name, "pos": pos, "interior": what, "data": data})
	if what in ["subway", "food_cart", "vending", "atm", "phone_booth", "hoop", "fountain"]:
		points.append({"kind": what, "pos": pos})


## A paved square with a fountain you can toss a coin into, benches, trees
## and a food cart.
func _build_plaza(rect: Rect2) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.19, c.y), Vector3(rect.size.x - 2.0, 0.06, rect.size.y - 2.0), _plain(Color("#b8ac98"), 0.85), false)
	for k in 8:
		add_box(Vector3(c.x - rect.size.x * 0.4 + k * rect.size.x * 0.114, 0.23, c.y), Vector3(0.3, 0.02, rect.size.y - 6.0), _plain(Color("#a09480"), 0.85), false)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 4.0
	bowl.bottom_radius = 4.3
	bowl.height = 0.8
	_mesh_instance(bowl, Transform3D(Basis(), Vector3(c.x, 0.4, c.y)), _concrete_mat)
	var water := CylinderMesh.new()
	water.top_radius = 3.6
	water.bottom_radius = 3.6
	water.height = 0.1
	_mesh_instance(water, Transform3D(Basis(), Vector3(c.x, 0.82, c.y)), _plain(Color("#3a8ab8"), 0.05, 0.2))
	var spout := CylinderMesh.new()
	spout.top_radius = 0.4
	spout.bottom_radius = 0.8
	spout.height = 2.6
	_mesh_instance(spout, Transform3D(Basis(), Vector3(c.x, 1.3, c.y)), _concrete_mat)
	add_cylinder_collision(Vector3(c.x, 0.4, c.y), 4.2, 0.8)
	_interactable("Toss a coin in the fountain", Vector3(c.x, 0.5, c.y - 5.0), "fountain")
	for k in 4:
		var ang := k * PI * 0.5 + PI * 0.25
		var bp := Vector3(c.x + cos(ang) * 11.0, 0.45, c.y + sin(ang) * 11.0)
		add_box(bp, Vector3(2.2, 0.5, 0.7), _trunk_mat, true, -ang + PI * 0.5)
		_tree(Vector3(c.x + cos(ang) * 20.0, 0, c.y + sin(ang) * 20.0))
	_food_cart(Vector3(c.x + 14.0, 0, c.y - 4.0))


## A surface car park full of parked cars.
func _build_parking(rect: Rect2) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.18, c.y), Vector3(rect.size.x - 2.0, 0.05, rect.size.y - 2.0), _plain(Color("#3a3c40"), 0.95), false)
	var line := _plain(Color("#e8e8e0"), 0.8)
	for row in 2:
		var z := c.y - 12.0 + row * 24.0
		for k in 10:
			var x := c.x - 24.0 + k * 5.2
			add_box(Vector3(x - 2.6, 0.22, z), Vector3(0.12, 0.02, 5.0), line, false)
			if rng.randf() < 0.55:
				parked.append({"kind": "car", "xform": Transform3D(Basis(Vector3.UP, 0.0 if row == 0 else PI), Vector3(x, 0.6, z))})
	_vending(Vector3(c.x + 26.0, 0, c.y))


## A building site: a steel frame going up, a tower crane, girders and a
## site office. Climb the frame, or the crane.
func _build_construction(rect: Rect2, index: int) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.18, c.y), Vector3(rect.size.x - 2.0, 0.05, rect.size.y - 2.0), _plain(Color("#8a7a5a"), 0.95), false)
	var steel := _plain(Color("#c86a1e"), 0.6)
	var floors := rng.randi_range(4, 8)
	var fr := Rect2(c.x - 14, c.y - 12, 28, 24)
	for f in floors:
		var y := f * 4.0
		add_box(Vector3(fr.get_center().x, y + 4.0, fr.get_center().y), Vector3(fr.size.x, 0.35, fr.size.y), _concrete_mat, true)
		for px in 4:
			for pz in 3:
				var p := Vector3(fr.position.x + px * fr.size.x / 3.0, y + 2.0, fr.position.y + pz * fr.size.y / 2.0)
				add_box(p, Vector3(0.4, 4.0, 0.4), steel, true)
	buildings.append({"rect": fr, "h": floors * 4.0 + 4.0})
	# Tower crane
	var cp := Vector3(rect.end.x - 8.0, 0, rect.position.y + 8.0)
	var ch := floors * 4.0 + 30.0
	add_box(cp + Vector3.UP * ch * 0.5, Vector3(1.6, ch, 1.6), _plain(Color("#e8c018"), 0.6), true)
	add_box(cp + Vector3(-18.0, ch + 1.0, 0), Vector3(44.0, 1.2, 1.2), _plain(Color("#e8c018"), 0.6), true)
	add_box(cp + Vector3(6.0, ch + 1.0, 0), Vector3(6.0, 2.4, 2.0), _concrete_mat, true)
	add_box(cp + Vector3(-32.0, ch - 8.0, 0), Vector3(0.08, 18.0, 0.08), _dark_mat, false)
	add_box(cp + Vector3(-32.0, ch - 17.5, 0), Vector3(3.0, 1.0, 1.0), steel, false)
	# Girders and the site office
	for k in 4:
		add_box(Vector3(rect.position.x + 10.0, 0.4 + k * 0.4, rect.end.y - 8.0), Vector3(12.0, 0.35, 0.5), steel, true)
	add_box(Vector3(rect.position.x + 8.0, 1.4, rect.position.y + 8.0), Vector3(8.0, 2.8, 3.0), _plain(Color("#d8d0b8"), 0.8), true)
	# Hoarding round the site
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x, 1.2, c.y + side * (rect.size.y * 0.5 - 1.0)), Vector3(rect.size.x - 12.0, 2.4, 0.2), _plain(Color("#2a5a8a"), 0.8), true)


## A pair of basketball courts with hoops you can shoot at.
func _build_hoops(rect: Rect2) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.19, c.y), Vector3(rect.size.x - 4.0, 0.06, rect.size.y - 4.0), _plain(Color("#3a6a8a"), 0.8), false)
	for half in [-1.0, 1.0]:
		var cc := Vector3(c.x, 0, c.y + half * 13.0)
		add_box(cc + Vector3(0, 0.24, 0), Vector3(26, 0.02, 0.15), _plain(Color("#f0f0f0")), false)
		for side in [-1.0, 1.0]:
			add_box(cc + Vector3(side * 13.0, 2.0, 0), Vector3(0.3, 4.0, 0.3), _dark_mat)
			add_box(cc + Vector3(side * 12.5, 3.6, 0), Vector3(0.2, 1.2, 1.8), _plain(Color("#f0f0f0")), false)
			_hoop(cc + Vector3(side * 12.2, 3.1, 0), side)
	_vending(Vector3(c.x - rect.size.x * 0.5 + 4.0, 0, c.y))


func _hoop(p: Vector3, side: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.26
	_mesh_instance(ring, Transform3D(Basis(), p - Vector3(side * 0.3, 0, 0)), _plain(Color("#e8601a"), 0.5))
	_interactable("Shoot a hoop", p - Vector3(side * 4.0, 2.6, 0), "hoop")


## A gas station: canopy, pumps and the shop.
func _build_gas_station(rect: Rect2) -> void:
	var c := rect.get_center()
	add_box(Vector3(c.x, 0.18, c.y), Vector3(rect.size.x - 2.0, 0.05, rect.size.y - 2.0), _plain(Color("#4a4c50"), 0.9), false)
	add_box(Vector3(c.x, 5.6, c.y - 8.0), Vector3(30.0, 0.8, 16.0), _plain(Color("#e8e8e8"), 0.6), true)
	add_box(Vector3(c.x, 5.2, c.y - 8.0), Vector3(30.2, 0.2, 16.2), _plain(Color("#d8201a"), 0.5, 1.2), false)
	for k in 4:
		var x := c.x - 10.0 + (k % 2) * 20.0
		var z := c.y - 12.0 + (k / 2) * 8.0
		add_box(Vector3(x, 2.8, z), Vector3(0.6, 5.6, 0.6), _concrete_mat, true)
	for k in 3:
		var pp := Vector3(c.x - 8.0 + k * 8.0, 0.9, c.y - 8.0)
		add_box(pp, Vector3(1.0, 1.8, 0.7), _plain(Color("#d8201a"), 0.5), true)
		add_box(pp + Vector3(0, 0.4, -0.36), Vector3(0.6, 0.4, 0.02), _plain(Color("#bfe8ff"), 0.3, 1.0), false)
	var shop := Rect2(c.x - 12.0, c.y + 8.0, 24.0, 12.0)
	_add_building(shop, 5.0, facade_mats[3][0] if facade_mats.size() > 3 else _concrete_mat)
	_label("GAS", Vector3(c.x, 7.4, c.y - 16.2), 2.0, Color("#ffffff"))
	_vending(Vector3(c.x + 14.0, 0, c.y + 6.0))


# --- Street interactables ------------------------------------------------------

## Each street block gets a few: a subway entrance on some corners, food
## carts, vending machines, ATMs and phone booths along the sidewalks.
func _street_props(rect: Rect2, index: int) -> void:
	if kind != "metro" or spec.get("ruined", false):
		return
	var corner := Vector3(rect.position.x - 4.5, 0, rect.position.y - 4.5)
	var r := rng.randf()
	if r < 0.035:
		_subway(Vector3(rect.position.x + 3.0, 0, rect.position.y + 1.2), index)
	elif r < 0.08:
		_food_cart(Vector3(rect.position.x + rng.randf_range(8, rect.size.x - 8), 0, rect.position.y - 1.0))
	elif r < 0.13:
		_atm(Vector3(rect.position.x + rng.randf_range(6, rect.size.x - 6), 0, rect.end.y + 0.4))
	elif r < 0.17:
		_phone_booth(Vector3(rect.end.x + 0.8, 0, rect.position.y + rng.randf_range(6, rect.size.y - 6)))
	elif r < 0.21:
		_vending(Vector3(rect.position.x - 0.8, 0, rect.position.y + rng.randf_range(6, rect.size.y - 6)))


func _subway(p: Vector3, index: int) -> void:
	var name := "%s Subway (%d)" % [DISTRICTS[index], subways.filter(func(s) -> bool: return s["island"] == index).size() + 1]
	add_box(p + Vector3(0, 1.4, 0), Vector3(4.2, 0.2, 3.0), _plain(Color("#2a6a3a"), 0.6), false)
	for sx in [-1.0, 1.0]:
		add_box(p + Vector3(sx * 2.0, 0.7, 0), Vector3(0.12, 1.4, 3.0), _steel_mat, false)
	add_box(p + Vector3(0, 0.12, 0.2), Vector3(3.6, 0.12, 2.4), _dark_mat, false)
	add_box(p + Vector3(0, 2.6, 0), Vector3(0.3, 2.4, 0.3), _dark_mat, false)
	add_box(p + Vector3(0, 3.9, 0), Vector3(0.8, 0.8, 0.12), _plain(Color("#3aff6a"), 0.4, 1.5), false)
	_label("SUBWAY", p + Vector3(0, 2.0, -1.6), 0.6, Color("#d8ffe0"))
	subways.append({"name": name, "pos": p + Vector3(0, 0.5, -2.2), "island": index})
	_interactable("Take the subway", p + Vector3(0, 0.5, -2.2), "subway", name)


func _food_cart(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.9, 0), Vector3(2.4, 1.2, 1.2), _plain(Color("#c8c8cc"), 0.4), true)
	add_box(p + Vector3(0, 2.4, 0), Vector3(2.8, 0.1, 1.8), _awning_mat(), false)
	for sx in [-1.0, 1.0]:
		add_box(p + Vector3(sx * 1.2, 1.6, 0), Vector3(0.06, 1.6, 0.06), _steel_mat, false)
	_label("HOT DOGS", p + Vector3(0, 2.8, 0), 0.5, Color("#ffe8a0"))
	_interactable("Grab a hot dog", p + Vector3(0, 0.5, -1.4), "food_cart")


func _vending(p: Vector3) -> void:
	add_box(p + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.8), _plain(Color("#c8201a"), 0.4), true)
	add_box(p + Vector3(0, 1.2, -0.41), Vector3(0.7, 1.2, 0.02), _plain(Color("#bfe8ff"), 0.2, 1.2), false)
	_interactable("Vending machine: an energy drink", p + Vector3(0, 0.5, -1.2), "vending")


func _atm(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.8, 0), Vector3(0.9, 1.6, 0.6), _plain(Color("#3a4a5a"), 0.4), true)
	add_box(p + Vector3(0, 1.3, 0.31), Vector3(0.5, 0.35, 0.02), _plain(Color("#6ad0ff"), 0.2, 1.2), false)
	_interactable("ATM", p + Vector3(0, 0.5, 1.1), "atm")


func _phone_booth(p: Vector3) -> void:
	add_box(p + Vector3(0, 1.3, 0), Vector3(1.2, 2.6, 1.2), _plain(Color("#1d3fa8"), 0.4), true)
	add_box(p + Vector3(0, 2.75, 0), Vector3(1.3, 0.3, 1.3), _plain(Color("#e8e8e8"), 0.4, 0.8), false)
	_interactable("Phone booth: call a teammate", p + Vector3(-1.2, 0.5, 0), "phone_booth")


func _awning_mat() -> Material:
	_init_detail_mats()
	return _awning_mats[rng.randi() % _awning_mats.size()]


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
	4: {Vector2i(3, 3): "wayne_tower", Vector2i(5, 2): "gcpd", Vector2i(1, 6): "arkham", Vector2i(4, 5): "park", Vector2i(6, 4): "crows"},
	5: {Vector2i(2, 5): "kent_farm", Vector2i(4, 3): "water_tower", Vector2i(5, 4): "smallville_high", Vector2i(3, 3): "main_street",
		Vector2i(4, 1): "jsa_hq"},
}


func _build_block(index: int, i: int, j: int) -> void:
	var c: Vector2 = ISLAND_CENTERS[index]
	var st: Dictionary = STYLES[index]
	var rect := _block_rect(c, i, j)
	var bc := rect.get_center()
	add_box(Vector3(bc.x, 0.08, bc.y), Vector3(BLOCK, 0.16, BLOCK), _sidewalk_mat, false)
	var key := Vector2i(i - LM_OFF, j - LM_OFF)
	var reserved: Dictionary = LANDMARK_BLOCKS[index]
	if reserved.has(key):
		var what: String = reserved[key]
		if what == "park":
			_build_park(rect, true, st.get("palms", false))
		elif what == "court":
			_build_court(rect)
		return
	if st.get("rural", false) and absi(key.x - 3) + absi(key.y - 3) > 1:
		_build_farm(rect)
		return
	var glades := index == 0 and i >= 5 and j >= 5
	var edge := i == 0 or j == 0 or i == N - 1 or j == N - 1
	if not edge and rng.randf() < 0.05:
		_build_park(rect, false, st.get("palms", false))
		return
	if not st.get("rural", false) and not spec.get("ruined", false) and kind == "metro":
		var roll := rng.randf()
		if roll < 0.035 and not edge:
			_build_plaza(rect)
			return
		elif roll < 0.06:
			_build_parking(rect)
			return
		elif roll < 0.08:
			_build_construction(rect, index)
			return
		elif roll < 0.095:
			_build_hoops(rect)
			return
		elif roll < 0.11 and edge:
			_build_gas_station(rect)
			return
	_street_props(rect, index)
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
		if st.get("gothic", false) and not spec.get("ruined", false):
			_gothic_crown(fr, h, m)
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
	if not spec.get("ruined", false) and rng.randf() < 0.55:
		# Street furniture along the curb.
		var kinds := ["bench", "hydrant", "mailbox", "dumpster", "newsbox", "hydrant", "bench"]
		var k: String = kinds[rng.randi() % kinds.size()]
		var along := rng.randf_range(rect.position.x + 6.0, rect.end.x - 6.0)
		var fp := Vector3(along, 0.2, rect.position.y + 1.6)
		parked.append({"kind": k, "xform": Transform3D(Basis(Vector3.UP, PI if k == "bench" else 0.0), fp)})


## Gotham: stepped crowns, spires and gargoyles on the rooftops.
func _gothic_crown(r: Rect2, h: float, m: Material) -> void:
	var c := r.get_center()
	if h > 60.0:
		var w := r.size * 0.55
		add_box(Vector3(c.x, h + 6.0, c.y), Vector3(w.x, 12.0, w.y), m)
		add_box(Vector3(c.x, h + 15.0, c.y), Vector3(w.x * 0.5, 6.0, w.y * 0.5), m)
		add_box(Vector3(c.x, h + 30.0, c.y), Vector3(1.2, 24.0, 1.2), _dark_mat, false)
		buildings.append({"rect": Rect2(c - w * 0.5, w), "h": h + 12.0})
	for k in 4:
		var corner := Vector2(r.position.x + (1.5 if k % 2 == 0 else r.size.x - 1.5), r.position.y + (1.5 if k < 2 else r.size.y - 1.5))
		add_box(Vector3(corner.x, h + 1.4, corner.y), Vector3(1.2, 1.6, 1.8), _dark_mat, false, k * PI * 0.5)
		add_box(Vector3(corner.x, h + 2.6, corner.y), Vector3(0.6, 0.8, 0.6), _dark_mat, false)


## Smallville: a field (corn, wheat or pasture), sometimes with a farmstead.
func _build_farm(rect: Rect2) -> void:
	var c := rect.get_center()
	var crops := [Color("#c8a83a"), Color("#5a8a2a"), Color("#7a9a3a"), Color("#a8803a")]
	var col: Color = crops[rng.randi() % crops.size()]
	add_box(Vector3(c.x, 0.18, c.y), Vector3(rect.size.x - 2.0, 0.1, rect.size.y - 2.0), _plain(col.darkened(0.25)), false)
	var rows := _plain(col)
	for k in 10:
		add_box(Vector3(c.x - rect.size.x * 0.42 + k * rect.size.x * 0.093, 0.7, c.y), Vector3(1.2, 1.1, rect.size.y - 8.0), rows, false)
	# Fence
	var fence := _trunk_mat
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x, 0.6, c.y + side * (rect.size.y * 0.5 - 0.5)), Vector3(rect.size.x, 0.15, 0.15), fence, false)
		add_box(Vector3(c.x + side * (rect.size.x * 0.5 - 0.5), 0.6, c.y), Vector3(0.15, 0.15, rect.size.y), fence, false)
	if rng.randf() < 0.35:
		var house := Rect2(rect.position + Vector2(4, 4), Vector2(14, 12))
		_farmhouse(house, _plain(Color("#e8e0d0")))
	if rng.randf() < 0.3:
		_tree(Vector3(rect.end.x - 6.0, 0, rect.position.y + 6.0))


func _farmhouse(r: Rect2, m: Material) -> void:
	_add_building(r, 6.0, m)
	var c := r.get_center()
	var roof := _plain(Color("#5a3a2a"))
	add_box(Vector3(c.x, 7.2, c.y - r.size.y * 0.22), Vector3(r.size.x + 1.0, 0.4, r.size.y * 0.6), roof, false, 0.0)
	add_box(Vector3(c.x, 8.0, c.y), Vector3(r.size.x + 1.0, 1.6, r.size.y * 0.35), roof, false)
	add_box(Vector3(c.x, 1.0, r.position.y - 1.5), Vector3(r.size.x, 0.2, 3.0), _trunk_mat)


func _red_barn(r: Rect2) -> void:
	var red := _plain(Color("#9a2a1e"))
	_hollow(r, "kent_barn", 10.0, red)
	var c := r.get_center()
	add_box(Vector3(c.x, 11.5, c.y), Vector3(r.size.x * 0.75, 3.0, r.size.y + 0.6), _plain(Color("#3a2a24")), true)
	for side in [-1.0, 1.0]:
		add_box(Vector3(c.x + side * 3.6, 3.0, r.position.y - 0.1), Vector3(3.0, 6.0, 0.2), _plain(Color("#f0e8d8")), false)


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
	parked.append({"kind": "bike" if rng.randf() < 0.15 else "car", "xform": Transform3D(Basis(Vector3.UP, rot), pos)})


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
		_hoop(Vector3(c.x + side * 13.2, 3.1, c.y), side)
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
	for pair in BRIDGE_PAIRS:
		var a: Vector2 = ISLAND_CENTERS[pair[0]]
		var b: Vector2 = ISLAND_CENTERS[pair[1]]
		var d := (b - a).normalized()
		_bridge(a + d * LAND, b - d * LAND, ROAD + 6.0)


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
		var rect := _block_rect(c, key.x + LM_OFF, key.y + LM_OFF)
		var bc := rect.get_center()
		var base := Vector3(bc.x, 0, bc.y)
		var front := Vector3(bc.x, 0.5, rect.position.y - 4.0)
		var district: String = DISTRICTS[index]
		match what:
			"queen":
				var qh := 210.0 * float(spec.get("height", 1.0))
				_hollow_tower(rect.grow(-14.0), "queen_consolidated", qh, _glass_mats[0], Color("#3aff6a"))
				_label("QUEEN CONSOLIDATED", base + Vector3(0, 32, 0), 4.0, Color("#d8ffe0"))
				_add_landmark("Queen Consolidated", front, district, "queen_consolidated")
			"verdant":
				_hollow(rect.grow(-12.0), "bunker", 10.0, _dark_mat)
				_label("VERDANT", base + Vector3(0, 13, 0), 3.0, Color("#3aff6a"))
				add_box(Vector3(bc.x, 4.5, rect.position.y + 11.5), Vector3(12.0, 1.0, 0.4), _plain(Color("#3aff6a"), 0.4, 3.0), false)
				_add_landmark("Verdant", front, "The Glades", "bunker")
				# The Arrowbike, parked outside.
				parked.append({"kind": "bike", "xform": Transform3D(Basis(Vector3.UP, PI * 0.5), front + Vector3(9.0, -0.4, 1.0))})
			"scpd":
				_add_building(rect.grow(-8.0), 26.0, facade_mats[0][2])
				_label("SCPD", base + Vector3(0, 30, 0), 3.5, Color("#bcd4ff"))
				_add_landmark("SCPD", front, district)
			"star_labs":
				_star_labs(base)
				_add_landmark("S.T.A.R. Labs", Vector3(bc.x, 0.5, bc.y - 30.0), district, "star_labs")
			"ccpd":
				_hollow(rect.grow(-8.0), "ccpd", 24.0, facade_mats[1][1])
				_label("CCPD", base + Vector3(0, 28, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("CCPD", front, district, "ccpd")
			"jitters":
				var r := rect.grow(-6.0)
				_add_building(Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(r.size.x, r.size.y * 0.55)), 30.0, facade_mats[1][0])
				_hollow(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), "jitters", 7.0, _plain(Color("#6a3a22")))
				add_box(Vector3(bc.x, 5.6, r.position.y - 0.3), Vector3(16.0, 1.0, 0.3), _plain(Color("#ffd27a"), 0.4, 2.0), false)
				_label("JITTERS", Vector3(bc.x, 9.5, r.position.y), 2.5, Color("#ffd27a"))
				_add_landmark("Jitters", Vector3(bc.x, 0.5, r.position.y - 3.0), district, "jitters")
			"picture_news":
				_add_building(rect.grow(-8.0), 45.0, facade_mats[1][2])
				_label("PICTURE NEWS", base + Vector3(0, 49, 0), 3.0, Color("#ffffff"))
				_add_landmark("Picture News", front, district)
			"catco":
				_hollow(rect.grow(-12.0), "catco", 180.0 * float(spec.get("height", 1.0)), facade_mats[2][0])
				add_box(Vector3(bc.x, 176.0 * float(spec.get("height", 1.0)), bc.y), Vector3(40.4, 1.2, 40.4), _plain(Color("#ffffff"), 0.5, 2.0), false)
				add_box(base + Vector3(0, 120, -(rect.size.y * 0.5 - 12.0) - 2.5), Vector3(14, 0.6, 5), _concrete_mat)
				_label("CATCO", base + Vector3(0, 188, 0), 8.0, Color("#ffffff"))
				_add_landmark("CatCo Worldwide", front, district, "catco")
			"deo":
				_hollow(rect.grow(-14.0), "deo", 120.0, _dark_mat)
				add_box(Vector3(bc.x, 116.0, bc.y), Vector3(36.4, 1.2, 36.4), _plain(Color("#4fa8ff"), 0.5, 2.0), false)
				add_box(base + Vector3(0, 121.0, 0), Vector3(16, 0.4, 16), _plain(Color("#3a3a3a")))
				_label("D.E.O.", base + Vector3(0, 130, 0), 4.0, Color("#bcd4ff"))
				_add_landmark("The D.E.O.", front, district, "deo")
			"lcorp":
				_hollow_tower(rect.grow(-14.0), "l_corp", 150.0, _glass_mats[2], Color("#c8d8e8"))
				_label("L-CORP", base + Vector3(0, 158, 0), 4.0, Color("#e8f0f8"))
				_add_landmark("L-Corp", front, district, "l_corp")
			"garfield":
				_hollow(rect.grow(-6.0), "garfield", 12.0, facade_mats[3][0])
				_label("GARFIELD HIGH", base + Vector3(0, 15, 0), 3.0, Color("#ffe0a0"))
				_add_landmark("Garfield High", front, district, "garfield")
			"wayne_tower":
				var wr := rect.grow(-16.0)
				_hollow(wr, "batcave", 260.0 * float(spec.get("height", 1.0)), facade_mats[4][1])
				_gothic_crown(wr, 260.0 * float(spec.get("height", 1.0)), facade_mats[4][1])
				_label("W", base + Vector3(0, 240, -(wr.size.y * 0.5) - 0.5), 14.0, Color("#ffd27a"))
				_label("WAYNE TOWER", base + Vector3(0, 26, -(wr.size.y * 0.5) - 1.0), 3.0, Color("#e8d8b0"))
				_add_landmark("Wayne Tower", front, district, "batcave")
			"gcpd":
				_add_building(rect.grow(-8.0), 34.0, facade_mats[4][2])
				_label("GCPD", base + Vector3(0, 38, 0), 4.0, Color("#bcd4ff"))
				# The Bat-Signal and its beam into the clouds
				add_box(base + Vector3(0, 36, 0), Vector3(3.0, 2.4, 3.0), _steel_mat)
				add_box(base + Vector3(0, 37.6, 0), Vector3(2.6, 0.2, 2.6), _plain(Color("#fff2c0"), 0.2, 4.0), false)
				var beam := CylinderMesh.new()
				beam.top_radius = 14.0
				beam.bottom_radius = 1.3
				beam.height = 320.0
				var bm := StandardMaterial3D.new()
				bm.albedo_color = Color(1.0, 0.95, 0.7, 0.07)
				bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				bm.cull_mode = BaseMaterial3D.CULL_DISABLED
				var tilt := Basis(Vector3.RIGHT, -0.35)
				_mesh_instance(beam, Transform3D(tilt, base + Vector3(0, 38, 0) + tilt * Vector3(0, 160, 0)), bm)
				_label("GCPD - BAT-SIGNAL", base + Vector3(0, 4, -(rect.size.y * 0.5) + 6.0), 1.5, Color("#ffe8a0"))
				_add_landmark("GCPD", front, district)
			"arkham":
				var ar := rect.grow(-6.0)
				_hollow(ar, "arkham", 16.0, facade_mats[4][0])
				_gothic_crown(Rect2(ar.get_center() - Vector2(8, 8), Vector2(16, 16)), 34.0, facade_mats[4][0])
				add_box(Vector3(ar.get_center().x, 25.0, ar.get_center().y), Vector3(16, 18, 16), facade_mats[4][0])
				for side in [-1.0, 1.0]:
					add_box(Vector3(bc.x + side * (BLOCK * 0.5 - 1.0), 2.0, bc.y), Vector3(0.5, 4.0, BLOCK), _steel_mat)
				_label("ARKHAM ASYLUM", base + Vector3(0, 40, 0), 3.0, Color("#c8e0c0"))
				_add_landmark("Arkham Asylum", front, district, "arkham")
			"crows":
				_tower(rect.grow(-14.0), 140.0, _glass_mats[4], Color("#ff3a3a"))
				_label("CROWS SECURITY", base + Vector3(0, 146, 0), 4.0, Color("#ff9a9a"))
				_add_landmark("Crows Security", front, district)
			"kent_farm":
				_red_barn(Rect2(rect.position + Vector2(30, 24), Vector2(22, 30)))
				_farmhouse(Rect2(rect.position + Vector2(6, 8), Vector2(16, 14)), _plain(Color("#f0ece0")))
				var silo := CylinderMesh.new()
				silo.top_radius = 3.2
				silo.bottom_radius = 3.2
				silo.height = 18.0
				_mesh_instance(silo, Transform3D(Basis(), Vector3(rect.end.x - 6.0, 9.0, rect.end.y - 6.0)), _plain(Color("#b8bcc0"), 0.5))
				add_cylinder_collision(Vector3(rect.end.x - 6.0, 9.0, rect.end.y - 6.0), 3.2, 18.0)
				add_box(Vector3(bc.x, 0.18, bc.y), Vector3(BLOCK - 2.0, 0.1, BLOCK - 2.0), _grass_mat, false)
				_label("KENT FARM", Vector3(bc.x, 3.0, rect.position.y - 1.0), 1.5, Color("#ffffff"))
				_add_landmark("Kent Farm", Vector3(rect.position.x + 41.0, 0.5, rect.position.y + 20.0), district, "kent_barn")
			"jsa_hq":
				var brick := _plain(Color("#7a3a2a"))
				_hollow(rect.grow(-14.0), "jsa_hq", 16.0, brick)
				add_box(Vector3(bc.x, 16.8, bc.y), Vector3(rect.size.x - 26.0, 1.0, rect.size.y - 26.0), _plain(Color("#3a2a1e")), false)
				_label("JUSTICE SOCIETY OF AMERICA", base + Vector3(0, 18.5, 0), 2.2, Color("#ffd23a"))
				_add_landmark("JSA Headquarters", Vector3(bc.x, 0.5, rect.position.y + 12.0), district, "jsa_hq")
			"water_tower":
				for k in 4:
					var off := Vector2(-4 if k % 2 == 0 else 4, -4 if k < 2 else 4)
					add_box(Vector3(bc.x + off.x, 10.0, bc.y + off.y), Vector3(0.6, 20.0, 0.6), _steel_mat)
				var tank := CylinderMesh.new()
				tank.top_radius = 7.0
				tank.bottom_radius = 7.0
				tank.height = 8.0
				_mesh_instance(tank, Transform3D(Basis(), Vector3(bc.x, 24.0, bc.y)), _plain(Color("#d8dce0"), 0.5))
				_label("SMALLVILLE", Vector3(bc.x, 24.0, bc.y - 7.2), 2.5, Color("#2a4a8a"))
				_add_landmark("Smallville Water Tower", front, district)
			"smallville_high":
				_add_building(rect.grow(-8.0), 10.0, facade_mats[5][1])
				_label("SMALLVILLE HIGH - HOME OF THE CROWS", base + Vector3(0, 13, 0), 2.0, Color("#ffe0a0"))
				_add_landmark("Smallville High", front, district)
			"main_street":
				for k in 4:
					var sr := Rect2(rect.position + Vector2(2 + k * 15.5, 2), Vector2(13, 18))
					_add_building(sr, rng.randf_range(6.0, 9.0), facade_mats[5][k % 3])
				_label("MAIN STREET", Vector3(bc.x, 12, rect.position.y), 1.8, Color("#ffffff"))
				_add_landmark("Smallville Main Street", front, district)
			"clinic":
				_add_building(rect.grow(-10.0), 14.0, _plain(Color("#d8d0c4")))
				add_box(Vector3(bc.x, 9.0, rect.position.y + 9.7), Vector3(3.0, 3.0, 0.3), _plain(Color("#e03030"), 0.4, 2.0), false)
				_label("FREELAND CLINIC", base + Vector3(0, 17, 0), 2.5, Color("#ffffff"))
				_add_landmark("Freeland Clinic", front, district)


func _build_bay_landmarks() -> void:
	# The Waverider's landing pad, off the Star City - Central City bridge.
	var pad := Rect2(BAY_X - 45, -549, 90, 110)
	add_box(Vector3(BAY_X, -0.45, pad.get_center().y), Vector3(pad.size.x, 1.0, pad.size.y), _concrete_mat)
	var stripe := _plain(Color("#ffd23a"), 0.6, 0.8)
	for side in [-1.0, 1.0]:
		add_box(Vector3(BAY_X + side * 20.0, 0.06, pad.get_center().y), Vector3(1.0, 0.1, 90.0), stripe, false)
	for k in 6:
		add_box(Vector3(BAY_X - 40 + k * 16.0, 0.3, pad.end.y - 1.0), Vector3(0.4, 0.6, 0.4), _plain(Color("#6ad0ff"), 0.2, 3.0), false)
	extra_land.append({"rect": pad, "name": "Waverider Landing Pad"})
	_label("TIME BUREAU PAD", Vector3(BAY_X, 3.0, pad.end.y - 2.0), 1.6, Color("#bfe8ff"))
	landmarks.append({"name": "The Waverider", "pos": Vector3(BAY_X, 0.5, -462), "district": "Waverider Landing Pad"})


## A building whose ground floor is hollow, with an open doorway in the
## middle of its front (-Z) face, and a room for an interior inside. Floors
## above the room are solid as usual.
func _hollow(r: Rect2, room: String, total_h: float, m: Material) -> void:
	var size: Vector3 = Interiors.SIZES[room]
	var base_h := size.y + 0.9
	var c := r.get_center()
	var t := 0.8
	var dw := Interiors.DOOR_W + 0.4
	var dh := Interiors.DOOR_H + 0.3
	add_box(Vector3(c.x, base_h * 0.5, r.end.y - t * 0.5), Vector3(r.size.x, base_h, t), m)
	add_box(Vector3(r.position.x + t * 0.5, base_h * 0.5, c.y), Vector3(t, base_h, r.size.y), m)
	add_box(Vector3(r.end.x - t * 0.5, base_h * 0.5, c.y), Vector3(t, base_h, r.size.y), m)
	var side_w := (r.size.x - dw) * 0.5
	add_box(Vector3(r.position.x + side_w * 0.5, base_h * 0.5, r.position.y + t * 0.5), Vector3(side_w, base_h, t), m)
	add_box(Vector3(r.end.x - side_w * 0.5, base_h * 0.5, r.position.y + t * 0.5), Vector3(side_w, base_h, t), m)
	add_box(Vector3(c.x, (dh + base_h) * 0.5, r.position.y + t * 0.5), Vector3(dw, base_h - dh, t), m)
	if total_h > base_h:
		add_box(Vector3(c.x, (base_h + total_h) * 0.5, c.y), Vector3(r.size.x, total_h - base_h, r.size.y), m)
	add_box(Vector3(c.x, total_h + 0.3, c.y), Vector3(r.size.x + 0.6, 0.6, r.size.y + 0.6), _roof_mat, true)
	buildings.append({"rect": r, "h": total_h})
	# A lit entrance so it's easy to spot from the street.
	add_box(Vector3(c.x, dh + 0.25, r.position.y - 0.25), Vector3(dw + 1.2, 0.35, 1.0), _plain(Color("#ffe2a0"), 0.4, 2.5), false)
	_label("ENTRANCE", Vector3(c.x, dh + 0.9, r.position.y - 0.4), 0.4, Color("#ffe8b0"))
	# The room sits just behind the doorway, turned to face the street.
	var origin := Vector3(c.x, 0.18, r.position.y + t + 0.05 + size.z * 0.5)
	interior_slots[room] = {"origin": origin, "yaw": PI}


## A skyscraper with a walk-in lobby (and an elevator down from the roof).
func _hollow_tower(r: Rect2, room: String, h: float, m: Material, crown: Color) -> void:
	_hollow(r, room, h, m)
	var c := r.get_center()
	add_box(Vector3(c.x, h - 4.0, c.y), Vector3(r.size.x + 0.4, 1.2, r.size.y + 0.4), _plain(crown, 0.5, 2.0), false)
	add_box(Vector3(c.x, h + 12.0, c.y), Vector3(0.6, 24.0, 0.6), _plain(Color("#aaaaaa")), false)
	add_box(Vector3(c.x + 6.0, h + 1.6, c.y + 6.0), Vector3(3.0, 2.6, 3.0), _concrete_mat)
	doors.append({"name": "Elevator down to the lobby", "pos": Vector3(c.x + 6.0, h + 1.1, c.y + 3.8), "interior": room})
	roofs[room] = Vector3(c.x + 6.0, h + 1.2, c.y + 2.5)


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
	# The drum's ground floor is a ring of wall segments with a gap for the
	# front doors; the upper floors are solid.
	drum.height = 11.0
	_mesh_instance(drum, Transform3D(Basis(), base + Vector3(0, 12.5, 0)), facade_mats[2][0])
	add_cylinder_collision(base + Vector3(0, 12.5, 0), 25.0, 11.0)
	var segs := 40
	for k in segs:
		var ang := (k + 0.5) * TAU / segs
		var dir := Vector3(sin(ang), 0, -cos(ang))
		if absf(wrapf(ang, -PI, PI)) < TAU / segs * 0.7:
			continue
		add_box(base + dir * 25.0 + Vector3.UP * 3.5, Vector3(TAU * 25.0 / segs + 0.4, 7.0, 1.0), facade_mats[2][0], true, -ang)
	add_box(base + Vector3(0, 6.9, 0), Vector3(48, 0.4, 48), _plain(Color("#cfd6dd")), false)
	interior_slots["star_labs"] = {"origin": base + Vector3(0, 0.18, 0), "yaw": PI}
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
	_label("ENTRANCE", base + Vector3(0, 5.4, -27.5), 0.45, Color("#e0f0ff"))
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
	_hollow(Rect2(c.x - 40, c.y - 25, 80, 50), "iron_heights", 18.0, _plain(Color("#7a7a74")))
	_label("IRON HEIGHTS", Vector3(c.x, 26, c.y), 4.0, Color("#ffb0a0"))
	_bridge(Vector2(ISLAND_CENTERS[1].x + LAND, c.y), Vector2(c.x - half, c.y), ROAD)
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
	var grid := Rect2(-REALM_HALF, -REALM_HALF, REALM_HALF * 2.0, REALM_HALF * 2.0)
	islands.append({"name": "Old West", "center": Vector2.ZERO, "land": Rect2(-SEA, -SEA, SEA * 2.0, SEA * 2.0), "grid": grid, "style": STYLES[3], "index": 3})
	var dirt := PlaneMesh.new()
	dirt.size = Vector2(ROAD * 1.5, REALM_HALF * 2.0)
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
## A floating realm: a platform with a single road grid so spawning works.
func _realm_island(name: String, size: float) -> void:
	var grid := Rect2(-REALM_HALF, -REALM_HALF, REALM_HALF * 2.0, REALM_HALF * 2.0)
	islands.append({"name": name, "center": Vector2.ZERO, "land": Rect2(-size, -size, size * 2.0, size * 2.0), "grid": grid, "style": STYLES[1], "index": 1})


## The Anti-Matter Universe: a cracked red-black wasteland under the
## Anti-Monitor's tower, with chunks of destroyed Earths drifting overhead.
func _build_antimatter() -> void:
	add_box(Vector3(0, -1.0, 0), Vector3(1600, 2.0, 1600), _plain(Color("#1a0a0e"), 0.6))
	_realm_island("The Anti-Matter Universe", 800.0)
	var crack := _plain(Color("#ff2a3a"), 0.3, 2.5)
	for k in 60:
		var p := Vector3(rng.randf_range(-600, 600), 0.02, rng.randf_range(-600, 600))
		add_box(p, Vector3(rng.randf_range(10, 60), 0.05, rng.randf_range(0.4, 1.2)), crack, false, rng.randf() * TAU)
	var rock := _plain(Color("#2a1a1e"), 0.8)
	for k in 50:
		var p := Vector3(rng.randf_range(-700, 700), rng.randf_range(30, 220), rng.randf_range(-700, 700))
		var sz := Vector3(rng.randf_range(10, 50), rng.randf_range(6, 24), rng.randf_range(10, 50))
		add_box(p, sz, rock if k % 3 else facade_mats[rng.randi() % 4][0], false, rng.randf() * TAU)
	for k in 20:
		var p := Vector3(rng.randf_range(-500, 500), 0, rng.randf_range(-500, 500))
		if p.length() < 80.0:
			continue
		add_box(p + Vector3.UP * 8.0, Vector3(rng.randf_range(4, 10), 16.0, rng.randf_range(4, 10)), rock, true, rng.randf() * TAU)
	# The Anti-Monitor's tower
	add_box(Vector3(0, 90, -300), Vector3(40, 180, 40), _plain(Color("#120608"), 0.4))
	add_box(Vector3(0, 200, -300), Vector3(20, 40, 20), _plain(Color("#120608"), 0.4))
	add_box(Vector3(0, 150, -279), Vector3(10, 10, 1), _plain(Color("#ff2a3a"), 0.3, 5.0), false)
	_label("THE ANTI-MATTER UNIVERSE", Vector3(0, 60, -150), 10.0, Color("#ff8a9a"))
	landmarks.append({"name": "Anti-Monitor's Tower", "pos": Vector3(0, 0.5, -250), "district": "The Anti-Matter Universe"})
	landmarks.append({"name": "Anti-Matter Plains", "pos": Vector3(0, 0.5, 0), "district": "The Anti-Matter Universe"})
	add_box(Vector3(0, 40, 60), Vector3(3, 80, 3), _plain(Color("#ffffff"), 0.2, 4.0), false)
	_label("THE WAY HOME", Vector3(0, 6, 60), 2.0, Color("#ffffff"))
	doors.append({"name": "Way home", "pos": Vector3(0, 0.5, 60), "interior": "exit_speedforce"})


## Vanishing Point: the Time Bureau's station at the end of time, a metal
## deck floating in the Temporal Zone.
func _build_vanishing_point() -> void:
	var deck := _plain(Color("#5a6470"), 0.4)
	add_box(Vector3(0, -1.0, 0), Vector3(500, 2.0, 500), deck)
	_realm_island("Vanishing Point", 250.0)
	var trim := _plain(Color("#a58aff"), 0.3, 2.0)
	for side in [-1.0, 1.0]:
		add_box(Vector3(side * 250.0, 0.6, 0), Vector3(0.5, 1.2, 500), _steel_mat)
		add_box(Vector3(0, 0.6, side * 250.0), Vector3(500, 1.2, 0.5), _steel_mat)
	for k in 12:
		var x := -220.0 + k * 40.0
		add_box(Vector3(x, 0.02, 0), Vector3(1.0, 0.05, 480), trim, false)
	# The Bureau: a tall central building and timeship hangars
	_add_building(Rect2(-40, -160, 80, 60), 70.0, facade_mats[2][1])
	_label("TIME BUREAU", Vector3(0, 76, -130), 6.0, Color("#e0d8ff"))
	for k in 4:
		var hx := -150.0 + k * 100.0
		_add_building(Rect2(hx - 20, 60, 40, 30), 18.0, _dark_mat)
		add_box(Vector3(hx, 0.05, 40), Vector3(24, 0.1, 24), trim, false)
	landmarks.append({"name": "Time Bureau HQ", "pos": Vector3(0, 0.5, -90), "district": "Vanishing Point"})
	landmarks.append({"name": "Timeship Hangars", "pos": Vector3(0, 0.5, 30), "district": "Vanishing Point"})


## Argo City: Kryptonian crystal towers on a rock adrift in space.
## Argo City: the last Kryptonian city, a domed disc of crystal towers
## drifting in orbit. Earth hangs below it, the Moon off to one side, stars
## all around. Fly up out of Earth's atmosphere to get here; dive off the edge
## to fall home.
func _build_argo() -> void:
	var rock := _plain(Color("#4a4038"), 0.95)
	var rock2 := _plain(Color("#3a322c"), 0.95)
	# The city's disc and the jagged chunk of Krypton it sits on.
	var disc := CylinderMesh.new()
	disc.top_radius = 355.0
	disc.bottom_radius = 330.0
	disc.height = 8.0
	disc.radial_segments = 48
	_mesh_instance(disc, Transform3D(Basis(), Vector3(0, -4.0, 0)), _plain(Color("#8a94a4"), 0.5))
	var rim := TorusMesh.new()
	rim.inner_radius = 352.0
	rim.outer_radius = 358.0
	rim.rings = 64
	_mesh_instance(rim, Transform3D(Basis(), Vector3(0, 0.2, 0)), _plain(Color("#8fd8ff"), 0.2, 2.0))
	add_cylinder_collision(Vector3(0, -4.0, 0), 355.0, 8.0)
	for k in 18:
		var ang := k * TAU / 18.0 + rng.randf() * 0.2
		var d := rng.randf_range(80.0, 290.0)
		var h := rng.randf_range(40.0, 140.0)
		add_box(Vector3(cos(ang) * d, -8.0 - h * 0.5, sin(ang) * d), Vector3(rng.randf_range(80, 160), h, rng.randf_range(80, 160)), rock if k % 2 == 0 else rock2, false, ang)
	add_box(Vector3(0, -120.0, 0), Vector3(260, 200.0, 260), rock2, false, 0.6)
	_realm_island("Argo City", 350.0)
	var crystal := _plain(Color("#bfe8ff"), 0.1, 1.2)
	var crystal_gold := _plain(Color("#ffe08a"), 0.1, 1.0)
	var white := _plain(Color("#c8d0dc"), 0.35)
	var silver := _plain(Color("#9aa6b4"), 0.25)
	# Plaza: the House of El's crest set into the floor.
	add_box(Vector3(0, 0.05, 0), Vector3(120, 0.1, 120), _plain(Color("#6a7484"), 0.3), false)
	add_box(Vector3(0, 0.12, 0), Vector3(30, 0.06, 30), _plain(Color("#c8102e"), 0.3, 0.4), false, PI * 0.25)
	add_box(Vector3(0, 0.14, 0), Vector3(20, 0.06, 20), _plain(Color("#f2c21b"), 0.3, 0.6), false, PI * 0.25)
	# Rings of crystal towers, tallest in the middle.
	for ring in 3:
		var count := 10 + ring * 6
		for k in count:
			var ang := k * TAU / count + ring * 0.3
			var d := 90.0 + ring * 75.0 + rng.randf_range(-12.0, 12.0)
			var p := Vector3(cos(ang) * d, 0, sin(ang) * d)
			var h := rng.randf_range(40.0, 130.0) * (1.25 - ring * 0.25)
			var w := rng.randf_range(10.0, 18.0)
			_add_building(Rect2(p.x - w * 0.5, p.z - w * 0.5, w, w), h, white if k % 3 else silver)
			add_box(p + Vector3(0, h + 9.0, 0), Vector3(w * 0.35, 18.0, w * 0.35), crystal if k % 4 else crystal_gold, false, ang)
			add_box(p + Vector3(0, h * 0.5, 0), Vector3(w + 0.6, 1.2, w + 0.6), _plain(Color("#8fd8ff"), 0.2, 1.6), false, 0.0)
	# The Hall of Elders: a great crystal spire behind the plaza.
	_add_building(Rect2(-18, -78, 36, 36), 60.0, white)
	add_box(Vector3(0, 110, -60), Vector3(10.0, 100.0, 10.0), crystal, true, PI * 0.25)
	for k in 6:
		var ang := k * TAU / 6.0
		add_box(Vector3(cos(ang) * 30.0, 18.0, sin(ang) * 30.0), Vector3(3.0, 36.0, 3.0), crystal, true, ang)
	# The dome that keeps the air in (no collision: fly in and out).
	var dome := SphereMesh.new()
	dome.radius = 360.0
	dome.height = 360.0
	dome.is_hemisphere = true
	dome.radial_segments = 48
	dome.rings = 16
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.6, 0.85, 1.0, 0.08)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.emission_enabled = true
	dm.emission = Color(0.4, 0.7, 1.0)
	dm.emission_energy_multiplier = 0.15
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dmi := _mesh_instance(dome, Transform3D(Basis(), Vector3(0, 0, 0)), dm)
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_space_backdrop()
	_label("ARGO CITY", Vector3(0, 50, 0), 8.0, Color("#bfe8ff"))
	_label("THE HOUSE OF EL", Vector3(0, 6, -40), 2.0, Color("#ffd23a"))
	_label("HALL OF ELDERS", Vector3(0, 66, -40), 3.0, Color("#bfe8ff"))
	landmarks.append({"name": "Argo City Plaza", "pos": Vector3(0, 0.5, 20), "district": "Argo City"})
	landmarks.append({"name": "Hall of Elders", "pos": Vector3(0, 0.5, -36), "district": "Argo City"})
	landmarks.append({"name": "The Dome's Edge", "pos": Vector3(0, 0.5, 330), "district": "Argo City"})


## Earth below, the Moon, and a field of stars.
func _build_space_backdrop() -> void:
	var earth := SphereMesh.new()
	earth.radius = 2400.0
	earth.height = 4800.0
	earth.radial_segments = 64
	earth.rings = 32
	var em := StandardMaterial3D.new()
	em.albedo_color = Color("#1a4a9a")
	em.emission_enabled = true
	em.emission = Color("#0a2a6a")
	em.emission_energy_multiplier = 0.5
	em.roughness = 0.6
	var earth_center := Vector3(0, -2950, -400)
	_mesh_instance(earth, Transform3D(Basis(), earth_center), em).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Continents and clouds: flattened patches lying on the sphere.
	var land := _plain(Color("#3a7a3a"), 0.9, 0.3)
	var desert := _plain(Color("#b89a5a"), 0.9, 0.3)
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(1, 1, 1, 0.55)
	cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.emission_enabled = true
	cloud.emission = Color(0.8, 0.85, 0.9)
	cloud.emission_energy_multiplier = 0.4
	for k in 26:
		var dir := Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-0.6, 0.6)).normalized()
		var basis := Basis(Quaternion(Vector3.UP, dir))
		var patch := SphereMesh.new()
		var r := rng.randf_range(120.0, 380.0)
		patch.radius = r
		patch.height = r * 0.08
		var mat: Material = land if k % 3 else desert
		var lift := 2402.0
		if k >= 16:
			mat = cloud
			lift = 2430.0
		_mesh_instance(patch, Transform3D(basis * Basis.from_scale(Vector3(1.0, 1.0, rng.randf_range(0.5, 1.4))), earth_center + dir * lift), mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var atmo := SphereMesh.new()
	atmo.radius = 2470.0
	atmo.height = 4940.0
	atmo.radial_segments = 64
	atmo.rings = 32
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.4, 0.7, 1.0, 0.12)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance(atmo, Transform3D(Basis(), earth_center), am).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The Moon
	var moon := SphereMesh.new()
	moon.radius = 140.0
	moon.height = 280.0
	_mesh_instance(moon, Transform3D(Basis(), Vector3(1300, 420, -1500)), _plain(Color("#b8b8b0"), 1.0, 0.25))
	for k in 8:
		var crater := SphereMesh.new()
		crater.radius = rng.randf_range(12.0, 30.0)
		crater.height = crater.radius * 0.4
		var dir := Vector3(rng.randf_range(-1, 0.2), rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.0)).normalized()
		_mesh_instance(crater, Transform3D(Basis(Quaternion(Vector3.UP, dir)), Vector3(1300, 420, -1500) + dir * 139.0), _plain(Color("#8a8a84"), 1.0, 0.15))
	# Stars
	var star := _plain(Color("#ffffff"), 0.2, 4.0)
	var warm := _plain(Color("#ffe8c0"), 0.2, 4.0)
	for k in 520:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		var d := rng.randf_range(1500.0, 2100.0)
		var sz := rng.randf_range(1.5, 4.5)
		add_box(dir * d, Vector3(sz, sz, sz), star if k % 5 else warm, false, rng.randf() * TAU)


func _build_speed_force() -> void:
	# The Speed Force as Barry sees it: a dark blue void lit by blue and gold
	# lightning, a lightning road running into the swirling time vortex, and
	# moments of his life drifting past like windows.
	var fx := SpeedForceFX.new()
	fx.name = "SpeedForceFX"
	add_child(fx)
	var void_floor := _plain(Color("#060a1c"), 0.15, 0.2)
	add_box(Vector3(0, -1.0, 0), Vector3(1600, 2.0, 1600), void_floor)
	_realm_island("The Speed Force", 800.0)
	# Veins of light in the floor, like lightning frozen in glass.
	for k in 70:
		var p := Vector3(rng.randf_range(-600, 600), 0.02, rng.randf_range(-600, 600))
		var col := Color("#4fa8ff") if k % 2 else Color("#ffd23a")
		add_box(p, Vector3(rng.randf_range(20, 90), 0.05, rng.randf_range(0.3, 0.9)), _plain(col, 0.2, 2.5), false, rng.randf() * TAU)
	# The lightning road: a glowing runway toward the vortex.
	for k in 60:
		var z := -40.0 - k * 9.0
		var x := sin(k * 0.21) * 10.0
		add_box(Vector3(x, 0.08, z), Vector3(6.0, 0.12, 8.0), _plain(Color("#ffd23a") if k % 2 else Color("#ffe48a"), 0.2, 2.8), false, sin(k * 0.21) * 0.3)
		if k % 3 == 0:
			for side in [-1.0, 1.0]:
				add_box(Vector3(x + side * 4.5, 1.2, z), Vector3(0.3, 2.4, 0.3), _plain(Color("#4fa8ff"), 0.2, 3.0), false)
	# The time vortex: rings of light swirling around a tunnel at the end of the road.
	var vortex_z := -620.0
	for k in 14:
		var torus := TorusMesh.new()
		torus.inner_radius = 40.0 + k * 9.0
		torus.outer_radius = torus.inner_radius + 4.0 + k * 0.4
		torus.rings = 48
		torus.ring_segments = 8
		var col := Color("#4fa8ff").lerp(Color("#ffd23a"), float(k % 4) / 3.0)
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = FX.glow_mat(col, 0.55 - k * 0.025)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.FORWARD, k * 0.37), Vector3(0, 70, vortex_z - k * 18.0))
		ring.set_meta("spin", (0.6 if k % 2 == 0 else -0.45) * (1.0 + k * 0.05))
		fx.add_child(ring)
		fx.rings.append(ring)
	var core := SphereMesh.new()
	core.radius = 38.0
	core.height = 76.0
	_mesh_instance(core, Transform3D(Basis(), Vector3(0, 70, vortex_z - 260.0)), FX.glow_mat(Color("#ffffff"), 0.85))
	_label("THE TIME VORTEX", Vector3(0, 150, vortex_z), 5.0, Color("#bfe0ff"))
	# Memories: pieces of Barry's life floating in the void.
	var memories := [
		["THE ALLEN HOUSE, 2000", "#8a6a4a", "house"], ["S.T.A.R. LABS", "#c8ccd4", "labs"],
		["JITTERS", "#6a3a22", "shop"], ["THE PARTICLE ACCELERATOR", "#3a4a6a", "ring"],
		["THE WEST HOUSE", "#a87a5a", "house"], ["CCPD CRIME LAB", "#5a5a6a", "shop"],
		["NORA ALLEN", "#ffe8c0", "window"], ["THE NIGHT OF THE STORM", "#4fa8ff", "window"],
		["IRIS", "#ffd8a0", "window"], ["CENTRAL CITY, 2049", "#ffd23a", "window"]]
	for k in memories.size():
		var mem: Array = memories[k]
		var ang := k * TAU / memories.size() + 0.3
		var dist := 140.0 + (k % 3) * 70.0
		var node := Node3D.new()
		fx.add_child(node)
		node.position = Vector3(cos(ang) * dist, 25.0 + (k % 4) * 14.0, sin(ang) * dist - 80.0)
		node.set_meta("base", node.position)
		node.set_meta("phase", k * 0.9)
		node.set_meta("turn", 0.04 if k % 2 else -0.05)
		fx.drifting.append(node)
		_memory(node, str(mem[0]), Color(str(mem[1])), str(mem[2]))
	# The heart of the Speed Force, where it waits in a shape Barry knows.
	landmarks.append({"name": "Speed Force Heart", "pos": Vector3(0, 0.5, 0), "district": "The Speed Force"})
	add_box(Vector3(0, 0.1, 0), Vector3(18, 0.2, 18), _plain(Color("#c8a040"), 0.3, 0.35), false, PI * 0.25)
	var avatar := CharacterModel.new()
	avatar.position = Vector3(0, 0.2, -10)
	add_child(avatar)
	avatar.build({"suit": "#fff4d8", "pants": "#fff4d8", "accent": "#ffd23a", "skin": "#fff0d0", "hair": "#e8c890",
		"extras": ["glow_eyes", "coat"], "coat_color": "#fff8e8", "eye_glow": "#ffffff", "build": "female", "hair_style": "long",
		"boots": "#fff4d8", "gloves": "#fff0d0", "glove_length": 0.0, "anim": {"idle": "float"}})
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ffe8a0")
	glow.light_energy = 1.2
	glow.omni_range = 12.0
	glow.position = Vector3(0, 2.0, -10)
	add_child(glow)
	_label("THE SPEED FORCE (as Nora Allen)", Vector3(0, 3.0, -10), 0.6, Color("#ffe8a0"))
	# The way home: a column of light.
	add_box(Vector3(0, 40, 60), Vector3(3, 80, 3), _plain(Color("#ffffff"), 0.2, 4.0), false)
	_label("THE WAY HOME", Vector3(0, 6, 60), 2.0, Color("#ffffff"))
	doors.append({"name": "Way home", "pos": Vector3(0, 0.5, 60), "interior": "exit_speedforce"})
	doors.append({"name": "Talk to the Speed Force", "pos": Vector3(0, 0.5, -6), "interior": "speedforce_talk"})


## A memory: a framed window of light, or a broken-off chunk of a real place.
func _memory(node: Node3D, title: String, col: Color, shape: String) -> void:
	var parts := []   # [mesh, transform, material]
	var frame := FX.glow_mat(Color("#bfe0ff"), 0.9)
	match shape:
		"window":
			parts.append([_bm(Vector3(22, 13, 0.4)), Transform3D(), FX.glow_mat(col, 0.55)])
			for e in [[Vector3(0, 6.7, 0), Vector3(23, 0.6, 0.6)], [Vector3(0, -6.7, 0), Vector3(23, 0.6, 0.6)],
					[Vector3(11.2, 0, 0), Vector3(0.6, 14, 0.6)], [Vector3(-11.2, 0, 0), Vector3(0.6, 14, 0.6)]]:
				parts.append([_bm(e[1]), Transform3D(Basis(), e[0]), frame])
		"house":
			parts.append([_bm(Vector3(14, 8, 12)), Transform3D(), _plain(col, 0.8, 0.3)])
			parts.append([_bm(Vector3(15, 1.2, 13)), Transform3D(Basis(), Vector3(0, 4.6, 0)), _plain(Color("#4a2a1e"), 0.8, 0.2)])
			parts.append([_bm(Vector3(2.2, 3.4, 0.2)), Transform3D(Basis(), Vector3(0, -2.3, -6.05)), FX.glow_mat(Color("#ffe8a0"), 0.9)])
			parts.append([_bm(Vector3(18, 2.5, 16)), Transform3D(Basis(), Vector3(0, -5.2, 0)), _plain(Color("#3a3028"), 0.95)])
		"labs":
			parts.append([_bm(Vector3(24, 10, 16)), Transform3D(), _plain(col, 0.4, 0.3)])
			parts.append([_bm(Vector3(24.4, 1.0, 16.4)), Transform3D(Basis(), Vector3(0, 2, 0)), FX.glow_mat(Color("#ff3a2a"), 0.8)])
			parts.append([_bm(Vector3(28, 2.5, 20)), Transform3D(Basis(), Vector3(0, -6.2, 0)), _plain(Color("#3a3a40"), 0.95)])
		"shop":
			parts.append([_bm(Vector3(14, 7, 8)), Transform3D(), _plain(col, 0.8, 0.3)])
			parts.append([_bm(Vector3(12, 3.5, 0.2)), Transform3D(Basis(), Vector3(0, -0.5, -4.05)), FX.glow_mat(Color("#ffd8a0"), 0.85)])
			parts.append([_bm(Vector3(16, 2.0, 10)), Transform3D(Basis(), Vector3(0, -4.4, 0)), _plain(Color("#3a3028"), 0.95)])
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 12.0
			t.outer_radius = 14.5
			parts.append([t, Transform3D(), _plain(col, 0.4, 0.4)])
			parts.append([SphereMesh.new(), Transform3D(Basis.from_scale(Vector3.ONE * 5.0), Vector3.ZERO), FX.glow_mat(Color("#ffd23a"), 0.9)])
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		mi.material_override = part[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	var l := Label3D.new()
	l.text = title
	l.font_size = 96
	l.pixel_size = 0.03
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("#e8f0ff")
	l.position = Vector3(0, 10.5, 0)
	node.add_child(l)


func _bm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
