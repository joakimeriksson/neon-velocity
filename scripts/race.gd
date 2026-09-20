class_name Race
extends Node3D

## Race flow: spawn the grid, count down, track laps and positions, finish.
## Also the combat referee: hands out pickups, launches weapons, recharges ships in the pit
## lane and handles eliminations.

enum State { COUNTDOWN, RACING, FINISHED }

@export var ship_scene: PackedScene
@export var laps := 3
@export var ai_count := 4
@export var countdown_seconds := 3.0
@export var rescue_after := 0.8      ## seconds off the track before the rescue picks a ship up

const AI_NAMES := ["Halcyon", "Voss", "Kestrel", "Mirage", "Sable-9", "Tessera"]
## Engine sound per AI slot: gamesynth preset plus parameter tweaks so no two ships sound alike.
const AI_ENGINES := [
	["Heavy", {}],
	["Turbine", {"whine/detune_cents": 9.0}],
	["Scramjet", {}],
	["Racer", {"whine/hz": 3000.0, "roar/hz": 800.0}],
]
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
var _eliminated_at := {}   # Ship -> race_time
var _reverb: AudioEffectReverb
var _log := OS.has_environment("AG_COMBAT_LOG")   ## print pickups, shots, hits and pit stops


func _ready() -> void:
	var def := TrackDefs.ALL[Game.track_index]
	_apply_environment(def.get("env", TrackDefs.NIGHT_RAIN))
	track.load_def(def)
	city.build(track, camera, def.get("env", TrackDefs.NIGHT_RAIN), def.get("setting", {}))
	var grid := track.get_grid_transforms(ai_count + 1)
	# Pole is the fastest AI; the player starts at the back.
	for i in ai_count:
		var ship := _spawn_ship(grid[i], AI_NAMES[i % AI_NAMES.size()], AI_COLORS[i % AI_COLORS.size()], "ai_%d" % i, AI_ENGINES[i % AI_ENGINES.size()])
		var driver := AIDriver.new()
		ship.add_child(driver)
		# Lanes either side of the centre line, closer in on a narrow circuit.
		var lane_offset := minf(3.0, track.track_width * 0.15)
		driver.setup(track, 1.0 - 0.04 * i, (-1.0 if i % 2 == 0 else 1.0) * lane_offset)
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
		player.landed.connect(func(impact: float):
			_rumble(0.5, clampf(impact / 25.0, 0.2, 1.0), 0.25)
			camera.shake(clampf(impact / 30.0, 0.1, 0.9)))
		player.hit_taken.connect(func(_damage: float, by_name: String, weapon: String):
			_rumble(1.0, 1.0, 0.5)
			camera.shake(1.4)
			hud.flash("Hit by %s's %s" % [by_name, weapon.to_lower()], HudCanvas.RED))
		player.item_changed.connect(func():
			if player.item != Items.NONE:
				Sfx.play("pickup"))

	# Dev: AG_ENERGY=40 starts every ship at that energy, to exercise pit stops and warnings.
	if OS.has_environment("AG_ENERGY"):
		for ship in ships:
			ship.energy = float(OS.get_environment("AG_ENERGY"))

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
			ship.invulnerable = true   # weapons fly on the title screen, but nobody is knocked out
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


func _spawn_ship(at: Transform3D, ship_name: String, color: Color, model := "", engine: Array = ["Racer", {}]) -> Ship:
	var ship: Ship = ship_scene.instantiate()
	ship.team_color = color
	ship.ship_name = ship_name
	ship.model_path = _find_model(model)
	var audio: EngineAudio = ship.get_node("EngineAudio")
	audio.jet_preset = engine[0]
	audio.jet_tweaks = engine[1]
	add_child(ship)
	ship.spawn_transform = at
	ship.respawn()
	# Seed progress from the grid position so the first update isn't read as a reverse crossing.
	ship.frame_hint = track.get_nearest_frame_index(at.origin)
	ship.progress = float(ship.frame_hint) / float(track.frames.size())
	ship.item_pad_hit.connect(func(): ship.give_item(Items.roll(_position_of(ship), ships.size())))
	ship.item_used.connect(_on_item_used.bind(ship))
	ship.eliminated.connect(_on_eliminated.bind(ship))
	if _log:
		ship.wall_hit.connect(func(strength: float):
			print("%6.1f  %-8s wall %.2f at %.1f%% of lap, lateral %.1f, speed %.0f" % [race_time, ship.ship_name, strength, ship.progress * 100.0, ship.track_lateral, ship.speed]))
		ship.landed.connect(func(impact: float):
			if ship.air_time > 0.5:
				print("%6.1f  %-8s air %.2f s  (~%.1f m high)  touchdown %.0f m/s  at %.0f%% of lap" % [race_time, ship.ship_name, ship.air_time, 30.0 * ship.air_time * ship.air_time / 8.0, impact, ship.progress * 100.0]))
	ships.append(ship)
	return ship


# --- Combat --------------------------------------------------------------------------

