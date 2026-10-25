class_name VehicleModel
extends RefCounted
## Builds car and motorcycle models: side profiles extruded into a body, a
## glass greenhouse with roof and pillars, wheels with tyres and rims, wheel
## arches, bumpers, grille, mirrors, plates and lights. Several body styles,
## plus taxis and police cruisers.

const STYLES := {
	# length, width, sill, belt, roof, hood, windshield run, rear window run, trunk, wheel radius
	"sedan": {"L": 4.5, "W": 1.9, "sill": 0.34, "belt": 0.98, "roof": 1.46, "hood": 1.25, "ws": 0.75, "rw": 0.65, "trunk": 0.85, "wr": 0.36},
	"hatch": {"L": 3.9, "W": 1.8, "sill": 0.32, "belt": 0.96, "roof": 1.5, "hood": 1.0, "ws": 0.7, "rw": 0.35, "trunk": 0.15, "wr": 0.34},
	"suv": {"L": 4.7, "W": 2.0, "sill": 0.48, "belt": 1.18, "roof": 1.85, "hood": 1.15, "ws": 0.55, "rw": 0.3, "trunk": 0.2, "wr": 0.44},
	"van": {"L": 5.0, "W": 2.0, "sill": 0.4, "belt": 1.15, "roof": 2.35, "hood": 0.75, "ws": 0.6, "rw": 0.05, "trunk": 0.02, "wr": 0.4},
	"sports": {"L": 4.4, "W": 1.95, "sill": 0.26, "belt": 0.78, "roof": 1.16, "hood": 1.6, "ws": 0.9, "rw": 0.75, "trunk": 0.55, "wr": 0.35},
	"pickup": {"L": 5.2, "W": 2.0, "sill": 0.5, "belt": 1.2, "roof": 1.88, "hood": 1.25, "ws": 0.5, "rw": 0.1, "trunk": 2.0, "wr": 0.44},
}
const PAINTS := ["#b0201a", "#1f4fa8", "#e8e8e8", "#1a1a1a", "#8a8f99", "#2e7d32", "#d8a514", "#5a2a86", "#c0602a", "#2a3a4a",
	"#6a0e14", "#c8c8c0", "#0e2a5a", "#4a4a4a"]


# Built models, shared by every car of the same style and paint: a parked
# car costs a few mesh instances instead of its own copy of every mesh.
static var _car_cache := {}
static var _bike_cache := {}


## Builds into `parent`. Returns {body: MeshInstance3D, size: Vector3, lights: Array}.
static func build_car(parent: Node3D, style: String, paint: Color) -> Dictionary:
	var key := style + paint.to_html()
	if not _car_cache.has(key):
		var holder := Node3D.new()
		var built := _build_car(holder, style, paint)
		_car_cache[key] = {"parts": _parts_of(holder), "body": holder.get_children().find(built["body"]),
			"size": built["size"], "lights": built["lights"]}
		holder.free()
	var c: Dictionary = _car_cache[key]
	var copied := _copy_parts(c["parts"], parent, c["lights"])
	var body: MeshInstance3D = copied["parts"][c["body"]] if int(c["body"]) >= 0 else null
	return {"body": body, "size": c["size"], "lights": copied["lights"]}


## A built model as plain data: [mesh, transform, material] per part.
static func _parts_of(holder: Node3D) -> Array:
	var out: Array = []
	for src in holder.get_children():
		out.append([src.mesh, src.transform, src.material_override])
	return out


## Copies a cached model's parts into `parent`, sharing the meshes. Lights
## (police flashers) get their own materials, since they're animated.
static func _copy_parts(parts_data: Array, parent: Node3D, lights: Array) -> Dictionary:
	var parts: Array = []
	var own_lights: Array = []
	for part in parts_data:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		var m: Material = part[2]
		if m != null and lights.has(m):
			m = m.duplicate()
			own_lights.append(m)
		mi.material_override = m
		parent.add_child(mi)
		parts.append(mi)
	return {"parts": parts, "lights": own_lights}


