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

@export_group("Hover")
@export var hover_height := 1.3
@export var hover_stiffness := 10.0
@export var align_speed := 7.0
@export var gravity := 30.0

@export_group("Visual")
@export var team_color := Color(0.9, 0.2, 0.3)
@export var bank_angle := 0.55
@export var pitch_angle := 0.08

@onready var ground_ray: RayCast3D = $GroundRay
@onready var body: Node3D = $Body
@onready var engine_light: OmniLight3D = $EngineLight
@onready var trail: GPUParticles3D = $Trail
@onready var _engine_mat: StandardMaterial3D = $Body/EngineL.get_active_material(0)

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

var spawn_transform := Transform3D.IDENTITY
var speed := 0.0
var grounded := false
var scraping := false

var _up := Vector3.UP
var _bank := 0.0
var _pitch := 0.0
var _throttle := 0.0
var _last_wall_hit_ms := 0
var _last_ship_hit_ms := 0


func _ready() -> void:
	var accent: StandardMaterial3D = $Body/Nose.material_override.duplicate()
	accent.albedo_color = team_color
	for part in [$Body/Nose, $Body/FinL, $Body/FinR]:
		part.material_override = accent


func respawn(at: Transform3D = spawn_transform) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	_up = at.basis.y
	speed = 0.0


func boost() -> void:
	velocity += -global_transform.basis.z * boost_strength
	boosted.emit()


func pad_near() -> void:
	pad_passed.emit()


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		throttle_in = 0.0
		brake_in = 0.0
		steer_in = 0.0
		airbrake_l = false
		airbrake_r = false
	var airbraking := airbrake_l or airbrake_r

	# --- Align to the track surface
	grounded = ground_ray.is_colliding()
	var target_up := ground_ray.get_collision_normal() if grounded else Vector3.UP
	_up = _up.slerp(target_up, minf(align_speed * delta, 1.0)).normalized()

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
	v_plane += fwd * (throttle_in * thrust - brake_in * brake_force) * delta
	v_plane -= v_plane * drag * delta
	if airbraking:
		v_plane -= v_plane * airbrake_drag * delta
	var grip := airbrake_grip if airbraking else lateral_grip
	var lateral := v_plane.dot(right)
	v_plane -= right * lateral * minf(grip * delta, 1.0)
	var forward_speed := v_plane.dot(fwd)
	if forward_speed < -8.0:
		v_plane -= fwd * (forward_speed + 8.0)
	# Boost pads push past max_speed; bleed the excess off gradually instead of clamping.
	var planar_speed := v_plane.length()
	if planar_speed > max_speed:
		v_plane = v_plane / planar_speed * lerpf(planar_speed, max_speed, minf(overspeed_decay * delta, 1.0))

	# --- Hover: critically damped spring on height above the surface, else fall
	var v_up: float
	if grounded:
		var dist := global_position.distance_to(ground_ray.get_collision_point())
		v_up = (hover_height - dist) * hover_stiffness
	else:
		v_up = velocity.dot(_up) - gravity * delta

	velocity = v_plane + _up * v_up
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
				ship_hit.emit(clampf((velocity - other.velocity).length() / max_speed, 0.1, 1.0))
		elif absf(c.get_normal().dot(_up)) < 0.5:
			touching_wall = true
	if touching_wall:
		if not scraping:
			# First contact is the impact; after that it's a scrape.
			velocity -= velocity * wall_scrape
			if now - _last_wall_hit_ms > 250:
				_last_wall_hit_ms = now
				wall_hit.emit(clampf(speed / max_speed, 0.15, 1.0))
		else:
			velocity -= velocity * minf(scrape_drag * delta, 1.0)
	scraping = touching_wall

	speed = (velocity - _up * velocity.dot(_up)).length()
	_throttle = lerpf(_throttle, throttle_in, minf(6.0 * delta, 1.0))
	_update_visuals(lateral, delta)


func _update_visuals(lateral: float, delta: float) -> void:
	# Roll into the turn, plus a bit extra when sliding sideways.
	_bank = lerpf(_bank, steer_in * bank_angle + lateral * 0.01, minf(8.0 * delta, 1.0))
	_pitch = lerpf(_pitch, _throttle * pitch_angle, minf(5.0 * delta, 1.0))
	body.rotation = Vector3(_pitch, 0.0, _bank)
	var glow := 0.6 + _throttle * 3.0
	_engine_mat.emission_energy_multiplier = glow
	engine_light.light_energy = glow * 1.5
	trail.amount_ratio = clampf(speed / max_speed, 0.05, 1.0)
