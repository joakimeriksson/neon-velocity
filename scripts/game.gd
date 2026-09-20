extends Node

## Autoload: cross-scene state and the flow Title -> Race -> Highscores -> Title.
## AG_TRACK=<n> env var picks a circuit for headless runs.

const TITLE := "NEON VELOCITY"
const POSITION_POINTS := [1000, 700, 500, 350, 200]

var track_index := 0
## True while a race scene is only a moving backdrop for the title screen.
var attract := false
## Filled in by Race when the player finishes; consumed by the highscore screen.
var last_result := {}


func _ready() -> void:
	_fit_window_to_screen()
	if OS.has_environment("AG_TRACK"):
		track_index = clampi(int(OS.get_environment("AG_TRACK")), 0, TrackDefs.ALL.size() - 1)


## The project window is 1920x1080 pixels, which on a Retina display is a 960x540-point
## window with a HUD too small to read. Grow it to most of the screen, keeping 16:9.
func _fit_window_to_screen() -> void:
	if OS.has_feature("web") or OS.has_feature("movie") or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED or DisplayServer.screen_get_scale() < 1.5:
		return
	var usable := DisplayServer.screen_get_usable_rect()
	var height := int(minf(usable.size.y * 0.9, usable.size.x * 0.9 * 9.0 / 16.0))
	var size := Vector2i(height * 16 / 9, height)
	if size.x <= window.size.x:
		return
	window.size = size
	window.position = usable.position + (usable.size - size) / 2


func start_race(index: int) -> void:
	track_index = clampi(index, 0, TrackDefs.ALL.size() - 1)
	attract = false
	last_result = {}
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func to_highscores() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/highscore.tscn")


## Position points, a bonus for beating the circuit's par time, a fast-lap bonus, and combat
## points for weapon hits landed and rivals eliminated.
static func score_for(track: Dictionary, position: int, race_time: float, best_lap: float, laps: int, hits := 0, kills := 0) -> Dictionary:
	var pos_points: int = POSITION_POINTS[clampi(position - 1, 0, POSITION_POINTS.size() - 1)]
	var par: float = track.get("par_lap", 30.0) * laps
	var time_bonus := maxi(0, roundi((par - race_time) * 25.0))
	var lap_bonus := 250 if best_lap > 0.0 and best_lap < track.get("par_lap", 30.0) * 0.97 else 0
	var combat := hits * 75 + kills * 250
	return {
		"position": pos_points,
		"time": time_bonus,
		"lap": lap_bonus,
		"combat": combat,
		"total": pos_points + time_bonus + lap_bonus + combat,
	}


static func controller_name() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return ""
	var raw := Input.get_joy_name(pads[0])
	var lower := raw.to_lower()
	if "dualsense" in lower or "ps5" in lower:
		return "DualSense (PS5)"
	if "dualshock" in lower or "ps4" in lower or "wireless controller" in lower:
		return "DualShock 4"
	if "ps3" in lower or "playstation" in lower:
		return "PlayStation controller"
	return raw
