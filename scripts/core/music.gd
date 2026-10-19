class_name Music
extends Node
## Procedural soundtrack: a calm ambient loop while you explore and a driving
## combat loop when a fight breaks out (louder for bosses), crossfading with
## the action. Synthesised at startup; nothing is loaded from disk.

const RATE := 11025
const BEAT := 0.5        # 120 bpm
const LOOP := 8.0

var world
var _calm: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _mix := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	_calm = AudioStreamPlayer.new()
	_calm.stream = _render(_calm_sample)
	_calm.volume_db = -14.0
	add_child(_calm)
	_combat = AudioStreamPlayer.new()
	_combat.stream = _render(_combat_sample)
	_combat.volume_db = -60.0
	add_child(_combat)
	_calm.play()
	_combat.play()


func _render(fn: Callable) -> AudioStreamWAV:
	var count := int(LOOP * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v := clampf(float(fn.call(float(i) / RATE)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


static func _note(semis: float) -> float:
	return 220.0 * pow(2.0, semis / 12.0)


## Am - F - C - G pads with a slow arpeggio on top.
func _calm_sample(t: float) -> float:
	var chords := [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]
	var bar := int(t / 2.0) % 4
	var local := fmod(t, 2.0)
	var env := minf(1.0, local * 2.0) * minf(1.0, (2.0 - local) * 2.0)
	var v := 0.0
	for s in chords[bar]:
		v += sin(TAU * _note(float(s) - 12.0) * t) * 0.12
	var arp_i := int(t / 0.25) % 3
	var arp_t := fmod(t, 0.25)
	v += sin(TAU * _note(float(chords[bar][arp_i]) + 12.0) * t) * 0.08 * exp(-arp_t * 9.0)
	return v * env


## Kick, snare and hats with a minor bass line and stabs.
func _combat_sample(t: float) -> float:
	var beat_t := fmod(t, BEAT)
	var beat := int(t / BEAT)
	var v := 0.0
	# Kick on every beat, snare on 2 and 4.
	v += sin(TAU * (55.0 + 90.0 * exp(-beat_t * 30.0)) * beat_t) * exp(-beat_t * 9.0) * 0.6
	if beat % 2 == 1:
		v += (randf() * 2.0 - 1.0) * exp(-beat_t * 14.0) * 0.35
	var eighth := fmod(t, BEAT * 0.5)
	v += (randf() * 2.0 - 1.0) * exp(-eighth * 60.0) * 0.08
	# Bass: A - A - F - G
	var bass: int = [0, 0, -4, -2][int(t / 2.0) % 4]
	var bf := _note(float(bass) - 24.0)
	v += (1.0 if fmod(t * bf, 1.0) < 0.5 else -1.0) * 0.12 * (0.6 + 0.4 * exp(-fmod(t, BEAT * 0.5) * 6.0))
	# Stabs on the off-beats.
	if beat % 4 == 3:
		for s in [0, 3, 7]:
			v += sin(TAU * _note(float(s + bass)) * t) * 0.07 * exp(-beat_t * 5.0)
	return v


func _process(delta: float) -> void:
	if _calm == null or world == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	var since := Time.get_ticks_msec() / 1000.0 - Game.last_combat_time
	var want := 1.0 if since < 6.0 else 0.0
	if world.hud and world.hud.boss_panel.visible:
		want = 1.3
	_mix = move_toward(_mix, want, real * 0.6)
	var vol := float(Game.settings.get("music", 0.7))
	var lin_calm := clampf(1.0 - _mix, 0.0, 1.0) * vol * 0.5
	var lin_combat := clampf(_mix, 0.0, 1.3) * vol * 0.5
	_calm.volume_db = linear_to_db(maxf(lin_calm, 0.0001))
	_combat.volume_db = linear_to_db(maxf(lin_combat, 0.0001))
