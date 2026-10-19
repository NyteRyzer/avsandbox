class_name Motion
extends RefCounted
## How a character carries themself: idle mannerism, walk/run style, speedster
## sprint style and flight pose. Each character's "look.anim" picks one of each
## and tunes it (stride, cadence, arm swing, lean, bounce, sway), so no two
## characters move alike.
##
## Poses are dictionaries of joint angles (radians) keyed like CharacterModel:
## pitch/roll/drop for the hips, spine_x/y, head_x/y, sh_l_x/z, sh_r_x/z,
## el_l/r, th_l/r, th_l_z/th_r_z (legs apart), kn_l/r.

## Idle mannerisms.
const IDLES := {
	"relaxed": {},
	"fists": {"sh_l_x": 0.95, "sh_r_x": 0.8, "el_l": 2.1, "el_r": 2.2, "sh_l_z": 0.15, "sh_r_z": -0.15, "spine_y": 0.25,
		"th_l": 0.18, "th_r": -0.12, "kn_l": -0.25, "kn_r": -0.15},
	"arms_crossed": {"sh_l_x": 0.18, "sh_r_x": 0.22, "sh_l_z": 0.6, "sh_r_z": -0.6, "el_l": 1.5, "el_r": 1.45, "head_x": -0.06},
	"hands_hips": {"sh_l_z": -0.75, "sh_r_z": 0.75, "sh_l_x": -0.25, "sh_r_x": -0.25, "el_l": 1.7, "el_r": 1.7, "head_x": -0.08,
		"th_l_z": 0.08, "th_r_z": -0.08},
	"bow_ready": {"sh_l_x": 0.55, "sh_l_z": -0.15, "el_l": 0.35, "sh_r_x": 0.3, "el_r": 1.2, "spine_y": -0.3, "head_y": 0.25,
		"th_l": 0.15, "th_r": -0.1},
	"staff_ready": {"sh_r_x": 0.7, "el_r": 1.25, "sh_l_x": 0.55, "el_l": 1.5, "sh_l_z": 0.25, "spine_y": 0.2, "th_l": 0.12, "kn_l": -0.2},
	"hunched": {"spine_x": -0.4, "head_x": 0.35, "sh_l_x": 0.35, "sh_r_x": 0.35, "el_l": 0.4, "el_r": 0.4, "sh_l_z": -0.25, "sh_r_z": 0.25,
		"kn_l": -0.3, "kn_r": -0.3, "th_l": 0.25, "th_r": 0.25, "drop": -0.06},
	"bounce": {"sh_l_x": 0.3, "sh_r_x": 0.3, "el_l": 1.1, "el_r": 1.1, "th_l": 0.1, "kn_l": -0.2, "kn_r": -0.15},
	"menace": {"head_y": 0.3, "head_x": 0.18, "sh_l_z": -0.3, "sh_r_z": 0.3, "el_l": 0.5, "el_r": 0.5, "spine_x": -0.08},
	"casting": {"sh_l_x": 0.75, "sh_r_x": 0.75, "sh_l_z": -0.45, "sh_r_z": 0.45, "el_l": 1.3, "el_r": 1.3, "head_x": -0.05},
	"regal": {"sh_l_x": -0.35, "sh_r_x": -0.35, "el_l": 0.55, "el_r": 0.55, "sh_l_z": 0.12, "sh_r_z": -0.12, "head_x": -0.15, "spine_x": 0.06},
	"blade_low": {"sh_r_x": 0.25, "sh_r_z": 0.35, "el_r": 0.35, "sh_l_x": 0.7, "el_l": 1.8, "spine_y": -0.25, "th_l": 0.22, "kn_l": -0.35,
		"th_r": -0.15, "kn_r": -0.2},
	"pockets": {"sh_l_x": -0.2, "sh_r_x": -0.2, "sh_l_z": -0.18, "sh_r_z": 0.18, "el_l": 0.7, "el_r": 0.7, "head_y": -0.15, "spine_y": 0.1},
	"heavy": {"sh_l_z": -0.5, "sh_r_z": 0.5, "el_l": 0.7, "el_r": 0.7, "spine_x": -0.12, "head_x": 0.1, "th_l_z": 0.12, "th_r_z": -0.12},
	"float": {"sh_l_z": -0.4, "sh_r_z": 0.4, "sh_l_x": 0.15, "sh_r_x": 0.15, "el_l": 0.25, "el_r": 0.25, "head_x": 0.05},
}

## Walk/run styles: tuning for the gait plus a pose added on top.
const RUNS := {
	"athlete": {"stride": 1.0, "cadence": 1.0, "arms": 1.0, "lean": 0.18, "bounce": 1.0},
	"sprinter": {"stride": 1.15, "cadence": 1.05, "arms": 1.4, "lean": 0.3, "bounce": 0.8, "elbow": 1.5},
	"heavy": {"stride": 0.8, "cadence": 0.82, "arms": 0.7, "lean": 0.12, "bounce": 2.2, "spread": 0.35, "sway": 0.28, "elbow": 1.1},
	"lumber": {"stride": 0.85, "cadence": 0.78, "arms": 0.9, "lean": 0.5, "bounce": 2.0, "spread": 0.45, "sway": 0.35,
		"pose": {"sh_l_x": 0.45, "sh_r_x": 0.45, "head_x": 0.35}},
	"prowl": {"stride": 1.05, "cadence": 1.1, "arms": 0.8, "lean": 0.4, "bounce": 0.5, "pose": {"drop": -0.12, "kn_l": -0.35, "kn_r": -0.35, "sh_l_x": 0.35, "sh_r_x": 0.35}},
	"ninja": {"stride": 1.15, "cadence": 1.12, "arms": 0.1, "lean": 0.5, "bounce": 0.35, "elbow": 0.15, "pose": {"sh_l_x": -1.0, "sh_r_x": -1.0, "sh_l_z": -0.15, "sh_r_z": 0.15}},
	"marching": {"stride": 1.1, "cadence": 0.95, "arms": 0.8, "lean": 0.02, "bounce": 0.6, "elbow": 0.15, "knee": 0.6},
	"swagger": {"stride": 0.9, "cadence": 0.85, "arms": 0.6, "lean": -0.04, "bounce": 0.9, "sway": 0.4, "pose": {"head_y": 0.15, "sh_r_z": 0.2}},
	"glide": {"stride": 0.55, "cadence": 0.8, "arms": 0.12, "lean": 0.0, "bounce": 0.15, "knee": 0.4, "pose": {"sh_l_z": -0.3, "sh_r_z": 0.3}},
	"bounce": {"stride": 1.0, "cadence": 1.18, "arms": 1.25, "lean": 0.15, "bounce": 2.4},
	"stomp": {"stride": 0.8, "cadence": 0.8, "arms": 0.5, "lean": 0.08, "bounce": 2.6, "spread": 0.3, "elbow": 0.6, "knee": 0.55},
	"stalk": {"stride": 0.9, "cadence": 0.9, "arms": 0.25, "lean": 0.32, "bounce": 0.4, "pose": {"head_x": 0.22, "sh_l_z": -0.15, "sh_r_z": 0.15}},
	"skip": {"stride": 0.95, "cadence": 1.15, "arms": 0.4, "lean": 0.05, "bounce": 2.8, "pose": {"sh_l_z": -0.9, "el_l": 0.4, "head_y": 0.2}},
	"strut": {"stride": 1.0, "cadence": 0.95, "arms": 0.55, "lean": -0.02, "bounce": 0.7, "sway": 0.2, "pose": {"head_x": -0.1}},
}

## Speedster sprints (above 14 m/s).
const SPRINTS := {
	"classic": {"lean": 0.55, "arms": 1.4, "elbow": 1.55, "head": 0.35},
	"upright": {"lean": 0.28, "arms": 1.2, "elbow": 1.35, "head": 0.1},
	"arms_back": {"lean": 0.9, "arms": 0.15, "elbow": 0.1, "head": 0.65, "pose": {"sh_l_x": -1.5, "sh_r_x": -1.5, "sh_l_z": -0.25, "sh_r_z": 0.25}},
	"tucked": {"lean": 0.65, "arms": 0.8, "elbow": 2.1, "head": 0.45},
	"wide": {"lean": 0.45, "arms": 1.9, "elbow": 1.1, "head": 0.25, "pose": {"sh_l_z": -0.3, "sh_r_z": 0.3}},
	"bouncy": {"lean": 0.5, "arms": 1.5, "elbow": 1.4, "head": 0.3, "bounce": 2.5},
	"phantom": {"lean": 0.72, "arms": 0.35, "elbow": 0.6, "head": 0.55, "pose": {"sh_l_z": -0.15, "sh_r_z": 0.15}},
	"armored": {"lean": 0.35, "arms": 0.7, "elbow": 0.9, "head": 0.15, "pose": {"sh_l_z": -0.5, "sh_r_z": 0.5}},
	"army": {"lean": 0.58, "arms": 1.1, "elbow": 1.7, "head": 0.05},
	"veteran": {"lean": 0.42, "arms": 1.6, "elbow": 1.45, "head": 0.25, "stride": 1.2},
	"cape": {"lean": 0.78, "arms": 0.5, "elbow": 0.4, "head": 0.5, "pose": {"sh_l_x": -0.9, "sh_r_x": -0.9, "sh_l_z": -0.45, "sh_r_z": 0.45}},
}