func _on_item_used(item: int, ship: Ship) -> void:
	var s := _track_s(ship)
	if _log:
		print("%6.1f  %-8s uses %s" % [race_time, ship.ship_name, Items.NAMES[item]])
	match item:
		Items.ROCKET:
			_launch(Projectile.Kind.ROCKET, ship, s + 2.5, ship.track_lateral, maxf(ship.speed + 75.0, 125.0))
			_play_for(ship, "rocket_fire")
		Items.MISSILE:
			var p := _launch(Projectile.Kind.MISSILE, ship, s + 2.5, ship.track_lateral, maxf(ship.speed + 50.0, 115.0))
			p.target = _ship_ahead_of(ship, 320.0)
			_play_for(ship, "missile_fire")
		Items.MINE:
			for k in 3:
				_launch(Projectile.Kind.MINE, ship, s - 3.0 - k * 3.5, ship.track_lateral + randf_range(-2.5, 2.5), 0.0)
			_play_for(ship, "mine_drop")
		Items.SHIELD:
			_play_for(ship, "shield_on")


func _launch(kind: Projectile.Kind, ship: Ship, s: float, lateral: float, speed: float) -> Projectile:
	var p := Projectile.new()
	p.kind = kind
	p.race = self
	p.owner_ship = ship
	p.s = s
	p.lateral = lateral
	p.speed = speed
	add_child(p)
	return p


func _play_for(ship: Ship, sfx: String) -> void:
	if ship.is_player:
		Sfx.play(sfx, 1.0, 2.0)
	else:
		Sfx.play_at(sfx, ship.global_position, 1.0, 0.0, 30.0)


## Under a roof: no rain on the camera, and the engines ring off the walls.
func _update_tunnel(delta: float) -> void:
	var inside := track.in_tunnel(player.frame_hint)
	var rain := camera.get_node_or_null("Rain")
	if rain:
		rain.visible = not inside
	if _reverb == null:
		var bus := AudioServer.get_bus_index("SFX")
		if bus < 0:
			return
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.75
		_reverb.damping = 0.35
		_reverb.spread = 0.9
		_reverb.dry = 1.0
		_reverb.wet = 0.0
		AudioServer.add_bus_effect(bus, _reverb)
	_reverb.wet = lerpf(_reverb.wet, 0.4 if inside else 0.0, minf(4.0 * delta, 1.0))


func _exit_tree() -> void:
	# The bus outlives the scene; take the reverb off so restarts don't stack them.
	if _reverb:
		var bus := AudioServer.get_bus_index("SFX")
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _reverb:
				AudioServer.remove_bus_effect(bus, i)
				break


## Over the wall or under the road: after a moment a rescue drops the ship back on the track
## at a standstill. The lost time is the penalty.
func _check_off_track(ship: Ship, delta: float) -> void:
	var f := track.frames[posmod(ship.frame_hint, track.frames.size())]
	var rel := ship.global_position - f.origin
	var beyond_wall := absf(rel.dot(f.basis.x)) > track.track_width * 0.5 + 1.5
	var below_road := rel.dot(f.basis.y) < -5.0
	if (beyond_wall and not ship.grounded) or below_road:
		ship.off_track_time += delta
	else:
		ship.off_track_time = 0.0
	if ship.off_track_time > rescue_after:
		if _log:
			print("%6.1f  %-8s rescued: %s, lateral %.1f m, %.1f m below the road line, at %.0f%% of lap, speed %.0f" % [race_time, ship.ship_name, "over the wall" if beyond_wall else "under the road", rel.dot(f.basis.x), -rel.dot(f.basis.y), ship.progress * 100.0, ship.speed])
		var back := track.frames[track.safe_frame(ship.frame_hint + 2)]
		ship.respawn(Transform3D(back.basis, back.origin + back.basis.y * 1.5))
		if ship == player and not Game.attract:
			hud.flash("Off the track. Rescued", HudCanvas.AMBER)
			Sfx.play("shield_on", 0.7, 0.0)


## Fractional frame index of a ship along the lap.
func _track_s(ship: Ship) -> float:
	var f := track.frames[posmod(ship.frame_hint, track.frames.size())]
	return ship.frame_hint + (ship.global_position - f.origin).dot(-f.basis.z) / track.step


## Metres from `from` forward along the lap to `to` (always positive, wraps).
func track_distance(from: Ship, to: Ship) -> float:
	var n := track.frames.size()
	return posmod(to.frame_hint - from.frame_hint, n) * track.step


func _ship_ahead_of(ship: Ship, within: float) -> Ship:
	var best: Ship = null
	var best_d := within
	for other in ships:
		if other == ship or other.is_eliminated:
			continue
		var d := track_distance(ship, other)
		if d > 1.0 and d < best_d:
			best_d = d
			best = other
	return best


func ship_behind(ship: Ship, within: float) -> Ship:
	for other in ships:
		if other != ship and not other.is_eliminated:
			var d := track_distance(other, ship)
			if d > 1.0 and d < within:
				return other
	return null


