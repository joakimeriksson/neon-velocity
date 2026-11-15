class_name PlayerDriver
extends Node

## Feeds keyboard/gamepad input into the parent Ship.

## Two taps of the same airbrake within this many seconds is a side-shift that way.
const DOUBLE_TAP := 0.28

@onready var ship: Ship = get_parent()

var _last_tap := {"airbrake_left": -1.0, "airbrake_right": -1.0}
var _clock := 0.0


func _physics_process(delta: float) -> void:
	_clock += delta
	for action in _last_tap:
		if Input.is_action_just_pressed(action):
			if _clock - _last_tap[action] < DOUBLE_TAP:
				ship.side_shift(-1.0 if action == "airbrake_left" else 1.0)
				_last_tap[action] = -1.0
			else:
				_last_tap[action] = _clock
	ship.throttle_in = Input.get_action_strength("accelerate")
	ship.brake_in = Input.get_action_strength("brake")
	ship.steer_in = Input.get_axis("steer_right", "steer_left")
	ship.airbrake_l = Input.is_action_pressed("airbrake_left")
	ship.airbrake_r = Input.is_action_pressed("airbrake_right")
	if Input.is_action_just_pressed("fire"):
		ship.use_item()
	if Input.is_action_just_pressed("absorb"):
		ship.absorb_item()