## Flight: [hovering pose, cruising pose]. The model blends by speed and
## adds flaps, rolls and bobbing per style.
const FLIGHTS := {
	"superman": [{"th_l": 0.15, "kn_l": -0.45, "kn_r": -0.2, "sh_l_z": -0.3, "sh_r_z": 0.3, "el_l": 0.4, "el_r": 0.4},
		{"pitch": -1.4, "sh_r_x": 3.05, "el_r": 0.0, "sh_l_x": 0.2, "sh_l_z": -0.12, "el_l": 0.1, "head_x": 0.9, "kn_l": -0.25, "kn_r": -0.05}],
	"supergirl": [{"th_l": 0.1, "kn_l": -0.3, "kn_r": -0.35, "sh_l_z": -0.2, "sh_r_z": 0.2, "el_l": 0.2, "el_r": 0.2, "head_x": -0.05},
		{"pitch": -1.45, "sh_l_x": -0.25, "sh_r_x": -0.25, "sh_l_z": -0.12, "sh_r_z": 0.12, "el_l": 0.0, "el_r": 0.0, "head_x": 1.0}],
	"fists_forward": [{"sh_l_x": 0.6, "sh_r_x": 0.6, "el_l": 1.6, "el_r": 1.6, "kn_l": -0.4, "kn_r": -0.4},
		{"pitch": -1.35, "sh_l_x": 3.0, "sh_r_x": 3.0, "sh_l_z": 0.15, "sh_r_z": -0.15, "el_l": 0.15, "el_r": 0.15, "head_x": 0.85}],
	"left_fist": [{"sh_l_z": -0.5, "sh_r_z": 0.5, "el_l": 0.6, "el_r": 0.6, "head_x": 0.15},
		{"pitch": -1.3, "sh_l_x": 3.05, "el_l": 0.0, "sh_r_x": -0.3, "sh_r_z": 0.25, "el_r": 0.4, "head_x": 0.75, "kn_r": -0.35}],
	"flail": [{"sh_l_z": -1.1, "sh_r_z": 1.1, "el_l": 0.3, "el_r": 0.3, "kn_l": -0.7, "kn_r": -0.2, "th_l": 0.4},
		{"pitch": -1.0, "sh_l_z": -1.2, "sh_r_z": 1.2, "sh_l_x": 0.5, "sh_r_x": 0.5, "el_l": 0.3, "el_r": 0.3, "kn_l": -0.6, "kn_r": -0.2, "head_x": 0.6}],
	"dive": [{"sh_l_x": 0.3, "sh_r_x": 0.3, "el_l": 0.5, "el_r": 0.5, "kn_l": -0.3, "kn_r": -0.3},
		{"pitch": -1.5, "sh_l_x": 3.1, "sh_r_x": 3.1, "sh_l_z": 0.25, "sh_r_z": -0.25, "el_l": 0.0, "el_r": 0.0, "head_x": 1.0}],
	"martian": [{"sh_l_x": 0.42, "sh_r_x": 0.48, "sh_l_z": 0.42, "sh_r_z": -0.42, "el_l": 1.75, "el_r": 1.7},
		{"pitch": -1.4, "sh_l_x": 0.42, "sh_r_x": 0.48, "sh_l_z": 0.42, "sh_r_z": -0.42, "el_l": 1.75, "el_r": 1.7, "head_x": 0.95}],
	"wings": [{"sh_l_z": -0.9, "sh_r_z": 0.9, "el_l": 0.5, "el_r": 0.5, "kn_l": -0.35, "kn_r": -0.35, "th_l": 0.2, "th_r": 0.2},
		{"pitch": -1.2, "sh_l_z": -1.3, "sh_r_z": 1.3, "sh_l_x": 0.2, "sh_r_x": 0.2, "el_l": 0.2, "el_r": 0.2, "head_x": 0.75}],
	"firestorm": [{"sh_l_z": -0.6, "sh_r_z": 0.6, "el_l": 0.3, "el_r": 0.3, "th_l_z": 0.15, "th_r_z": -0.15, "head_x": -0.05},
		{"pitch": -0.9, "sh_l_x": -0.6, "sh_r_x": -0.6, "sh_l_z": -0.5, "sh_r_z": 0.5, "el_l": 0.1, "el_r": 0.1, "th_l_z": 0.25, "th_r_z": -0.25, "head_x": 0.5}],
	"jet": [{"sh_l_z": -0.15, "sh_r_z": 0.15, "el_l": 0.1, "el_r": 0.1, "kn_l": -0.1, "kn_r": -0.1},
		{"pitch": -1.5, "sh_l_x": 0.0, "sh_r_x": 0.0, "sh_l_z": -0.05, "sh_r_z": 0.05, "el_l": 0.0, "el_r": 0.0, "head_x": 1.05}],
	"levitate": [{"sh_l_z": -0.55, "sh_r_z": 0.55, "el_l": 0.25, "el_r": 0.25, "sh_l_x": 0.2, "sh_r_x": 0.2, "kn_l": -0.15, "kn_r": -0.15},
		{"pitch": -0.35, "sh_l_z": -0.8, "sh_r_z": 0.8, "sh_l_x": 0.2, "sh_r_x": 0.2, "el_l": 0.2, "el_r": 0.2, "head_x": 0.2}],
	"spread_eagle": [{"sh_l_z": -1.35, "sh_r_z": 1.35, "el_l": 0.15, "el_r": 0.15, "th_l_z": 0.3, "th_r_z": -0.3},
		{"pitch": -1.1, "sh_l_z": -1.45, "sh_r_z": 1.45, "el_l": 0.1, "el_r": 0.1, "th_l_z": 0.35, "th_r_z": -0.35, "head_x": 0.7}],
	"staff_ride": [{"sh_r_x": 0.9, "el_r": 0.6, "sh_l_x": 0.9, "el_l": 0.8, "th_l": 0.9, "th_r": 0.9, "kn_l": -1.2, "kn_r": -1.1},
		{"pitch": -0.8, "sh_r_x": 1.9, "el_r": 0.2, "sh_l_x": 1.6, "el_l": 0.6, "th_l": 0.7, "th_r": 0.5, "kn_l": -1.0, "kn_r": -0.7, "head_x": 0.5}],
	"lightning_rider": [{"sh_l_z": -0.35, "sh_r_z": 0.35, "sh_l_x": -0.2, "sh_r_x": -0.2, "el_l": 0.3, "el_r": 0.3, "head_x": -0.1},
		{"pitch": -0.75, "sh_l_x": -0.7, "sh_r_x": -0.7, "sh_l_z": -0.35, "sh_r_z": 0.35, "el_l": 0.4, "el_r": 0.4, "head_x": 0.4, "kn_l": -0.4}],
	"palm_forward": [{"sh_r_x": 1.2, "el_r": 0.3, "sh_l_z": -0.4, "el_l": 0.4},
		{"pitch": -1.25, "sh_r_x": 2.8, "el_r": 0.1, "sh_l_x": -0.4, "sh_l_z": -0.3, "head_x": 0.75, "kn_l": -0.5, "kn_r": -0.15}],
	"corkscrew": [{"sh_l_z": -1.0, "sh_r_z": 1.0, "el_l": 0.8, "el_r": 0.8, "head_x": -0.1},
		{"pitch": -1.35, "sh_l_x": 3.0, "sh_r_x": 3.0, "el_l": 0.0, "el_r": 0.0, "head_x": 0.9}],
	"ring": [{"sh_l_z": -0.12, "sh_r_z": 0.12, "el_l": 0.15, "el_r": 0.15},
		{"pitch": -0.6, "sh_l_z": -0.1, "sh_r_z": 0.1, "sh_l_x": -0.2, "sh_r_x": -0.2, "head_x": 0.4}],
	"titan": [{"sh_l_z": -0.9, "sh_r_z": 0.9, "sh_l_x": 0.4, "sh_r_x": 0.4, "el_l": 0.9, "el_r": 0.9, "head_x": 0.12},
		{"pitch": -0.5, "sh_l_z": -1.0, "sh_r_z": 1.0, "sh_l_x": 0.3, "sh_r_x": 0.3, "el_l": 0.7, "el_r": 0.7, "head_x": 0.3}],
	"warsuit": [{"sh_l_x": 0.4, "sh_r_x": 0.4, "el_l": 1.3, "el_r": 1.3, "kn_l": -0.2, "kn_r": -0.2},
		{"pitch": -1.45, "sh_l_x": 0.2, "sh_r_x": 0.2, "sh_l_z": -0.35, "sh_r_z": 0.35, "el_l": 0.9, "el_r": 0.9, "head_x": 1.0}],
	"conductor": [{"sh_r_x": 2.6, "el_r": 0.3, "sh_l_z": -0.5, "el_l": 0.6},
		{"pitch": -0.5, "sh_r_x": 2.9, "el_r": 0.2, "sh_l_z": -0.7, "el_l": 0.3, "head_x": 0.3}],
	"spectral": [{"sh_l_z": -1.0, "sh_r_z": 1.0, "sh_l_x": 0.3, "sh_r_x": 0.3, "el_l": 0.1, "el_r": 0.1, "kn_l": -0.05, "kn_r": -0.05},
		{"pitch": -0.25, "sh_l_z": -1.2, "sh_r_z": 1.2, "sh_l_x": 0.1, "sh_r_x": 0.1, "head_x": 0.1}],
	"dreamer": [{"sh_l_z": -0.3, "sh_r_z": 0.3, "el_l": 0.6, "el_r": 0.6, "head_x": -0.2, "head_y": 0.2, "kn_l": -0.5, "th_l": 0.3},
		{"pitch": -0.9, "sh_l_x": 1.5, "el_l": 0.4, "sh_r_z": 0.6, "head_x": 0.4, "kn_l": -0.6, "th_l": 0.2}],
	"hunched": [{"spine_x": -0.4, "head_x": 0.35, "sh_l_x": 0.6, "sh_r_x": 0.6, "el_l": 0.7, "el_r": 0.7, "kn_l": -0.8, "kn_r": -0.8, "th_l": 0.5, "th_r": 0.5},
		{"pitch": -1.0, "sh_l_x": 1.3, "sh_r_x": 1.3, "el_l": 0.9, "el_r": 0.9, "head_x": 0.5, "kn_l": -0.9, "kn_r": -0.9}],
	"cosmic_dive": [{"sh_l_z": -0.7, "sh_r_z": 0.7, "el_l": 0.5, "el_r": 0.5, "kn_l": -0.3, "kn_r": -0.6, "th_r": 0.3},
		{"pitch": -1.3, "sh_l_x": -0.5, "sh_r_x": -0.5, "sh_l_z": -0.8, "sh_r_z": 0.8, "el_l": 0.3, "el_r": 0.3, "head_x": 0.85, "kn_r": -0.5}],
	"meteor": [{"sh_l_x": 0.7, "sh_r_x": 0.7, "el_l": 1.9, "el_r": 1.9, "spine_x": -0.2, "kn_l": -0.5, "kn_r": -0.5},
		{"pitch": -1.3, "sh_l_x": 2.4, "sh_r_x": 2.4, "el_l": 1.0, "el_r": 1.0, "head_x": 0.8}],
}

## Extra motion per flight style: wing flaps, barrel rolls, bobbing.
const FLIGHT_FX := {
	"wings": {"flap": 1.0}, "corkscrew": {"roll": 2.5}, "flail": {"wobble": 1.0}, "levitate": {"bob": 1.6},
	"spectral": {"bob": 1.0}, "dreamer": {"bob": 1.2}, "titan": {"bob": 0.6}, "hunched": {"wobble": 0.5},
	"staff_ride": {"bob": 0.8}, "lightning_rider": {"wobble": 0.3}, "spread_eagle": {"wobble": 0.4},
}


static func lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a.keys():
		out[k] = lerpf(float(a[k]), float(b.get(k, 0.0)), t)
	for k in b.keys():
		if not out.has(k):
			out[k] = lerpf(0.0, float(b[k]), t)
	return out
