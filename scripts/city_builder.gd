class_name CityBuilder
extends Node3D

## Procedural megacity around a track: towers with lit windows (one MultiMesh + facade
## shader), neon advertising panels, a wet ground plane, sweeping searchlights, and rain
## that follows the camera. The track is an elevated highway through it.

@export var rng_seed := 7
@export var building_count := 1300
@export var min_gap := 24.0          ## metres between the track edge and the nearest facade
@export var max_distance := 520.0
@export var ground_drop := 35.0      ## city ground this far below the track's lowest point
@export var sign_count := 800
@export var sign_lights := 28
@export var street_lights := 40
@export var searchlight_count := 4

const CELL := 40.0
const SIGN_PALETTE: Array[Color] = [
	Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.5, 0.1), Color(0.3, 1.0, 0.45),
	Color(0.7, 0.3, 1.0), Color(1.0, 0.15, 0.15), Color(1.0, 0.9, 0.3), Color(0.2, 0.5, 1.0),
]

var ground_y := 0.0

var _rng := RandomNumberGenerator.new()
var _track: TrackBuilder
var _track_cells := {}      # Vector2i -> Array[Vector3]
var _building_cells := {}   # Vector2i -> Array[int] (indices into _buildings)
var _buildings: Array[Dictionary] = []
var _searchlights: Array[SpotLight3D] = []
var _beam_angles: Array[float] = []


var _env := {}
var _height_scale := 1.0
var _water := false


## `setting` comes from the circuit: {"drop", "count", "gap", "reach", "height", "water"}.
func build(track: TrackBuilder, camera: Node3D, env := {}, setting := {}) -> void:
	_env = env
	ground_drop = setting.get("drop", 35.0)
	building_count = setting.get("count", 1300)
	min_gap = setting.get("gap", 24.0)
	max_distance = setting.get("reach", 520.0)
	_height_scale = setting.get("height", 1.0)
	_water = setting.get("water", false)
	for child in get_children():
		remove_child(child)
		child.free()
	_track = track
	_rng.seed = rng_seed
	_buildings.clear()
	_building_cells.clear()
	_searchlights.clear()
	_beam_angles.clear()
	ground_y = track.lowest_y() - ground_drop
	_index_track()
	_place_buildings()
	_add_building_mesh()
	_add_signs()
	_add_ground()
	_add_street_lights()
	_add_searchlights()
	_add_rain(camera)


func _process(delta: float) -> void:
	for i in _searchlights.size():
		_beam_angles[i] += delta * (0.25 + 0.12 * i)
		var a := _beam_angles[i]
		var tilt := 0.6 + 0.15 * sin(a * 0.7)
		var dir := Vector3(cos(a) * sin(tilt), cos(tilt), sin(a) * sin(tilt))
		var light := _searchlights[i]
		light.look_at(light.global_position + dir, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP)


# --- Placement ------------------------------------------------------------------

static func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


func _index_track() -> void:
	_track_cells.clear()
	for f in _track.frames:
		var c := _cell(f.origin.x, f.origin.z)
		if not _track_cells.has(c):
			_track_cells[c] = []
		_track_cells[c].append(f.origin)


## True if no part of the track passes within `radius` (horizontally) of pos.
func _clear_of_track(pos: Vector3, radius: float) -> bool:
	var r := ceili(radius / CELL) + 1
	var c := _cell(pos.x, pos.z)
	var r2 := radius * radius
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _track_cells.has(key):
				continue
			for p in _track_cells[key]:
				var d := Vector2(p.x - pos.x, p.z - pos.z).length_squared()
				if d < r2:
					return false
	return true


func _clear_of_buildings(pos: Vector3, radius: float) -> bool:
	var r := ceili(radius / CELL) + 1
	var c := _cell(pos.x, pos.z)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _building_cells.has(key):
				continue
			for idx in _building_cells[key]:
				var b: Dictionary = _buildings[idx]
				var need: float = radius + maxf(b.size.x, b.size.z) * 0.55
				if Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length_squared() < need * need:
					return false
	return true