func ship_ahead(ship: Ship, within: float) -> Ship:
	return _ship_ahead_of(ship, within)


## Called by a projectile when it reaches a ship.
func report_hit(attacker: Ship, victim: Ship, weapon: String, landed: bool) -> void:
	if _log:
		print("%6.1f  %-8s %s -> %s  %s  (energy %.0f)" % [race_time, attacker.ship_name if is_instance_valid(attacker) else "?", weapon, victim.ship_name, "HIT" if landed else "blocked", victim.energy])
	if not is_instance_valid(attacker) or attacker == victim:
		return
	if landed:
		attacker.hits_landed += 1
		if victim.is_eliminated:
			attacker.kills += 1
	if attacker == player and not Game.attract:
		if not landed:
			hud.flash("%s blocked by %s's shield" % [weapon.capitalize(), victim.ship_name], Items.COLORS[Items.SHIELD])
		elif victim.is_eliminated:
			hud.flash("%s eliminated" % victim.ship_name, HudCanvas.AMBER)
		else:
			hud.flash("%s hit %s" % [weapon.capitalize(), victim.ship_name], HudCanvas.GREEN)


func _on_eliminated(ship: Ship) -> void:
	_eliminated_at[ship] = race_time
	if _log:
		print("%6.1f  %-8s ELIMINATED" % [race_time, ship.ship_name])
	ship.finished = true
	ship.finish_time = race_time
	if ship != player or Game.attract:
		return
	state = State.FINISHED
	_player_finish_time = race_time
	_rumble(1.0, 1.0, 0.9)
	camera.shake(2.0)
	var def := TrackDefs.ALL[Game.track_index]
	Game.last_result = {
		"track": def.name,
		"position": _position_of(player),
		"time": race_time,
		"best_lap": player.best_lap if player.best_lap < INF else 0.0,
		"eliminated": true,
		"score": {"position": 0, "time": 0, "lap": 0, "combat": 0, "total": 0},
	}
	hud.center_text = "Eliminated"
	get_tree().create_timer(2.2).timeout.connect(_show_results)


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
			var text := str(ceili(_countdown)) if _countdown > 0.0 else "Go"
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
	hud.position = _position_of(player)
	hud.field = ships.size()
	_update_tunnel(delta)
	# Warn from about 300 m before the pit lane until its end.
	var lead := 300.0 / (track.frames.size() * track.step)
	var pit_start: float = track.pit_lane[0]
	var pit_end: float = track.pit_lane[1]
	var pit_side: float = track.pit_lane[2]
	var approaching := player.progress > pit_start - lead and player.progress < pit_end - 0.01
	hud.pit_ahead = ("RIGHT" if pit_side > 0.0 else "LEFT") if approaching else ""


func _update_ship(ship: Ship, delta: float) -> void:
	if ship.global_position.y < track.lowest_y() - 40.0:
		ship.respawn(track.get_respawn_transform(ship.global_position))
	if ship.finished:
		return
	_check_off_track(ship, delta)
	ship.lap_time += delta
	var idx := track.get_nearest_frame_index(ship.global_position, ship.frame_hint)
	ship.frame_hint = idx
	ship.track_lateral = track.get_lateral(ship.global_position, idx)
	ship.recharging = ship.energy < ship.max_energy and track.in_pit(idx, ship.track_lateral)
	if ship.recharging:
		if _log and not ship.get_meta("pit_logged", false):
			print("%6.1f  %-8s enters pit lane (energy %.0f)" % [race_time, ship.ship_name, ship.energy])
		ship.recharge(delta)
	ship.set_meta("pit_logged", ship.recharging)
	var progress := float(idx) / float(track.frames.size())
	# Crossing the line: progress wraps from the last tenth to the first tenth.
	if ship.progress > 0.9 and progress < 0.1:
		if ship.lap > 0:
			if ship == player:
				hud.lap_completed(ship.lap_time, ship.best_lap)
			ship.best_lap = minf(ship.best_lap, ship.lap_time)
		if ship.lap > 0:
			print("%s  lap %d  %.3f  energy %.0f" % [ship.ship_name, ship.lap, ship.lap_time, ship.energy])
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
			"score": Game.score_for(def, position, race_time, player.best_lap, laps, player.hits_landed, player.kills),
		}
		hud.center_text = "Finished %s" % _ordinal(position)
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


## Finishers in finishing order, then everyone still racing (or timed out) by distance
## covered, then eliminated ships, the last one standing ranked highest.
func _rank_key(ship: Ship) -> float:
	if _eliminated_at.has(ship):
		return -1000000.0 + _eliminated_at[ship]
	var order := _finish_order.find(ship)
	if order >= 0:
		return 1000000.0 - order
	return ship.lap + ship.progress


func _position_of(ship: Ship) -> int:
	var key := _rank_key(ship)
	var pos := 1
	for other in ships:
		if other != ship and _rank_key(other) > key:
			pos += 1
	return pos


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 not in [11, 12, 13]:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix
