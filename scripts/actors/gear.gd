class_name Gear
extends RefCounted
## Weapons and gear, built into a MeshBuilder in "grip space": the origin is
## the centre of the fist, -Y runs out past the knuckles along the forearm,
## and -Z points forward when the arm hangs at the side. So a pistol barrel
## runs along -Y (it aims wherever the arm points) and a sword blade runs
## along -Z (it stands up when the arm is raised).

const WOOD := Color("#4a3322")
const DARK := Color("#1b1c1f")
const STEEL := Color("#c9ced4")
const GUNMETAL := Color("#3a3d42")
const BRASS := Color("#b08a3a")


static func build(kind: String, mb: MeshBuilder, glow: MeshBuilder, xf: Transform3D, look: Dictionary) -> void:
	var accent := Color(str(look.get("accent", "#333333")))
	match kind:
		"bow":
			bow(mb, xf, Color(str(look.get("bow_color", "#2b2420"))))
		"katana":
			blade(mb, xf, 0.95, 0.028, STEEL, DARK, Color("#c07a20"), false)
		"sword":
			blade(mb, xf, 0.9, 0.035, STEEL, DARK, BRASS, false)
		"scimitar":
			blade(mb, xf, 0.85, 0.04, STEEL, Color("#3a2a1a"), BRASS, true)
		"dagger":
			blade(mb, xf, 0.28, 0.022, STEEL, DARK, DARK, false)
		"cicada_dagger":
			blade(glow, xf, 0.42, 0.03, Color("#ff3a2a"), DARK, DARK, true)
			mb.tube(Vector3(0, 0, 0.05), Vector3(0, 0, -0.06), 0.018, 0.018, xf, DARK)
		"staff":
			mb.tube(Vector3(-0.85, 0, 0), Vector3(0.85, 0, 0), 0.016, 0.016, xf, Color(str(look.get("staff_color", "#d8d8d8"))))
			for x in [-0.85, -0.12, 0.12, 0.85]:
				mb.tube(Vector3(x - 0.03, 0, 0), Vector3(x + 0.03, 0, 0), 0.019, 0.019, xf, DARK)
		"cosmic_staff":
			# Starman's Cosmic Staff: a long brass-and-steel rod with a leather
			# grip, banded segments, and a forked crescent head around a glowing core.
			var brass := Color("#c9a85a")
			var steel := Color("#b8bec6")
			mb.tube(Vector3(0, 0.78, 0), Vector3(0, -0.98, 0), 0.019, 0.017, xf, steel, 10)
			mb.tube(Vector3(0, 0.1, 0), Vector3(0, -0.12, 0), 0.023, 0.023, xf, Color("#3a2a1e"), 10)
			for y in [0.62, 0.38, 0.16, -0.16, -0.42, -0.68]:
				mb.tube(Vector3(0, y + 0.018, 0), Vector3(0, y - 0.018, 0), 0.025, 0.025, xf, brass, 10)
			mb.tube(Vector3(0, 0.78, 0), Vector3(0, 0.84, 0), 0.026, 0.012, xf, brass, 10)
			mb.tube(Vector3(0, -0.96, 0), Vector3(0, -1.03, 0), 0.03, 0.036, xf, brass, 10)
			for side in [-1.0, 1.0]:
				var pts := [Vector3(side * 0.03, -1.02, 0), Vector3(side * 0.085, -1.1, 0), Vector3(side * 0.095, -1.2, 0),
					Vector3(side * 0.06, -1.29, 0), Vector3(side * 0.018, -1.33, 0)]
				for k in pts.size() - 1:
					mb.tube(pts[k], pts[k + 1], 0.012, 0.009, xf, brass, 6)
			glow.ellipsoid(Vector3(0, -1.17, 0), Vector3(0.045, 0.06, 0.045), xf, Color("#fff2a0"))
			glow.ellipsoid(Vector3(0, -1.17, 0), Vector3(0.02, 0.09, 0.02), xf, Color("#ffffff"))
		"weather_wand":
			mb.tube(Vector3(0, 0.08, 0), Vector3(0, -0.45, 0), 0.016, 0.012, xf, DARK)
			glow.ellipsoid(Vector3(0, -0.5, 0), Vector3(0.035, 0.05, 0.035), xf, Color("#bfe0ff"))
		"mace":
			mb.tube(Vector3(0, 0, 0.08), Vector3(0, 0, -0.55), 0.02, 0.02, xf, Color("#3a2a1a"))
			mb.ellipsoid(Vector3(0, 0, -0.62), Vector3(0.09, 0.09, 0.09), xf, Color("#b08a3a"))
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]:
				mb.tube(Vector3(0, 0, -0.62) + d * 0.07, Vector3(0, 0, -0.62) + d * 0.14, 0.03, 0.0, xf, Color("#8a6a2a"), 6)
		"pistol":
			pistol(mb, xf, GUNMETAL, 1.0)
		"pistol_big":
			pistol(mb, xf, Color("#9a9a9a"), 1.35)
		"cold_gun":
			mb.box(Vector3(0, -0.04, -0.02), Vector3(0.07, 0.2, 0.11), xf, Color("#c8d6e0"))
			mb.tube(Vector3(0, -0.12, -0.02), Vector3(0, -0.36, -0.02), 0.035, 0.028, xf, Color("#6a7a88"))
			mb.box(Vector3(0, 0.03, 0.05), Vector3(0.05, 0.11, 0.05), xf, DARK)
			glow.tube(Vector3(0, -0.36, -0.02), Vector3(0, -0.385, -0.02), 0.03, 0.03, xf, Color("#8fe0ff"))
			glow.tube(Vector3(0, -0.18, -0.065), Vector3(0, -0.3, -0.065), 0.008, 0.008, xf, Color("#8fe0ff"))
		"heat_gun":
			mb.box(Vector3(0, -0.04, -0.02), Vector3(0.08, 0.22, 0.12), xf, Color("#5a5048"))
			mb.tube(Vector3(0, -0.12, -0.03), Vector3(0, -0.42, -0.03), 0.04, 0.032, xf, BRASS)
			mb.box(Vector3(0, 0.03, 0.05), Vector3(0.05, 0.11, 0.05), xf, DARK)
			glow.tube(Vector3(0, -0.42, -0.03), Vector3(0, -0.445, -0.03), 0.033, 0.033, xf, Color("#ff8a1e"))
		"shield":
			# Domed round shield strapped to the outside (-X) of the left forearm.
			mb.loft([{"y": -0.02, "rx": 0.3, "rz": 0.34}, {"y": 0.0, "rx": 0.3, "rz": 0.34}, {"y": 0.04, "rx": 0.24, "rz": 0.27}, {"y": 0.055, "rx": 0.0, "rz": 0.0}],
				xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.06, 0.12, 0)), Color("#bfc6cc"), 20)
		"boomerang":
			boomerang(mb, xf * Transform3D(Basis(), Vector3(0, -0.02, -0.12)), Color("#d8d8d8"))
		"heavy_claws":
			for x in [-0.03, 0.0, 0.03]:
				mb.tube(Vector3(x, -0.04, -0.02), Vector3(x * 1.4, -0.26, -0.06), 0.01, 0.002, xf, Color("#e0e8f0"), 5)
		"t_gauntlet", "gauntlet":
			mb.tube(Vector3(0, 0.2, 0), Vector3(0, 0.02, 0), 0.05, 0.048, xf, accent)
			glow.ellipsoid(Vector3(0, -0.03, -0.045), Vector3(0.018, 0.018, 0.01), xf, Color(str(look.get("glow", "#4fc3ff"))))


