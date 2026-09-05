class_name Race
extends Node3D

## Race flow: spawn the grid, count down, track laps and positions, finish.

enum State { COUNTDOWN, RACING, FINISHED }

@export var ship_scene: PackedScene
@export var laps := 3
@export var ai_count := 4
@export var countdown_seconds := 3.0

const AI_NAMES := ["Feisar", "AG-Sys", "Auricom", "Qirex", "Piranha", "Assegai"]
const AI_COLORS := [Color(1.0, 0.8, 0.1), Color(0.2, 0.9, 0.4), Color(1.0, 0.5, 0.1), Color(0.7, 0.3, 1.0), Color(0.2, 0.6, 1.0), Color(0.9, 0.9, 0.9)]

@onready var track: TrackBuilder = $Track
@onready var city: CityBuilder = $City
@onready var camera := $ChaseCamera
@onready var hud := $HUD

var ships: Array[Ship] = []
var player: Ship
var state := State.COUNTDOWN
var race_time := 0.0
var _countdown := 0.0
var _finish_order: Array[Ship] = []
var _results: Results
var _pause: PauseMenu
var _player_finish_time := 0.0


func _ready() -> void:
	var def := TrackDefs.ALL[Game.track_index]
	_apply_environment(def.get("env", TrackDefs.NIGHT_RAIN))
	track.load_def(def)
	city.build(track, camera, def.get("env", TrackDefs.NIGHT_RAIN))
	var grid := track.get_grid_transforms(ai_count + 1)
	# Pole is the fastest AI; the player starts at the back.
	for i in ai_count:
		var ship := _spawn_ship(grid[i], AI_NAMES[i % AI_NAMES.size()], AI_COLORS[i % AI_COLORS.size()], "ai_%d" % i)
		var driver := AIDriver.new()
		ship.add_child(driver)
		driver.setup(track, 1.0 - 0.04 * i, (-1.0 if i % 2 == 0 else 1.0) * 3.0)
	player = _spawn_ship(grid[ai_count], "You", Color(0.9, 0.2, 0.3), "player")
	player.is_player = true
	if OS.has_environment("AG_AUTOPILOT") or Game.attract:
		var driver := AIDriver.new()
		player.add_child(driver)
		driver.setup(track, 1.0, 0.0)
	else:
		player.add_child(PlayerDriver.new())
		player.wall_hit.connect(func(strength: float):
			_rumble(0.4, strength, 0.3)
			camera.shake(strength))
		player.ship_hit.connect(func(strength: float):
			_rumble(0.6, strength * 0.7, 0.2)
			camera.shake(strength * 0.6))
		player.boosted.connect(func(): _rumble(0.9, 0.3, 0.45))

	camera.target = player
	camera._snap()
	Music.attach_ship(player)
	hud.player = player
	hud.laps = laps
	_countdown = countdown_seconds
	if Game.attract:
		# Backdrop for the title screen: no HUD, no countdown, never finishes.
		hud.visible = false
		laps = 999
		state = State.RACING
		for ship in ships:
			ship.controls_enabled = true
	else:
		_pause = PauseMenu.new()
		add_child(_pause)


## models/ships/<name>.glb, falling back to ai.glb for AI ships, else the placeholder hull.
static func _find_model(name: String) -> String:
	for candidate in [name, "ai" if name.begins_with("ai_") else ""]:
		if candidate != "" and ResourceLoader.exists("res://models/ships/%s.glb" % candidate):
			return "res://models/ships/%s.glb" % candidate
	return ""


## Time of day: sky, sun, fog from the circuit's env preset.
func _apply_environment(env: Dictionary) -> void:
	var e: Environment = $WorldEnvironment.environment
	var sky_mat: ProceduralSkyMaterial = e.sky.sky_material
	sky_mat.sky_top_color = env.sky_top
	sky_mat.sky_horizon_color = env.sky_horizon
	sky_mat.ground_horizon_color = env.sky_horizon
	e.ambient_light_energy = env.ambient
	e.fog_light_color = env.fog_color
	e.fog_density = env.fog_density
	e.volumetric_fog_density = env.vol_fog
	e.volumetric_fog_albedo = env.vol_fog_albedo
	e.volumetric_fog_emission = env.vol_fog_emission
	e.tonemap_exposure = env.exposure
	var sun: DirectionalLight3D = $Sun
	sun.light_color = env.sun_color
	sun.light_energy = env.sun_energy
	sun.rotation_degrees = env.sun_rotation


