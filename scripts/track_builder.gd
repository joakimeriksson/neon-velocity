@tool
class_name TrackBuilder
extends Node3D

## Generates a closed, banked race track from a list of control points.
## Builds the floor, side walls, neon edge strips, start line and a trimesh collider.

@export var track_width := 18.0
@export var wall_height := 2.5
@export var step := 2.0
## How strongly the track banks into corners (0 = flat).
@export var bank_strength := 22.0
@export var max_bank := 0.55
## Lap fractions where boost pads sit.
@export var boost_pad_positions: Array[float] = [0.12, 0.38, 0.6, 0.83]
@export var boost_pad_length := 6.0
@export var rebuild := false:
	set(value):
		build()

## One lap, roughly 2.3 km (~30 s at race pace). Y is elevation.
const CONTROL_POINTS: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(220, 0, -150),
	Vector3(380, 25, -420),
	Vector3(280, 45, -720),
	Vector3(0, 20, -820),
	Vector3(-280, 0, -700),
	Vector3(-420, -20, -380),
	Vector3(-300, -5, -100),
]

var frames: Array[Transform3D] = []

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _strip_mat: StandardMaterial3D
var _start_mat: StandardMaterial3D
var _boost_mat: StandardMaterial3D


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_make_materials()
	frames = _sample_frames(_make_curve())
	_add_mesh(_build_surface(), _floor_mat, true)
	_add_mesh(_build_walls(), _wall_mat, true)
	_add_mesh(_build_strips(), _strip_mat, false)
	_add_mesh(_build_start_line(), _start_mat, false)
	_add_boost_pads()
	_add_void_floor()


## Where the ship starts: on the start line, hovering, facing down the track.
func get_start_transform() -> Transform3D:
	var f := frames[0]
	return Transform3D(f.basis, f.origin + f.basis.y * 1.5)


## Closest track frame to a world position (for respawns and lap progress).
## With a hint (the previous answer) only a window around it is searched.
func get_nearest_frame_index(pos: Vector3, hint := -1) -> int:
	var n := frames.size()
	var lo := 0
	var hi := n
	if hint >= 0:
		lo = hint - 10
		hi = hint + 40
	var best := 0
	var best_d := INF
	for k in range(lo, hi):
		var i := posmod(k, n)
		var d := frames[i].origin.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## Starting grid: two columns, staggered back from the start line.
