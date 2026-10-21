class_name MeshBuilder
extends RefCounted
## Accumulates vertex-coloured geometry and commits it as one ArrayMesh, so a
## whole body part (with its costume colours) is a single draw call.
##
## The main primitive is `loft`: a stack of elliptical rings joined into a
## smooth surface. Bodies, limbs, heads, hoods, capes and car bodies are all
## lofts. A colour callback paints each vertex, which is how costumes get
## belts, gloves, boot tops, cowls, masks and piping.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static var _materials: Dictionary = {}
static var _detail_materials: Dictionary = {}
static var _sculpt_cache: Dictionary = {}

## Surface tags for detail materials, carried in the vertex colour's alpha
## as k / 15 (15, an opaque colour, means "no detail").
const TAGS := {"skin": 0, "hair": 1, "leather": 2, "quilt": 3, "scales": 4, "weave": 5, "knit": 6,
	"tactical": 7, "denim": 8, "rubber": 9, "wet": 10, "brushed": 11, "chain": 12, "mesh": 13, "suede": 14}


static func tagged(c: Color, tag: String) -> Color:
	if not TAGS.has(tag):
		return Color(c, 1.0)
	return Color(c, float(TAGS[tag]) / 15.0)


func is_empty() -> bool:
	return verts.is_empty()


## rings: Array of Dictionaries {y, rx, rz, cx?, cz?, c?}. Rings run bottom
## to top along local +Y and are transformed by `xform`.
## color: a Color, or a Callable(t: float, theta: float, ring: Dictionary) -> Color
## where t is 0..1 along the loft and theta is the angle (0 = front, -Z).
## arc: fraction of the circle to build, centred on the back (1.0 = closed).
func loft(rings: Array, xform: Transform3D, color, segments := 16, cap_bottom := true, cap_top := true, arc := 1.0, splits: Array = [], subdiv := 1) -> void:
	if subdiv > 1 or not splits.is_empty():
		rings = refine(rings, splits, subdiv)
	var base := verts.size()
	var n := rings.size()
	var closed := arc >= 0.999
	var cols := segments if closed else segments + 1
	var start_angle := PI * (1.0 - arc)  # theta 0 = front; open arcs leave the front open
	var span := TAU * arc
	var y0 := float(rings[0]["y"])
	var y1 := float(rings[n - 1]["y"])
	var span_y := y1 - y0 if absf(y1 - y0) > 1e-6 else 1.0
	var local_pos := PackedVector3Array()
	for i in n:
		var r: Dictionary = rings[i]
		var t := (float(r["y"]) - y0) / span_y
		for j in cols:
			var theta := start_angle + span * float(j) / segments
			var x: float = r.get("cx", 0.0) + sin(theta) * float(r["rx"])
			var z: float = r.get("cz", 0.0) - cos(theta) * float(r["rz"])
			var p := Vector3(x, float(r["y"]), z)
			local_pos.append(p)
			verts.append(xform * p)
			colors.append(_color_at(color, t, theta, r))
			normals.append(Vector3.ZERO)
	for i in n - 1:
		for j in segments:
			var a := base + i * cols + j
			var b := base + i * cols + ((j + 1) % cols if closed else j + 1)
			var c := a + cols
			var d := b + cols
			indices.append_array([a, b, c, b, d, c])
	if closed:
		if cap_bottom:
			_cap(base, cols, rings[0], xform, color, 0.0, true)
		if cap_top:
			_cap(base + (n - 1) * cols, cols, rings[n - 1], xform, color, 1.0, false)
	_smooth_normals(base)


## Adds rings between existing ones (subdiv) and a pair of rings straddling
## each split height (as a 0..1 fraction of the loft), so colour changes
## there are crisp instead of smeared across a whole segment.
static func refine(rings: Array, splits: Array, subdiv: int) -> Array:
	var out := []
	for i in rings.size() - 1:
		var a: Dictionary = rings[i]
		var b: Dictionary = rings[i + 1]
		for k in subdiv:
			out.append(_lerp_ring(a, b, float(k) / subdiv))
	out.append(rings[rings.size() - 1])
	if splits.is_empty():
		return out
	var y0 := float(out[0]["y"])
	var y1 := float(out[out.size() - 1]["y"])
	for sp in splits:
		var ys: float = lerpf(y0, y1, float(sp))
		for i in out.size() - 1:
			var ya: float = out[i]["y"]
			var yb: float = out[i + 1]["y"]
			if (ys - ya) * (ys - yb) <= 0.0 and absf(yb - ya) > 1e-5:
				var t := (ys - ya) / (yb - ya)
				var eps := 0.0015 / absf(yb - ya)
				var lo := _lerp_ring(out[i], out[i + 1], clampf(t - eps, 0.0, 1.0))
				var hi := _lerp_ring(out[i], out[i + 1], clampf(t + eps, 0.0, 1.0))
				out.insert(i + 1, hi)
				out.insert(i + 1, lo)
				break
	return out


static func _lerp_ring(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var r := {}
	for key in ["y", "rx", "rz", "cx", "cz"]:
		r[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), t)
	if a.has("c") and t < 0.5:
		r["c"] = a["c"]
	elif b.has("c") and t >= 0.5:
		r["c"] = b["c"]
	return r


func _cap(ring_start: int, cols: int, r: Dictionary, xform: Transform3D, color, t: float, bottom: bool) -> void:
	var center := xform * Vector3(r.get("cx", 0.0), float(r["y"]), r.get("cz", 0.0))
	var ci := verts.size()
	verts.append(center)
	colors.append(_color_at(color, t, PI, r))
	normals.append(Vector3.ZERO)
	for j in cols:
		var a := ring_start + j
		var b := ring_start + (j + 1) % cols
		if bottom:
			indices.append_array([ci, b, a])
		else:
			indices.append_array([ci, a, b])


func _color_at(color, t: float, theta: float, r: Dictionary) -> Color:
	if r.has("c"):
		return r["c"]
	if color is Callable:
		return color.call(t, wrapf(theta, -PI, PI), r)
	return color


func _smooth_normals(from_vertex: int) -> void:
	# Accumulate face normals over the triangles that reference new vertices.
	var tri_start := 0
	for k in range(indices.size() - 3, -1, -3):
		if indices[k] < from_vertex:
			tri_start = k + 3
			break
	for k in range(tri_start, indices.size(), 3):
		var ia := indices[k]
		var ib := indices[k + 1]
		var ic := indices[k + 2]
		var fn := (verts[ic] - verts[ia]).cross(verts[ib] - verts[ia])
		normals[ia] += fn
		normals[ib] += fn
		normals[ic] += fn
	for v in range(from_vertex, verts.size()):
		var nv := normals[v]
		normals[v] = nv.normalized() if nv.length_squared() > 1e-12 else Vector3.UP


## Moves every vertex added since `from_vertex` by fn(local_pos) -> offset
## (in the builder's space) and re-smooths their normals. Used to sculpt
## faces into a lofted head.
## With a cache_key, the offsets are computed once per key (the same loft
## always gets the same sculpt), which keeps crowds cheap to build.
func sculpt(from_vertex: int, fn: Callable, cache_key := "") -> void:
	var count := verts.size() - from_vertex
	var offs: PackedVector3Array
	if cache_key != "" and _sculpt_cache.has(cache_key) and (_sculpt_cache[cache_key] as PackedVector3Array).size() == count:
		offs = _sculpt_cache[cache_key]
	else:
		offs = PackedVector3Array()
		offs.resize(count)
		for i in count:
			offs[i] = fn.call(verts[from_vertex + i])
		if cache_key != "":
			_sculpt_cache[cache_key] = offs
	for i in count:
		verts[from_vertex + i] += offs[i]
		normals[from_vertex + i] = Vector3.ZERO
	_smooth_normals(from_vertex)


## Ellipsoid centred at `center` with radii `radii` (before xform).
func ellipsoid(center: Vector3, radii: Vector3, xform: Transform3D, color, segments := 14, stacks := 9) -> void:
	var rings := []
	for i in stacks + 1:
		var a := -PI * 0.5 + PI * float(i) / stacks
		var s := cos(a)
		rings.append({"y": center.y + sin(a) * radii.y, "rx": maxf(0.0005, s * radii.x), "rz": maxf(0.0005, s * radii.z),
			"cx": center.x, "cz": center.z})
	loft(rings, xform, color, segments, false, false)


## A tapered tube between two points, e.g. a limb segment or a bow limb.
func tube(a: Vector3, b: Vector3, ra: float, rb: float, xform: Transform3D, color, segments := 10, caps := true) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.0001:
		return
	var y := axis / length
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	var local := Transform3D(Basis(x, y, -z), a)
	loft([{"y": 0.0, "rx": ra, "rz": ra}, {"y": length, "rx": rb, "rz": rb}], xform * local, color, segments, caps, caps)


## A tube following a polyline (bows, boomerangs, straps, wires).
func path(points: PackedVector3Array, radius: float, xform: Transform3D, color, segments := 6) -> void:
	for i in points.size() - 1:
		tube(points[i], points[i + 1], radius, radius, xform, color, segments, true)


## Flat-shaded box.
func box(center: Vector3, size: Vector3, xform: Transform3D, color: Color, rot := Basis()) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, -1), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 0, 1), [Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
	]
	var nb := (xform.basis * rot).orthonormalized()
	for f in faces:
		var base := verts.size()
		for p in f[1]:
			verts.append(xform * (center + rot * p))
			normals.append((nb * f[0]).normalized())
			colors.append(color)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## A flat polygon (in the XY plane, facing -Z) extruded by `depth`.
func prism(outline: PackedVector2Array, depth: float, xform: Transform3D, color: Color) -> void:
	var n := outline.size()
	var tris := Geometry2D.triangulate_polygon(outline)
	if tris.is_empty():
		return
	for side in [-1.0, 1.0]:
		var base := verts.size()
		var nrm := (xform.basis * Vector3(0, 0, side)).normalized()
		for p in outline:
			verts.append(xform * Vector3(p.x, p.y, side * depth * 0.5))
			normals.append(nrm)
			colors.append(color)
		for k in range(0, tris.size(), 3):
			if side < 0.0:
				indices.append_array([base + tris[k], base + tris[k + 2], base + tris[k + 1]])
			else:
				indices.append_array([base + tris[k], base + tris[k + 1], base + tris[k + 2]])
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var edge := (b - a).normalized()
		var nrm := (xform.basis * Vector3(edge.y, -edge.x, 0)).normalized()
		var base := verts.size()
		for p in [Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(a.x, a.y, depth * 0.5)]:
			verts.append(xform * p)
			normals.append(nrm)
			colors.append(color)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func commit(material_kind := "skin", detailed := false) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, detail_material(material_kind) if detailed else material(material_kind))
	return mesh


## Character materials: the same kinds as `material`, but with procedural
## micro-detail chosen per vertex by its surface tag (glow stays unshaded).
static func detail_material(kind: String) -> Material:
	if kind == "glow":
		return material(kind)
	if _detail_materials.has(kind):
		return _detail_materials[kind]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/character_cloth.gdshader" if kind == "cloth" else "res://shaders/character_surface.gdshader")
	match kind:
		"metal":
			m.set_shader_parameter("base_rough", 0.32)
			m.set_shader_parameter("base_metal", 0.75)
		"gloss":
			m.set_shader_parameter("base_rough", 0.34)
			m.set_shader_parameter("base_metal", 0.08)
		"cloth":
			m.set_shader_parameter("base_rough", 0.82)
		_:
			m.set_shader_parameter("base_rough", 0.68)
	_detail_materials[kind] = m
	return m


## Shared vertex-colour materials: "skin" (matte cloth and skin), "metal"
## (armour, weapons, cars), "gloss" (leather, visors, paint), "glow"
## (unshaded, for energy).
static func material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match kind:
		"metal":
			m.metallic = 0.75
			m.roughness = 0.32
		"gloss":
			m.metallic = 0.15
			m.roughness = 0.28
		"glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"cloth":
			m.roughness = 0.8
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			m.roughness = 0.72
	_materials[kind] = m
	return m


func make_instance(parent: Node3D, material_kind := "skin", detailed := false) -> MeshInstance3D:
	var mesh := commit(material_kind, detailed)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi
