class_name Ship
extends CharacterBody3D

## Anti-gravity racer controller.
## Hovers on a raycast, thrusts along the nose, grip pulls lateral drift back in line,
## airbrakes tighten a turn at the cost of speed. Uses floating motion mode so the
## body just slides along walls and never treats anything as a "floor".
## Inputs are written each tick by a driver child (PlayerDriver or AIDriver).

signal boosted
signal pad_passed   ## crossed a boost pad's zone (hit or near miss)
signal wall_hit(strength: float)
signal ship_hit(strength: float)
signal item_pad_hit                                          ## drove over a live item pad with an empty slot
signal item_changed
signal item_used(item: int)
signal item_absorbed
signal hit_taken(damage: float, by_name: String, weapon: String)   ## weapon hits only
signal eliminated
signal landed(impact: float)   ## came down from a jump; impact is the touchdown speed in m/s

@export_group("Engine")
@export var max_speed := 95.0        ## m/s (~340 km/h)
@export var thrust := 40.0
@export var brake_force := 55.0
@export var drag := 0.30
@export var airbrake_drag := 1.2
@export var boost_strength := 30.0
@export var overspeed_decay := 1.5   ## how fast speed above max_speed bleeds off

@export_group("Handling")
@export var turn_rate := 1.9         ## rad/s at full steer
@export var airbrake_turn := 1.4     ## extra rad/s while an airbrake is held
@export var lateral_grip := 4.0      ## how quickly sideways velocity is killed
@export var airbrake_grip := 1.2     ## lower grip while airbraking -> slide
@export var wall_scrape := 0.15      ## fraction of speed lost on wall impact
@export var scrape_drag := 1.2       ## extra drag per second while sliding along a wall

@export_group("Energy")
@export var max_energy := 100.0
@export var wall_damage := 9.0       ## energy lost on a full-speed wall impact
@export var scrape_damage := 5.0     ## energy per second while grinding along a wall
@export var ship_hit_damage := 3.0
@export var recharge_rate := 42.0    ## energy per second in the pit lane
@export var shield_seconds := 5.0

@export_group("Hover")
@export var hover_height := 1.3
@export var hover_spring := 90.0     ## m/s^2 of lift per metre below hover height
@export var hover_damping := 14.0
@export var hover_range := 3.2       ## beyond this far off the surface the ship is flying
## How hard the track can pull the ship down. Low values let crests throw the ship into
## the air; high values glue it to the road.
@export var track_pull := 14.0
@export var align_speed := 7.0
@export var air_align_speed := 2.0
@export var gravity := 30.0
@export var air_thrust := 0.35       ## fraction of thrust available while flying
@export var air_grip := 0.35         ## lateral grip while flying
@export var hard_landing := 27.0     ## touchdown speed (m/s) above which a landing hurts; a clean crest lands at ~20

@export_group("Visual")
@export var team_color := Color(0.9, 0.2, 0.3)
## Optional .glb hull (see models/ships/README.md). Empty = placeholder box hull.
@export_file("*.glb") var model_path := ""
## Fixed pitch applied to an imported hull (radians, negative = nose down).
@export var model_pitch_trim := -0.04
@export var bank_angle := 0.55
@export var pitch_angle := 0.018    ## nose-up under thrust (radians)
@export var brake_dip := 0.03       ## nose-down while braking

@onready var ground_ray: RayCast3D = $GroundRay
@onready var body: Node3D = $Body
@onready var engine_light: OmniLight3D = $EngineLight
@onready var trail: GPUParticles3D = $Trail
@onready var _engine_mat: StandardMaterial3D = $Body/EngineL.get_active_material(0)
@onready var _flames: Array[Node3D] = [$Body/FlameL, $Body/FlameR]
@onready var _cores: Array[MeshInstance3D] = [$Body/CoreL, $Body/CoreR]
@onready var _jets: Array[GPUParticles3D] = [$Body/JetL, $Body/JetR]
@onready var _flame_mat: ShaderMaterial = $Body/FlameL/FlameMeshL.mesh.material.duplicate()

# --- Inputs, written by the driver
var throttle_in := 0.0
var brake_in := 0.0
var steer_in := 0.0          ## +1 = left
var airbrake_l := false
var airbrake_r := false
var controls_enabled := false

# --- Race state, maintained by Race
var ship_name := "Ship"
var is_player := false
var lap := 0
var progress := 0.0
var lap_time := 0.0
var best_lap := INF
var finished := false
var finish_time := 0.0
var frame_hint := -1
var track_lateral := 0.0     ## metres right of the track centre line
var recharging := false
var hits_landed := 0
var kills := 0

# --- Combat state
var energy := 100.0
var item := Items.NONE
var shield_time := 0.0
var is_eliminated := false
var invulnerable := false    ## takes hits (slowdown, effects) but loses no energy: attract mode

var spawn_transform := Transform3D.IDENTITY
var speed := 0.0
var grounded := false
var scraping := false
var air_time := 0.0          ## seconds since the ship last hovered over track
var off_track_time := 0.0    ## maintained by Race; rescue when it runs long

var _up := Vector3.UP
var _bank := 0.0
var _pitch := 0.0
var _throttle := 0.0
var _boost_vis := 0.0
var _last_wall_hit_ms := 0
var _last_ship_hit_ms := 0
var _spin := 0.0
var _immunity := 0.0   ## seconds of weapon immunity left after a hit, so mines can't chain
var _shield_mesh: MeshInstance3D


func _ready() -> void:
	var accent: StandardMaterial3D = $Body/Nose.material_override.duplicate()
	accent.albedo_color = team_color
	for part in [$Body/Nose, $Body/FinL, $Body/FinR]:
		part.material_override = accent
	if model_path != "" and ResourceLoader.exists(model_path):
		_install_model(model_path)
	# Per-ship flame material so throttle drives each ship's own afterburner.
	for flame in _flames:
		flame.get_child(0).material_override = _flame_mat
	energy = max_energy
	# Long enough to see the landing coming and line up with it.
	ground_ray.target_position = Vector3(0, -30, 0)
	_shield_mesh = _make_shield_mesh()
	add_child(_shield_mesh)


