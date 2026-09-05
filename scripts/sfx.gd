extends Node

## Autoload. One-shot sound effects, in priority order:
##   1. a res://audio/sfx/<name>.(wav|ogg) file,
##   2. a designed gamesynth patch (SfxPatches) played live by the synth,
##   3. a WAV synthesised here at startup (fallback without the extension).
## Names used by the game: countdown_tick, countdown_go, lap, finish, boost, wall_hit, ship_hit.

const SFX_DIR := "res://audio/sfx"
const RATE := 44100

@export var volume_db := -10.0

var _streams := {}


func _ready() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".import")
		if name.get_extension() in ["wav", "ogg"]:
			_streams[name.get_basename()] = load(SFX_DIR.path_join(name))


func has(name: String) -> bool:
	return _stream_for(name) != null


func _stream_for(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var synth := SfxPatches.make_stream(name)
	if synth:
		_streams[name] = synth
		return synth
	var generated := _generate(name)
	if generated:
		_streams[name] = generated
	return generated


## Non-positional (UI / player-relative).
func play(name: String, pitch := 1.0, db := 0.0) -> void:
	var stream := _stream_for(name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## Positional, in the 3D world.
func play_at(name: String, position: Vector3, pitch := 1.0, db := 0.0) -> void:
	var stream := _stream_for(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.unit_size = 12.0
	p.max_db = 3.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = position
	p.play()


# --- Synthesis ---------------------------------------------------------------------

func _generate(name: String) -> AudioStreamWAV:
	match name:
		"countdown_tick":
			return _tone_blip([660.0], 0.09, 0.45, 40.0)
		"countdown_go":
			return _tone_blip([880.0, 1320.0], 0.35, 0.5, 9.0)
		"lap":
			return _chime([880.0, 1174.7], 0.16, 0.4)
		"finish":
			return _chime([659.3, 880.0, 1318.5, 1760.0], 0.18, 0.45)
		"boost":
			return _whoosh()
		"wall_hit":
			return _impact()
		"ship_hit":
			return _clank()
	return null


## Short decaying sine(s): the countdown lights.
func _tone_blip(freqs: Array, seconds: float, amp: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		var env := exp(-decay * t) * minf(t * 400.0, 1.0)
		out[i] = v / freqs.size() * env * amp
	return _to_wav(out)


## Notes in sequence, each ringing into the next.
func _chime(freqs: Array, step: float, amp: float) -> AudioStreamWAV:
	var seconds := step * freqs.size() + 0.6
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := int(RATE * step * k)
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * freqs[k] * t) + 0.3 * sin(TAU * freqs[k] * 2.0 * t)) * exp(-5.0 * t) * amp * 0.6
	return _to_wav(out)


## Boost pad: filtered noise with a band sweeping up, over a rising sub tone.
func _whoosh() -> AudioStreamWAV:
	var seconds := 0.8
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var hp_state := 0.0
	var a_hp := 1.0 - exp(-TAU * 250.0 / RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := t / seconds
		var white := randf() * 2.0 - 1.0
		var cutoff := 400.0 + 4000.0 * pow(x, 1.5)
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		lp += a * (white - lp)
		lp2 += a * (lp - lp2)
		hp_state += a_hp * (lp2 - hp_state)
		var noise := (lp2 - hp_state) * 4.0
		var env := minf(t * 40.0, 1.0) * exp(-4.0 * maxf(t - 0.15, 0.0))
		var freq := 70.0 + 110.0 * x
		phase += freq / RATE
		var sub := sin(TAU * phase) * exp(-6.0 * t)
		out[i] = (noise * 0.8 + sub * 0.5) * env
	return _to_wav(out)


## Wall strike: bright crunchy noise burst, inharmonic metallic ring-out, low thud, soft-clipped.
func _impact() -> AudioStreamWAV:
	var seconds := 0.7
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [523.0, 1370.0, 2140.0, 3310.0]
	var amps := [1.0, 0.6, 0.4, 0.25]
	var lp := 0.0
	var hp := 0.0
	var a_hp := 1.0 - exp(-TAU * 900.0 / RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := randf() * 2.0 - 1.0
		var cutoff := 1500.0 + 4500.0 * exp(-12.0 * t)
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		lp += a * (white - lp)
		hp += a_hp * (lp - hp)
		var crunch := (lp - hp) * 4.0 * exp(-14.0 * t)
		var ring := 0.0
		for k in partials.size():
			ring += amps[k] * sin(TAU * partials[k] * t * (1.0 + 0.002 * sin(t * 30.0)))
		ring *= 0.35 * exp(-9.0 * t)
		var freq := 110.0 * exp(-9.0 * t) + 42.0
		phase += freq / RATE
		var thud := sin(TAU * phase) * exp(-7.0 * t) * 1.4
		var mixv := (crunch + ring + thud) * minf(t * 600.0, 1.0)
		out[i] = tanh(mixv * 2.4)
	return _to_wav(out)


## Ship-to-ship contact: short metallic clank.
func _clank() -> AudioStreamWAV:
	var seconds := 0.35
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [820.0, 1650.0, 2470.0, 4100.0]
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 3000.0 / RATE)
	for i in n:
		var t := float(i) / RATE
		var white := randf() * 2.0 - 1.0
		lp += a * (white - lp)
		var ring := 0.0
		for k in partials.size():
			ring += sin(TAU * partials[k] * t) / (k + 1.0)
		out[i] = tanh((lp * 2.0 * exp(-40.0 * t) + ring * 0.5 * exp(-14.0 * t)) * 2.0)
	return _to_wav(out)


## Kept for reference: the original dull thud.
func _thud() -> AudioStreamWAV:
	var seconds := 0.3
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 700.0 / RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := randf() * 2.0 - 1.0
		lp += a * (white - lp)
		var freq := 90.0 * exp(-8.0 * t) + 45.0
		phase += freq / RATE
		out[i] = lp * 1.5 * exp(-30.0 * t) + sin(TAU * phase) * exp(-14.0 * t) * 0.9
	return _to_wav(out)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var scale := minf(1.0, 0.9 / peak)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