static func _build_car(parent: Node3D, style: String, paint: Color) -> Dictionary:
	var s: Dictionary = STYLES.get(style if STYLES.has(style) else "sedan", STYLES["sedan"])
	if style in ["taxi", "police"]:
		s = STYLES["sedan"]
	var L: float = s["L"]
	var W: float = s["W"]
	var sill: float = s["sill"]
	var belt: float = s["belt"]
	var roof: float = s["roof"]
	var wr: float = s["wr"]
	var paint_mb := MeshBuilder.new()
	var dark_mb := MeshBuilder.new()
	var glass_mb := MeshBuilder.new()
	var glow_mb := MeshBuilder.new()
	# The profile is drawn in (length, height) and extruded across the width.
	var side := Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3.ZERO)
	var f := -L * 0.5   # front
	var r := L * 0.5    # rear
	var dark := Color("#18191c")
	var trim := Color("#2a2c30")
	var chrome := Color("#c8ccd2")
	# Lower body: rounded nose and tail.
	var lower := PackedVector2Array([
		Vector2(f + 0.12, sill), Vector2(f, sill + 0.12), Vector2(f, belt - 0.22), Vector2(f + 0.12, belt - 0.06),
		Vector2(f + 0.45, belt), Vector2(r - 0.4, belt), Vector2(r - 0.06, belt - 0.08), Vector2(r, belt - 0.24),
		Vector2(r, sill + 0.1), Vector2(r - 0.15, sill)])
	paint_mb.prism(lower, W, side, paint)
	# Hood slope: the bonnet rises a touch toward the windshield.
	var cab_f: float = f + float(s["hood"])
	var cab_r: float = r - float(s["trunk"])
	var roof_f: float = cab_f + float(s["ws"])
	var roof_r: float = cab_r - float(s["rw"])
	# Greenhouse: tinted glass all round, with the roof and pillars in paint.
	var green := PackedVector2Array([Vector2(cab_f, belt - 0.01), Vector2(roof_f, roof - 0.06), Vector2(roof_r, roof - 0.06), Vector2(cab_r, belt - 0.01)])
	glass_mb.prism(green, W * 0.84, side, Color("#1a2632"))
	var roof_slab := PackedVector2Array([Vector2(roof_f - 0.06, roof - 0.09), Vector2(roof_f + 0.02, roof), Vector2(roof_r - 0.02, roof), Vector2(roof_r + 0.06, roof - 0.09)])
	paint_mb.prism(roof_slab, W * 0.86, side, paint)
	for sx in [-1.0, 1.0]:
		var x: float = sx * W * 0.42
		# A pillars along the windshield, C pillars along the rear window, a B pillar mid-door.
		paint_mb.tube(Vector3(x, belt, cab_f + 0.04), Vector3(x, roof - 0.05, roof_f), 0.045, 0.04, Transform3D(), paint, 6)
		paint_mb.tube(Vector3(x, belt, cab_r - 0.04), Vector3(x, roof - 0.05, roof_r), 0.06, 0.05, Transform3D(), paint, 6)
		if roof_r - roof_f > 1.2:
			var bz := lerpf(roof_f, roof_r, 0.45)
			paint_mb.box(Vector3(x, (belt + roof) * 0.5, bz), Vector3(0.05, roof - belt, 0.09), Transform3D(), paint)
		# Chrome belt line, door seams, handles and a mirror.
		dark_mb.box(Vector3(sx * (W * 0.5 + 0.004), belt - 0.03, (cab_f + cab_r) * 0.5), Vector3(0.01, 0.025, cab_r - cab_f), Transform3D(), chrome)
		var seam_z := lerpf(cab_f, cab_r, 0.48)
		dark_mb.box(Vector3(sx * (W * 0.5 + 0.004), (sill + belt) * 0.5, seam_z), Vector3(0.01, belt - sill - 0.12, 0.012), Transform3D(), trim)
		dark_mb.box(Vector3(sx * (W * 0.5 + 0.004), (sill + belt) * 0.5, cab_f + 0.05), Vector3(0.01, belt - sill - 0.15, 0.012), Transform3D(), trim)
		for hz in [seam_z - 0.35, seam_z + 0.5]:
			dark_mb.box(Vector3(sx * (W * 0.5 + 0.012), belt - 0.16, hz), Vector3(0.02, 0.04, 0.16), Transform3D(), chrome)
		dark_mb.box(Vector3(sx * (W * 0.5 + 0.12), belt + 0.08, cab_f + 0.1), Vector3(0.22, 0.12, 0.08), Transform3D(), dark)
		# Side skirt
		dark_mb.box(Vector3(sx * (W * 0.5 - 0.02), sill + 0.04, 0.0), Vector3(0.06, 0.08, L - 1.6), Transform3D(), trim)
	# Bumpers, grille, plates
	dark_mb.box(Vector3(0, sill + 0.14, f - 0.02), Vector3(W * 0.98, 0.22, 0.14), Transform3D(), trim)
	dark_mb.box(Vector3(0, sill + 0.14, r + 0.02), Vector3(W * 0.98, 0.22, 0.14), Transform3D(), trim)
	dark_mb.box(Vector3(0, belt - 0.32, f - 0.005), Vector3(W * 0.45, 0.2, 0.04), Transform3D(), Color("#0e0e10"))
	dark_mb.box(Vector3(0, belt - 0.32, f - 0.01), Vector3(W * 0.47, 0.025, 0.045), Transform3D(), chrome)
	dark_mb.box(Vector3(0, sill + 0.3, f - 0.03), Vector3(0.5, 0.12, 0.02), Transform3D(), Color("#e8e8e0"))
	dark_mb.box(Vector3(0, sill + 0.34, r + 0.03), Vector3(0.5, 0.12, 0.02), Transform3D(), Color("#e8e8e0"))
	# Wheels: tyre, rim, hub; a dark arch painted behind each.
	var wheel_z := [f + float(s["hood"]) * 0.62, r - maxf(0.75, float(s["trunk"]) * 0.55 + 0.45)]
	if style == "pickup":
		wheel_z[1] = r - 1.0
	for wz in wheel_z:
		for sx in [-1.0, 1.0]:
			var arch := PackedVector2Array()
			for k in 9:
				var a := PI * k / 8.0
				arch.append(Vector2(wz + cos(a) * (wr + 0.08), wr + sin(a) * (wr + 0.08)))
			dark_mb.prism(arch, 0.02, Transform3D(side.basis, Vector3(sx * (W * 0.5 + 0.002), 0, 0)), Color("#0c0c0e"))
			var c := Vector3(sx * (W * 0.5 - 0.12), wr, wz)
			dark_mb.tube(c - Vector3(sx * 0.13, 0, 0), c + Vector3(sx * 0.13, 0, 0), wr, wr, Transform3D(), Color("#141414"), 14)
			dark_mb.tube(c + Vector3(sx * 0.1, 0, 0), c + Vector3(sx * 0.14, 0, 0), wr * 0.62, wr * 0.62, Transform3D(), chrome, 12)
			dark_mb.tube(c + Vector3(sx * 0.13, 0, 0), c + Vector3(sx * 0.15, 0, 0), wr * 0.18, wr * 0.15, Transform3D(), Color("#5a5e64"), 8)
	# Lights
	var lights := []
	for sx in [-1.0, 1.0]:
		glow_mb.box(Vector3(sx * W * 0.34, belt - 0.2, f + 0.02), Vector3(W * 0.2, 0.11, 0.04), Transform3D(), Color("#fff4d0"))
		glow_mb.box(Vector3(sx * W * 0.38, belt - 0.2, r - 0.01), Vector3(W * 0.16, 0.12, 0.04), Transform3D(), Color("#ff2018"))
		glow_mb.box(Vector3(sx * W * 0.45, sill + 0.2, f - 0.07), Vector3(0.12, 0.05, 0.02), Transform3D(), Color("#ffb040"))
	# Pickups get an open bed; vans a sliding-door seam.
	if style == "pickup":
		for sx in [-1.0, 1.0]:
			paint_mb.box(Vector3(sx * (W * 0.5 - 0.05), belt + 0.18, (cab_r + r) * 0.5), Vector3(0.1, 0.36, r - cab_r), Transform3D(), paint)
		paint_mb.box(Vector3(0, belt + 0.18, r - 0.05), Vector3(W, 0.36, 0.1), Transform3D(), paint)
		dark_mb.box(Vector3(0, belt + 0.01, (cab_r + r) * 0.5), Vector3(W - 0.2, 0.03, r - cab_r - 0.1), Transform3D(), Color("#2a2420"))
	if style == "taxi":
		dark_mb.box(Vector3(0, roof + 0.17, (roof_f + roof_r) * 0.5), Vector3(0.75, 0.24, 0.3), Transform3D(), Color("#f0d020"))
		glow_mb.box(Vector3(0, roof + 0.17, (roof_f + roof_r) * 0.5), Vector3(0.6, 0.12, 0.32), Transform3D(), Color("#fff8c0"))
		for sx in [-1.0, 1.0]:
			for k in 10:
				dark_mb.box(Vector3(sx * (W * 0.5 + 0.006), belt - 0.1, f + 1.2 + k * 0.22), Vector3(0.01, 0.07, 0.11),
					Transform3D(), Color("#141414") if k % 2 == 0 else Color("#f0f0e8"))
	if style == "police":
		for sx in [-1.0, 1.0]:
			# White doors with a stripe
			dark_mb.box(Vector3(sx * (W * 0.5 + 0.003), (sill + belt) * 0.5 + 0.04, (cab_f + cab_r) * 0.5), Vector3(0.012, belt - sill - 0.2, cab_r - cab_f - 0.3),
				Transform3D(), Color("#ecece8"))
			dark_mb.box(Vector3(sx * (W * 0.5 + 0.008), belt - 0.25, (cab_f + cab_r) * 0.5), Vector3(0.012, 0.06, cab_r - cab_f - 0.3), Transform3D(), Color("#1d3fa8"))
		dark_mb.box(Vector3(0, roof + 0.06, (roof_f + roof_r) * 0.5), Vector3(W * 0.7, 0.08, 0.3), Transform3D(), Color("#1a1a1a"))
	var body := paint_mb.make_instance(parent, "gloss")
	dark_mb.make_instance(parent, "skin")
	var glass := glass_mb.make_instance(parent, "gloss")
	if glass:
		glass.material_override = _glass_mat()
	glow_mb.make_instance(parent, "glow")
	if style == "police":
		for k in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(W * 0.32, 0.12, 0.26)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#ff2020") if k == 0 else Color("#2050ff")
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 2.5
			mi.material_override = m
			mi.position = Vector3((k - 0.5) * W * 0.34, roof + 0.15, (roof_f + roof_r) * 0.5)
			parent.add_child(mi)
			lights.append(m)
	return {"body": body, "size": Vector3(W, roof, L), "lights": lights}