## Swap the placeholder hull for an imported model: hide the box parts, tint "Accent"
## materials with the team colour, and move exhausts/headlight to the model's named empties.
func _install_model(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	for part in [$Body/Hull, $Body/Nose, $Body/Canopy, $Body/FinL, $Body/FinR, $Body/EngineL, $Body/EngineR]:
		part.visible = false
	body.add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var mat: Material = mesh.get_active_material(i)
			if mat and "accent" in mat.resource_name.to_lower():
				var tinted: Material = mat.duplicate()
				if tinted is BaseMaterial3D:
					tinted.albedo_color = team_color
				mesh.set_surface_override_material(i, tinted)
	var sockets := {"EngineL": [$Body/FlameL, $Body/CoreL, $Body/JetL], "EngineR": [$Body/FlameR, $Body/CoreR, $Body/JetR]}
	for socket_name in sockets:
		var socket: Node3D = model.find_child(socket_name, true, false)
		if socket:
			for node in sockets[socket_name]:
				var keep_basis: Basis = node.transform.basis
				node.position = body.to_local(socket.global_position)
				node.transform.basis = keep_basis
	var head: Node3D = model.find_child("Headlight", true, false)
	if head:
		$Headlight.position = to_local(head.global_position)


func respawn(at: Transform3D = spawn_transform) -> void:
	if is_eliminated:
		return
	global_transform = at
	velocity = Vector3.ZERO
	_up = at.basis.y
	speed = 0.0
	air_time = 0.0
	off_track_time = 0.0


func boost() -> void:
	velocity += -global_transform.basis.z * boost_strength
	_boost_vis = 1.0
	boosted.emit()


func pad_near() -> void:
	pad_passed.emit()


# --- Items ---------------------------------------------------------------------------

## Called by an item pad. Returns true if the ship took the pickup (its slot was empty).
func collect_item_pad() -> bool:
	if item != Items.NONE or is_eliminated or finished:
		return false
	item_pad_hit.emit()
	return true


func give_item(new_item: int) -> void:
	item = new_item
	item_changed.emit()


func use_item() -> void:
	if item == Items.NONE or not controls_enabled or is_eliminated:
		return
	var used := item
	item = Items.NONE
	item_changed.emit()
	match used:
		Items.TURBO:
			velocity += -global_transform.basis.z * boost_strength * 0.5
			boost()
		Items.SHIELD:
			shield_time = shield_seconds
	item_used.emit(used)


## Trade the held item for energy instead of firing it.
func absorb_item() -> void:
	if item == Items.NONE or not controls_enabled or is_eliminated:
		return
	item = Items.NONE
	energy = minf(energy + Items.ABSORB_ENERGY, max_energy)
	item_changed.emit()
	item_absorbed.emit()


# --- Energy --------------------------------------------------------------------------

## Returns true if the damage landed (false when shielded, finished or already out).
## A named `weapon` also knocks speed off and spins the hull.
func apply_damage(amount: float, by_name := "", weapon := "") -> bool:
	if is_eliminated or finished:
		return false
	if shield_time > 0.0:
		return false
	if not invulnerable:
		energy -= amount
	if weapon != "":
		velocity *= 0.55
		_spin = 1.0
		_immunity = 1.2
		hit_taken.emit(amount, by_name, weapon)
	if energy <= 0.0:
		_eliminate()
	return true


## True for a moment after a weapon hit: projectiles pass through instead of stacking damage.
func weapon_immune() -> bool:
	return _immunity > 0.0


func recharge(delta: float) -> void:
	energy = minf(energy + recharge_rate * delta, max_energy)


func _eliminate() -> void:
	energy = 0.0
	is_eliminated = true
	controls_enabled = false
	item = Items.NONE
	velocity = Vector3.ZERO
	body.visible = false
	trail.emitting = false
	engine_light.visible = false
	$Headlight.visible = false
	_shield_mesh.visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	Explosion.spawn(get_parent(), global_position, 2.2)
	eliminated.emit()   # EngineAudio plays the blast


func _make_shield_mesh() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.16)
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	mi.scale = Vector3(2.0, 1.1, 3.1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _physics_process(delta: float) -> void:
	if is_eliminated:
		return
	shield_time = maxf(shield_time - delta, 0.0)
	_immunity = maxf(_immunity - delta, 0.0)
	if not controls_enabled:
		throttle_in = 0.0
		brake_in = 0.0
		steer_in = 0.0
		airbrake_l = false
		airbrake_r = false
	var airbraking := airbrake_l or airbrake_r

	# --- Hovering over track, or flying? Align to the surface below, quickly when hovering
	# and gently in the air so the ship lines up with its landing.
	var ray_hit := ground_ray.is_colliding()
	var dist := INF
	if ray_hit:
		dist = global_position.distance_to(ground_ray.get_collision_point())
	grounded = ray_hit and dist < hover_range
	var target_up := ground_ray.get_collision_normal() if ray_hit else Vector3.UP
	var align := align_speed if grounded else air_align_speed
	_up = _up.slerp(target_up, minf(align * delta, 1.0)).normalized()

	# --- Heading: project forward onto the surface plane, then yaw around the surface normal
	var fwd := -global_transform.basis.z
	fwd = (fwd - _up * fwd.dot(_up))
	if fwd.length_squared() < 0.0001:
		fwd = global_transform.basis.x.cross(_up)
	fwd = fwd.normalized()
	var yaw := steer_in * turn_rate
	if airbrake_l:
		yaw += airbrake_turn
	if airbrake_r:
		yaw -= airbrake_turn
	# Turning authority scales with speed so a stationary ship doesn't spin on the spot.
	var speed_factor := clampf(speed / max_speed, 0.35, 1.0)
	fwd = fwd.rotated(_up, yaw * speed_factor * delta)
	global_transform.basis = Basis.looking_at(fwd, _up)
	var right := global_transform.basis.x

	# --- Planar velocity: thrust, drag, grip
	var v_plane := velocity - _up * velocity.dot(_up)
	var authority := 1.0 if grounded else air_thrust
	v_plane += fwd * (throttle_in * thrust * authority - brake_in * brake_force * authority) * delta
	v_plane -= v_plane * drag * delta
	if airbraking:
		v_plane -= v_plane * airbrake_drag * delta
	var grip := airbrake_grip if airbraking else lateral_grip
	if not grounded:
		grip = air_grip
	var lateral := v_plane.dot(right)
	v_plane -= right * lateral * minf(grip * delta, 1.0)
	var forward_speed := v_plane.dot(fwd)
	if forward_speed < -8.0:
		v_plane -= fwd * (forward_speed + 8.0)
	# Boost pads push past max_speed; bleed the excess off gradually instead of clamping.
	var planar_speed := v_plane.length()
	if planar_speed > max_speed:
		v_plane = v_plane / planar_speed * lerpf(planar_speed, max_speed, minf(overspeed_decay * delta, 1.0))

	# --- Vertical: the ship keeps its momentum. Hovering, a spring-damper holds it at hover
	# height; it pushes up as hard as it needs to but pulls down only by `track_pull`, so when
	# the road falls away faster than that (a crest at speed, a drop) the ship flies.
	var v_up := velocity.dot(_up)
	var gravity_push := Vector3.ZERO
	if grounded:
		if air_time > 0.35:
			var impact := maxf(-v_up, 0.0)
			landed.emit(impact)
			if impact > hard_landing:
				apply_damage((impact - hard_landing) * 0.9)
		air_time = 0.0
		var lift := hover_spring * (hover_height - dist) - hover_damping * v_up
		v_up += maxf(lift, -(gravity + track_pull)) * delta
	else:
		air_time += delta
		gravity_push = Vector3.DOWN * gravity * delta

	velocity = v_plane + _up * v_up + gravity_push
	up_direction = _up
	move_and_slide()

	var touching_wall := false
	var now := Time.get_ticks_msec()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is Ship:
			if now - _last_ship_hit_ms > 300:
				_last_ship_hit_ms = now
				var other: Ship = c.get_collider()
				var knock := clampf((velocity - other.velocity).length() / max_speed, 0.1, 1.0)
				ship_hit.emit(knock)
				apply_damage(knock * ship_hit_damage)
		elif absf(c.get_normal().dot(_up)) < 0.5:
			touching_wall = true
	if touching_wall:
		if not scraping:
			# First contact is the impact; after that it's a scrape.
			velocity -= velocity * wall_scrape
			if now - _last_wall_hit_ms > 250:
				_last_wall_hit_ms = now
				var impact := clampf(speed / max_speed, 0.15, 1.0)
				wall_hit.emit(impact)
				apply_damage(impact * wall_damage)
		else:
			velocity -= velocity * minf(scrape_drag * delta, 1.0)
			apply_damage(scrape_damage * delta)
	scraping = touching_wall

	speed = (velocity - _up * velocity.dot(_up)).length()
	_throttle = lerpf(_throttle, throttle_in, minf(6.0 * delta, 1.0))
	_update_visuals(lateral, delta)


func _update_visuals(lateral: float, delta: float) -> void:
	# Roll into the turn, plus a bit extra when sliding sideways.
	_bank = lerpf(_bank, steer_in * bank_angle + lateral * 0.01, minf(8.0 * delta, 1.0))
	var target_pitch := _throttle * pitch_angle - brake_in * brake_dip
	if not grounded and speed > 5.0:
		# Flying: nose up on the way up, down on the way down.
		target_pitch = clampf(atan2(velocity.dot(_up), speed) * 0.7, -0.45, 0.45)
	_pitch = lerpf(_pitch, target_pitch, minf(5.0 * delta, 1.0))
	# A weapon hit throws the hull into a decaying yaw wobble.
	_spin *= exp(-3.5 * delta)
	var spin_yaw := sin(_spin * 14.0) * _spin * 0.9
	body.rotation = Vector3(_pitch + (model_pitch_trim if model_path != "" else 0.0), spin_yaw, _bank)
	_shield_mesh.visible = shield_time > 0.0
	if _shield_mesh.visible:
		# Flicker out over the last second.
		_shield_mesh.transparency = 0.0 if shield_time > 1.0 else (0.5 + 0.5 * sin(shield_time * 40.0)) * 0.8
	_boost_vis *= exp(-1.8 * delta)
	var glow := 0.4 + _throttle * 1.4 + _boost_vis * 1.5
	_engine_mat.emission_energy_multiplier = glow
	engine_light.light_energy = glow * 1.5
	engine_light.light_color = Color(0.3, 0.9, 1.0).lerp(Color(0.7, 0.85, 1.0), _boost_vis)
	trail.amount_ratio = clampf(speed / max_speed, 0.05, 1.0)
	# Afterburner: length and brightness follow throttle, boost flares it out.
	var length := 0.6 + _throttle * 2.2 + _boost_vis * 3.0
	var width := 0.85 + _throttle * 0.25 + _boost_vis * 0.4
	for flame in _flames:
		flame.scale = Vector3(width, length, width)
	_flame_mat.set_shader_parameter("intensity", 0.2 + _throttle * 0.5 + _boost_vis * 0.5)
	_flame_mat.set_shader_parameter("boost", _boost_vis)
	if OS.has_environment("AG_NO_EXHAUST"):
		for f in _flames: f.visible = false
		for c in _cores: c.visible = false
		for j in _jets: j.visible = false
		trail.visible = false
		return
	# Particle jet: density and reach follow throttle; boost throws it much further.
	var jet_ratio := clampf(0.15 + _throttle * 0.85, 0.0, 1.0)
	for jet in _jets:
		jet.amount_ratio = jet_ratio
		jet.lifetime = 0.12 + _throttle * 0.08 + _boost_vis * 0.12
		jet.speed_scale = 1.0 + _boost_vis * 0.6
	# Hot core disc at the nozzle: the part that reads from straight behind.
	var core := 0.5 + _throttle * 0.4 + _boost_vis * 0.6
	for c in _cores:
		c.scale = Vector3.ONE * core
		c.transparency = 0.0
