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

var _shake := 0.0


func shake(amount: float) -> void:
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


var _fwd_smooth := Vector3.FORWARD
var _offset := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not target:
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
	global_position = t.origin + _offset
	if _shake > 0.001:
		global_position += (t.basis.x * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) * _shake * shake_strength
		_shake *= exp(-7.0 * delta)
	look_at(t.origin + fwd * look_ahead, up)
	var s := target.speed / target.max_speed
	fov = lerpf(fov, base_fov + speed_fov * s, minf(4.0 * delta, 1.0))
