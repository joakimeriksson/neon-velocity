extends Node

## Autoload. The race announcer: short spoken lines from res://audio/voice/<line>.(wav|ogg),
## one at a time, with the music dipping underneath. Every file is optional: a line with no
## file is simply not said, so the game runs the same without the folder.
## `tools/voice/make_voice.sh` makes the set with VoxCPM2 on the Spark.

const VOICE_DIR := "res://audio/voice"
const DUCK_DB := -5.0

@export var volume_db := -3.0

var _lines := {}
var _player: AudioStreamPlayer
var _pending := ""
var _pending_wait := 0.0
var _duck: AudioEffectAmplify
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Voice" if AudioServer.get_bus_index("Voice") >= 0 else &"SFX"
	_player.volume_db = volume_db
	_player.finished.connect(_on_finished)
	add_child(_player)
	var dir := DirAccess.open(VOICE_DIR)
	if dir:
		for file in dir.get_files():
			var name := file.trim_suffix(".import")
			if name.get_extension() in ["wav", "ogg"]:
				_lines[name.get_basename()] = VOICE_DIR.path_join(name)
	var music := AudioServer.get_bus_index("Music")
	if music >= 0 and not _lines.is_empty():
		_duck = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(music, _duck)


func has(line: String) -> bool:
	return _lines.has(line)


## Say a line, after `delay` seconds. A line already being spoken is finished first; only
## the newest waiting line is kept, so the announcer never falls behind the race.
func say(line: String, delay := 0.0) -> void:
	if not _lines.has(line) or Game.attract:
		return
	_pending = line
	_pending_wait = delay


func _process(delta: float) -> void:
	if _pending == "":
		return
	_pending_wait -= delta
	if _pending_wait > 0.0 or _player.playing:
		return
	var stream := load(_lines[_pending]) as AudioStream
	_pending = ""
	if stream == null:
		return
	_player.stream = stream
	_player.play()
	_set_duck(DUCK_DB, 0.12)


func _on_finished() -> void:
	if _pending == "" or _pending_wait > 0.3:
		_set_duck(0.0, 0.5)


func _set_duck(db: float, seconds: float) -> void:
	if _duck == null:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_duck, ^"volume_db", db, seconds)