func _place_buildings() -> void:
	var frames := _track.frames
	var half_w := _track.track_width * 0.5
	var attempts := 0
	while _buildings.size() < building_count and attempts < building_count * 6:
		attempts += 1
		var f: Transform3D = frames[_rng.randi_range(0, frames.size() - 1)]
		var fwd := Vector3(-f.basis.z.x, 0.0, -f.basis.z.z).normalized()
		var right := Vector3(fwd.z, 0.0, -fwd.x)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		# Bias towards the track so the canyon walls are dense and the far city thins out.
		var dist := min_gap + (max_distance - min_gap) * pow(_rng.randf(), 1.5)
		var w := _rng.randf_range(10.0, 34.0)
		var d := _rng.randf_range(10.0, 34.0)
		var pos := f.origin + right * side * (half_w + dist + maxf(w, d) * 0.5) + fwd * _rng.randf_range(-30.0, 30.0)
		pos.y = ground_y
		var footprint := maxf(w, d) * 0.72
		if not _clear_of_track(pos, half_w + min_gap + footprint):
			continue
		if not _clear_of_buildings(pos, footprint):
			continue
		var h := (24.0 + 240.0 * pow(_rng.randf(), 2.2)) * _height_scale
		if _rng.randf() < 0.04:
			h *= 1.7
		var yaw := atan2(fwd.x, fwd.z) if _rng.randf() < 0.75 else _rng.randf() * TAU
		var grey := _rng.randf_range(0.35, 0.7)
		var tint := Color(grey * _rng.randf_range(0.85, 1.0), grey * _rng.randf_range(0.85, 1.0), grey * _rng.randf_range(0.95, 1.15))
		var b := {
			"pos": Vector3(pos.x, ground_y + h * 0.5, pos.z),
			"size": Vector3(w, h, d),
			"yaw": yaw,
			"tint": tint,
			"lit": 0.02 if _rng.randf() < 0.12 else _rng.randf_range(0.05, 0.38),
			"seed": _rng.randf(),
			"track_dist": dist,
		}
		_buildings.append(b)
		var c := _cell(pos.x, pos.z)
		if not _building_cells.has(c):
			_building_cells[c] = []
		_building_cells[c].append(_buildings.size() - 1)
		# A wider podium under a third of the towers breaks up the box silhouettes.
		if _rng.randf() < 0.35 and h > 60.0:
			var ph := _rng.randf_range(12.0, 30.0)
			var podium := b.duplicate()
			podium.pos = Vector3(pos.x, ground_y + ph * 0.5, pos.z)
			podium.size = Vector3(w * 1.5, ph, d * 1.5)
			podium.lit = b.lit * 0.6
			podium.seed = _rng.randf()
			_buildings.append(podium)


static func _building_basis(b: Dictionary) -> Basis:
	var cy := cos(b.yaw)
	var sy := sin(b.yaw)
	return Basis(Vector3(cy, 0, -sy) * b.size.x, Vector3(0, b.size.y, 0), Vector3(sy, 0, cy) * b.size.z)


# --- Geometry -------------------------------------------------------------------

