class_name AIDriver
extends Node

## Drives the parent Ship along the track centre line (offset by `lane`),
## airbraking into sharp corners. `skill` scales top speed so the field spreads out.

@export var skill := 1.0
@export var lane := 0.0
@export var base_look_ahead := 6.0     ## frames ahead at standstill
@export var speed_look_ahead := 0.12   ## extra frames per m/s

var track: TrackBuilder
@onready var ship: Ship = get_parent()


func setup(p_track: TrackBuilder, p_skill: float, p_lane: float) -> void:
	track = p_track
	skill = p_skill
	lane = p_lane
	ship.max_speed *= skill
	ship.thrust *= skill


func _physics_process(_delta: float) -> void:
	if not track:
		return
	var n := track.frames.size()
	var i := track.get_nearest_frame_index(ship.global_position, ship.frame_hint)
	ship.frame_hint = i
	var ahead := int(base_look_ahead + ship.speed * speed_look_ahead)
	var f := track.frames[(i + ahead) % n]
	var target := f.origin + f.basis.x * lane
	var local := ship.to_local(target)
	# Target to the right (+x) means steer right, which is negative steer.
	var steer := clampf(-local.x * 0.2, -1.0, 1.0)
	ship.steer_in = steer
	ship.throttle_in = 1.0
	ship.brake_in = 0.0
	# Sharp corner coming: airbrake on the inside to tighten the line.
	var corner := absf(steer) > 0.7 and ship.speed > ship.max_speed * 0.5
	ship.airbrake_l = corner and steer > 0.0
	ship.airbrake_r = corner and steer < 0.0
