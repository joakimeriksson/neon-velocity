class_name AIDriver
extends Node

## Drives the parent Ship along the track centre line (offset by `lane`),
## airbraking into sharp corners. `skill` scales top speed so the field spreads out.
## Also plays the combat game: fires what it picks up when it has a target, and dives
## into the pit lane when energy runs low.

@export var skill := 1.0
@export var lane := 0.0
@export var base_look_ahead := 6.0     ## frames ahead at standstill
@export var speed_look_ahead := 0.12   ## extra frames per m/s

@export var pit_below := 55.0          ## head for the pit lane under this much energy
## Corner speed is `corner_grip * sqrt(radius)` m/s: 40 m hairpin -> ~50 m/s, 130 m sweeper -> flat out.
@export var corner_grip := 7.6
@export var braking := 45.0            ## m/s^2 the AI counts on when judging a braking point

var track: TrackBuilder
@onready var ship: Ship = get_parent()

var _held := 0.0      ## seconds the current item has been in the slot
var _patience := 2.0  ## how long to look for a good shot before just using it


func setup(p_track: TrackBuilder, p_skill: float, p_lane: float) -> void:
	track = p_track
	skill = p_skill
	lane = p_lane
	ship.max_speed *= skill
	ship.thrust *= skill


func _physics_process(delta: float) -> void:
	if not track:
		return
	var n := track.frames.size()
	var i := track.get_nearest_frame_index(ship.global_position, ship.frame_hint)
	ship.frame_hint = i
	var ahead := int(base_look_ahead + ship.speed * speed_look_ahead)
	var f := track.frames[(i + ahead) % n]
	var target := f.origin + f.basis.x * _lane_at(float((i + ahead) % n) / n)
	_use_items(delta)
	var local := ship.to_local(target)
	# Target to the right (+x) means steer right, which is negative steer.
	var steer := clampf(-local.x * 0.2, -1.0, 1.0)
	ship.steer_in = steer
	# Brake for what's coming: the fastest speed now that still lets the ship slow to each
	# upcoming corner's speed by the time it gets there.
	var allowed := INF
	var reach := int(ship.speed * 2.2 / track.step) + 4
	for k in range(0, reach, 2):
		var corner_speed := corner_grip * skill * sqrt(track.radius[(i + k) % n])
		allowed = minf(allowed, sqrt(corner_speed * corner_speed + 2.0 * braking * k * track.step))
	var too_fast := ship.speed > allowed
	ship.throttle_in = 0.0 if too_fast else 1.0
	ship.brake_in = clampf((ship.speed - allowed) / 8.0, 0.0, 1.0) if too_fast else 0.0
	# Sharp corner coming: airbrake on the inside to tighten the line.
	var corner := absf(steer) > 0.7 and ship.speed > ship.max_speed * 0.5
	ship.airbrake_l = corner and steer > 0.0
	ship.airbrake_r = corner and steer < 0.0


## Normal lane, or the pit lane when the ship needs energy and the lane is coming up.
func _lane_at(fraction: float) -> float:
	if ship.energy < pit_below and fraction > track.pit_lane[0] - 0.07 and fraction < track.pit_lane[1]:
		var band := track.pit_band()
		return band[0] * 0.55 + band[1] * 0.45
	return lane


func _use_items(delta: float) -> void:
	if ship.item == Items.NONE:
		_held = 0.0
		return
	if _held == 0.0:
		_patience = randf_range(1.5, 6.0)
	_held += delta
	var race := ship.get_parent() as Race
	if race == null or _held < 0.6:
		return
	var fire := _held > _patience
	match ship.item:
		Items.ROCKET:
			var victim := race.ship_ahead(ship, 140.0)
			fire = fire or (victim != null and absf(victim.track_lateral - ship.track_lateral) < 3.0)
		Items.MISSILE:
			fire = race.ship_ahead(ship, 300.0) != null or _held > _patience + 4.0
		Items.MINE:
			fire = fire or race.ship_behind(ship, 70.0) != null
		Items.SHIELD:
			fire = fire or ship.energy < 50.0
		Items.TURBO:
			fire = fire and absf(ship.steer_in) < 0.3
	if fire:
		# Low on energy with nothing to shoot at: bank the item instead.
		if ship.energy < 30.0 and ship.item != Items.SHIELD:
			ship.absorb_item()
		else:
			ship.use_item()
