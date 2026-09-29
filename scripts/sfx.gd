extends Node
## Every sound in the game, synthesised from arithmetic when the game starts —
## no sound files, so nothing to license. Call Sfx.play("thud").

const RATE := 22050
const VOICES := 10

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	sounds["launch"] = _make(0.35, _launch)
	sounds["creak"] = _make(0.18, _creak)
	sounds["wood"] = _make(0.22, _wood)
	sounds["stone"] = _make(0.25, _stone)
	sounds["ice"] = _make(0.3, _ice)
	sounds["break"] = _make(0.4, _break)
	sounds["boing"] = _make(0.3, _boing)
	sounds["hup"] = _make(0.22, _hup)
	sounds["king"] = _make(0.6, _king)
	sounds["win"] = _make(1.3, _win)
	sounds["lose"] = _make(1.4, _lose)
	sounds["click"] = _make(0.06, _click)
	sounds["splash"] = _make(0.6, _splash)


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not sounds.has(name):
		return
	var p := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = sounds[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s: float = clamp(fn.call(t, t / seconds), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _noise() -> float:
	return randf() * 2.0 - 1.0


# Each recipe gets t (seconds) and k (0..1 through the sound).

func _launch(t: float, k: float) -> float:
	# A whoosh: noise that swells then fades, pitch sliding down through a wobble.
	var env := sin(PI * k) * (1.0 - k)
	return _noise() * env * 0.5 + sin(TAU * (500.0 - 380.0 * k) * t) * env * 0.25


func _creak(t: float, k: float) -> float:
	# Wood straining as the catapult arm is pulled back.
	var buzz: float = sign(sin(TAU * (90.0 + 30.0 * sin(k * 20.0)) * t))
	return buzz * 0.18 * sin(PI * k)


func _wood(t: float, k: float) -> float:
	# A hollow knock: a low tone with a thump of noise on top.
	var env := exp(-k * 9.0)
	return (sin(TAU * 180.0 * t) * 0.7 + sin(TAU * 290.0 * t) * 0.3 + _noise() * 0.35 * exp(-k * 30.0)) * env


func _stone(t: float, k: float) -> float:
	# A dull clack: very short, very low.
	var env := exp(-k * 12.0)
	return (sin(TAU * 95.0 * t) * 0.6 + _noise() * 0.6 * exp(-k * 25.0)) * env


func _ice(t: float, k: float) -> float:
	# A glassy tink: two high tones ringing.
	var env := exp(-k * 7.0)
	return (sin(TAU * 1760.0 * t) * 0.35 + sin(TAU * 2637.0 * t) * 0.25 + _noise() * 0.2 * exp(-k * 40.0)) * env


func _break(t: float, k: float) -> float:
	# A crunch: crackling noise bursts over a falling tone.
	var crackle: float = _noise() * (0.5 + 0.5 * sign(sin(TAU * 37.0 * t)))
	return (crackle * 0.6 + sin(TAU * (160.0 - 90.0 * k) * t) * 0.3) * exp(-k * 5.0)


func _boing(t: float, k: float) -> float:
	# A cartoon spring: a tone whose pitch bounces up and down.
	var f := 220.0 + 160.0 * sin(k * 18.0) * (1.0 - k)
	return sin(TAU * f * t) * 0.45 * (1.0 - k)


func _hup(t: float, k: float) -> float:
	# The knight's "hup!": a buzzy vowel that bends upward.
	var f := 180.0 + 120.0 * k
	var v := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.3 * sin(TAU * f * 3.0 * t)
	return v * 0.25 * sin(PI * k)


func _king(t: float, k: float) -> float:
	# The king's indignant "hmph-oh!": a falling wail.
	var f := 520.0 - 300.0 * k + 12.0 * sin(TAU * 7.0 * t)
	var v := sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t)
	return v * 0.3 * sin(PI * min(k * 1.4, 1.0))


func _win(t: float, _k: float) -> float:
	# A fanfare: four rising notes, the last one held.
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var idx: int = min(int(t / 0.16), 3)
	var local := t - idx * 0.16
	var f: float = notes[idx]
	var env := exp(-local * (6.0 if idx < 3 else 1.6))
	return (sin(TAU * f * t) * 0.5 + sign(sin(TAU * f * t)) * 0.12) * env


func _lose(t: float, _k: float) -> float:
	# The sad trombone: wah, wah, wah, waaah.
	var notes := [311.13, 293.66, 277.18, 261.63]
	var idx: int = min(int(t / 0.3), 3)
	var local := t - idx * 0.3
	var f: float = notes[idx] * (1.0 + (0.02 * sin(TAU * 6.0 * t) if idx == 3 else 0.0))
	var env: float = min(local * 20.0, 1.0) * (exp(-local * 3.0) if idx < 3 else exp(-local * 1.2))
	var v := sin(TAU * f * t) + 0.6 * sin(TAU * f * 2.0 * t) + 0.3 * sin(TAU * f * 3.0 * t)
	return v * 0.22 * env


func _click(t: float, k: float) -> float:
	return sin(TAU * 900.0 * t) * (1.0 - k) * 0.4


func _splash(t: float, k: float) -> float:
	# A plop into the moat, then fizzing water.
	var plop := sin(TAU * (300.0 + 500.0 * k) * t) * exp(-k * 25.0)
	return plop * 0.5 + _noise() * 0.35 * exp(-k * 4.0) * min(k * 20.0, 1.0)