func _add_building_mesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = _buildings.size()
	for i in _buildings.size():
		var b := _buildings[i]
		mm.set_instance_transform(i, Transform3D(_building_basis(b), b.pos))
		mm.set_instance_color(i, b.tint)
		mm.set_instance_custom_data(i, Color(b.seed, b.lit * _env.get("window_lit", 1.0), 0.0, 0.0))

	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = 0.04
	noise.fractal_octaves = 4
	var grime := NoiseTexture2D.new()
	grime.noise = noise
	grime.seamless = true
	grime.width = 256
	grime.height = 256

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/building.gdshader")
	mat.set_shader_parameter("grime", grime)
	mat.set_shader_parameter("ground_y", ground_y)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _add_signs() -> void:
	# Candidates: buildings near the track, weighted towards the closest.
	var near: Array[Dictionary] = []
	for b in _buildings:
		if b.track_dist < 150.0:
			near.append(b)
	if near.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	mm.mesh = quad
	mm.instance_count = sign_count
	var lights_left := sign_lights
	for i in sign_count:
		var b: Dictionary = near[_rng.randi_range(0, near.size() - 1)]
		var basis := _building_basis(b)
		# Face the sign toward the track: pick the wall whose normal points at the nearest frame.
		var toward: Vector3 = _track.frames[_track.get_nearest_frame_index(b.pos)].origin - b.pos
		toward.y = 0.0
		var faces := [basis.x.normalized(), -basis.x.normalized(), basis.z.normalized(), -basis.z.normalized()]
		var half := [b.size.x * 0.5, b.size.x * 0.5, b.size.z * 0.5, b.size.z * 0.5]
		var face_w := [b.size.z, b.size.z, b.size.x, b.size.x]
		var best := 0
		for k in 4:
			if faces[k].dot(toward) > faces[best].dot(toward):
				best = k
		var normal: Vector3 = faces[best]
		var tangent := Vector3.UP.cross(normal).normalized()
		var width: float = _rng.randf_range(6.0, minf(30.0, face_w[best] * 0.9))
		if _rng.randf() < 0.12:
			width = minf(48.0, face_w[best] * 0.95)  # giant billboard
		var height: float = width * _rng.randf_range(0.25, 0.6)
		if _rng.randf() < 0.2:
			var t := width
			width = height * 0.6
			height = t * 1.2
		var y: float = _rng.randf_range(6.0, maxf(8.0, b.size.y - height - 4.0))
		var lateral: float = _rng.randf_range(-1.0, 1.0) * (face_w[best] * 0.5 - width * 0.5 - 1.0)
		var pos: Vector3 = b.pos + normal * (half[best] + 0.35) + tangent * lateral
		pos.y = ground_y + y + height * 0.5
		var sign_basis := Basis(tangent * width, Vector3.UP * height, normal)
		mm.set_instance_transform(i, Transform3D(sign_basis, pos))
		var color: Color = SIGN_PALETTE[_rng.randi_range(0, SIGN_PALETTE.size() - 1)]
		color.a = _rng.randf()
		mm.set_instance_color(i, color)
		if lights_left > 0 and b.track_dist < 90.0 and width > 14.0:
			lights_left -= 1
			var light := OmniLight3D.new()
			light.light_color = Color(color.r, color.g, color.b)
			light.light_energy = 4.0
			light.omni_range = 90.0
			light.omni_attenuation = 1.2
			light.position = pos + normal * 3.0
			add_child(light)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/neon_sign.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _add_street_lights() -> void:
	# Sodium-orange lamps at street level between the towers: they mostly read as
	# glow in the fog far below the track, which is the Blade Runner look.
	var frames := _track.frames
	for i in street_lights:
		var f: Transform3D = frames[(i * frames.size()) / street_lights]
		var side := -1.0 if i % 2 == 0 else 1.0
		var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
		var light := OmniLight3D.new()
		light.position = f.origin + right * side * _rng.randf_range(20.0, 70.0)
		light.position.y = ground_y + 6.0
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 6.0
		light.omni_range = 120.0
		light.omni_attenuation = 1.5
		light.light_volumetric_fog_energy = 2.5
		add_child(light)


func _add_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position.y = ground_y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.035, 0.045)
	mat.roughness = 0.2
	mat.metallic = 0.1
	if _water:
		# Harbour: a flat, glossy sea that carries the sky.
		mat.albedo_color = Color(0.03, 0.12, 0.17)
		mat.roughness = 0.06
		mat.metallic = 0.55
	mi.material_override = mat
	add_child(mi)


func _add_searchlights() -> void:
	var tallest := _buildings.duplicate()
	tallest.sort_custom(func(a, b): return a.size.y > b.size.y)
	for i in mini(searchlight_count, tallest.size()):
		var b: Dictionary = tallest[i * 3 % tallest.size()]
		var light := SpotLight3D.new()
		light.position = b.pos + Vector3(0, b.size.y * 0.5 + 1.0, 0)
		light.light_color = Color(0.8, 0.85, 1.0)
		light.light_energy = 60.0
		light.spot_range = 700.0
		light.spot_angle = 4.0
		light.spot_attenuation = 0.6
		light.light_volumetric_fog_energy = 4.0
		light.shadow_enabled = false
		add_child(light)
		_searchlights.append(light)
		_beam_angles.append(_rng.randf() * TAU)


func _add_rain(camera: Node3D) -> void:
	if camera == null:
		return
	for old in camera.get_children():
		if old.name == "Rain":
			old.queue_free()
	if not _env.get("rain", true):
		return
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 18, 40)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 40.0
	pm.gravity = Vector3.ZERO
	var drop := QuadMesh.new()
	drop.size = Vector2(0.05, 1.1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.28)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = mat
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 2500
	rain.lifetime = 1.3
	rain.process_material = pm
	rain.draw_pass_1 = drop
	rain.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	rain.position = Vector3(0, 10, -14)
	camera.add_child(rain)
