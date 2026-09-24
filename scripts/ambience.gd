class_name Ambience
extends Node

## The continuous sounds around the player, all gamesynth generators driven by game state:
## rain on the circuits that have it (sheltered in tunnels), wind that rises with speed, and
## the pit lane's recharge hum. Does nothing without the extension.

var race: Race

var _rain   # SoundGeneratorPlayback
var _wind
var _recharge
# Landscape circuits: beds that follow the zone the player is in.
var _crowd
var _shore
var _crowd_player: AudioStreamPlayer
var _shore_player: AudioStreamPlayer


func setup(p_race: Race, env: Dictionary) -> void:
	race = p_race
	if not ClassDB.class_exists("SoundGenerator") or OS.has_environment("AG_NO_AMBIENCE"):
		set_process(false)
		return
	if env.get("rain", false):
		_rain = _start("rain", "", -16.0)
	_wind = _start("wind", "", -14.0)
	_recharge = _start("res://audio/models/recharge.toml", "", -5.0)
	if race.landscape:
		_crowd = _start("crowd", "Stadium", -80.0)
		_crowd_player = _last
		_shore = _start("ocean", "Lake shore", -80.0)
		_shore_player = _last


func _start(source: String, preset: String, db: float):
	var gen = ClassDB.class_call_static("SoundGenerator", "from_file" if source.begins_with("res://") else "create", source)
	if gen == null or gen.get_error() != "":
		push_warning("Ambience: '%s' unavailable: %s" % [source, gen.get_error() if gen else "null"])
		return null
	if preset != "":
		gen.preset = preset
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.bus = &"SFX"
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	p.volume_db = db
	add_child(p)
	p.play()
	_last = p
	return p.get_stream_playback()


var _last: AudioStreamPlayer


func _process(_delta: float) -> void:
	var ship := race.player
	if ship == null:
		return
	if race.landscape:
		_zone_beds(ship)
	var speed := clampf(ship.speed / ship.max_speed, 0.0, 1.2)
	var sheltered := race.track.in_tunnel(ship.frame_hint)
	if _rain:
		_rain.set_inputs({"intensity": 0.65, "shelter": 1.0 if sheltered else 0.0})
	if _wind and not race.landscape:
		# Flying, the hull is out in the open air: gustier.
		_wind.set_inputs({"strength": minf(speed, 1.0) * (0.35 if sheltered else 1.0), "gustiness": 0.25 if ship.grounded else 0.7})
	if _recharge:
		_recharge.set_inputs({"active": 1.0 if ship.recharging else 0.0, "charge": ship.energy / ship.max_energy})


## The crowd swells past the grandstands; water laps along the lake and the docks; the wind
## picks up on the cliff road and over the mountain.
func _zone_beds(ship: Ship) -> void:
	var land := race.landscape
	var n := race.track.frames.size()
	var from_line := mini(ship.frame_hint, n - ship.frame_hint)
	var near_stands := clampf(1.0 - (from_line - 40) / 110.0, 0.0, 1.0)
	if _crowd:
		_crowd.set_inputs({"size": 1.0, "excitement": 0.55 + 0.4 * near_stands})
		_crowd_player.volume_db = -16.0 + linear_to_db(maxf(near_stands, 0.001))
	var water := land.zone_weight(ship.frame_hint, "causeway") + 0.5 * land.zone_weight(ship.frame_hint, "docks") + 0.35 * land.zone_weight(ship.frame_hint, "city")
	if _shore:
		_shore.set_inputs({"size": 0.4, "distance": 0.35})
		_shore_player.volume_db = -18.0 + linear_to_db(maxf(minf(water, 1.0), 0.001))
	if _wind:
		var exposed := land.zone_weight(ship.frame_hint, "cliff") + 0.6 * land.zone_weight(ship.frame_hint, "mountain")
		_wind.set_inputs({"strength": minf(ship.speed / ship.max_speed, 1.0) * (0.7 + 0.5 * exposed), "gustiness": 0.3 + 0.5 * exposed})


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
