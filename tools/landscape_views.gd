extends Node

## Renders fixed viewpoints of a landscape circuit for review: an overview, then views along the
## lap from behind and above the road. Record with the movie writer and take one frame per view:
##   AG_TRACK=2 godot --path . --write-movie out/views.avi --fixed-fps 10 --quit-after 200 tools/landscape_views.tscn
## Each view is held HOLD frames (so fog settles); frame k of view v is at (v * HOLD + HOLD - 1) / 10 s.

const HOLD := 8
const LAP_VIEWS := [0.05, 0.125, 0.275, 0.33, 0.44, 0.495, 0.6, 0.715, 0.76, 0.83, 0.88, 0.97]

var race: Race
var cam := Camera3D.new()
var _f := 0
var _views: Array = []


func _ready() -> void:
	Game.track_index = int(OS.get_environment("AG_TRACK")) if OS.has_environment("AG_TRACK") else 2
	await get_tree().process_frame
	race = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(race)
	cam.far = 4000.0
	race.add_child(cam)
	race.hud.visible = false
	var t := race.track
	var n := t.frames.size()
	var c := Vector3.ZERO
	for f in t.frames:
		c += f.origin
	c /= n
	# Overview from the south-west, high.
	_views.append([c + Vector3(-900, 750, 1100), c])
	for fraction in LAP_VIEWS:
		var i := int(fraction * n)
		var f: Transform3D = t.frames[i]
		var fwd := -f.basis.z
		var eye := f.origin - fwd * 34.0 + Vector3.UP * 12.0
		var look := t.frames[(i + 40) % n].origin + Vector3.UP * 4.0
		_views.append([eye, look])
	print("views: ", _views.size(), "  (overview + ", LAP_VIEWS, ")")


func _process(_delta: float) -> void:
	if race == null or _views.is_empty():
		return
	var v := mini(_f / HOLD, _views.size() - 1)
	cam.global_position = _views[v][0]
	cam.look_at(_views[v][1], Vector3.UP)
	cam.current = true
	_f += 1
	if _f >= _views.size() * HOLD:
		get_tree().quit()
