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

@export var pit_below := 45.0          ## head for the pit lane under this much energy

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
	ship.throttle_in = 1.0
	ship.brake_in = 0.0
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
