extends Node

## Autoload. One-shot sound effects, in priority order:
##   1. a res://audio/sfx/<name>.(wav|ogg) file,
##   2. a gamesynth event generator (GENERATORS): layered, a little different on every
##      trigger, shaped by `power` (how hard) and `distance` (how far from the listener),
##   3. a hand-made gamesynth patch (SfxPatches), for sounds with no generator (the pad bell),
##   4. a WAV synthesised here at startup (fallback without the extension).

const SFX_DIR := "res://audio/sfx"
## Event name -> [generator name or res:// model file, preset ("" = default), level in dB].
const GENERATORS := {
	"countdown_tick": ["beep", "", 0.0],
	"countdown_go": ["beep", "Go", 2.0],
	"energy_low": ["beep", "Warning", -2.0],
	"lock_on": ["lock_on", "Incoming!", 2.0],
	"lap": ["res://audio/models/checkpoint.toml", "", 0.0],
	"pickup": ["pickup", "", 0.0],
	"absorb": ["pickup", "Energy cell", 0.0],
	"boost": ["boost", "", 0.0],
	"turbo": ["boost", "Turbo", 2.0],
	"airbrake": ["airbrake", "", -4.0],
	"wall_hit": ["impact", "", 2.0],
	"ship_hit": ["impact", "Glancing", 0.0],
	"landing": ["impact", "Heavy slam", 2.0],
	"rocket_fire": ["rocket", "", 0.0],
	"missile_fire": ["rocket", "Heavy missile", 0.0],
	"mine_drop": ["mine_drop", "Cluster", 0.0],
	"mine_blast": ["mine_blast", "", 2.0],
	"explosion": ["explosion", "", 2.0],
	"explosion_big": ["explosion", "Ship destroyed", 5.0],
	"shield_on": ["shield_up", "", 0.0],
	"shield_block": ["shield_hit", "", 0.0],
	"rescue": ["shield_up", "Autopilot engage", 0.0],
}
const RATE := 44100

@export var volume_db := -14.0
## Positional events belong to other ships unless the caller says otherwise; four rivals
## whooshing, landing and trading paint would otherwise bury the music and the player's own sounds.
@export var others_db := -7.0
## Most effect players alive at once. Past this, other ships' positional sounds are dropped;
## the player's own always play.
@export var max_voices := 36

var _streams := {}
var _levels := {}   # name -> dB trim for generator streams


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
	var generator := _make_generator(name)
	if generator:
		_streams[name] = generator
		return generator
	var synth := SfxPatches.make_stream(name)
	if synth:
		_streams[name] = synth
		return synth
	var generated := _generate(name)
	if generated:
		_streams[name] = generated
	return generated


func _make_generator(name: String) -> AudioStream:
	if not GENERATORS.has(name) or not ClassDB.class_exists("SoundGenerator"):
		return null
	var spec: Array = GENERATORS[name]
	var source: String = spec[0]
	var gen = ClassDB.class_call_static("SoundGenerator", "from_file" if source.begins_with("res://") else "create", source)
	if gen == null or gen.get_error() != "":
		push_warning("Sfx: generator '%s' unavailable: %s" % [source, gen.get_error() if gen else "null"])
		return null
	if spec[1] != "":
		gen.preset = spec[1]
	_levels[name] = float(spec[2])
	return gen


## Generators are shared between their players; these apply to the next play().
func _shape(name: String, stream: AudioStream, power: float, distance: float) -> void:
	if _levels.has(name):
		stream.set_start_input("power", clampf(power, 0.0, 1.0))
		stream.set_start_input("distance", clampf(distance, 0.0, 1.0))


## Non-positional (UI / player-relative). `power` 0..1 shapes a generator's sound.
func play(name: String, pitch := 1.0, db := 0.0, power := 1.0) -> void:
	var stream := _stream_for(name)
	if stream == null:
		return
	_shape(name, stream, power, 0.0)
	db += _levels.get(name, 0.0)
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # synthesised streams can't be browser samples
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	_expire(p, stream)


## Positional, in the 3D world. `unit_size` is the distance at which falloff starts.
func play_at(name: String, position: Vector3, pitch := 1.0, db := 0.0, unit_size := 12.0, power := 1.0, own := false) -> void:
	if get_child_count() >= max_voices:
		return
	var stream := _stream_for(name)
	if stream == null:
		return
	# Godot handles the loudness falloff; the generator handles how distance dulls the sound.
	var camera := get_viewport().get_camera_3d()
	var far := camera.global_position.distance_to(position) / 300.0 if camera else 0.0
	_shape(name, stream, power, far)
	db += _levels.get(name, 0.0) + (0.0 if own else others_db)
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # synthesised streams can't be browser samples
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.unit_size = unit_size
	p.max_db = 0.0   # never louder than its set level, however close
	p.max_distance = 600.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = position
	p.play()
	_expire(p, stream)


## gamesynth's one-shots go silent when they end but keep filling the buffer, so Godot never
## sees them finish and `finished` never fires. Ask the playback directly and free the player.
func _process(_delta: float) -> void:
	for p in get_children():
		if p.is_queued_for_deletion() or not p.has_method("get_stream_playback") or not p.playing:
			continue
		var playback: AudioStreamPlayback = p.get_stream_playback()
		if playback and playback.has_method("is_playing") and not playback.is_playing():
			p.queue_free()


## Safety net: whatever the stream does, a one-shot's player is gone shortly after its length.
func _expire(player: Node, stream: AudioStream) -> void:
	var length := stream.get_length()
	var life := (length if length > 0.0 else 8.0) + 2.0
	get_tree().create_timer(life).timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free())


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
		# Combat, for builds without the synth extension.
		"rocket_fire", "missile_fire":
			return _whoosh()
		"explosion":
			return _impact()
		"mine_drop", "shield_block":
			return _clank()
		"shield_on":
			return _chime([587.3, 880.0, 1174.7], 0.06, 0.4)
		"pickup":
			return _chime([784.0, 1174.7], 0.07, 0.4)
		"recharge":
			return _tone_blip([523.3], 0.1, 0.4, 30.0)
		"energy_low":
			return _tone_blip([440.0], 0.12, 0.45, 20.0)
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
