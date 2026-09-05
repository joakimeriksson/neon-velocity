class_name EngineAudio
extends Node3D

## Layered engine sound for one ship. Each ship plays four loops through positional
## AudioStreamPlayer3Ds with pitch/volume driven by speed, throttle, airbrakes, boosts
## and wall hits. A loop comes from res://audio/engine/<name>.wav if that file exists
## (mono, seamless, ~1 s, at the reference pitch below), otherwise it is synthesised
## at startup. Names: drone (55 Hz), turbine (220 Hz), exhaust_low, exhaust_high.

@export var enabled := true
@export var master_db := -4.0

const RATE := 44100
const LOOP_LEN := RATE  # one second: tones use integer cycle counts so loops are seamless

static var _loops := {}

@onready var ship: Ship = get_parent()

var _drone: AudioStreamPlayer3D
var _turbine: AudioStreamPlayer3D
var _exhaust_low: AudioStreamPlayer3D
var _exhaust_high: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D

var _throttle := 0.0
var _hiss_gain := 0.0
var _boost_env := 0.0
var _impact_env := 0.0


func _ready() -> void:
	if not enabled:
		set_process(false)
		return
	_drone = _make_player("drone", _gen_drone)
	_turbine = _make_player("turbine", _gen_turbine)
	_exhaust_low = _make_player("exhaust_low", _gen_noise_low)
	_exhaust_high = _make_player("exhaust_high", _gen_noise_high)
	_hiss = _make_player("exhaust_high", _gen_noise_high)
	_impact = _make_player("exhaust_low", _gen_noise_low)
	_impact.stop()
	ship.boosted.connect(_on_boost)
	ship.wall_hit.connect(_on_wall_hit)


func _process(delta: float) -> void:
	var speed_ratio := clampf(ship.speed / ship.max_speed, 0.0, 1.3)
	_throttle = lerpf(_throttle, ship.throttle_in, minf(5.0 * delta, 1.0))
	_boost_env *= exp(-2.5 * delta)
	_impact_env *= exp(-9.0 * delta)
	var airbraking := ship.airbrake_l or ship.airbrake_r
	_hiss_gain = lerpf(_hiss_gain, 1.0 if airbraking else 0.0, minf((12.0 if airbraking else 4.0) * delta, 1.0))

	_drone.pitch_scale = 0.85 + speed_ratio * 0.6
	_set_gain(_drone, 0.35 + speed_ratio * 0.15)

	_turbine.pitch_scale = 0.45 + speed_ratio * 1.55 + _boost_env * 0.5
	_set_gain(_turbine, 0.08 + _throttle * 0.32 + _boost_env * 0.2)

	_exhaust_low.pitch_scale = 0.9 + speed_ratio * 0.3
	_set_gain(_exhaust_low, 0.15 + _throttle * 0.25)
	_exhaust_high.pitch_scale = 0.8 + speed_ratio * 0.5
	_set_gain(_exhaust_high, 0.02 + _throttle * _throttle * 0.2 + speed_ratio * 0.06 + _boost_env * 0.35)

	_hiss.pitch_scale = 1.4
	_set_gain(_hiss, _hiss_gain * (0.15 + speed_ratio * 0.3))

	if _impact.playing:
		_set_gain(_impact, _impact_env)
		if _impact_env < 0.01:
			_impact.stop()


func _on_boost() -> void:
	_boost_env = 1.0
	Sfx.play_at("boost", ship.global_position)


func _on_wall_hit(strength: float) -> void:
	_impact_env = clampf(strength * 1.2, 0.2, 1.0)
	Sfx.play_at("wall_hit", ship.global_position, 0.8 + strength * 0.4, -12.0 + strength * 12.0)
	_impact.pitch_scale = 0.6
	if not _impact.playing:
		_impact.play()


func _set_gain(player: AudioStreamPlayer3D, linear: float) -> void:
	player.volume_db = linear_to_db(maxf(linear, 0.0001)) + master_db


func _make_player(loop_name: String, generator: Callable) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _get_loop(loop_name, generator)
	p.bus = &"SFX"
	p.unit_size = 12.0
	p.max_db = 3.0
	p.max_distance = 400.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.volume_db = -80.0
	# Route to SFX so engine noise and music have separate faders.
	if AudioServer.get_bus_index("SFX") >= 0:
		p.bus = &"SFX"
	add_child(p)
	p.play(randf() * 0.9)  # desync ships sharing a loop
	return p


# --- Loop synthesis ---------------------------------------------------------

const LOOP_DIR := "res://audio/engine"


static func _get_loop(loop_name: String, generator: Callable) -> AudioStream:
	if _loops.has(loop_name):
		return _loops[loop_name]
	var path := LOOP_DIR.path_join(loop_name + ".wav")
	if ResourceLoader.exists(path):
		var recorded := load(path) as AudioStreamWAV
		if recorded:
			recorded.loop_mode = AudioStreamWAV.LOOP_FORWARD
			recorded.loop_begin = 0
			recorded.loop_end = recorded.data.size() / (2 if recorded.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if recorded.stereo else 1)
			_loops[loop_name] = recorded
			print("EngineAudio: using recorded loop ", path.get_file())
			return recorded
	var samples := PackedFloat32Array()
	samples.resize(LOOP_LEN)
	generator.call(samples)
	# Seamless join for noise loops: crossfade the tail into the head.
	var fade := 512
	for i in fade:
		var t := float(i) / fade
		var tail := LOOP_LEN - fade + i
		samples[tail] = samples[tail] * (1.0 - t) + samples[i] * t
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(LOOP_LEN * 2)
	for i in LOOP_LEN:
		bytes.encode_s16(i * 2, int(samples[i] / peak * 0.9 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = LOOP_LEN
	wav.data = bytes
	_loops[loop_name] = wav
	return wav


## Low hover drone: 55 Hz with a 56 Hz partner for a slow 1 Hz beat, plus low harmonics.
static func _gen_drone(out: PackedFloat32Array) -> void:
	for i in LOOP_LEN:
		var t := float(i) / RATE
		out[i] = sin(TAU * 55.0 * t) + 0.7 * sin(TAU * 56.0 * t) \
			+ 0.35 * sin(TAU * 110.0 * t) + 0.15 * sin(TAU * 165.0 * t)


## Turbine: 220 Hz with rolling-off harmonics, a bright 7th partial whine, 8 Hz shimmer.
static func _gen_turbine(out: PackedFloat32Array) -> void:
	var phases := []
	for k in 12:
		phases.append(randf() * TAU)
	for i in LOOP_LEN:
		var t := float(i) / RATE
		var v := 0.0
		for k in range(1, 13):
			var amp := 1.0 / pow(k, 1.25)
			if k == 7:
				amp *= 2.5
			v += amp * sin(TAU * 220.0 * k * t + phases[k - 1])
		out[i] = v * (1.0 + 0.12 * sin(TAU * 8.0 * t))


## Dark exhaust rumble: brown noise through a ~350 Hz one-pole low-pass.
static func _gen_noise_low(out: PackedFloat32Array) -> void:
	var brown := 0.0
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 350.0 / RATE)
	for i in LOOP_LEN:
		brown = clampf(brown + (randf() * 2.0 - 1.0) * 0.05, -1.0, 1.0)
		lp += a * (brown - lp)
		out[i] = lp


## Bright exhaust / airbrake hiss: white noise through a ~1500 Hz one-pole high-pass.
static func _gen_noise_high(out: PackedFloat32Array) -> void:
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 1500.0 / RATE)
	for i in LOOP_LEN:
		var white := randf() * 2.0 - 1.0
		lp += a * (white - lp)
		out[i] = white - lp