func _spawn_ship(at: Transform3D, ship_name: String, color: Color, model := "") -> Ship:
	var ship: Ship = ship_scene.instantiate()
	ship.team_color = color
	ship.ship_name = ship_name
	ship.model_path = _find_model(model)
	add_child(ship)
	ship.spawn_transform = at
	ship.respawn()
	# Seed progress from the grid position so the first update isn't read as a reverse crossing.
	ship.frame_hint = track.get_nearest_frame_index(at.origin)
	ship.progress = float(ship.frame_hint) / float(track.frames.size())
	ships.append(ship)
	return ship


func _process(delta: float) -> void:
	if Game.attract:
		race_time += delta
		for ship in ships:
			_update_ship(ship, delta)
		return
	if Input.is_action_just_pressed("pause") and state != State.FINISHED and not _pause.visible:
		_pause.set_paused(true)
		return

	match state:
		State.COUNTDOWN:
			_countdown -= delta
			var text := str(ceili(_countdown)) if _countdown > 0.0 else "GO!"
			if text != hud.center_text:
				Sfx.play("countdown_go" if _countdown <= 0.0 else "countdown_tick")
			hud.center_text = text
			if _countdown <= 0.0:
				state = State.RACING
				for ship in ships:
					ship.controls_enabled = true
				get_tree().create_timer(1.0).timeout.connect(func(): if state == State.RACING: hud.center_text = "")
		State.RACING, State.FINISHED:
			race_time += delta
			for ship in ships:
				_update_ship(ship, delta)
			if state == State.FINISHED:
				_update_results()

	if state != State.FINISHED and Input.is_action_just_pressed("reset") and not _pause.visible:
		player.respawn(track.get_respawn_transform(player.global_position))
	hud.position_text = "%s / %d" % [_ordinal(_position_of(player)), ships.size()]


func _update_ship(ship: Ship, delta: float) -> void:
	if ship.global_position.y < track.lowest_y() - 40.0:
		ship.respawn(track.get_respawn_transform(ship.global_position))
	if ship.finished:
		return
	ship.lap_time += delta
	var idx := track.get_nearest_frame_index(ship.global_position, ship.frame_hint)
	ship.frame_hint = idx
	var progress := float(idx) / float(track.frames.size())
	# Crossing the line: progress wraps from the last tenth to the first tenth.
	if ship.progress > 0.9 and progress < 0.1:
		if ship.lap > 0:
			ship.best_lap = minf(ship.best_lap, ship.lap_time)
		if ship.lap > 0:
			print("%s  lap %d  %.3f" % [ship.ship_name, ship.lap, ship.lap_time])
		ship.lap += 1
		ship.lap_time = 0.0
		if ship.lap > laps:
			_finish(ship)
		elif ship == player and ship.lap > 1:
			Sfx.play("lap")
	elif ship.progress < 0.1 and progress > 0.9:
		ship.lap -= 1  # reversed back over the line
	ship.progress = progress


func _finish(ship: Ship) -> void:
	ship.finished = true
	ship.finish_time = race_time
	ship.controls_enabled = false
	_finish_order.append(ship)
	if ship == player:
		state = State.FINISHED
		Sfx.play("finish")
		_player_finish_time = race_time
		var position := _finish_order.size()
		var def := TrackDefs.ALL[Game.track_index]
		Game.last_result = {
			"track": def.name,
			"position": position,
			"time": race_time,
			"best_lap": player.best_lap if player.best_lap < INF else 0.0,
			"score": Game.score_for(def, position, race_time, player.best_lap, laps),
		}
		hud.center_text = "FINISHED  %s" % _ordinal(position)
		get_tree().create_timer(1.6).timeout.connect(_show_results)


func _show_results() -> void:
	hud.visible = false
	_results = Results.new()
	add_child(_results)
	_results.show_results(self)


## Keep the field's times updating; ships still out 15 s after the player are marked DNF.
func _update_results() -> void:
	if _results == null:
		return
	var changed := false
	for ship in ships:
		if not ship.finished and race_time - _player_finish_time > 15.0 and not ship.get_meta("dnf", false):
			ship.set_meta("dnf", true)
			ship.finished = true
			ship.controls_enabled = false
			changed = true
	if changed or Engine.get_process_frames() % 30 == 0:
		_results.refresh()


func _rumble(weak: float, strong: float, duration: float) -> void:
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, weak, strong, duration)


func _position_of(ship: Ship) -> int:
	if ship.finished:
		return _finish_order.find(ship) + 1
	var pos := _finish_order.size() + 1
	var score := ship.lap + ship.progress
	for other in ships:
		if other != ship and not other.finished and other.lap + other.progress > score:
			pos += 1
	return pos


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 not in [11, 12, 13]:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix
