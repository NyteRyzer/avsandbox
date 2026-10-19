class_name CharacterModel
extends Node3D
## A jointed, sculpted humanoid built at runtime from a character's "look":
## lofted torso, limbs and head with costume colours painted per vertex
## (belts, gloves, boot tops, piping, cowls, masks), separate hair, hoods,
## capes, armour, emblem decals and hand-held gear. A pose-based animator
## drives locomotion, flight, melee combos, casting poses and hit reactions.
## The model faces -Z and stands about 1.8 m tall at scale 1.

static var _mat_cache: Dictionary = {}

var look: Dictionary = {}
var extras: Array = []
var build_type := "male"
var D: Dictionary = {}

# Rig
var hips: Node3D
var body: Node3D      # alias of hips, kept for callers that tilt the whole body
var spine: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var th_l: Node3D
var th_r: Node3D
var kn_l: Node3D
var kn_r: Node3D
var cape: Node3D
var cape_low: Node3D
var wings: Array[Node3D] = []
var eye_points: Array[Node3D] = []
var muzzle: Node3D
var meshes: Array[MeshInstance3D] = []

# Animation state
var _phase := 0.0
var _action := ""
var _action_t := 0.0
var _action_len := 0.3
var _action_step := 0
var _hit_t := 0.0
var _recoil := 0.0
var _tumble := 0.0
var _tumble_speed := 0.0
var _breath := 0.0
var _override: Material = null
var _flash_mat: StandardMaterial3D
var _builders: Dictionary = {}
var _stretch := 1.0
var _pose: Dictionary = {}


