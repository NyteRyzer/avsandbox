extends Node
## Procedurally generated sound effects. Every sound is synthesised at startup
## into an AudioStreamWAV, so the game ships with no audio files.

const RATE := 22050
const POOL_3D := 24
const POOL_UI := 6

var streams: Dictionary = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_ui := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generate()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 140.0
		p.unit_size = 12.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players_3d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_ui.append(p)


## Plays a named sound at a world position (3D) or, with no position, flat.
func play(sound: String, pos = null, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not streams.has(sound):
		return
	var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if pos == null:
		var p := _players_ui[_next_ui]
		_next_ui = (_next_ui + 1) % POOL_UI
		p.stream = streams[sound]
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
	else:
		var p := _players_3d[_next_3d]
		_next_3d = (_next_3d + 1) % POOL_3D
		p.stream = streams[sound]
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.global_position = pos
		p.play()


func _generate() -> void:
	streams["punch"] = _make(0.14, func(t, d): return _noise() * _env(t, d, 0.002, 0.1) * 0.8 + sin(TAU * 90.0 * t) * _env(t, d, 0.001, 0.12))
	streams["hit"] = _make(0.1, func(t, d): return (_noise() * 0.6 + _square(220.0 - t * 900.0, t) * 0.4) * _env(t, d, 0.001, 0.08))
	streams["whoosh"] = _make(0.35, func(t, d): return _noise() * sin(PI * t / d) * 0.5)
	streams["arrow"] = _make(0.22, func(t, d): return (_noise() * 0.35 + sin(TAU * (900.0 - t * 2500.0) * t) * 0.3) * _env(t, d, 0.005, 0.2))
	streams["zap"] = _make(0.25, func(t, d): return _square(1200.0 - t * 3800.0, t) * 0.35 * _env(t, d, 0.002, 0.22))
	streams["lightning"] = _make(0.45, func(t, d): return (_noise() * 0.7 + _square(60.0, t) * 0.3) * _env(t, d, 0.001, 0.4) * (0.6 + 0.4 * sin(TAU * 31.0 * t)))
	streams["gun"] = _make(0.18, func(t, d): return (_noise() * 0.9 + sin(TAU * 140.0 * t) * 0.5) * _env(t, d, 0.0005, 0.12))
	streams["explosion"] = _make(1.1, func(t, d): return (_brown() * 1.4 + sin(TAU * (60.0 - t * 30.0) * t) * 0.5) * _env(t, d, 0.004, 1.0))
	streams["sonic"] = _make(0.6, func(t, d): return (sin(TAU * (520.0 + 160.0 * sin(TAU * 7.0 * t)) * t) * 0.4 + _noise() * 0.2) * _env(t, d, 0.02, 0.55))
	streams["freeze"] = _make(0.5, func(t, d): return (sin(TAU * 1800.0 * t) * 0.15 + _noise() * 0.25) * _env(t, d, 0.01, 0.45) * (0.5 + 0.5 * sin(TAU * 40.0 * t)))
	streams["fire"] = _make(0.5, func(t, d): return _brown() * 0.9 * _env(t, d, 0.03, 0.45))
	streams["beam"] = _make(0.25, func(t, d): return (_square(180.0, t) * 0.12 + sin(TAU * 360.0 * t) * 0.15) * _env(t, d, 0.01, 0.1))
	streams["slam"] = _make(0.8, func(t, d): return (_brown() * 1.2 + sin(TAU * (45.0 - t * 20.0) * t) * 0.8) * _env(t, d, 0.002, 0.75))
	streams["teleport"] = _make(0.5, func(t, d): return sin(TAU * (200.0 + t * 1600.0) * t) * 0.3 * _env(t, d, 0.02, 0.45))
	streams["slowmo"] = _make(0.9, func(t, d): return sin(TAU * (500.0 - t * 400.0) * t) * 0.3 * _env(t, d, 0.05, 0.8))
	streams["ko"] = _make(0.4, func(t, d): return sin(TAU * (300.0 - t * 500.0) * t) * 0.35 * _env(t, d, 0.01, 0.38))
	streams["click"] = _make(0.05, func(t, d): return sin(TAU * 1400.0 * t) * 0.3 * _env(t, d, 0.001, 0.045))
	streams["event"] = _make(0.6, func(t, d): return (sin(TAU * 660.0 * t) + sin(TAU * 880.0 * t) * (1.0 if t > 0.2 else 0.0)) * 0.18 * _env(t, d, 0.01, 0.55))
	streams["smoke"] = _make(0.6, func(t, d): return _noise() * 0.4 * _env(t, d, 0.01, 0.58))


var _brown_state := 0.0


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _brown() -> float:
	_brown_state = clampf(_brown_state + (randf() * 2.0 - 1.0) * 0.12, -1.0, 1.0)
	return _brown_state


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * maxf(freq, 20.0), 1.0) < 0.5 else -1.0


func _env(t: float, duration: float, attack: float, release: float) -> float:
	if t < attack:
		return t / attack
	var remaining := duration - t
	return clampf(remaining / release, 0.0, 1.0)


func _make(duration: float, fn: Callable) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var v := clampf(float(fn.call(t, duration)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