static func bow(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	# Recurve bow standing along grip-space Z (vertical when aiming).
	var pts := PackedVector3Array()
	var steps := 16
	for i in steps + 1:
		var t := -1.0 + 2.0 * float(i) / steps
		var z := t * 0.62
		var bend := -0.16 * (1.0 - t * t)   # limbs bow forward (grip-space -Y)
		var recurve := 0.05 * pow(absf(t), 6.0)  # tips flick back
		pts.append(Vector3(0, bend + recurve + 0.04, z))
	for i in steps:
		var r := 0.016 if absf(float(i) / steps - 0.5) < 0.12 else 0.011
		mb.tube(pts[i], pts[i + 1], r, r, xf, color, 6, false)
	mb.tube(Vector3(0, 0.0, -0.07), Vector3(0, 0.0, 0.07), 0.024, 0.024, xf, Color("#121212"), 8)
	mb.tube(pts[0], pts[steps], 0.003, 0.003, xf, Color("#e8e0d0"), 4)


static func arrow(mb: MeshBuilder, xf: Transform3D, shaft: Color, tip: Color, length := 0.78) -> void:
	# Points along -Z.
	mb.tube(Vector3(0, 0, length * 0.5), Vector3(0, 0, -length * 0.5), 0.006, 0.006, xf, shaft, 5)
	mb.tube(Vector3(0, 0, -length * 0.5), Vector3(0, 0, -length * 0.5 - 0.07), 0.016, 0.0, xf, tip, 6)
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var fletch := PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.02), Vector2(0.03, 0.11), Vector2(0, 0.13)])
		mb.prism(fletch, 0.003, xf * Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, length * 0.5 - 0.13)), Color("#e8e2d6"))


