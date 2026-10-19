class_name StyleMeter
extends RefCounted
## The style rank: varied, uninterrupted fighting climbs from D to SSS; getting
## hit or going quiet drops it. Higher ranks pay more for every knockout.

const RANKS := [[0.0, ""], [8.0, "D  Decent"], [20.0, "C  Cool"], [36.0, "B  Brutal"], [56.0, "A  Amazing"],
	[80.0, "S  Super"], [110.0, "SS  Spectacular"], [150.0, "SSS  Legendary"]]

var points := 0.0
var best := 0
var _idle := 0.0
var _last_kind := ""


func add(n: float, kind: String) -> void:
	var gain := n * 2.0
	if kind != _last_kind and kind != "":
		gain += 3.0  # variety is stylish
	_last_kind = kind
	points = minf(points + gain, 180.0)
	_idle = 0.0
	best = maxi(best, rank())


func hurt() -> void:
	points *= 0.6


func tick(delta: float) -> void:
	_idle += delta
	if _idle > 2.0:
		points = maxf(0.0, points - delta * (6.0 + points * 0.05))


func rank() -> int:
	var r := 0
	for i in RANKS.size():
		if points >= float(RANKS[i][0]):
			r = i
	return r


func label() -> String:
	return str(RANKS[rank()][1])


## Score multiplier for knockouts.
func multiplier() -> float:
	return 1.0 + rank() * 0.15
