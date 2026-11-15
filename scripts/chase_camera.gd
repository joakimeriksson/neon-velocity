extends Camera3D

## Chase camera: sits behind and above the ship in the ship's own frame
## (so it rolls with banked track), looks a little ahead, and widens the FOV with speed.

@export var target: Ship
@export var distance := 8.5
@export var height := 2.8
@export var look_ahead := 10.0
@export var follow_speed := 11.0
@export var turn_follow := 4.0   ## how quickly the camera swings round behind a turning ship
@export var base_fov := 75.0
@export var speed_fov := 20.0
@export var shake_strength := 0.7

## CHASE is the driving view. INTRO sweeps down over the grid before the countdown.
## ORBIT swings out to the ship's rear quarter once the race is run, and slides the ship
## to the left of the frame so the results panel doesn't sit on top of it.
enum Mode { CHASE, INTRO, ORBIT }

var mode := Mode.CHASE

var _shake := 0.0
var _mode_time := 0.0
var _intro_length := 3.5


func shake(amount: float) -> void:
	if Settings.get_value("game/camera_shake"):
		_shake = maxf(_shake, amount)


func _ready() -> void:
	# Soft fill from the camera so the followed ship's hull always reads, whatever the scene lighting.
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 0.9
	fill.omni_range = 16.0
	fill.omni_attenuation = 1.5
	fill.shadow_enabled = false
	add_child(fill)
	if target:
		_snap()


func _snap() -> void:
	var t := target.global_transform
	_fwd_smooth = -t.basis.z
	_offset = t.basis.z * distance + t.basis.y * height
	global_position = t.origin + t.basis.z * distance + t.basis.y * height
	look_at(t.origin - t.basis.z * look_ahead, t.basis.y)
	_restart_doppler()


var _fwd_smooth := Vector3.FORWARD
var _offset := Vector3.ZERO


## Sweep in from high beyond the start gantry, down past the grid, into the chase position.
func play_intro(seconds: float) -> void:
	mode = Mode.INTRO
	_mode_time = 0.0
	_intro_length = maxf(seconds, 0.1)
	_intro_step()


func end_intro() -> void:
	if mode == Mode.INTRO:
		mode = Mode.CHASE
		_snap()


func orbit() -> void:
	mode = Mode.ORBIT
	_mode_time = 0.0


func _intro_step() -> void:
	var t := target.global_transform
	var fwd := -t.basis.z
	var u := smoothstep(0.0, 1.0, _mode_time / _intro_length)
	var p0 := t.origin + fwd * 88.0 + t.basis.y * 24.0 + t.basis.x * 20.0
	var p1 := t.origin + fwd * 24.0 + t.basis.y * 4.0 - t.basis.x * 5.0
	var p2 := t.origin - fwd * distance + t.basis.y * height
	global_position = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
	var look := t.origin + fwd * lerpf(16.0, look_ahead, u) + t.basis.y * lerpf(1.0, 0.0, u)
	look_at(look, t.basis.y)
	fov = lerpf(52.0, base_fov, u)


func _orbit_step(delta: float) -> void:
	var t := target.global_transform
	var up := t.basis.y
	_fwd_smooth = _fwd_smooth.slerp(-t.basis.z, 1.0 - exp(-turn_follow * delta)).normalized()
	var right := _fwd_smooth.cross(up).normalized()
	# Swing out over three seconds, then sway there. It stays behind the ship and above
	# the walls, where there is always road to stand over.
	var swing := smoothstep(0.0, 3.0, _mode_time)
	var angle := 0.55 * swing + 0.2 * sin(maxf(_mode_time - 3.0, 0.0) * 0.45)
	var desired := (-_fwd_smooth * cos(angle) + right * sin(angle)) * (distance + 1.0) + up * (height + 0.4)
	_offset = _offset.lerp(desired, 1.0 - exp(-6.0 * delta))
	global_position = t.origin + _offset
	h_offset = lerpf(h_offset, 4.6 * swing, minf(3.0 * delta, 1.0))
	v_offset = 0.0
	look_at(t.origin + _fwd_smooth * 4.0 + up * 0.4, up)
	fov = lerpf(fov, 64.0, minf(2.0 * delta, 1.0))


func _physics_process(delta: float) -> void:
	if not target:
		return
	_mode_time += delta
	if mode == Mode.INTRO:
		_intro_step()
		return
	if mode == Mode.ORBIT:
		_orbit_step(delta)
		return
	var t := target.global_transform
	var up := t.basis.y
	# Smooth the heading the camera hangs off, so a sharp turn doesn't fling the ship to
	# the edge of the frame; the ship's own yaw still reads through its bank and drift.
	var raw_fwd := -t.basis.z
	if _fwd_smooth.length_squared() < 0.5:
		_fwd_smooth = raw_fwd
	_fwd_smooth = _fwd_smooth.slerp(raw_fwd, 1.0 - exp(-turn_follow * delta)).normalized()
	var fwd := _fwd_smooth
	# Smooth the offset in the ship's frame, not the world position: a world-space lerp
	# trails further behind the faster the ship goes (17 m at top speed instead of 8.5).
	var desired_offset := -fwd * distance + up * height
	var k := 1.0 - exp(-follow_speed * delta)
	_offset = _offset.lerp(desired_offset, k)
	var before := global_position
	global_position = t.origin + _offset
	# The camera is the audio listener with Doppler tracking. A respawn teleports it, which
	# Godot reads as a burst of speed that blips every engine to its pitch limit: restart the
	# tracking there. Anything past 2.5x top speed in one step is a jump, not driving.
	if before.distance_to(global_position) > maxf(target.max_speed * 2.5 * delta, 1.0):
		_restart_doppler()
	# Shake the view (h/v_offset), not the node: moving the listener every step would make
	# every engine warble through Doppler.
	h_offset = 0.0
	v_offset = 0.0
	if _shake > 0.001:
		h_offset = randf_range(-1.0, 1.0) * _shake * shake_strength
		v_offset = randf_range(-1.0, 1.0) * _shake * shake_strength
		_shake *= exp(-7.0 * delta)
	look_at(t.origin + fwd * look_ahead, up)
	var s := target.speed / target.max_speed
	fov = lerpf(fov, base_fov + speed_fov * s, minf(4.0 * delta, 1.0))


func _restart_doppler() -> void:
	var mode := doppler_tracking
	if mode != DOPPLER_TRACKING_DISABLED:
		doppler_tracking = DOPPLER_TRACKING_DISABLED
		doppler_tracking = mode
