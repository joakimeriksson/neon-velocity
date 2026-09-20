class_name Ambience
extends Node

## The continuous sounds around the player, all gamesynth generators driven by game state:
## rain on the circuits that have it (sheltered in tunnels), wind that rises with speed, and
## the pit lane's recharge hum. Does nothing without the extension.

var race: Race

var _rain   # SoundGeneratorPlayback
var _wind
var _recharge


func setup(p_race: Race, env: Dictionary) -> void:
	race = p_race
	if not ClassDB.class_exists("SoundGenerator"):
		set_process(false)
		return
	if env.get("rain", false):
		_rain = _start("rain", "", -13.0)
	_wind = _start("wind", "", -11.0)
	_recharge = _start("res://audio/models/recharge.toml", "", -5.0)


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
	return p.get_stream_playback()


func _process(_delta: float) -> void:
	var ship := race.player
	if ship == null:
		return
	var speed := clampf(ship.speed / ship.max_speed, 0.0, 1.2)
	var sheltered := race.track.in_tunnel(ship.frame_hint)
	if _rain:
		_rain.set_inputs({"intensity": 0.65, "shelter": 1.0 if sheltered else 0.0})
	if _wind:
		# Flying, the hull is out in the open air: gustier.
		_wind.set_inputs({"strength": minf(speed, 1.0) * (0.35 if sheltered else 1.0), "gustiness": 0.25 if ship.grounded else 0.7})
	if _recharge:
		_recharge.set_inputs({"active": 1.0 if ship.recharging else 0.0, "charge": ship.energy / ship.max_energy})


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
