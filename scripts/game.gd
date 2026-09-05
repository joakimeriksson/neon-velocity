extends Node

## Autoload: cross-scene state. AG_TRACK=<n> env var picks a circuit for headless runs.

var track_index := 0


func _ready() -> void:
	if OS.has_environment("AG_TRACK"):
		track_index = clampi(int(OS.get_environment("AG_TRACK")), 0, TrackDefs.ALL.size() - 1)


func start_race(index: int) -> void:
	track_index = clampi(index, 0, TrackDefs.ALL.size() - 1)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