func get_grid_transforms(count: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var n := frames.size()
	for i in count:
		var back := 3 + i * 3          # frames behind the line
		var side := -1.0 if i % 2 == 0 else 1.0
		var f := frames[posmod(-back, n)]
		result.append(Transform3D(f.basis, f.origin + f.basis.x * side * track_width * 0.22 + f.basis.y * 1.5))
	return result


func get_respawn_transform(pos: Vector3) -> Transform3D:
	var f := frames[get_nearest_frame_index(pos)]
	return Transform3D(f.basis, f.origin + f.basis.y * 1.5)


## 0..1 progress around the lap.
func get_progress(pos: Vector3) -> float:
	return float(get_nearest_frame_index(pos)) / float(frames.size())


func lowest_y() -> float:
	var y := INF
	for f in frames:
		y = minf(y, f.origin.y)
	return y


# --- Geometry -----------------------------------------------------------------

func _make_curve() -> Curve3D:
	var curve := Curve3D.new()
	var n := CONTROL_POINTS.size()
	for i in n:
		var prev := CONTROL_POINTS[(i - 1 + n) % n]
		var next := CONTROL_POINTS[(i + 1) % n]
		var tangent := (next - prev) * 0.25
		curve.add_point(CONTROL_POINTS[i], -tangent, tangent)
	curve.closed = true
	curve.bake_interval = 0.5
	return curve


## Samples evenly spaced frames along the curve. Basis: x = right, y = up, -z = forward.
func _sample_frames(curve: Curve3D) -> Array[Transform3D]:
	var length := curve.get_baked_length()
	var count := int(length / step)
	var positions: Array[Vector3] = []
	var forwards: Array[Vector3] = []
	for i in count:
		var s := i * step
		var p := curve.sample_baked(s)
		var p2 := curve.sample_baked(fmod(s + 0.5, length))
		positions.append(p)
		forwards.append((p2 - p).normalized())

	# Bank from local curvature: positive = left turn -> raise the right (outer) edge.
	var banks: Array[float] = []
	for i in count:
		var a := forwards[(i - 1 + count) % count]
		var b := forwards[(i + 1) % count]
		banks.append(clampf(a.cross(b).y * bank_strength, -max_bank, max_bank))
	for _pass in 6:
		var smoothed: Array[float] = []
		for i in count:
			smoothed.append((banks[(i - 1 + count) % count] + banks[i] + banks[(i + 1) % count]) / 3.0)
		banks = smoothed

	var result: Array[Transform3D] = []
	for i in count:
		var fwd := forwards[i]
		var right := fwd.cross(Vector3.UP).normalized()
		var up := right.cross(fwd).normalized()
		# Rotating about the forward axis by a negative angle lifts the right edge.
		right = right.rotated(fwd, -banks[i])
		up = up.rotated(fwd, -banks[i])
		result.append(Transform3D(Basis(right, up, -fwd), positions[i]))
	return result


func _edge(i: int, side: float, lift := 0.0) -> Vector3:
	var f := frames[i % frames.size()]
	return f.origin + f.basis.x * side * track_width * 0.5 + f.basis.y * lift


func _build_surface() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in frames.size():
		var n0 := frames[i].basis.y
		var n1 := frames[(i + 1) % frames.size()].basis.y
		var v := float(i) * step / track_width
		_quad(st,
			_edge(i, -1), _edge(i, 1), _edge(i + 1, 1), _edge(i + 1, -1),
			n0, n0, n1, n1,
			Vector2(0, v), Vector2(1, v), Vector2(1, v + step / track_width), Vector2(0, v + step / track_width))
	return st.commit()


func _build_walls() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in frames.size():
		var f0 := frames[i]
		var f1 := frames[(i + 1) % frames.size()]
		var v := float(i) * step / wall_height
		var uv0 := Vector2(0, v)
		var uv1 := Vector2(1, v)
		var uv2 := Vector2(1, v + step / wall_height)
		var uv3 := Vector2(0, v + step / wall_height)
		# Left wall faces +x (inward), right wall faces -x.
		_quad(st,
			_edge(i, -1), _edge(i, -1, wall_height), _edge(i + 1, -1, wall_height), _edge(i + 1, -1),
			f0.basis.x, f0.basis.x, f1.basis.x, f1.basis.x, uv0, uv1, uv2, uv3)
		_quad(st,
			_edge(i, 1), _edge(i, 1, wall_height), _edge(i + 1, 1, wall_height), _edge(i + 1, 1),
			-f0.basis.x, -f0.basis.x, -f1.basis.x, -f1.basis.x, uv0, uv1, uv2, uv3)
	return st.commit()


func _build_strips() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := 1.0 - 1.2 / track_width
	for i in frames.size():
		var n0 := frames[i].basis.y
		var n1 := frames[(i + 1) % frames.size()].basis.y
		for side in [-1.0, 1.0]:
			_quad(st,
				_edge(i, side, 0.03), _edge(i, side * inner, 0.03),
				_edge(i + 1, side * inner, 0.03), _edge(i + 1, side, 0.03),
				n0, n0, n1, n1, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
	return st.commit()


func _build_start_line() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := frames[0].basis.y
	_quad(st,
		_edge(0, -1, 0.04), _edge(0, 1, 0.04), _edge(1, 1, 0.04), _edge(1, -1, 0.04),
		n, n, n, n, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# Clockwise winding: Godot treats clockwise faces as front, and trimesh collision
	# only registers front faces, so a flipped track would be fall-through from above.
	for tri in [[a, na, ua], [c, nc, uc], [b, nb, ub], [a, na, ua], [d, nd, ud], [c, nc, uc]]:
		st.set_normal(tri[1])
		st.set_uv(tri[2])
		st.add_vertex(tri[0])


func _add_mesh(mesh: ArrayMesh, material: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		mi.add_child(body)


func _add_boost_pads() -> void:
	var n := frames.size()
	var pad_frames := int(boost_pad_length / step)
	for fraction in boost_pad_positions:
		var start := int(fraction * n)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in pad_frames:
			var i := (start + k) % n
			var up0 := frames[i].basis.y
			var up1 := frames[(i + 1) % n].basis.y
			_quad(st,
				_edge(i, -0.4, 0.05), _edge(i, 0.4, 0.05), _edge(i + 1, 0.4, 0.05), _edge(i + 1, -0.4, 0.05),
				up0, up0, up1, up1, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
		_add_mesh(st.commit(), _boost_mat, false)

		var mid := frames[(start + pad_frames / 2) % n]
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(track_width * 0.8, 4.0, boost_pad_length)
		shape.shape = box
		area.add_child(shape)
		area.transform = Transform3D(mid.basis, mid.origin + mid.basis.y * 1.5)
		area.body_entered.connect(_on_boost_pad_entered)
		add_child(area)


func _on_boost_pad_entered(body: Node3D) -> void:
	if body is Ship:
		body.boost()


func _add_void_floor() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	mi.mesh = plane
	mi.position.y = lowest_y() - 80.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.01, 0.04)
	mi.material_override = mat
	add_child(mi)


func _make_materials() -> void:
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.13, 0.13, 0.16)
	_floor_mat.roughness = 0.35
	_floor_mat.metallic = 0.4
	_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.1, 0.1, 0.16)
	_wall_mat.roughness = 0.6
	_wall_mat.emission_enabled = true
	_wall_mat.emission = Color(0.1, 0.5, 0.7)
	_wall_mat.emission_energy_multiplier = 0.25
	_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_strip_mat = StandardMaterial3D.new()
	_strip_mat.albedo_color = Color(0.1, 0.9, 1.0)
	_strip_mat.emission_enabled = true
	_strip_mat.emission = Color(0.1, 0.9, 1.0)
	_strip_mat.emission_energy_multiplier = 3.0
	_strip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_start_mat = StandardMaterial3D.new()
	_start_mat.albedo_color = Color(1.0, 0.4, 0.9)
	_start_mat.emission_enabled = true
	_start_mat.emission = Color(1.0, 0.4, 0.9)
	_start_mat.emission_energy_multiplier = 3.0
	_start_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_boost_mat = StandardMaterial3D.new()
	_boost_mat.albedo_color = Color(1.0, 0.55, 0.1)
	_boost_mat.emission_enabled = true
	_boost_mat.emission = Color(1.0, 0.55, 0.1)
	_boost_mat.emission_energy_multiplier = 2.5
	_boost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
