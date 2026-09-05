extends Node3D
## Side/rear view of one ship at full throttle with a periodic boost, for tuning the afterburner:
##   godot --path . --write-movie out/flame.avi --fixed-fps 30 --quit-after 90 tools/flame_test.tscn

var _ship: Ship
var _t := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.02, 0.05)
	e.glow_enabled = true
	e.glow_intensity = 1.1
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	_ship = load("res://scenes/ship.tscn").instantiate()
	add_child(_ship)
	_ship.set_physics_process(false)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(7.5, 2.8, 6.5)
	cam.look_at(Vector3(0, 0, 1.8))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.6
	add_child(sun)


func _process(delta: float) -> void:
	_t += delta
	_ship._throttle = 1.0
	if fmod(_t, 2.0) < 0.05:
		_ship._boost_vis = 1.0
	_ship._update_visuals(0.0, delta)