static func mat(color: Color, emission := 0.0, unshaded := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [color.to_html(), emission, unshaded, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.65
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


## Kept for props: merges plain primitive-mesh children into one mesh.
static func merge_children(parent: Node3D, metallic := 0.0) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var merged: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if not (child is MeshInstance3D) or child.is_queued_for_deletion():
			continue
		var pm := child.mesh as PrimitiveMesh
		if pm == null:
			continue
		var m := pm.material as StandardMaterial3D
		if m == null or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			continue
		var arrays := pm.get_mesh_arrays()
		var xf: Transform3D = child.transform
		var nb := xf.basis.inverse().transposed()
		var base := mb.verts.size()
		for v in arrays[Mesh.ARRAY_VERTEX]:
			mb.verts.append(xf * v)
			mb.colors.append(m.albedo_color)
		for n in arrays[Mesh.ARRAY_NORMAL]:
			mb.normals.append((nb * n).normalized())
		for i in arrays[Mesh.ARRAY_INDEX]:
			mb.indices.append(base + i)
		merged.append(child)
	if merged.size() < 2:
		return null
	var mi := mb.make_instance(parent, "metal" if metallic > 0.0 else "skin")
	for child in merged:
		child.queue_free()
	return mi


# --- Look helpers -------------------------------------------------------------

func _c(key: String, fallback: String) -> Color:
	var v = look.get(key, fallback)
	if typeof(v) != TYPE_STRING or v == "":
		v = fallback
	return Color(str(v))


func _has(e: String) -> bool:
	return extras.has(e)


func _mb(pivot: Node3D, kind := "skin") -> MeshBuilder:
	var key := "%d|%s" % [pivot.get_instance_id(), kind]
	if not _builders.has(key):
		_builders[key] = {"pivot": pivot, "kind": kind, "mb": MeshBuilder.new()}
	return _builders[key]["mb"]


func _pivot(parent: Node3D, pos: Vector3, name_hint := "") -> Node3D:
	var n := Node3D.new()
	n.name = name_hint if name_hint != "" else "P"
	n.position = pos
	parent.add_child(n)
	return n


func _dims() -> Dictionary:
	var d := {
		"hip_y": 0.95, "thigh": 0.44, "shin": 0.44, "upper": 0.29, "fore": 0.26,
		"shoulder": 0.205, "chest_rx": 0.17, "chest_rz": 0.115, "waist_rx": 0.135, "waist_rz": 0.092,
		"hip_rx": 0.15, "hip_rz": 0.1, "arm_r": 0.056, "thigh_r": 0.083, "head": 1.0, "neck_r": 0.05,
		"spine_len": 0.45, "bust": 0.0,
	}
	match build_type:
		"female":
			d.merge({"shoulder": 0.18, "chest_rx": 0.148, "chest_rz": 0.1, "waist_rx": 0.112, "waist_rz": 0.082,
				"hip_rx": 0.158, "hip_rz": 0.105, "arm_r": 0.045, "thigh_r": 0.08, "neck_r": 0.042, "bust": 0.035,
				"upper": 0.27, "fore": 0.245, "head": 0.96}, true)
		"bulky":
			d.merge({"shoulder": 0.25, "chest_rx": 0.21, "chest_rz": 0.14, "waist_rx": 0.17, "waist_rz": 0.12,
				"hip_rx": 0.17, "hip_rz": 0.115, "arm_r": 0.072, "thigh_r": 0.098, "neck_r": 0.065}, true)
		"armored":
			d.merge({"shoulder": 0.24, "chest_rx": 0.2, "chest_rz": 0.135, "waist_rx": 0.155, "waist_rz": 0.11,
				"hip_rx": 0.165, "hip_rz": 0.11, "arm_r": 0.066, "thigh_r": 0.092, "neck_r": 0.06}, true)
		"gorilla":
			d.merge({"hip_y": 0.72, "thigh": 0.33, "shin": 0.33, "upper": 0.42, "fore": 0.4, "shoulder": 0.3,
				"chest_rx": 0.3, "chest_rz": 0.22, "waist_rx": 0.24, "waist_rz": 0.18, "hip_rx": 0.2, "hip_rz": 0.15,
				"arm_r": 0.1, "thigh_r": 0.11, "neck_r": 0.11, "head": 1.25, "spine_len": 0.5}, true)
	return d


## Old roster entries described costumes only through `extras`; this fills in
## the structured fields (build, hair style, emblem, gear) from them.
func _normalize() -> void:
	extras = look.get("extras", []).duplicate()
	build_type = str(look.get("build", ""))
	if build_type == "":
		build_type = "gorilla" if _has("gorilla") else ("armored" if _has("armor") else "male")
	if look.get("no_belt", false):
		extras.append("no_belt")
	if not look.has("hair_style"):
		look["hair_style"] = "bald" if _has("bald") else ("long" if _has("hair_long") else "short")


# --- Build --------------------------------------------------------------------

func build(look_def: Dictionary) -> void:
	look = look_def.duplicate(true)
	_normalize()
	for c in get_children():
		c.queue_free()
	meshes.clear()
	wings.clear()
	eye_points.clear()
	_builders.clear()
	cape = null
	cape_low = null
	muzzle = null
	D = _dims()

	hips = _pivot(self, Vector3(0, D["hip_y"], 0), "Hips")
	body = hips
	spine = _pivot(hips, Vector3(0, 0.02, 0), "Spine")
	head = _pivot(spine, Vector3(0, D["spine_len"] + 0.21, -0.01), "Head")
	var sh_y: float = D["spine_len"] - 0.01
	sh_l = _pivot(spine, Vector3(-D["shoulder"], sh_y, 0.0), "ShoulderL")
	sh_r = _pivot(spine, Vector3(D["shoulder"], sh_y, 0.0), "ShoulderR")
	el_l = _pivot(sh_l, Vector3(0, -D["upper"], 0), "ElbowL")
	el_r = _pivot(sh_r, Vector3(0, -D["upper"], 0), "ElbowR")
	hand_l = _pivot(el_l, Vector3(0, -D["fore"], 0), "HandL")
	hand_r = _pivot(el_r, Vector3(0, -D["fore"], 0), "HandR")
	th_l = _pivot(hips, Vector3(-0.088 * D["hip_rx"] / 0.15, -0.03, 0), "ThighL")
	th_r = _pivot(hips, Vector3(0.088 * D["hip_rx"] / 0.15, -0.03, 0), "ThighR")
	kn_l = _pivot(th_l, Vector3(0, -D["thigh"], 0), "KneeL")
	kn_r = _pivot(th_r, Vector3(0, -D["thigh"], 0), "KneeR")
	if build_type == "gorilla":
		spine.rotation.x = -0.45
		head.rotation.x = 0.4

	_build_pelvis()
	_build_torso()
	_build_head()
	for side in [-1.0, 1.0]:
		_build_arm(side)
		_build_leg(side)
	_build_costume_extras()
	_build_gear()
	_commit()

	scale = Vector3.ONE * float(look.get("scale", 1.0)) * (0.96 if build_type == "female" else 1.0)
	_flash_mat = mat(Color(1.0, 0.45, 0.4), 0.6)


func _commit() -> void:
	for key in _builders:
		var entry: Dictionary = _builders[key]
		var mi: MeshInstance3D = entry["mb"].make_instance(entry["pivot"], entry["kind"])
		if mi:
			# Hair, hoods and brows would self-shadow the face with a blocky
			# shadow-map edge; the head still receives the body's shadow.
			if entry["kind"] == "glow" or entry["pivot"] == head:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			meshes.append(mi)
	_builders.clear()


# --- Colour regions -----------------------------------------------------------

func _suit() -> Color:
	return _c("suit", "#444444")


func _accent() -> Color:
	return _c("accent", "#222222")


func _pants() -> Color:
	return _c("pants", look.get("legs", look.get("suit", "#444444")))


func _boots() -> Color:
	if _has("boots_red"):
		return Color("#b81820")
	return _c("boots", look.get("accent", "#222222"))


func _gloves() -> Color:
	return _c("gloves", look.get("accent", "#222222"))


func _belt() -> Color:
	return _c("belt", look.get("accent", "#222222"))


func _trim() -> Color:
	return _c("trim", str(look.get("suit", "#444444")))


func _skin() -> Color:
	# Slightly darkened: lofted skin reads brighter than flat-shaded boxes did.
	var c := _c("skin", "#c99a78")
	# Lofted skin catches more light than flat boxes did: deepen it a little,
	# more for pale tones (which otherwise wash out to white), and warm it.
	c = c.darkened(0.12 + 0.08 * c.v)
	c.s = minf(1.0, c.s * 1.18 + 0.02)
	return c


# --- Body parts ---------------------------------------------------------------

func _build_pelvis() -> void:
	var hx: float = D["hip_rx"]
	var hz: float = D["hip_rz"]
	var pants := _pants()
	var belt := _belt()
	var has_belt := not _has("no_belt")
	var col := func(t: float, theta: float, r: Dictionary) -> Color:
		if has_belt and r["y"] > 0.035:
			return belt
		return pants
	_mb(hips).loft([
		{"y": -0.14, "rx": hx * 0.55, "rz": hz * 0.6},
		{"y": -0.1, "rx": hx * 0.95, "rz": hz * 0.95},
		{"y": -0.03, "rx": hx, "rz": hz},
		{"y": 0.035, "rx": hx * 0.97, "rz": hz * 0.97},
		{"y": 0.036, "rx": hx * 0.99, "rz": hz * 0.99},
		{"y": 0.07, "rx": D["waist_rx"] * 1.01, "rz": D["waist_rz"] * 1.01},
	], Transform3D(), col, 18)
	if has_belt and not _has("no_buckle"):
		_mb(hips, "metal").box(Vector3(0, 0.052, -D["waist_rz"] - 0.006), Vector3(0.055, 0.032, 0.012), Transform3D(), _c("buckle", "#c9a227"))


func _build_torso() -> void:
	var wx: float = D["waist_rx"]
	var wz: float = D["waist_rz"]
	var cx: float = D["chest_rx"]
	var cz: float = D["chest_rz"]
	var L: float = D["spine_len"]
	var bust: float = D["bust"]
	var suit := _suit()
	var trim := _trim()
	var has_trim := look.has("trim")
	var accent := _accent()
	var straps := _has("emblem_x")
	var collar := _c("collar", look.get("suit", "#444444"))
	var skin := _skin()
	var neck_suit := _has("cowl") or _has("helmet") or _has("helmet_savitar") or _has("turtleneck") or build_type == "armored"
	var neck_top := L + 0.13
	var col := func(t: float, theta: float, r: Dictionary) -> Color:
		var y: float = r["y"]
		if y > L + 0.02:
			return suit if neck_suit else skin
		if y > L - 0.03:
			return collar
		if has_trim and absf(absf(theta) - PI * 0.5) < 0.11:
			return trim
		return suit
	var rings := [
		{"y": 0.0, "rx": wx, "rz": wz},
		{"y": L * 0.2, "rx": wx * 1.02, "rz": wz * 1.02},
		{"y": L * 0.42, "rx": lerpf(wx, cx, 0.6), "rz": lerpf(wz, cz, 0.6), "cz": -0.004},
		{"y": L * 0.6, "rx": cx * 0.98, "rz": cz + bust * 0.8, "cz": -0.008 - bust * 0.5},
		{"y": L * 0.72, "rx": cx, "rz": cz + bust, "cz": -0.008 - bust * 0.6},
		{"y": L * 0.86, "rx": cx * 1.03, "rz": cz * 0.92, "cz": -0.003},
		{"y": L * 0.95, "rx": cx * 0.88, "rz": cz * 0.78},
		{"y": L + 0.0, "rx": cx * 0.6, "rz": cz * 0.66, "cz": 0.004},
		{"y": L + 0.03, "rx": D["neck_r"] * 1.45, "rz": D["neck_r"] * 1.3, "cz": 0.008},
		{"y": L + 0.05, "rx": D["neck_r"] * 1.1, "rz": D["neck_r"] * 1.05, "cz": 0.006},
		{"y": L + 0.08, "rx": D["neck_r"], "rz": D["neck_r"], "cz": 0.004},
		{"y": neck_top, "rx": D["neck_r"] * 0.95, "rz": D["neck_r"] * 0.95, "cz": -0.004},
	]
	var kind := "metal" if build_type == "armored" else ("gloss" if _has("leather") else "skin")
	_mb(spine, kind).loft(rings, Transform3D(), col, 24, true, true, 1.0, [], 3)
	# Shoulder caps (deltoids) live on the torso so they don't pinch.
	for side in [-1.0, 1.0]:
		_mb(spine, kind).ellipsoid(Vector3(side * (D["shoulder"] - 0.012), L - 0.04, 0.0),
			Vector3(D["arm_r"] * 1.12, D["arm_r"] * 1.02, D["arm_r"] * 1.12), Transform3D(), suit, 14, 8)
	if straps:
		# Martian Manhunter's X harness: two straps crossing the chest.
		for side in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for i in 7:
				var t := float(i) / 6.0
				var y := lerpf(L + 0.0, L * 0.12, t)
				var x := lerpf(side * cx * 0.72, -side * wx * 0.85, t)
				var ring_rz := lerpf(cz * 0.8, wz, t) + (cz * 0.25) * sin(t * PI)
				pts.append(Vector3(x, y, -ring_rz - 0.004))
			_mb(spine, "gloss").path(pts, 0.018, Transform3D(), accent, 6)
	# Emblem
	var emblem := _emblem_spec()
	if not emblem.is_empty():
		var size: float = emblem.get("size", 0.15) * cx / 0.17
		var dec := Emblems.decal(emblem["kind"], Color(str(emblem["c1"])), Color(str(emblem["c2"])), size)
		if dec:
			spine.add_child(dec)
			dec.position = Vector3(0, L * 0.72 + float(emblem.get("dy", 0.0)), -(cz + bust) - 0.012 - bust * 0.6)
			dec.rotation.x = -0.12
			meshes.append(dec)


func _emblem_spec() -> Dictionary:
	if look.has("emblem"):
		return look["emblem"]
	var accent := str(look.get("accent", "#222222"))
	var suit := str(look.get("suit", "#444444"))
	if _has("emblem_s"):
		return {"kind": "s_shield", "c1": "#c8102e", "c2": "#f2c21b", "size": 0.17}
	if _has("emblem_bolt"):
		return {"kind": "bolt", "c1": "#f2efe6", "c2": "#e6b422", "size": 0.15}
	if _has("emblem_bat"):
		return {"kind": "bat", "c1": accent, "c2": accent, "size": 0.22}
	if _has("emblem_star"):
		return {"kind": "star", "c1": "#f5f5f5", "c2": "#f5f5f5", "size": 0.13}
	if _has("emblem"):
		return {"kind": "circle", "c1": accent, "c2": Color(suit).lightened(0.3).to_html(false), "size": 0.12}
	return {}


func _build_head() -> void:
	var k: float = D["head"]
	var skin := _skin()
	var suit := _suit()
	var cowl := _has("cowl")
	var mask := _has("mask_dark") or _has("mask_star") or _has("mask_reign")
	var mask_col := Color("#e0c068") if _has("mask_star") else Color("#101012")
	var reign := _has("mask_reign")
	var deathstroke := _has("mask_deathstroke")
	var accent := _accent()
	var hockey := _has("mask_hockey")
	var bandana := _has("mask_bandana")
	var bandana_col := accent if accent.r > 0.3 else Color("#2a2a2a")
	var gorilla := build_type == "gorilla"
	var facial := str(look.get("facial", ""))
	var beard := facial == "beard"
	var stubble := facial == "stubble"
	var goatee := facial == "goatee"
	var hair := _c("hair", "#3b2a1e")
	var skull := _has("mask_skull")
	var bandage := _has("mask_bandage")
	var col := func(t: float, theta: float, r: Dictionary) -> Color:
		var y: float = r["y"] / k
		var front := absf(theta) < 1.05
		if skull:
			if front and y > 0.015 and y < 0.05 and absf(absf(theta) - 0.42) < 0.24:
				return Color("#4a4a4a")
			return Color("#141414")
		if bandage:
			if front and y > 0.015 and y < 0.05 and absf(theta) < 0.8:
				return Color("#c8a890")
			return Color("#e8e4dc") if int(floor(y * 70.0 + theta * 2.0)) % 2 == 0 else Color("#d4cec2")
		if deathstroke:
			return accent if theta > 0.0 else Color("#141414")
		if cowl:
			if front and y < -0.015:
				return skin
			return suit
		if hockey and front and y < 0.09:
			return Color("#ebebe6")
		if bandana and front and y < -0.02:
			return bandana_col
		if beard and absf(theta) < 1.4 and y < -0.035:
			return hair
		if goatee and absf(theta) < 0.35 and y < -0.06:
			return hair
		if stubble and absf(theta) < 1.3 and y < -0.035:
			return skin.lerp(hair, 0.35)
		if reign and front and y > -0.02 and y < 0.075:
			return mask_col
		if mask and front and y > 0.012 and y < 0.058 and absf(theta) < 0.95:
			return mask_col
		return skin
	var R := _head_profile(build_type == "female")
	if gorilla:
		R = [[-0.13, 0.07, 0.07, 0.0], [-0.1, 0.085, 0.1, -0.03], [-0.06, 0.1, 0.12, -0.04], [-0.02, 0.105, 0.11, -0.02],
			[0.02, 0.1, 0.1, 0.0], [0.04, 0.11, 0.1, -0.01], [0.07, 0.09, 0.09, 0.01], [0.11, 0.06, 0.07, 0.02], [0.13, 0.001, 0.001, 0.02]]
	var rings := []
	for r in R:
		rings.append({"y": r[0] * k, "rx": r[1] * k, "rz": r[2] * k, "cz": r[3] * k})
	_mb(head, "gloss" if cowl or deathstroke else "skin").loft(rings, Transform3D(), col, 24)
	var hb := _mb(head)
	# Ears
	if not cowl and not gorilla:
		for side in [-1.0, 1.0]:
			hb.ellipsoid(Vector3(side * 0.079 * k, 0.012 * k, 0.012 * k), Vector3(0.012, 0.026, 0.018) * k, Transform3D(), skin.darkened(0.06), 8, 5)
	# Face
	var face_z := -0.093 * k
	var covered_eyes := _has("goggles") or _has("helmet") or hockey
	if not deathstroke and not gorilla:
		# Nose
		var nose_col := suit if cowl else skin
		hb.tube(Vector3(0, 0.03 * k, face_z + 0.006 * k), Vector3(0, -0.012 * k, face_z - 0.014 * k), 0.006 * k, 0.009 * k, Transform3D(), nose_col, 8)
		hb.ellipsoid(Vector3(0, -0.014 * k, face_z - 0.012 * k), Vector3(0.012, 0.009, 0.009) * k, Transform3D(), nose_col, 8, 5)
		# Lips
		var lip := skin.darkened(0.22).lerp(Color("#a03040"), 0.35 if build_type == "female" else 0.0)
		if not hockey and not bandana:
			hb.ellipsoid(Vector3(0, -0.047 * k, face_z + 0.012 * k), Vector3(0.02, 0.005, 0.006) * k, Transform3D(), lip, 8, 4)
		# Brows
		if not cowl and not mask and not covered_eyes:
			for side in [-1.0, 1.0]:
				hb.box(Vector3(side * 0.03 * k, 0.05 * k, face_z + 0.004 * k), Vector3(0.026, 0.0045, 0.006) * k, Transform3D(), hair.darkened(0.25), Basis(Vector3.BACK, side * -0.1))
	if not covered_eyes:
		var glow_eyes := _has("glow_eyes") or _has("glow_eyes_red")
		var eye_col := Color("#ff2a2a") if _has("glow_eyes_red") else _c("eye_glow", look.get("trail", look.get("accent", "#bfe8ff")))
		for side in [-1.0, 1.0]:
			var ep := Vector3(side * 0.03 * k, 0.03 * k, face_z + 0.017 * k)
			if gorilla:
				ep = Vector3(side * 0.04 * k, 0.03 * k, -0.11 * k)
			if glow_eyes:
				_mb(head, "glow").ellipsoid(ep + Vector3(0, 0, -0.004), Vector3(0.014, 0.008, 0.008) * k, Transform3D(), eye_col, 8, 4)
			else:
				hb.ellipsoid(ep, Vector3(0.011, 0.0068, 0.008) * k, Transform3D(), Color("#e8e4dc"), 10, 6)
				hb.ellipsoid(ep + Vector3(0, 0, -0.0065 * k), Vector3(0.0052, 0.0052, 0.003) * k, Transform3D(), _c("eye_color", "#3a2a1a"), 8, 4)
				# Upper lid / brow shadow
				hb.ellipsoid(ep + Vector3(0, 0.006 * k, -0.002 * k), Vector3(0.0125, 0.003, 0.0075) * k, Transform3D(), skin.darkened(0.12), 8, 4)
			var pt := _pivot(head, ep + Vector3(0, 0, -0.01), "Eye")
			eye_points.append(pt)
	else:
		for side in [-1.0, 1.0]:
			eye_points.append(_pivot(head, Vector3(side * 0.031 * k, 0.034 * k, face_z), "Eye"))
	_build_hair(k)
	_build_headgear(k)


## Rings for a head: an ellipsoidal skull above the cheekbones, tapering to a
## narrower jaw and a chin that sits forward. [y, rx, rz, cz] per ring.
static func _head_profile(female: bool) -> Array:
	var out := []
	var steps := 18
	var jaw_w := 0.05 if female else 0.056
	for i in steps + 1:
		var v := float(i) / steps
		var y := lerpf(-0.118, 0.153, v)
		var rx: float
		var rz: float
		var cz := 0.004
		if y >= -0.015:
			var e := clampf((y - 0.028) / 0.125, -1.0, 1.0)
			var f := sqrt(maxf(0.0, 1.0 - e * e))
			rx = 0.081 * f
			rz = 0.097 * f
			cz = 0.004 + 0.008 * maxf(0.0, e)
		else:
			# 0 at the cheekbones, 1 at the bottom of the chin
			var u := clampf((-0.015 - y) / 0.103, 0.0, 1.0)
			var top_f := sqrt(maxf(0.0, 1.0 - pow((-0.015 - 0.028) / 0.125, 2.0)))
			rx = lerpf(0.081 * top_f, jaw_w * 0.62, u * u) * (1.0 - 0.25 * pow(u, 6.0))
			rz = lerpf(0.097 * top_f, 0.062, u) * (1.0 - 0.3 * pow(u, 5.0))
			cz = lerpf(0.0, -0.016, u)
		out.append([y, maxf(rx, 0.0015), maxf(rz, 0.0015), cz])
	return out


func _build_hair(k: float) -> void:
	var style := str(look.get("hair_style", "short"))
	if _has("cowl") or _has("helmet") or _has("helmet_savitar") or _has("helmet_fate") or _has("mask_deathstroke") or _has("mask_skull") or _has("mask_bandage") or build_type == "gorilla" or style == "bald":
		return
	var hair := _c("hair", "#3b2a1e")
	var hb := _mb(head, "gloss")
	# Strands: stripes of lighter and darker hair, darker at the roots.
	var strands := func(t: float, theta: float, _r: Dictionary) -> Color:
		var v := sin(theta * 23.0 + t * 3.0) * 0.5 + sin(theta * 41.0) * 0.3
		var c := hair.lightened(0.1 * maxf(0.0, v)).darkened(0.12 * maxf(0.0, -v))
		return c.darkened(0.1 * (1.0 - t))
	var thick := 0.012 if style == "buzz" else 0.02
	if style == "curly" or style == "wild":
		thick = 0.032
	# Cap: covers the top and back of the skull, with a hairline at the front.
	var rings := []
	var R := [[0.055, 0.084, 0.1], [0.085, 0.082, 0.098], [0.11, 0.073, 0.09], [0.132, 0.055, 0.07], [0.148, 0.028, 0.036], [0.156, 0.002, 0.002]]
	if style == "slick":
		thick = 0.012
	for r in R:
		rings.append({"y": r[0] * k, "rx": r[1] * k + thick * 0.5, "rz": r[2] * k + thick * 0.5, "cz": 0.014 * k})
	hb.loft(rings, Transform3D(), strands, 24)
	# Sides and back (arc leaves the face open)
	var back_len := 0.06
	match style:
		"long":
			back_len = 0.3
		"bob":
			back_len = 0.13
		"ponytail":
			back_len = 0.07
		"wild", "curly":
			back_len = 0.12
	var side_rings := [
		{"y": (0.07 - back_len) * k, "rx": 0.085 * k + thick, "rz": 0.09 * k + thick, "cz": 0.025 * k},
		{"y": 0.0, "rx": 0.088 * k + thick * 0.5, "rz": 0.1 * k + thick * 0.5, "cz": 0.014 * k},
		{"y": 0.06 * k, "rx": 0.086 * k + thick * 0.5, "rz": 0.1 * k + thick * 0.5, "cz": 0.014 * k},
	]
	if style == "long":
		side_rings.push_front({"y": (0.07 - back_len - 0.03) * k, "rx": 0.07 * k, "rz": 0.05 * k, "cz": 0.06 * k})
	hb.loft(side_rings, Transform3D(), strands, 24, false, false, 0.62)
	if style == "ponytail":
		hb.tube(Vector3(0, 0.07 * k, 0.1 * k), Vector3(0, -0.18 * k, 0.13 * k), 0.025 * k, 0.012 * k, Transform3D(), hair, 8)


func _build_headgear(k: float) -> void:
	var suit := _suit()
	var accent := _accent()
	var hb := _mb(head)
	var gloss := _mb(head, "gloss")
	if _has("glasses"):
		# Clark's and Kara's disguise: thin dark frames.
		var frame := Color("#1a1a1a")
		for side in [-1.0, 1.0]:
			var c := Vector3(side * 0.031 * k, 0.03 * k, -0.105 * k)
			gloss.box(c + Vector3(0, 0.011 * k, 0), Vector3(0.03, 0.004, 0.004) * k, Transform3D(), frame)
			gloss.box(c - Vector3(0, 0.011 * k, 0), Vector3(0.03, 0.004, 0.004) * k, Transform3D(), frame)
			gloss.box(c + Vector3(side * 0.015 * k, 0, 0), Vector3(0.004, 0.024, 0.004) * k, Transform3D(), frame)
			gloss.box(c - Vector3(side * 0.015 * k, 0, 0), Vector3(0.004, 0.024, 0.004) * k, Transform3D(), frame)
			gloss.box(Vector3(side * 0.08 * k, 0.03 * k, -0.05 * k), Vector3(0.004, 0.004, 0.11) * k, Transform3D(), frame)
		gloss.box(Vector3(0, 0.03 * k, -0.106 * k), Vector3(0.012, 0.004, 0.004) * k, Transform3D(), frame)
	if _has("bolt_wings"):
		for side in [-1.0, 1.0]:
			var wing := PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0.012), Vector2(0.1, 0.05), Vector2(0.045, 0.028), Vector2(0.075, 0.06), Vector2(0.01, 0.03)])
			var xf := Transform3D(Basis(Vector3.UP, side * PI * 0.5) * Basis.from_scale(Vector3(side, 1, 1)), Vector3(side * 0.083 * k, 0.015 * k, 0.01 * k))
			_mb(head, "metal").prism(wing, 0.006, xf, Color("#e6b422"))
	if _has("cat_ears"):
		for side in [-1.0, 1.0]:
			hb.tube(Vector3(side * 0.055 * k, 0.1 * k, 0.0), Vector3(side * 0.07 * k, 0.155 * k, 0.005), 0.022 * k, 0.0, Transform3D(), suit, 4)
	if _has("glasses_dark"):
		for side in [-1.0, 1.0]:
			gloss.box(Vector3(side * 0.031 * k, 0.03 * k, -0.106 * k), Vector3(0.032, 0.022, 0.005) * k, Transform3D(), Color("#0a0a0c"))
		gloss.box(Vector3(0, 0.032 * k, -0.107 * k), Vector3(0.014, 0.004, 0.004) * k, Transform3D(), Color("#0a0a0c"))
	if _has("helmet_fate"):
		# The Helmet of Fate: polished gold, with a T-shaped eye slit.
		var gold := Color("#d8a21e")
		_mb(head, "metal").loft([
			{"y": -0.15 * k, "rx": 0.1 * k, "rz": 0.11 * k, "cz": 0.0},
			{"y": -0.08 * k, "rx": 0.105 * k, "rz": 0.118 * k},
			{"y": 0.0, "rx": 0.107 * k, "rz": 0.12 * k},
			{"y": 0.08 * k, "rx": 0.104 * k, "rz": 0.116 * k},
			{"y": 0.15 * k, "rx": 0.08 * k, "rz": 0.09 * k, "cz": 0.005},
			{"y": 0.2 * k, "rx": 0.03 * k, "rz": 0.04 * k, "cz": 0.01},
			{"y": 0.21 * k, "rx": 0.002, "rz": 0.002, "cz": 0.01},
		], Transform3D(), gold, 22)
		hb.box(Vector3(0, 0.035 * k, -0.121 * k), Vector3(0.13, 0.024, 0.008) * k, Transform3D(), Color("#0a0a0c"))
		hb.box(Vector3(0, -0.02 * k, -0.12 * k), Vector3(0.026, 0.09, 0.008) * k, Transform3D(), Color("#0a0a0c"))
		for side in [-1.0, 1.0]:
			_mb(head, "metal").box(Vector3(side * 0.112 * k, -0.02 * k, 0.0), Vector3(0.01, 0.1, 0.06) * k, Transform3D(), gold.darkened(0.2))
	if _has("bat_ears"):
		for side in [-1.0, 1.0]:
			hb.tube(Vector3(side * 0.05 * k, 0.11 * k, 0.01), Vector3(side * 0.062 * k, 0.2 * k, 0.012), 0.016 * k, 0.0, Transform3D(), suit, 6)
	if _has("hood"):
		var hood_col := suit.darkened(0.12)
		var rings := [
			{"y": -0.14 * k, "rx": 0.16 * k, "rz": 0.12 * k, "cz": 0.04 * k},
			{"y": -0.06 * k, "rx": 0.115 * k, "rz": 0.12 * k, "cz": 0.02 * k},
			{"y": 0.03 * k, "rx": 0.1 * k, "rz": 0.118 * k, "cz": 0.005 * k},
			{"y": 0.11 * k, "rx": 0.088 * k, "rz": 0.106 * k, "cz": 0.0},
			{"y": 0.165 * k, "rx": 0.05 * k, "rz": 0.075 * k, "cz": 0.0},
			{"y": 0.188 * k, "rx": 0.006, "rz": 0.02, "cz": -0.02 * k},
		]
		_mb(head).loft(rings, Transform3D(), hood_col, 20, false, true, 0.8)
	if _has("helmet") or _has("helmet_hawk"):
		var hcol := accent.lightened(0.12) if _has("helmet") else Color("#b08a3a")
		var rings := [
			{"y": -0.09 * k, "rx": 0.09 * k, "rz": 0.1 * k, "cz": 0.01 * k},
			{"y": -0.02 * k, "rx": 0.093 * k, "rz": 0.108 * k},
			{"y": 0.06 * k, "rx": 0.092 * k, "rz": 0.107 * k},
			{"y": 0.12 * k, "rx": 0.078 * k, "rz": 0.092 * k, "cz": 0.006},
			{"y": 0.16 * k, "rx": 0.042 * k, "rz": 0.05 * k, "cz": 0.008},
			{"y": 0.172 * k, "rx": 0.002, "rz": 0.002, "cz": 0.008},
		]
		_mb(head, "metal").loft(rings, Transform3D(), hcol, 20)
		if _has("helmet"):
			_mb(head, "gloss").loft([{"y": 0.015 * k, "rx": 0.088 * k, "rz": 0.106 * k}, {"y": 0.055 * k, "rx": 0.088 * k, "rz": 0.106 * k}],
				Transform3D(Basis(), Vector3(0, 0, -0.004)), Color("#0e1620"), 18, false, false, 0.5)
		else:
			hb.tube(Vector3(0, 0.07 * k, -0.1 * k), Vector3(0, 0.02 * k, -0.17 * k), 0.022 * k, 0.0, Transform3D(), hcol, 6)
	if _has("winged_helmet"):
		_mb(head, "metal").loft([{"y": 0.085 * k, "rx": 0.13 * k, "rz": 0.14 * k}, {"y": 0.1 * k, "rx": 0.12 * k, "rz": 0.13 * k},
			{"y": 0.15 * k, "rx": 0.075 * k, "rz": 0.085 * k}, {"y": 0.175 * k, "rx": 0.002, "rz": 0.002}], Transform3D(), Color("#b8b8b8"), 18)
		for side in [-1.0, 1.0]:
			var wing := PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0.01), Vector2(0.11, 0.06), Vector2(0.05, 0.035), Vector2(0.01, 0.04)])
			_mb(head, "metal").prism(wing, 0.006, Transform3D(Basis(Vector3.UP, side * PI * 0.5) * Basis.from_scale(Vector3(side, 1, 1)), Vector3(side * 0.12 * k, 0.11 * k, 0.01)), Color("#c9a227"))
	if _has("helmet_savitar"):
		_mb(head, "metal").loft([{"y": -0.14 * k, "rx": 0.11 * k, "rz": 0.12 * k}, {"y": 0.0, "rx": 0.1 * k, "rz": 0.12 * k},
			{"y": 0.12 * k, "rx": 0.085 * k, "rz": 0.11 * k}, {"y": 0.24 * k, "rx": 0.02 * k, "rz": 0.05 * k, "cz": 0.04 * k}], Transform3D(), suit.darkened(0.1), 18)
	if _has("goggles"):
		gloss.loft([{"y": 0.018 * k, "rx": 0.086 * k, "rz": 0.102 * k}, {"y": 0.05 * k, "rx": 0.086 * k, "rz": 0.102 * k}],
			Transform3D(), Color("#1e1e22"), 18, false, false, 1.0)
		for side in [-1.0, 1.0]:
			_mb(head, "glow" if look.has("goggle_glow") else "gloss").ellipsoid(Vector3(side * 0.033 * k, 0.034 * k, -0.103 * k), Vector3(0.019, 0.014, 0.008) * k,
				Transform3D(), _c("goggle_glow", "#3a4a58"), 10, 5)
	if _has("cap"):
		hb.loft([{"y": 0.06 * k, "rx": 0.088 * k, "rz": 0.103 * k, "cz": 0.01}, {"y": 0.12 * k, "rx": 0.082 * k, "rz": 0.097 * k, "cz": 0.01},
			{"y": 0.15 * k, "rx": 0.002, "rz": 0.002, "cz": 0.01}], Transform3D(), suit, 16)
		hb.box(Vector3(0, 0.068 * k, -0.12 * k), Vector3(0.16, 0.01, 0.07) * k, Transform3D(), Color("#0e0e0e"))
	if _has("mask_t"):
		hb.box(Vector3(0, 0.04 * k, -0.096 * k), Vector3(0.14, 0.026, 0.012) * k, Transform3D(), Color("#101010"))
		hb.box(Vector3(0, -0.005 * k, -0.1 * k), Vector3(0.03, 0.07, 0.012) * k, Transform3D(), Color("#101010"))
	if _has("flame_head"):
		_mb(head, "glow").loft([{"y": 0.05 * k, "rx": 0.1 * k, "rz": 0.11 * k}, {"y": 0.16 * k, "rx": 0.09 * k, "rz": 0.1 * k},
			{"y": 0.26 * k, "rx": 0.05 * k, "rz": 0.06 * k}, {"y": 0.34 * k, "rx": 0.002, "rz": 0.002}], Transform3D(),
			func(t: float, _th: float, _r: Dictionary) -> Color: return Color("#ffe060").lerp(Color("#ff5a10"), t), 14)
	if _has("glow_head"):
		_mb(head, "glow").ellipsoid(Vector3(0, 0.1 * k, 0.01), Vector3(0.07, 0.05, 0.08) * k, Transform3D(), Color("#b49aff"), 12, 6)


func _build_arm(side: float) -> void:
	var sh := sh_l if side < 0 else sh_r
	var el := el_l if side < 0 else el_r
	var hand := hand_l if side < 0 else hand_r
	var r: float = D["arm_r"]
	var up: float = D["upper"]
	var fo: float = D["fore"]
	var suit := _suit()
	var gloves := _gloves()
	var trim := _trim()
	var has_trim := look.has("trim")
	var sleeve := suit
	var skin := _skin()
	# Sleeve length: 2 = full sleeves, 1 = to the elbow, 0.45 = a T-shirt, 0 = bare arms.
	var sleeve_len := float(look.get("sleeve", 0.0 if _has("sleeveless") else 2.0))
	var upper_cut := 1.0 - minf(sleeve_len, 1.0)
	var fore_cut := 1.0 - clampf(sleeve_len - 1.0, 0.0, 1.0)
	var kind := "metal" if build_type == "armored" else ("gloss" if _has("leather") else "skin")
	var arm_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		# t runs elbow (0) to shoulder (1)
		if t < upper_cut:
			return skin
		if has_trim and absf(absf(theta) - PI * 0.5) < 0.16:
			return trim
		return sleeve
	_mb(sh, kind).loft([
		{"y": -up - 0.01, "rx": r * 0.78, "rz": r * 0.8},
		{"y": -up * 0.55, "rx": r * 0.98, "rz": r, "cz": -0.004},
		{"y": -up * 0.25, "rx": r * 1.02, "rz": r * 1.02},
		{"y": 0.01, "rx": r * 0.95, "rz": r * 0.95},
	], Transform3D(), arm_col, 12, true, true, 1.0, [upper_cut] if upper_cut > 0.01 and upper_cut < 0.99 else [], 2)
	var glove_from := float(look.get("glove_length", 0.55))
	var fore_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		# t runs wrist (0) to elbow (1)
		if t < glove_from:
			return gloves
		if t < fore_cut:
			return skin
		if has_trim and absf(absf(theta) - PI * 0.5) < 0.16:
			return trim
		return sleeve
	_mb(el, kind).loft([
		{"y": -fo - 0.005, "rx": r * 0.6, "rz": r * 0.52},
		{"y": -fo * 0.5, "rx": r * 0.77, "rz": r * 0.71},
		{"y": -fo * 0.2, "rx": r * 0.86, "rz": r * 0.84, "cz": -0.003},
		{"y": 0.015, "rx": r * 0.8, "rz": r * 0.8},
	], Transform3D(), fore_col, 12, true, true, 1.0, ([glove_from] if glove_from > 0.01 and glove_from < 0.99 else []) + ([fore_cut] if fore_cut > 0.01 and fore_cut < 0.99 else []), 2)
	_mb(el, kind).ellipsoid(Vector3(0, 0.0, 0.0), Vector3(r * 0.84, r * 0.84, r * 0.84), Transform3D(), sleeve if sleeve_len > 1.05 else skin, 10, 6)
	# Fist with a thumb
	var hk := r / 0.056
	var hand_col := gloves if glove_from > 0.01 else _skin()
	if build_type == "gorilla":
		hand_col = _skin().darkened(0.2)
	var hb := _mb(hand, kind if glove_from > 0.01 else "skin")
	if build_type == "gorilla":
		hb.ellipsoid(Vector3(0, -0.045 * hk, -0.004), Vector3(0.036, 0.05, 0.03) * hk, Transform3D(), hand_col, 10, 6)
	else:
		# A hand: palm, four curled fingers with knuckles, and a thumb.
		hb.ellipsoid(Vector3(0, -0.038 * hk, 0.0), Vector3(0.033, 0.042, 0.017) * hk, Transform3D(), hand_col, 10, 6)
		for f in 4:
			var fx := (-0.021 + f * 0.014) * hk
			var flen := (0.022 if f in [1, 2] else 0.019) * hk
			var base_pt := Vector3(fx, -0.072 * hk, -0.002 * hk)
			var mid := base_pt + Vector3(0, -flen, -0.006 * hk)
			var tip := mid + Vector3(0, -0.006 * hk, -0.016 * hk)
			hb.tube(base_pt, mid, 0.0072 * hk, 0.0066 * hk, Transform3D(), hand_col, 6)
			hb.tube(mid, tip, 0.0066 * hk, 0.0058 * hk, Transform3D(), hand_col, 6)
		var tb := Vector3(side * -0.026 * hk, -0.03 * hk, -0.01 * hk)
		hb.tube(tb, tb + Vector3(side * -0.006, -0.026, -0.014) * hk, 0.0085 * hk, 0.007 * hk, Transform3D(), hand_col, 6)
	if _has("armor") and build_type != "gorilla":
		_mb(el, "metal").loft([{"y": -fo * 0.9, "rx": r * 0.95, "rz": r * 0.95}, {"y": -fo * 0.35, "rx": r * 1.05, "rz": r * 1.05}],
			Transform3D(), _accent(), 12)