static var _glass: StandardMaterial3D


static func _glass_mat() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(0.1, 0.16, 0.22)
		_glass.metallic = 0.6
		_glass.roughness = 0.08
	return _glass


## A motorcycle: frame, tank, seat, forks, bars, wheels with spokes, exhaust.
static func build_bike(parent: Node3D, paint: Color) -> MeshInstance3D:
	var key := paint.to_html()
	if not _bike_cache.has(key):
		var holder := Node3D.new()
		var body := _build_bike(holder, paint)
		_bike_cache[key] = {"parts": _parts_of(holder), "body": holder.get_children().find(body)}
		holder.free()
	var c: Dictionary = _bike_cache[key]
	var copied := _copy_parts(c["parts"], parent, [])
	return copied["parts"][c["body"]] if int(c["body"]) >= 0 else null


static func _build_bike(parent: Node3D, paint: Color) -> MeshInstance3D:
	var p := MeshBuilder.new()
	var d := MeshBuilder.new()
	var g := MeshBuilder.new()
	var chrome := Color("#c8ccd2")
	var black := Color("#141414")
	var wr := 0.33
	for wz in [-0.72, 0.72]:
		d.tube(Vector3(-0.07, wr, wz), Vector3(0.07, wr, wz), wr, wr, Transform3D(), black, 16)
		d.tube(Vector3(-0.075, wr, wz), Vector3(0.075, wr, wz), wr * 0.55, wr * 0.55, Transform3D(), chrome, 12)
		d.tube(Vector3(-0.09, wr, wz), Vector3(0.09, wr, wz), 0.06, 0.06, Transform3D(), Color("#5a5e64"), 8)
	# Frame and engine
	d.tube(Vector3(0, wr, 0.72), Vector3(0, 0.62, 0.1), 0.04, 0.04, Transform3D(), Color("#2a2c30"), 6)
	d.tube(Vector3(0, 0.62, 0.1), Vector3(0, 0.88, -0.45), 0.045, 0.045, Transform3D(), Color("#2a2c30"), 6)
	d.box(Vector3(0, 0.5, 0.0), Vector3(0.32, 0.32, 0.5), Transform3D(), Color("#3a3c40"))
	for k in 3:
		d.tube(Vector3(-0.17, 0.42 + k * 0.08, -0.12), Vector3(0.17, 0.42 + k * 0.08, -0.12), 0.02, 0.02, Transform3D(), chrome, 6)
	# Tank, seat, tail
	p.ellipsoid(Vector3(0, 0.92, -0.18), Vector3(0.19, 0.13, 0.32), Transform3D(), paint, 14, 8)
	p.box(Vector3(0, 0.88, 0.5), Vector3(0.22, 0.1, 0.45), Transform3D(), paint, Basis(Vector3.RIGHT, -0.15))
	d.box(Vector3(0, 0.96, 0.18), Vector3(0.26, 0.08, 0.5), Transform3D(), black)
	# Forks, bars, headlamp, fairing
	for sx in [-0.09, 0.09]:
		d.tube(Vector3(sx, wr, -0.72), Vector3(sx, 1.05, -0.5), 0.025, 0.025, Transform3D(), chrome, 6)
	d.tube(Vector3(-0.36, 1.12, -0.48), Vector3(0.36, 1.12, -0.48), 0.02, 0.02, Transform3D(), black, 6)
	p.ellipsoid(Vector3(0, 1.02, -0.62), Vector3(0.17, 0.15, 0.1), Transform3D(), paint, 12, 6)
	g.ellipsoid(Vector3(0, 1.0, -0.71), Vector3(0.08, 0.07, 0.02), Transform3D(), Color("#fff4d0"), 10, 5)
	g.box(Vector3(0, 0.95, 0.75), Vector3(0.12, 0.05, 0.03), Transform3D(), Color("#ff2018"))
	# Exhaust
	d.tube(Vector3(0.16, 0.35, -0.05), Vector3(0.2, 0.45, 0.7), 0.045, 0.055, Transform3D(), chrome, 8)
	var body := p.make_instance(parent, "gloss")
	d.make_instance(parent, "metal")
	g.make_instance(parent, "glow")
	return body