static func blade(mb: MeshBuilder, xf: Transform3D, length: float, width: float, steel: Color, grip: Color, guard: Color, curved: bool) -> void:
	mb.tube(Vector3(0, 0, 0.11), Vector3(0, 0, -0.05), 0.017, 0.017, xf, grip, 6)
	mb.box(Vector3(0, 0, -0.06), Vector3(0.09, 0.03, 0.02), xf, guard)
	var segs := 6
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var z0 := -0.07 - t0 * length
		var z1 := -0.07 - t1 * length
		var y0 := (t0 * t0 * 0.12) if curved else 0.0
		var y1 := (t1 * t1 * 0.12) if curved else 0.0
		var w0 := width * (1.0 - t0 * 0.35)
		var w1 := width * (1.0 - t1 * 0.35) if i < segs - 1 else 0.004
		var mid := Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
		var seg_len := Vector2(z1 - z0, y1 - y0).length()
		var tilt := atan2(y1 - y0, -(z1 - z0))
		mb.box(mid, Vector3(0.008, (w0 + w1), seg_len + 0.002), xf, steel, Basis(Vector3.RIGHT, tilt))


static func pistol(mb: MeshBuilder, xf: Transform3D, color: Color, k: float) -> void:
	mb.box(Vector3(0, -0.04, -0.03) * k, Vector3(0.032, 0.17, 0.045) * k, xf, color)
	mb.box(Vector3(0, 0.02, 0.0) * k, Vector3(0.03, 0.05, 0.08) * k, xf, DARK)
	mb.tube(Vector3(0, -0.12, -0.03) * k, Vector3(0, -0.135, -0.03) * k, 0.008 * k, 0.008 * k, xf, DARK, 6)


static func boomerang(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	var outline := PackedVector2Array([Vector2(-0.2, -0.06), Vector2(-0.03, 0.08), Vector2(0.03, 0.08), Vector2(0.2, -0.06),
		Vector2(0.16, -0.09), Vector2(0.0, 0.02), Vector2(-0.16, -0.09)])
	mb.prism(outline, 0.016, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), color)


static func batarang(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in Emblems._bat_points():
		pts.append((Vector2(p.x, -p.y) - Vector2(0.5, -0.5)) * 0.3)
	mb.prism(pts, 0.012, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), color)


static func shuriken(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		var r := 0.1 if i % 2 == 0 else 0.03
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	mb.prism(pts, 0.008, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), color)


static func quiver(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	mb.loft([{"y": -0.25, "rx": 0.05, "rz": 0.04}, {"y": 0.22, "rx": 0.055, "rz": 0.045}], xf, color, 10)
	for i in 6:
		var off := Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.025, 0.025))
		mb.tube(off + Vector3(0, 0.2, 0), off + Vector3(0, 0.33, 0), 0.005, 0.005, xf, Color("#5a4630"), 4)
		mb.box(off + Vector3(0, 0.34, 0), Vector3(0.025, 0.06, 0.004), xf, Color("#e8e2d6"))