func _build_leg(side: float) -> void:
	var th := th_l if side < 0 else th_r
	var kn := kn_l if side < 0 else kn_r
	var r: float = D["thigh_r"]
	var tl: float = D["thigh"]
	var sl: float = D["shin"]
	var pants := _pants()
	var boots := _boots()
	var trim := _trim()
	var has_trim := look.has("trim")
	var boot_top := float(look.get("boot_height", 0.55))
	var kind := "metal" if build_type == "armored" else ("gloss" if _has("leather") else "skin")
	var thigh_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		if has_trim and absf(absf(theta) - PI * 0.5) < 0.12:
			return trim
		return pants
	_mb(th, kind).loft([
		{"y": -tl - 0.01, "rx": r * 0.64, "rz": r * 0.66},
		{"y": -tl * 0.8, "rx": r * 0.72, "rz": r * 0.75},
		{"y": -tl * 0.4, "rx": r * 0.9, "rz": r * 0.92, "cz": -0.006},
		{"y": -tl * 0.1, "rx": r, "rz": r},
		{"y": 0.03, "rx": r * 0.95, "rz": r * 0.95},
	], Transform3D(), thigh_col, 14)
	var shin_col := func(t: float, theta: float, _r: Dictionary) -> Color:
		if t < boot_top:
			return boots
		if has_trim and absf(absf(theta) - PI * 0.5) < 0.12:
			return trim
		return pants
	_mb(kn, kind).loft([
		{"y": -sl, "rx": r * 0.44, "rz": r * 0.46},
		{"y": -sl * 0.82, "rx": r * 0.5, "rz": r * 0.53},
		{"y": -sl * 0.55, "rx": r * 0.66, "rz": r * 0.69, "cz": 0.008},
		{"y": -sl * 0.3, "rx": r * 0.72, "rz": r * 0.76, "cz": 0.01},
		{"y": -sl * 0.05, "rx": r * 0.68, "rz": r * 0.7},
		{"y": 0.02, "rx": r * 0.66, "rz": r * 0.66},
	], Transform3D(), shin_col, 14, true, true, 1.0, [boot_top] if boot_top > 0.01 and boot_top < 0.99 else [], 2)
	_mb(kn, kind).ellipsoid(Vector3(0, 0.0, 0.0), Vector3(r * 0.68, r * 0.7, r * 0.7), Transform3D(), pants if boot_top < 0.95 else boots, 10, 6)
	# Foot: a lofted shoe running forward (-Z)
	var fk := r / 0.083
	var foot_rings := []
	for f in [[0.06, 0.035, 0.028, 0.0], [0.02, 0.042, 0.04, 0.0], [-0.05, 0.044, 0.034, -0.008], [-0.12, 0.038, 0.022, -0.016], [-0.15, 0.02, 0.012, -0.02]]:
		foot_rings.append({"y": f[0] * fk, "rx": f[1] * fk, "rz": f[2] * fk, "cz": f[3] * fk})
	_mb(kn, "gloss").loft(foot_rings, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -sl - 0.028 * fk, -0.01)),
		boots if build_type != "gorilla" else _skin().darkened(0.2), 12)
	if _has("armor") and build_type != "gorilla":
		_mb(kn, "metal").ellipsoid(Vector3(0, -0.01, -r * 0.55), Vector3(r * 0.55, r * 0.6, r * 0.35), Transform3D(), _accent(), 10, 6)


func _build_costume_extras() -> void:
	var suit := _suit()
	var accent := _accent()
	var L: float = D["spine_len"]
	var cx: float = D["chest_rx"]
	var cz: float = D["chest_rz"]
	# Jackets and coats: an open-fronted shell over the torso plus tails.
	if _has("coat") or _has("coat_short") or _has("jacket"):
		var coat := _c("coat_color", suit.darkened(0.2).to_html(false))
		var open := 0.82
		_mb(spine, "gloss").loft([
			{"y": -0.02, "rx": D["waist_rx"] + 0.016, "rz": D["waist_rz"] + 0.016},
			{"y": L * 0.6, "rx": cx + 0.016, "rz": cz + D["bust"] + 0.016, "cz": -0.006},
			{"y": L * 0.86, "rx": cx * 1.03 + 0.016, "rz": cz * 0.92 + 0.016},
			{"y": L + 0.02, "rx": cx * 0.62, "rz": cz * 0.7, "cz": 0.006},
			{"y": L + 0.07, "rx": D["neck_r"] * 1.4, "rz": D["neck_r"] * 1.4, "cz": 0.012},
		], Transform3D(), coat, 20, false, false, open)
		var tail := 0.55 if _has("coat") else 0.14
		_mb(hips, "gloss").loft([
			{"y": -tail, "rx": D["hip_rx"] * (1.45 if _has("coat") else 1.12), "rz": D["hip_rz"] * (1.5 if _has("coat") else 1.15), "cz": 0.01},
			{"y": -0.06, "rx": D["hip_rx"] + 0.018, "rz": D["hip_rz"] + 0.018},
			{"y": 0.08, "rx": D["waist_rx"] + 0.018, "rz": D["waist_rz"] + 0.018},
		], Transform3D(), coat, 20, false, false, 0.78 if _has("coat") else open)
		for side in [-1.0, 1.0]:
			_mb(sh_l if side < 0 else sh_r, "gloss").loft([{"y": -D["upper"] - 0.005, "rx": D["arm_r"] + 0.012, "rz": D["arm_r"] + 0.012},
				{"y": 0.015, "rx": D["arm_r"] * 1.05 + 0.012, "rz": D["arm_r"] * 1.05 + 0.012}], Transform3D(), coat, 12, false, false)
			_mb(el_l if side < 0 else el_r, "gloss").loft([{"y": -D["fore"] * 0.55, "rx": D["arm_r"] * 0.8 + 0.012, "rz": D["arm_r"] * 0.75 + 0.012},
				{"y": 0.015, "rx": D["arm_r"] * 0.82 + 0.012, "rz": D["arm_r"] * 0.82 + 0.012}], Transform3D(), coat, 12, false, false)
	if _has("skirt"):
		var stripes := _c("skirt_color", "#c8102e")
		var col := func(_t: float, theta: float, _r: Dictionary) -> Color:
			return stripes if int(floor((theta + PI) / (TAU / 16.0))) % 2 == 0 else Color("#f2f2f2")
		_mb(hips).loft([{"y": -0.2, "rx": D["hip_rx"] * 1.55, "rz": D["hip_rz"] * 1.6}, {"y": 0.0, "rx": D["hip_rx"] + 0.012, "rz": D["hip_rz"] + 0.012},
			{"y": 0.06, "rx": D["waist_rx"] + 0.012, "rz": D["waist_rz"] + 0.012}], Transform3D(), col, 16, false, false)
	if _has("armor") and build_type != "gorilla":
		var plate := accent
		for side in [-1.0, 1.0]:
			_mb(spine, "metal").ellipsoid(Vector3(side * (D["shoulder"] + 0.01), L - 0.02, 0.0), Vector3(0.085, 0.06, 0.095) * D["shoulder"] / 0.22,
				Transform3D(), plate, 12, 7)
		_mb(spine, "metal").loft([
			{"y": L * 0.45, "rx": cx * 0.9, "rz": cz * 0.8, "cz": -0.012},
			{"y": L * 0.7, "rx": cx * 1.0, "rz": cz * 0.95 + 0.01, "cz": -0.012},
			{"y": L * 0.92, "rx": cx * 0.9, "rz": cz * 0.8, "cz": -0.008},
		], Transform3D(), plate.darkened(0.15), 18, false, false, 0.5)
	if _has("quiver") or look.get("back", "") == "quiver":
		var q := Transform3D(Basis(Vector3.BACK, -0.35), Vector3(0.07, L * 0.62, cz + 0.06))
		Gear.quiver(_mb(spine, "gloss"), q, Color("#3a2a1a"))
	if look.get("back", "") == "katana":
		var k := Transform3D(Basis(Vector3.BACK, 0.6) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.02, L * 0.6, cz + 0.05))
		Gear.blade(_mb(spine, "metal"), k, 0.9, 0.026, Gear.STEEL, Gear.DARK, Color("#c07a20"), false)
	if look.get("back", "") == "tank":
		var t := Transform3D(Basis(), Vector3(0, L * 0.55, cz + 0.08))
		_mb(spine, "metal").loft([{"y": -0.2, "rx": 0.07, "rz": 0.07}, {"y": 0.22, "rx": 0.07, "rz": 0.07}], t, Color("#7a6a50"), 12)
	if _has("cape"):
		var cape_col := _c("cape", "#c8102e")
		if not look.has("cape"):
			if _has("emblem_bat"):
				cape_col = suit
			elif _has("mask_reign"):
				cape_col = Color("#141414")
			elif _has("emblem_x"):
				cape_col = Color("#1b2f73")
		var lining := _c("cape_lining", cape_col.darkened(0.3).to_html(false))
		cape = _pivot(spine, Vector3(0, L - 0.01, cz + 0.02), "Cape")
		cape_low = _pivot(cape, Vector3(0, -0.5, 0.0), "CapeLow")
		var w := cx + 0.07
		var cape_mat := "cloth"
		var col_fn := func(_t: float, theta: float, _r: Dictionary) -> Color:
			return cape_col if absf(theta) > PI * 0.5 else lining
		_mb(cape, cape_mat).loft([
			{"y": -0.5, "rx": w * 1.15, "rz": 0.07, "cz": 0.0},
			{"y": -0.2, "rx": w * 1.05, "rz": 0.07, "cz": 0.0},
			{"y": 0.0, "rx": w * 0.85, "rz": 0.06, "cz": -0.02},
			{"y": 0.04, "rx": w * 0.55, "rz": 0.05, "cz": -0.04},
		], Transform3D(), col_fn, 16, false, false, 0.55)
		_mb(cape_low, cape_mat).loft([
			{"y": -0.62, "rx": w * 1.3, "rz": 0.08},
			{"y": 0.0, "rx": w * 1.15, "rz": 0.07},
		], Transform3D(), col_fn, 16, false, false, 0.55)
	if _has("wings"):
		for side in [-1.0, 1.0]:
			var wpiv := _pivot(spine, Vector3(side * 0.08, L - 0.05, cz + 0.05), "Wing")
			var wb := _mb(wpiv, "metal")
			for f in 7:
				var a := deg_to_rad(10.0 + f * 11.0)
				var length := 0.95 - f * 0.08
				var feather := PackedVector2Array([Vector2(0, -0.04), Vector2(length, -0.02), Vector2(length + 0.06, 0.02), Vector2(0, 0.05)])
				var xf := Transform3D(Basis(Vector3.BACK, side * a - PI * 0.5 * (1.0 - side) * 0.0) * Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
				wb.prism(feather, 0.012, xf, Color("#b08a3a").lerp(Color("#6a4a2a"), f / 7.0))
			wings.append(wpiv)
	if _has("chair"):
		var cb := _mb(hips, "metal")
		cb.box(Vector3(0, -0.12, 0.05), Vector3(0.55, 0.1, 0.55), Transform3D(), Color("#2a2a30"))
		cb.box(Vector3(0, 0.3, 0.32), Vector3(0.55, 0.8, 0.08), Transform3D(), Color("#2a2a30"))
		_mb(hips, "glow").loft([{"y": -0.2, "rx": 0.18, "rz": 0.18}, {"y": -0.17, "rx": 0.18, "rz": 0.18}],
			Transform3D(), Color("#9a7aff"), 18)


func _build_gear() -> void:
	var gear: Dictionary = look.get("gear", {})
	if gear.is_empty():
		if _has("bow"):
			gear["left"] = "bow"
		if _has("sword"):
			gear["right"] = "katana" if _has("mask_deathstroke") else "sword"
		if _has("staff"):
			gear["right"] = "cosmic_staff" if _has("emblem_star") else "staff"
		if _has("shield"):
			gear["left_arm"] = "shield"
	for slot in gear:
		var kind := str(gear[slot])
		var pivot := hand_r
		var xf := Transform3D(Basis(), Vector3(0, -0.045, 0))
		match slot:
			"left":
				pivot = hand_l
			"left_arm":
				pivot = el_l
				xf = Transform3D(Basis(), Vector3(0, -D["fore"] * 0.45, 0))
			"right_arm":
				pivot = el_r
				xf = Transform3D(Basis(), Vector3(0, -D["fore"] * 0.45, 0))
		Gear.build(kind, _mb(pivot, "metal"), _mb(pivot, "glow"), xf, look)
		if kind in ["pistol", "pistol_big", "cold_gun", "heat_gun"] and muzzle == null:
			var reach := {"pistol": 0.15, "pistol_big": 0.2, "cold_gun": 0.39, "heat_gun": 0.45}
			muzzle = _pivot(pivot, Vector3(0, -0.045 - float(reach[kind]), -0.025), "Muzzle")
		if kind == "cosmic_staff":
			muzzle = _pivot(pivot, Vector3(0, -0.045 - 1.17, 0), "Muzzle")
		if kind == "weather_wand":
			muzzle = _pivot(pivot, Vector3(0, -0.55, 0), "Muzzle")


# --- Points used by combat ----------------------------------------------------

func hand_point(side: float) -> Vector3:
	var h := hand_l if side < 0 else hand_r
	return h.global_transform * Vector3(0, -0.05, 0)


func muzzle_point() -> Vector3:
	if muzzle:
		return muzzle.global_position
	return hand_point(1.0)


func eyes() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e in eye_points:
		out.append(e.global_position)
	return out


# --- Overrides ------------------------------------------------------------------

func flash_hit(heavy := false) -> void:
	_hit_t = 0.08
	_recoil = 1.0 if heavy else 0.55


func set_override(m: Material) -> void:
	if m == _override:
		return
	_override = m
	_apply_override(m)


func _apply_override(m: Material) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_override = m


func tumble(speed: float) -> void:
	_tumble_speed = speed


# --- Actions ------------------------------------------------------------------

## Plays a timed upper-body (or full-body) action. Styles: punch, kick, staff,
## blade, heavy, flurry, claw, stretch. Poses: bow, point, two_hands, gun,
## dual_guns, throw, eyes, breath, temples, slam, shield, cast_up, scream.
func play(action: String, duration := 0.3, step := 0) -> void:
	_action = action
	_action_t = 0.0
	_action_len = maxf(0.05, duration)
	_action_step = step


func punch() -> void:
	play("punch", 0.25, randi() % 2)


func aim() -> void:
	if _action == "" or _action_t >= _action_len:
		play("point", 0.45)


func is_busy() -> bool:
	return _action != "" and _action_t < _action_len


func set_stretch(v: float) -> void:
	_stretch = v


# --- Animation ----------------------------------------------------------------

func animate(delta: float, hspeed: float, grounded: bool, flying: bool, vspeed: float, dead: bool) -> void:
	if _hit_t > 0.0:
		_hit_t -= delta
		_apply_override(_flash_mat if _hit_t > 0.0 else _override)
	_recoil = maxf(0.0, _recoil - delta * 4.0)
	_breath += delta
	var p := _locomotion(delta, hspeed, grounded, flying, vspeed, dead)
	if _action != "" and not dead:
		_action_t += delta
		var t := clampf(_action_t / _action_len, 0.0, 1.0)
		var ap := _action_pose(_action, t, _action_step)
		var w := clampf(minf(t * 6.0, (1.0 - t) * 5.0 + 0.2), 0.0, 1.0)
		if _action in ["bow", "point", "two_hands", "gun", "dual_guns", "eyes", "breath", "temples", "shield", "scream", "cast_up"]:
			w = clampf(minf(t * 8.0, (1.0 - t) * 4.0 + 0.5), 0.0, 1.0)
		for k in ap:
			p[k] = lerpf(p.get(k, 0.0), ap[k], w)
		if _action_t >= _action_len:
			_action = ""
	if _recoil > 0.0 and not dead:
		p["spine_x"] = p.get("spine_x", 0.0) + _recoil * 0.45
		p["head_x"] = p.get("head_x", 0.0) + _recoil * 0.3
	_apply_pose(p, delta, dead)


func _anim(key: String, fallback):
	var a: Dictionary = look.get("anim", {})
	return a.get(key, fallback)


func _locomotion(delta: float, hspeed: float, grounded: bool, flying: bool, vspeed: float, dead: bool) -> Dictionary:
	var p := {}
	var tempo := float(_anim("tempo", 1.0))
	var breathe := sin(_breath * 1.8 * tempo) * 0.025
	p["sh_l_z"] = -0.1
	p["sh_r_z"] = 0.1
	p["el_l"] = 0.2
	p["el_r"] = 0.2
	p["spine_x"] = breathe
	if dead:
		p["pitch"] = -PI * 0.5
		p["drop"] = -D["hip_y"] + 0.18
		p["sh_l_z"] = -1.2
		p["sh_r_z"] = 1.1
		p["el_l"] = 0.4
		p["th_l"] = 0.1
		p["th_r"] = -0.15
		p["kn_l"] = -0.3
		return p
	if _has("chair"):
		p["th_l"] = 1.5
		p["th_r"] = 1.5
		p["kn_l"] = -1.5
		p["kn_r"] = -1.5
		p["drop"] = -0.35
		p["sh_l_x"] = 0.4
		p["sh_r_x"] = 0.4
		p["el_l"] = 1.2
		p["el_r"] = 1.2
		return p
	if flying:
		return _fly_pose(hspeed, vspeed)
	if not grounded:
		if vspeed > 0.0:
			p["th_l"] = 0.9
			p["kn_l"] = -1.3
			p["th_r"] = 0.1
			p["kn_r"] = -0.5
			p["sh_l_x"] = 0.6
			p["sh_r_x"] = -0.3
			p["el_l"] = 0.9
		else:
			p["th_l"] = 0.35
			p["kn_l"] = -0.5
			p["th_r"] = 0.2
			p["kn_r"] = -0.3
			p["sh_l_z"] = -0.7
			p["sh_r_z"] = 0.7
		return p
	if hspeed < 0.3:
		return _idle_pose(p)
	return _run_pose(delta, hspeed, p)


## Standing still: each character's mannerism, with a little life in it.
func _idle_pose(p: Dictionary) -> Dictionary:
	var style := str(_anim("idle", "relaxed"))
	var base: Dictionary = Motion.IDLES.get(style, {})
	for k in base:
		p[k] = base[k]
	var tempo := float(_anim("tempo", 1.0))
	match style:
		"fists":
			p["drop"] = -0.03 + sin(_breath * 4.0 * tempo) * 0.025
			p["spine_y"] = p.get("spine_y", 0.0) + sin(_breath * 2.0 * tempo) * 0.06
		"bounce":
			p["drop"] = absf(sin(_breath * 6.0 * tempo)) * 0.05
			p["head_y"] = sin(_breath * 1.3) * 0.4
			p["sh_l_x"] = p.get("sh_l_x", 0.0) + sin(_breath * 6.0 * tempo) * 0.2
			p["sh_r_x"] = p.get("sh_r_x", 0.0) - sin(_breath * 6.0 * tempo) * 0.2
		"menace":
			p["head_y"] = p.get("head_y", 0.0) + sin(_breath * 0.6) * 0.2
		"casting":
			p["el_l"] = p.get("el_l", 0.0) + sin(_breath * 2.5 * tempo) * 0.2
			p["el_r"] = p.get("el_r", 0.0) + cos(_breath * 2.5 * tempo) * 0.2
		"float":
			p["drop"] = 0.06 + sin(_breath * 1.6) * 0.05
		"pockets", "relaxed", "regal":
			p["head_y"] = p.get("head_y", 0.0) + sin(_breath * 0.45) * 0.25
		"hunched":
			p["spine_x"] = p.get("spine_x", 0.0) + sin(_breath * 1.4 * tempo) * 0.05
		"heavy":
			p["spine_x"] = p.get("spine_x", 0.0) + sin(_breath * 1.2) * 0.06
	p["spine_x"] = p.get("spine_x", 0.0) + sin(_breath * 1.8 * tempo) * 0.025
	return p


## Walking and running, shaped by the character's gait.
func _run_pose(delta: float, hspeed: float, p: Dictionary) -> Dictionary:
	var g: Dictionary = Motion.RUNS.get(str(_anim("run", "athlete")), Motion.RUNS["athlete"])
	var stride := float(g.get("stride", 1.0)) * float(_anim("stride", 1.0))
	var cadence := float(g.get("cadence", 1.0)) * float(_anim("cadence", 1.0))
	var arms := float(g.get("arms", 1.0)) * float(_anim("arms", 1.0))
	var lean := float(g.get("lean", 0.18)) + float(_anim("lean", 0.0))
	var bounce := float(g.get("bounce", 1.0)) * float(_anim("bounce", 1.0))
	var spread := float(g.get("spread", 0.0))
	var sway := float(g.get("sway", 0.0)) + float(_anim("sway", 0.0))
	var elbow := float(g.get("elbow", 1.1))
	var knee := float(g.get("knee", 1.0))
	var sprint: Dictionary = {}
	if hspeed > 14.0:
		sprint = Motion.SPRINTS.get(str(_anim("sprint", "classic")), Motion.SPRINTS["classic"])
		stride *= float(sprint.get("stride", 1.0))
		bounce *= float(sprint.get("bounce", 1.0))
	var amp := clampf(hspeed / 6.0, 0.0, 1.0)
	var rate := hspeed * 1.45 if hspeed < 14.0 else 20.3 + (hspeed - 14.0) * 0.12
	_phase += delta * rate * cadence
	var s := sin(_phase)
	var running := hspeed > 7.5
	var leg := (0.55 if not running else 0.95) * amp * stride
	p["th_l"] = s * leg
	p["th_r"] = -s * leg
	p["kn_l"] = -(0.1 + maxf(0.0, -cos(_phase)) * (0.7 if not running else 1.5) * knee) * amp
	p["kn_r"] = -(0.1 + maxf(0.0, cos(_phase)) * (0.7 if not running else 1.5) * knee) * amp
	var swing := (0.5 if not running else 0.9) * amp * arms
	p["sh_l_x"] = -s * swing
	p["sh_r_x"] = s * swing
	p["sh_l_z"] = -0.1 - spread
	p["sh_r_z"] = 0.1 + spread
	p["el_l"] = 0.25 + (elbow if running else 0.15) * amp
	p["el_r"] = 0.25 + (elbow if running else 0.15) * amp
	p["drop"] = -absf(cos(_phase)) * 0.035 * amp * bounce
	p["spine_y"] = s * (0.12 + sway) * amp
	if sway > 0.0:
		p["yaw"] = s * sway * 0.4 * amp
	p["spine_x"] = -(lean if running else lean * 0.4)
	var extra: Dictionary = g.get("pose", {})
	for k in extra:
		p[k] = p.get(k, 0.0) + float(extra[k]) * (1.0 if k.begins_with("sh_") or k.begins_with("head") or k == "drop" else amp)
	if not sprint.is_empty():
		var sw := float(sprint.get("arms", 1.4))
		p["spine_x"] = -float(sprint.get("lean", 0.55))
		p["head_x"] = float(sprint.get("head", 0.35))
		p["sh_l_x"] = -s * sw - 0.2
		p["sh_r_x"] = s * sw - 0.2
		p["sh_l_z"] = -0.1
		p["sh_r_z"] = 0.1
		p["el_l"] = float(sprint.get("elbow", 1.55))
		p["el_r"] = float(sprint.get("elbow", 1.55))
		var sp_pose: Dictionary = sprint.get("pose", {})
		for k in sp_pose:
			var wiggle: float = (p.get(k, 0.0) + 0.2) * 0.15 if k in ["sh_l_x", "sh_r_x"] else 0.0
			p[k] = float(sp_pose[k]) + wiggle
	return p


## Flying: each character has their own flight pose, blended by speed.
func _fly_pose(hspeed: float, vspeed: float) -> Dictionary:
	var style := str(_anim("fly", "superman"))
	var pair: Array = Motion.FLIGHTS.get(style, Motion.FLIGHTS["superman"])
	var t := clampf(hspeed / 30.0, 0.0, 1.0)
	var p := Motion.lerp_pose(pair[0], pair[1], t)
	var fx: Dictionary = Motion.FLIGHT_FX.get(style, {})
	var bob := float(fx.get("bob", 1.0))
	p["drop"] = p.get("drop", 0.0) + sin(_breath * 2.2) * 0.04 * bob
	if fx.has("flap"):
		var flap := sin(_breath * (5.0 if t < 0.5 else 3.0)) * (0.45 - t * 0.25)
		p["sh_l_z"] = p.get("sh_l_z", 0.0) - flap
		p["sh_r_z"] = p.get("sh_r_z", 0.0) + flap
	if fx.has("roll") and t > 0.5:
		p["roll"] = fmod(_breath * float(fx["roll"]), TAU)
	if fx.has("wobble"):
		var w := float(fx["wobble"])
		p["roll"] = sin(_breath * 1.7) * 0.2 * w
		p["sh_l_z"] = p.get("sh_l_z", 0.0) + sin(_breath * 3.1) * 0.25 * w
		p["sh_r_z"] = p.get("sh_r_z", 0.0) - sin(_breath * 2.7) * 0.25 * w
	if vspeed > 3.0 and t < 0.4:
		p["head_x"] = p.get("head_x", 0.0) - 0.25
	return p


func _action_pose(action: String, t: float, step: int) -> Dictionary:
	var p := {}
	var strike := sin(clampf(t * 1.6, 0.0, 1.0) * PI * 0.5)
	match action:
		"punch":
			var lead := "l" if step % 2 == 0 else "r"
			var back := "r" if lead == "l" else "l"
			p["sh_%s_x" % lead] = lerpf(0.4, 1.62, strike)
			p["sh_%s_z" % lead] = 0.0
			p["el_%s" % lead] = lerpf(1.8, 0.05, strike)
			p["sh_%s_x" % back] = 0.7
			p["el_%s" % back] = 2.1
			p["spine_y"] = (0.45 if lead == "l" else -0.45) * strike
			p["th_l"] = 0.3
			p["kn_l"] = -0.35
			p["th_r"] = -0.2
		"uppercut":
			p["sh_r_x"] = lerpf(-0.2, 2.6, strike)
			p["el_r"] = lerpf(2.0, 0.5, strike)
			p["sh_l_x"] = 0.7
			p["el_l"] = 2.0
			p["spine_x"] = lerpf(-0.2, 0.25, strike)
			p["spine_y"] = -0.35 * strike
			p["th_l"] = 0.25
			p["kn_l"] = -0.5
			p["drop"] = lerpf(-0.1, 0.05, strike)
		"kick":
			p["th_r"] = lerpf(0.0, 1.55, strike)
			p["kn_r"] = lerpf(-1.6, -0.05, strike)
			p["th_l"] = -0.1
			p["spine_x"] = 0.35 * strike
			p["sh_l_x"] = 0.6
			p["sh_r_x"] = 0.6
			p["el_l"] = 1.6
			p["el_r"] = 1.6
		"spin_kick":
			p["yaw"] = TAU * strike
			p["th_r"] = 1.2
			p["kn_r"] = -0.1
			p["sh_r_z"] = 1.2
			p["sh_l_z"] = -1.2
			p["spine_x"] = 0.3
		"staff":
			p["sh_l_x"] = 1.2
			p["sh_r_x"] = 1.2
			p["el_l"] = 0.6
			p["el_r"] = 0.6
			p["spine_y"] = lerpf(1.1, -1.1, strike) * (1.0 if step % 2 == 0 else -1.0)
			p["th_l"] = 0.3
			p["kn_l"] = -0.4
		"blade":
			var dir := 1.0 if step % 2 == 0 else -1.0
			p["sh_r_x"] = lerpf(2.7, 0.7, strike)
			p["sh_r_z"] = lerpf(0.6 * dir, -0.5 * dir, strike)
			p["el_r"] = lerpf(1.0, 0.1, strike)
			p["spine_y"] = lerpf(0.5 * dir, -0.6 * dir, strike)
			p["sh_l_x"] = 0.6
			p["el_l"] = 1.2
			p["th_l"] = 0.35
			p["kn_l"] = -0.4
		"heavy", "slam":
			var up := t < 0.45
			var k := t / 0.45 if up else (t - 0.45) / 0.55
			p["sh_l_x"] = lerpf(0.5, 3.0, k) if up else lerpf(3.0, 0.9, k)
			p["sh_r_x"] = p["sh_l_x"]
			p["el_l"] = 0.4
			p["el_r"] = 0.4
			p["spine_x"] = lerpf(0.0, 0.3, k) if up else lerpf(0.3, -0.5, k)
			p["drop"] = 0.0 if up else -0.12 * k
			p["kn_l"] = -0.6 * (0.0 if up else k)
			p["kn_r"] = -0.6 * (0.0 if up else k)
			p["th_l"] = 0.5 * (0.0 if up else k)
			p["th_r"] = 0.5 * (0.0 if up else k)
		"flurry":
			var f := sin(t * TAU * 5.0)
			p["sh_l_x"] = 1.5 + f * 0.15
			p["sh_r_x"] = 1.5 - f * 0.15
			p["el_l"] = 0.6 + maxf(0.0, f) * 1.2
			p["el_r"] = 0.6 + maxf(0.0, -f) * 1.2
			p["spine_y"] = f * 0.25
			p["spine_x"] = -0.15
		"claw":
			var side := 1.0 if step % 2 == 0 else -1.0
			p["sh_r_x" if side > 0 else "sh_l_x"] = lerpf(2.4, 0.9, strike)
			p["sh_r_z" if side > 0 else "sh_l_z"] = lerpf(0.8, -0.4, strike) * side
			p["spine_y"] = lerpf(0.5, -0.5, strike) * side
			p["spine_x"] = -0.2
		"stretch":
			p["sh_r_x"] = 1.6
			p["el_r"] = 0.0
			p["spine_y"] = -0.4
		"bow":
			p["sh_l_x"] = 1.57
			p["sh_l_z"] = 0.15
			p["el_l"] = 0.0
			p["sh_r_x"] = 1.45
			p["sh_r_z"] = -0.35
			p["el_r"] = lerpf(2.4, 1.6, clampf(t * 3.0, 0.0, 1.0))
			p["spine_y"] = 0.6
			p["head_y"] = -0.55
		"point", "gun":
			p["sh_r_x"] = 1.57
			p["el_r"] = 0.0
			p["sh_r_z"] = 0.05
			p["spine_y"] = -0.3
			p["head_y"] = 0.25
			p["sh_l_x"] = 0.3
		"dual_guns":
			p["sh_r_x"] = 1.57
			p["sh_l_x"] = 1.57
			p["el_l"] = 0.0
			p["el_r"] = 0.0
			p["sh_l_z"] = 0.12
			p["sh_r_z"] = -0.12
		"two_hands":
			p["sh_l_x"] = 1.5
			p["sh_r_x"] = 1.5
			p["sh_l_z"] = 0.25
			p["sh_r_z"] = -0.25
			p["el_l"] = 0.1
			p["el_r"] = 0.1
			p["spine_x"] = -0.1
		"throw":
			p["sh_r_x"] = lerpf(3.0, 1.1, strike)
			p["el_r"] = lerpf(1.4, 0.1, strike)
			p["spine_y"] = lerpf(0.5, -0.5, strike)
			p["sh_l_x"] = 1.0
		"eyes":
			p["head_x"] = 0.05
			p["spine_x"] = -0.05
			p["sh_l_z"] = -0.25
			p["sh_r_z"] = 0.25
		"breath":
			p["head_x"] = -0.15
			p["spine_x"] = 0.2
			p["sh_l_z"] = -0.45
			p["sh_r_z"] = 0.45
			p["el_l"] = 0.8
			p["el_r"] = 0.8
		"scream":
			p["head_x"] = -0.1
			p["spine_x"] = 0.15
			p["sh_l_z"] = -0.7
			p["sh_r_z"] = 0.7
			p["el_l"] = 0.6
			p["el_r"] = 0.6
		"temples":
			p["sh_l_x"] = 2.2
			p["sh_r_x"] = 2.2
			p["sh_l_z"] = -0.6
			p["sh_r_z"] = 0.6
			p["el_l"] = 2.3
			p["el_r"] = 2.3
			p["head_x"] = -0.1
		"cast_up":
			p["sh_l_x"] = 2.9
			p["sh_r_x"] = 2.9
			p["sh_l_z"] = -0.4
			p["sh_r_z"] = 0.4
			p["el_l"] = 0.1
			p["el_r"] = 0.1
			p["spine_x"] = 0.2
		"shield":
			p["sh_l_x"] = 1.3
			p["sh_l_z"] = 0.5
			p["el_l"] = 1.3
			p["spine_y"] = 0.3
		"dodge":
			p["pitch"] = -0.4
			p["th_l"] = 0.9
			p["kn_l"] = -1.4
			p["th_r"] = -0.4
			p["kn_r"] = -0.6
			p["sh_l_x"] = 0.6
			p["sh_r_x"] = -0.6
	return p


func _apply_pose(p: Dictionary, delta: float, dead: bool) -> void:
	var k := clampf(delta * 14.0, 0.0, 1.0)
	var slow := clampf(delta * 6.0, 0.0, 1.0)
	_pose_lerp(hips, "rotation:x", p.get("pitch", 0.0), slow if not dead else slow * 0.6)
	if _tumble_speed > 0.0:
		_tumble += delta * _tumble_speed
		_tumble_speed = maxf(0.0, _tumble_speed - delta * 9.0)
		hips.rotation.x = -_tumble
	else:
		_tumble = 0.0
	hips.position.y = lerpf(hips.position.y, D["hip_y"] + p.get("drop", 0.0), k)
	hips.rotation.y = p.get("yaw", 0.0) if p.has("yaw") else lerpf(hips.rotation.y, 0.0, k)
	if p.has("roll") and absf(p["roll"]) > 0.6:
		hips.rotation.z = p["roll"]
	else:
		_pose_lerp(hips, "rotation:z", p.get("roll", 0.0), slow)
	if build_type == "gorilla":
		p["spine_x"] = p.get("spine_x", 0.0) - 0.45
		p["head_x"] = p.get("head_x", 0.0) + 0.4
	_pose_lerp(spine, "rotation:x", p.get("spine_x", 0.0), k)
	_pose_lerp(spine, "rotation:y", p.get("spine_y", 0.0), k)
	_pose_lerp(head, "rotation:x", p.get("head_x", 0.0), k)
	_pose_lerp(head, "rotation:y", p.get("head_y", 0.0), k)
	_pose_lerp(sh_l, "rotation:x", p.get("sh_l_x", 0.0), k)
	_pose_lerp(sh_r, "rotation:x", p.get("sh_r_x", 0.0), k)
	_pose_lerp(sh_l, "rotation:z", p.get("sh_l_z", 0.0), k)
	_pose_lerp(sh_r, "rotation:z", p.get("sh_r_z", 0.0), k)
	_pose_lerp(el_l, "rotation:x", p.get("el_l", 0.0), k)
	_pose_lerp(el_r, "rotation:x", p.get("el_r", 0.0), k)
	_pose_lerp(th_l, "rotation:x", p.get("th_l", 0.0), k)
	_pose_lerp(th_r, "rotation:x", p.get("th_r", 0.0), k)
	_pose_lerp(th_l, "rotation:z", p.get("th_l_z", 0.0), k)
	_pose_lerp(th_r, "rotation:z", p.get("th_r_z", 0.0), k)
	_pose_lerp(kn_l, "rotation:x", p.get("kn_l", 0.0), k)
	_pose_lerp(kn_r, "rotation:x", p.get("kn_r", 0.0), k)
	el_r.scale.y = lerpf(el_r.scale.y, _stretch, k)
	if cape:
		# Running leans lift the cape off the back; in level flight it streams
		# out behind along the legs instead of standing up.
		var pitch_amt := absf(p.get("pitch", 0.0))
		var lean_amt := clampf(-p.get("spine_x", 0.0), 0.0, 1.0)
		var sway := clampf(lean_amt * 1.2 + pitch_amt * 0.2, 0.0, 1.2)
		var flutter := sin(_breath * 9.0) * 0.06 * (0.3 + sway + pitch_amt * 0.5)
		_pose_lerp(cape, "rotation:x", -0.06 - sway * 0.8 - flutter, slow)
		_pose_lerp(cape_low, "rotation:x", -0.1 - sway * 0.4 + flutter * 1.5, slow)
	for i in wings.size():
		var side := -1.0 if i == 0 else 1.0
		var flap := sin(_breath * 7.0) * 0.4 if p.has("pitch") and absf(p["pitch"]) > 0.0 else 0.0
		wings[i].rotation.z = lerpf(wings[i].rotation.z, side * (0.25 + flap), slow)
		wings[i].rotation.y = side * -0.35


func _pose_lerp(n: Node3D, prop: String, target: float, k: float) -> void:
	var cur: float = n.get_indexed(prop)
	n.set_indexed(prop, lerp_angle(cur, target, k))
