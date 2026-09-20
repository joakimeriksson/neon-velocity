extends Node

## Autoload. Player settings: volumes, video, comfort options. Saved in user://settings.cfg.
## Volumes are 0..1 sliders. Music, effects and engines sit at 0.8 by default, which is the
## mix as designed; above that is up to +4 dB of boost. Master tops out at the designed level.

signal changed(key: String)

const PATH := "user://settings.cfg"
const QUALITY := [["Performance", 0.5], ["Balanced", 0.6], ["Sharp", 0.8], ["Native", 1.0]]
const DEFAULTS := {
	"audio/master": 1.0,
	"audio/music": 0.8,
	"audio/effects": 0.8,
	"audio/engines": 0.8,
	"video/fullscreen": false,
	"video/quality": -1,        # -1 = leave the project's render scale alone
	"game/rumble": true,
	"game/camera_shake": true,
	"game/show_controls": true,
}
const BUSES := {"audio/master": "Master", "audio/music": "Music", "audio/effects": "SFX", "audio/engines": "Engines"}

var _values := {}
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_engines_bus()
	# Five engines, explosions and music can add up past full scale; catch it before it clips.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	_values = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for key in DEFAULTS:
			var parts: PackedStringArray = key.split("/")
			_values[key] = file.get_value(parts[0], parts[1], DEFAULTS[key])
	for key in _values:
		_apply(key)


func get_value(key: String):
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_dirty = true
	_apply(key)
	changed.emit(key)


func reset() -> void:
	for key in DEFAULTS:
		set_value(key, DEFAULTS[key])


func save() -> void:
	if not _dirty:
		return
	var file := ConfigFile.new()
	for key in _values:
		var parts: PackedStringArray = key.split("/")
		file.set_value(parts[0], parts[1], _values[key])
	file.save(PATH)
	_dirty = false


## Index into QUALITY that matches what the game is rendering at right now.
func current_quality() -> int:
	var chosen: int = _values["video/quality"]
	if chosen >= 0:
		return chosen
	var scale := get_tree().root.scaling_3d_scale
	var best := 0
	for i in QUALITY.size():
		if absf(QUALITY[i][1] - scale) < absf(QUALITY[best][1] - scale):
			best = i
	return best


## Engines get their own fader, separate from the other effects.
func _ensure_engines_bus() -> void:
	if AudioServer.get_bus_index("Engines") >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, "Engines")
	AudioServer.set_bus_send(index, "Master")


func _apply(key: String) -> void:
	if BUSES.has(key):
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus < 0:
			return
		var v: float = _values[key]
		var reference := 1.0 if key == "audio/master" else 0.8
		AudioServer.set_bus_mute(bus, v <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(pow(v / reference, 2.0), 0.00001)))
		return
	match key:
		"video/fullscreen":
			if OS.has_feature("web") or OS.has_feature("movie") or DisplayServer.get_name() == "headless":
				return
			var want := DisplayServer.WINDOW_MODE_FULLSCREEN if _values[key] else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
		"video/quality":
			var index: int = _values[key]
			if index >= 0:
				get_tree().root.scaling_3d_scale = QUALITY[clampi(index, 0, QUALITY.size() - 1)][1]
