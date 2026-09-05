extends Camera3D

## Chase camera: sits behind and above the ship in the ship's own frame
## (so it rolls with banked track), looks a little ahead, and widens the FOV with speed.

@export var target: Ship
@export var distance := 8.5
@export var height := 2.8
@export var look_ahead := 10.0
@export var follow_speed := 9.0
@export var base_fov := 75.0
@export var speed_fov := 20.0
@export var shake_strength := 0.7

var _shake := 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _ready() -> void:
	if target:
		_snap()


func _snap() -> void:
	var t := target.global_transform
	global_position = t.origin + t.basis.z * distance + t.basis.y * height
	look_at(t.origin - t.basis.z * look_ahead, t.basis.y)


func _physics_process(delta: float) -> void:
	if not target:
		return
	var t := target.global_transform
	var fwd := -t.basis.z
	var up := t.basis.y
	var desired := t.origin - fwd * distance + up * height
	var k := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired, k)
	if _shake > 0.001:
		global_position += (t.basis.x * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) * _shake * shake_strength
		_shake *= exp(-7.0 * delta)
	look_at(t.origin + fwd * look_ahead, up)
	var s := target.speed / target.max_speed
	fov = lerpf(fov, base_fov + speed_fov * s, minf(4.0 * delta, 1.0))
