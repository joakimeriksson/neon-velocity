class_name PlayerDriver
extends Node

## Feeds keyboard/gamepad input into the parent Ship.

@onready var ship: Ship = get_parent()


func _physics_process(_delta: float) -> void:
	ship.throttle_in = Input.get_action_strength("accelerate")
	ship.brake_in = Input.get_action_strength("brake")
	ship.steer_in = Input.get_axis("steer_right", "steer_left")
	ship.airbrake_l = Input.is_action_pressed("airbrake_left")
	ship.airbrake_r = Input.is_action_pressed("airbrake_right")
