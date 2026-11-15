extends Node

## Autoload: cross-scene state and the flow Title -> Race -> Highscores -> Title.
## AG_TRACK=<n> env var picks a circuit for headless runs.

const TITLE := "NEON VELOCITY"
const POSITION_POINTS := [1000, 700, 500, 350, 200]
## Speed classes. `scale` rescales time for every ship (see Ship.apply_speed_class): the
## circuits drive the same, only faster. Each class keeps its own high-score tables.
const CLASSES := [
	{"name": "Pulse", "scale": 0.86, "blurb": "Learn the circuits. About 290 km/h."},
	{"name": "Surge", "scale": 1.0, "blurb": "The league standard. About 340 km/h."},
	{"name": "Hyper", "scale": 1.14, "blurb": "For the fearless. About 390 km/h."},
]
## Championship points by finishing position; an eliminated ship scores nothing.
const CHAMP_POINTS := [10, 7, 5, 3, 1]

var track_index := 0
## True while a race scene is only a moving backdrop for the title screen.
var attract := false
## Filled in by Race when the player finishes; consumed by the highscore screen.
var last_result := {}
## Index into CLASSES.
var speed_class := 1
## "single": one race, then the circuit's high-score table. "championship": every circuit
## in order, points per race, the table at the end.
var mode := "single"
var champ_round := 0
var champ_points := {}     ## ship name -> points so far
var champ_score := 0       ## the player's race scores, added up
var champ_time := 0.0
var champ_recorded := false


func _ready() -> void:
	_fit_window_to_screen()
	if OS.has_environment("AG_TRACK"):
		track_index = clampi(int(OS.get_environment("AG_TRACK")), 0, TrackDefs.ALL.size() - 1)
	speed_class = clampi(int(Settings.get_value("game/speed_class")), 0, CLASSES.size() - 1)
	if OS.has_environment("AG_CLASS"):
		speed_class = clampi(int(OS.get_environment("AG_CLASS")), 0, CLASSES.size() - 1)
	# Dev: AG_CHAMP=1 makes a directly loaded race scene round one of a championship.
	if OS.has_environment("AG_CHAMP"):
		mode = "championship"


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
	mode = "single"
	_load_race(index)


## Same circuit again; in a championship, the same round.
func restart_race() -> void:
	_load_race(track_index)


func _load_race(index: int) -> void:
	track_index = clampi(index, 0, TrackDefs.ALL.size() - 1)
	attract = false
	last_result = {}
	champ_recorded = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func set_speed_class(index: int) -> void:
	speed_class = clampi(index, 0, CLASSES.size() - 1)
	Settings.set_value("game/speed_class", speed_class)
	Settings.save()


func class_scale() -> float:
	return CLASSES[speed_class].scale


func class_name_text() -> String:
	return CLASSES[speed_class].name


## High-score tables are per circuit and class. The standard class keeps the plain circuit
## name, which is what tables saved before classes existed are filed under.
func table_key(track_name: String, class_index := -1) -> String:
	var index := speed_class if class_index < 0 else class_index
	return track_name if index == 1 else "%s [%s]" % [track_name, CLASSES[index].name]


# --- Championship --------------------------------------------------------------------

func start_championship() -> void:
	mode = "championship"
	champ_round = 0
	champ_points = {}
	champ_score = 0
	champ_time = 0.0
	_load_race(0)


func champ_rounds() -> int:
	return TrackDefs.ALL.size()


## Called by Race once the order is settled: `order` is ship names from first to last,
## `out` the names that were eliminated. Safe to call again as late finishers come in.
func champ_record(order: Array, out: Array, player_score: int, player_time: float) -> void:
	if mode != "championship":
		return
	if champ_recorded:
		# Undo this round's earlier provisional entry before writing the settled one.
		for name in _round_points:
			champ_points[name] = int(champ_points.get(name, 0)) - int(_round_points[name])
		champ_score -= _round_score
		champ_time -= _round_time
	_round_points = {}
	for i in order.size():
		var points: int = 0 if out.has(order[i]) else CHAMP_POINTS[clampi(i, 0, CHAMP_POINTS.size() - 1)]
		_round_points[order[i]] = points
		champ_points[order[i]] = int(champ_points.get(order[i], 0)) + points
	_round_score = player_score
	_round_time = player_time
	champ_score += player_score
	champ_time += player_time
	champ_recorded = true


var _round_points := {}
var _round_score := 0
var _round_time := 0.0


func champ_round_points(name: String) -> int:
	return int(_round_points.get(name, 0))


## Names by points, highest first.
func champ_standings() -> Array:
	var names: Array = champ_points.keys()
	# Level on points: whoever did better in the latest round is ahead.
	names.sort_custom(func(a, b):
		if int(champ_points[a]) != int(champ_points[b]):
			return int(champ_points[a]) > int(champ_points[b])
		return champ_round_points(a) > champ_round_points(b))
	return names


func champ_is_last_round() -> bool:
	return champ_round >= champ_rounds() - 1


## After a round's results: the next circuit, or the final table.
func champ_continue() -> void:
	if not champ_is_last_round():
		champ_round += 1
		_load_race(champ_round)
		return
	var standing: int = champ_standings().find("You") + 1
	# The title is worth as much again as a good race.
	var bonus: int = [1500, 800, 400, 0, 0][clampi(standing - 1, 0, 4)]
	last_result = {
		"track": "Championship",
		"position": standing,
		"time": champ_time,
		"best_lap": 0.0,
		"score": {"total": champ_score + bonus},
	}
	mode = "single"
	to_highscores()


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
	# Par is measured in the standard class; a faster class has less time to beat.
	var par_lap: float = track.get("par_lap", 30.0) / track.get("class_scale", 1.0)
	var par: float = par_lap * laps
	var time_bonus := maxi(0, roundi((par - race_time) * 25.0))
	var lap_bonus := 250 if best_lap > 0.0 and best_lap < par_lap * 0.97 else 0
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
