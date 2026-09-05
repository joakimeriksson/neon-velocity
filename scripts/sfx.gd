extends Node

## Autoload. One-shot sound effects from res://audio/sfx/<name>.(wav|ogg).
## Missing files are silently skipped, so the game runs before any audio exists.
## Names used by the game: countdown_tick, countdown_go, lap, finish, boost, wall_hit.

const SFX_DIR := "res://audio/sfx"

@export var volume_db := -6.0

var _streams := {}


func _ready() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".import")
		if name.get_extension() in ["wav", "ogg"]:
			_streams[name.get_basename()] = load(SFX_DIR.path_join(name))


func has(name: String) -> bool:
	return _streams.has(name)


## Non-positional (UI / player-relative).
func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not _streams.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## Positional, in the 3D world.
func play_at(name: String, position: Vector3, pitch := 1.0, db := 0.0) -> void:
	if not _streams.has(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + db
	p.unit_size = 12.0
	p.max_db = 3.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = position
	p.play()
