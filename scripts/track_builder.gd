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
## Lap fractions where item pads sit (one each side of the centre line).
@export var item_pad_positions: Array[float] = []
@export var item_pad_cooldown := 3.0
## Pit lane: [start fraction, end fraction, side (-1 left, +1 right)]. Recharges energy.
@export var pit_lane: Array = [0.9, 0.985, 1.0]
@export var rebuild := false:
	set(value):
		build()

var control_points: Array[Vector3] = []
var neon_color := Color(0.1, 0.9, 1.0)
var light_color := Color(0.8, 0.9, 1.0)
## The road reflects the sun and sky; daylight circuits make it rougher and less metallic so it
## does not glare (the web renderer has no screen-space reflections and mirrors the bright sky).
var road_roughness := 0.35
var road_metallic := 0.4
var lit_sections: Array = []   # [[start_fraction, end_fraction], ...]
## Vertical features: ["crest" | "drop", lap fraction, height (m), length (m)]. Each snaps to
## the straightest stretch near its fraction. See _apply_relief().
var relief: Array = []
var relief_placed: Array = []   # [[kind, first frame, last frame], ...] where they ended up
## Frame ranges [first, last) with no road at all: fly it or fall.
var gaps: Array = []
## Roofed stretches as lap fractions [[start, end], ...]; trimmed clear of crests and gaps.
var tunnels: Array = []
var tunnel_ranges: Array = []   # [[first frame, last frame], ...] as built
## Stretches with no wall: [[start fraction, end fraction, side]], side -1 left, 1 right, 0 both.
var open_edges: Array = []

var frames: Array[Transform3D] = []
## Corner radius (m) at each frame, capped at 2000 on the straights. The AI brakes by it.
var radius := PackedFloat32Array()

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _strip_mat: StandardMaterial3D
var _start_mat: StandardMaterial3D
var _boost_mat: StandardMaterial3D
var _pit_mat: StandardMaterial3D
var _tunnel_mat: StandardMaterial3D
var _pad_ready_at := {}   # Area3D -> time (s) the item pad comes back


func _ready() -> void:
	# At runtime Race calls load_def(); in the editor show the first circuit.
	if Engine.is_editor_hint():
		load_def(TrackDefs.ALL[0])


## Configure from a TrackDefs entry and (re)build.
func load_def(def: Dictionary) -> void:
	control_points.assign(def.points)
	track_width = def.get("width", 18.0)
	bank_strength = def.get("bank_strength", 22.0)
	neon_color = def.get("neon", neon_color)
	road_roughness = def.get("env", {}).get("road_roughness", 0.35)
	road_metallic = def.get("env", {}).get("road_metallic", 0.4)
	light_color = def.get("light_color", light_color)
	lit_sections = def.get("lit_sections", [])
	relief = def.get("relief", [])
	tunnels = def.get("tunnels", [])
	open_edges = def.get("open_edges", [])
	boost_pad_positions.assign(def.get("boost_pads", [0.12, 0.38, 0.6, 0.83]))
	item_pad_positions.assign(def.get("item_pads", _default_item_pads()))
	pit_lane = def.get("pit", [0.9, 0.985, 1.0])
	build()


## Halfway between consecutive boost pads, skipping anything inside the pit lane stretch.
func _default_item_pads() -> Array:
	var result := []
	var pads := boost_pad_positions.duplicate()
	pads.sort()
	for i in pads.size():
		var a: float = pads[i]
		var b: float = pads[(i + 1) % pads.size()] + (1.0 if i == pads.size() - 1 else 0.0)
		var mid := fposmod((a + b) * 0.5, 1.0)
		if mid < 0.88 and mid > 0.03:
			result.append(mid)
	return result


func build() -> void:
	if control_points.is_empty():
		return
	for child in get_children():
		remove_child(child)
		child.free()
	_make_materials()
	_pad_ready_at.clear()
	frames = _sample_frames(_make_curve())
	_measure_radius()
	_plan_tunnels()
	_add_mesh(_build_surface(), _floor_mat, true)
	_add_mesh(_build_walls(), _wall_mat, true)
	_add_mesh(_build_strips(), _strip_mat, false)
	_add_mesh(_build_start_line(), _start_mat, false)
	_add_gap_edges()
	_add_tunnels()
	_add_boost_pads()
	_add_item_pads()
	_add_pit_lane()
	_add_track_lights()
	_add_void_floor()


func _measure_radius() -> void:
	var n := frames.size()
	radius.resize(n)
	for i in n:
		var a: Vector3 = -frames[(i - 3 + n) % n].basis.z
		var b: Vector3 = -frames[(i + 3) % n].basis.z
		a.y = 0.0
		b.y = 0.0
		var angle := absf(a.normalized().signed_angle_to(b.normalized(), Vector3.UP))
		radius[i] = minf(6.0 * step / maxf(angle, 0.00001), 2000.0)


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
	var f := frames[safe_frame(get_nearest_frame_index(pos))]
	return Transform3D(f.basis, f.origin + f.basis.y * 1.5)


func in_gap(index: int) -> bool:
	var i := posmod(index, frames.size())
	for g in gaps:
		if i >= g[0] and i < g[1]:
			return true
	return false


## A frame with road under it: anything on a ramp's lip or over a gap moves to the far side,
## so a rescued ship isn't asked to jump the gap again from a standstill.
func safe_frame(index: int) -> int:
	var i := posmod(index, frames.size())
	for g in gaps:
		if i >= g[0] - 12 and i < g[1] + 4:
			return (g[1] + 6) % frames.size()
	return i


func is_open(index: int, side: float) -> bool:
	var fraction := float(posmod(index, frames.size())) / float(frames.size())
	for e in open_edges:
		if fraction >= e[0] and fraction < e[1] and (e[2] == 0 or signf(e[2]) == signf(side)):
			return not in_tunnel(index)
	return false


func in_tunnel(index: int) -> bool:
	var i := posmod(index, frames.size())
	for t in tunnel_ranges:
		if i >= t[0] and i < t[1]:
			return true
	return false


## 0..1 progress around the lap.
func get_progress(pos: Vector3) -> float:
	return float(get_nearest_frame_index(pos)) / float(frames.size())


## Interpolated frame at a fractional frame index, shifted `lateral` metres to the right and
## `lift` metres off the surface. Projectiles and mines live in these coordinates.
func get_point(s: float, lateral := 0.0, lift := 0.0) -> Transform3D:
	var n := frames.size()
	var i := posmod(floori(s), n)
	var t := s - floorf(s)
	var a := frames[i]
	var b := frames[(i + 1) % n]
	var basis := a.basis.slerp(b.basis, t)
	var origin := a.origin.lerp(b.origin, t)
	return Transform3D(basis, origin + basis.x * lateral + basis.y * lift)


## Metres right of the centre line, measured in the given frame.
func get_lateral(pos: Vector3, index: int) -> float:
	var f := frames[posmod(index, frames.size())]
	return (pos - f.origin).dot(f.basis.x)


## The pit lane's lateral band: [inner edge, outer edge] in metres from the centre, signed.
func pit_band() -> Array:
	var side: float = pit_lane[2]
	return [side * track_width * 0.3, side * track_width * 0.48]


func in_pit(index: int, lateral: float) -> bool:
	var fraction := float(index) / float(frames.size())
	if fraction < pit_lane[0] or fraction > pit_lane[1]:
		return false
	var band := pit_band()
	return lateral >= minf(band[0], band[1]) and lateral <= maxf(band[0], band[1])


func lowest_y() -> float:
	var y := INF
	for f in frames:
		y = minf(y, f.origin.y)
	return y


# --- Geometry -----------------------------------------------------------------

func _make_curve() -> Curve3D:
	var curve := Curve3D.new()
	var n := control_points.size()
	for i in n:
		var prev := control_points[(i - 1 + n) % n]
		var next := control_points[(i + 1) % n]
		var tangent := (next - prev) * 0.25
		curve.add_point(control_points[i], -tangent, tangent)
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

	_apply_relief(positions)
	# Headings follow the reshaped road.
	for i in count:
		forwards[i] = (positions[(i + 1) % count] - positions[i]).normalized()

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


## How far (m, horizontally) the road strays from a straight line drawn from frame `from`
## along its heading, over the next `frames_ahead` frames.
func _flight_deviation(positions: Array[Vector3], from: int, frames_ahead: int) -> float:
	var count := positions.size()
	var origin := positions[posmod(from, count)]
	var heading := positions[posmod(from + 1, count)] - origin
	heading.y = 0.0
	heading = heading.normalized()
	var worst := 0.0
	for k in range(2, frames_ahead):
		var r := positions[posmod(from + k, count)] - origin
		r.y = 0.0
		worst = maxf(worst, (r - heading * r.dot(heading)).length())
	return worst


## Crests, drops and gaps, the things that throw a fast ship into the air.
##  - crest: a raised-cosine hump `height` tall over `length` metres. The ship leaves the road
##    on the way up and lands beyond it.
##  - drop: the road falls `height` over `length` metres, then climbs back gently over the next
##    500 m so the lap still closes.
##  - gap: a kicker ramp rising `height` over `length` metres with its steepest point at the
##    lip, then `gap` metres (5th value) of nothing, then the road again at its original level.
##    The frames across the gap still exist (for the AI, laps and projectiles); only the road,
##    walls and neon are missing.
## Each is slid along the lap (up to an eighth of it) to where a straight flight strays least
## from the road, kept clear of the other features, the start, the grid and the pit lane.
func _apply_relief(positions: Array[Vector3]) -> void:
	relief_placed.clear()
	gaps.clear()
	var count := positions.size()
	for feature in relief:
		var kind: String = feature[0]
		var height: float = feature[2]
		var length: float = feature[3]
		var gap_length: float = feature[4] if feature.size() > 4 else 0.0
		var span := int((length + gap_length + 170.0) / step)   # the feature plus room to fly and land
		var frames_long_ := int(length / step)
		# Where the ship leaves the road, and how far it then flies in a straight line.
		var launch := frames_long_ if kind == "gap" else (frames_long_ / 2 if kind == "crest" else 0)
		var flight := int((gap_length + 90.0) / step) if kind == "gap" else int((110.0 if kind == "crest" else 60.0) / step)
		var want := int(float(feature[1]) * count)
		var lo := maxi(want - count / 8, count / 25)
		var hi := mini(want + count / 8, int(count * 0.86) - span)
		var best := clampi(want, lo, maxi(lo, hi))
		var best_cost := INF
		for start in range(lo, maxi(lo + 1, hi)):
			var clash := false
			for r in relief_placed:
				if start < r[2] + 20 and start + span > r[1] - 45:
					clash = true
			if clash:
				continue
			# A flight is a straight line; the cost is how far the road strays from it, plus
			# a little for a curving run-up and for moving away from where it was asked for.
			var cost := _flight_deviation(positions, start + launch, flight)
			cost += _flight_deviation(positions, start - int(40.0 / step), int(40.0 / step) + launch) * 0.5
			cost += 40.0 * absf(start - want) / float(count)
			if cost < best_cost:
				best_cost = cost
				best = start
		# A gap where the road curves away under the flight is a trap, not a jump.
		if kind == "gap" and _flight_deviation(positions, best + launch, flight) > track_width * 0.3:
			push_warning("TrackBuilder: no stretch straight enough for the gap asked for at %.0f%%; skipped" % (float(feature[1]) * 100.0))
			continue
		relief_placed.append([kind, best, best + span])
		var frames_long := int(length / step)
		if kind == "gap":
			var gap_frames := int(gap_length / step)
			for k in frames_long + gap_frames:
				var offset := height * pow(float(k) / float(frames_long), 2.0)
				if k > frames_long:
					offset = height * (1.0 - float(k - frames_long) / float(gap_frames))
				positions[(best + k) % count].y += offset
			gaps.append([best + frames_long, best + frames_long + gap_frames])
		elif kind == "crest":
			for k in frames_long + 1:
				var x := float(k) / float(frames_long)
				positions[(best + k) % count].y += height * 0.5 * (1.0 - cos(TAU * x))
		else:
			var recover := int(500.0 / step)
			for k in frames_long + recover:
				var fall := smoothstep(0.0, 1.0, float(k) / float(frames_long))
				var climb := clampf(float(k - frames_long) / float(recover), 0.0, 1.0)
				positions[(best + k) % count].y -= height * fall * (1.0 - smoothstep(0.0, 1.0, climb))


func _edge(i: int, side: float, lift := 0.0) -> Vector3:
	var f := frames[i % frames.size()]
	return f.origin + f.basis.x * side * track_width * 0.5 + f.basis.y * lift


func _build_surface() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in frames.size():
		if in_gap(i):
			continue
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
		if in_gap(i):
			continue
		var f0 := frames[i]
		var f1 := frames[(i + 1) % frames.size()]
		var v := float(i) * step / wall_height
		var uv0 := Vector2(0, v)
		var uv1 := Vector2(1, v)
		var uv2 := Vector2(1, v + step / wall_height)
		var uv3 := Vector2(0, v + step / wall_height)
		# Left wall faces +x (inward), right wall faces -x. The left wall is the mirror image,
		# so its vertices run the other way round: trimesh collision only registers front
		# faces, and with the right wall's order the left one was pass-through from the track.
		if not is_open(i, -1.0):
			_quad(st,
				_edge(i + 1, -1), _edge(i + 1, -1, wall_height), _edge(i, -1, wall_height), _edge(i, -1),
				f1.basis.x, f1.basis.x, f0.basis.x, f0.basis.x, uv3, uv2, uv1, uv0)
		if not is_open(i, 1.0):
			_quad(st,
				_edge(i, 1), _edge(i, 1, wall_height), _edge(i + 1, 1, wall_height), _edge(i + 1, 1),
				-f0.basis.x, -f0.basis.x, -f1.basis.x, -f1.basis.x, uv0, uv1, uv2, uv3)
	return st.commit()


func _build_strips() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := 1.0 - 1.2 / track_width
	for i in frames.size():
		if in_gap(i):
			continue
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
		var start := _clear_of_gaps(int(fraction * n), pad_frames)
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
		# Two triggers: the painted pad itself boosts; a wider zone around it only counts as
		# a near miss (whoosh, no boost). The pad mesh spans 40% of the track width.
		_add_pad_area(mid, track_width * 0.4, _on_boost_pad_entered)
		_add_pad_area(mid, track_width * 0.95, _on_boost_pad_near)


func _add_pad_area(frame: Transform3D, width: float, handler: Callable) -> void:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 4.0, boost_pad_length)
	shape.shape = box
	area.add_child(shape)
	area.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 1.5)
	area.body_entered.connect(handler)
	add_child(area)


func _on_boost_pad_entered(body: Node3D) -> void:
	if body is Ship:
		body.boost()


func _on_boost_pad_near(body: Node3D) -> void:
	if body is Ship:
		body.pad_near()


## Slide a pad that would sit on a ramp or hang over a gap to just past the landing.
func _clear_of_gaps(start: int, length: int) -> int:
	for g in gaps:
		if start + length > g[0] - 30 and start < g[1] + 20:
			return g[1] + 24
	return start


## A bright bar across the lip and across the landing edge, so a gap can be read at speed.
func _add_gap_edges() -> void:
	for g in gaps:
		var lip: int = g[0]
		var landing: int = g[1]
		for i: int in [lip, landing]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var back: int = i - 1 if i == lip else i
			var up := frames[back % frames.size()].basis.y
			_quad(st,
				_edge(back, -1, 0.06), _edge(back, 1, 0.06), _edge(back + 1, 1, 0.06), _edge(back + 1, -1, 0.06),
				up, up, up, up, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
			_add_mesh(st.commit(), _start_mat if i == lip else _pit_mat, false)


## Tunnel ranges, trimmed so no tunnel covers a crest, ramp or gap.
func _plan_tunnels() -> void:
	tunnel_ranges.clear()
	var n := frames.size()
	for t in tunnels:
		var first := int(float(t[0]) * n)
		var last := int(float(t[1]) * n)
		for r in relief_placed:
			var r_first: int = r[1] - 25
			var r_last: int = r[2]
			if r_first < last and r_last > first:
				# Keep the longer side of whatever the feature cuts through.
				if r_first - first >= last - r_last:
					last = r_first
				else:
					first = r_last
		if last - first > 30:
			tunnel_ranges.append([first, last])


## Tunnels: the walls carried up and over into a faceted roof, a neon rib every 16 m and a
## light line along each shoulder.
func _add_tunnels() -> void:
	var n := frames.size()
	var half := track_width * 0.5
	# Cross-section, left to right, as (fraction of half width, height).
	var profile := [Vector2(-1.0, wall_height), Vector2(-1.0, 4.2), Vector2(-0.62, 7.0), Vector2(0.62, 7.0), Vector2(1.0, 4.2), Vector2(1.0, wall_height)]
	for range_ in tunnel_ranges:
		var first_frame: int = range_[0]
		var last_frame: int = range_[1]
		var shell := SurfaceTool.new()
		shell.begin(Mesh.PRIMITIVE_TRIANGLES)
		var glow := SurfaceTool.new()
		glow.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(first_frame, last_frame):
			var f0 := frames[i % n]
			var f1 := frames[(i + 1) % n]
			var rib: bool = (i - first_frame) % 8 == 0
			for k in profile.size() - 1:
				var a0: Vector3 = f0.origin + f0.basis.x * profile[k].x * half + f0.basis.y * profile[k].y
				var b0: Vector3 = f0.origin + f0.basis.x * profile[k + 1].x * half + f0.basis.y * profile[k + 1].y
				var a1: Vector3 = f1.origin + f1.basis.x * profile[k].x * half + f1.basis.y * profile[k].y
				var b1: Vector3 = f1.origin + f1.basis.x * profile[k + 1].x * half + f1.basis.y * profile[k + 1].y
				var normal: Vector3 = -((b0 - a0).cross(a1 - a0)).normalized()
				_quad(shell, a0, b0, b1, a1, normal, normal, normal, normal, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
				if rib:
					# A thin lit band just inside the shell.
					var inset := -normal * 0.06
					var a_end: Vector3 = a0.lerp(a1, 0.3)
					var b_end: Vector3 = b0.lerp(b1, 0.3)
					_quad(glow, a0 + inset, b0 + inset, b_end + inset, a_end + inset, normal, normal, normal, normal, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
			# Light lines along both shoulders.
			for side in [-1.0, 1.0]:
				var p0: Vector3 = f0.origin + f0.basis.x * side * half * 0.98 + f0.basis.y * 4.0
				var p1: Vector3 = f1.origin + f1.basis.x * side * half * 0.98 + f1.basis.y * 4.0
				var q0: Vector3 = p0 + f0.basis.y * 0.25
				var q1: Vector3 = p1 + f1.basis.y * 0.25
				var inward: Vector3 = -f0.basis.x * side
				_quad(glow, p0, q0, q1, p1, inward, inward, inward, inward, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)

		var shell_mi := MeshInstance3D.new()
		shell_mi.mesh = shell.commit()
		shell_mi.material_override = _tunnel_mat
		add_child(shell_mi)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var trimesh: ConcavePolygonShape3D = shell_mi.mesh.create_trimesh_shape()
		trimesh.backface_collision = true   # the roof has to stop a ship from inside
		shape.shape = trimesh
		body.add_child(shape)
		shell_mi.add_child(body)
		_add_mesh(glow.commit(), _strip_mat, false)

		# Enough real light to see the ships by.
		var at := first_frame + 10
		while at < last_frame:
			var f := frames[at % n]
			var light := OmniLight3D.new()
			light.light_color = neon_color.lerp(Color.WHITE, 0.4)
			light.light_energy = 2.2
			light.omni_range = 26.0
			light.position = f.origin + f.basis.y * 5.6
			add_child(light)
			at += 20


## Item pads: a pair per position, either side of the centre line, so picking one up means
## leaving the racing line. A pad goes dark for a few seconds after it's taken.
func _add_item_pads() -> void:
	var n := frames.size()
	var pad_frames := int(boost_pad_length / step)
	for fraction in item_pad_positions:
		var start := _clear_of_gaps(int(fraction * n), pad_frames)
		for side in [-1.0, 1.0]:
			var inner: float = side * 0.2
			var outer: float = side * 0.62
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for k in pad_frames:
				var i := (start + k) % n
				var up0 := frames[i].basis.y
				var up1 := frames[(i + 1) % n].basis.y
				_quad(st,
					_edge(i, minf(inner, outer), 0.05), _edge(i, maxf(inner, outer), 0.05),
					_edge(i + 1, maxf(inner, outer), 0.05), _edge(i + 1, minf(inner, outer), 0.05),
					up0, up0, up1, up1, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.3, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.85, 0.3, 1.0)
			mat.emission_energy_multiplier = 3.0
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add_mesh(st.commit(), mat, false)

			var mid := frames[(start + pad_frames / 2) % n]
			var area := Area3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(track_width * 0.21, 4.0, boost_pad_length)
			shape.shape = box
			area.add_child(shape)
			area.transform = Transform3D(mid.basis, mid.origin + mid.basis.x * side * track_width * 0.205 + mid.basis.y * 1.5)
			area.body_entered.connect(_on_item_pad_entered.bind(area, mat))
			add_child(area)


func _on_item_pad_entered(body: Node3D, area: Area3D, mat: StandardMaterial3D) -> void:
	if not (body is Ship):
		return
	# Game time, not wall-clock, so pads behave the same in slow motion or a fast headless sim.
	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	if now < _pad_ready_at.get(area, 0.0):
		return
	if body.collect_item_pad():
		_pad_ready_at[area] = now + item_pad_cooldown
		mat.emission_energy_multiplier = 0.15
		var tween := create_tween()
		tween.tween_interval(item_pad_cooldown)
		tween.tween_property(mat, ^"emission_energy_multiplier", 3.0, 0.3)


## Pit lane: a dashed recharge strip along one edge. Race checks `in_pit()` each frame.
func _add_pit_lane() -> void:
	var n := frames.size()
	var start := int(pit_lane[0] * n)
	var end := int(pit_lane[1] * n)
	var side: float = pit_lane[2]
	var lo := minf(side * 0.6, side * 0.96)
	var hi := maxf(side * 0.6, side * 0.96)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(start, end):
		if (i - start) % 3 == 2:
			continue   # gap: reads as chevrons at speed
		var up0 := frames[i % n].basis.y
		var up1 := frames[(i + 1) % n].basis.y
		_quad(st,
			_edge(i, lo, 0.04), _edge(i, hi, 0.04), _edge(i + 1, hi, 0.04), _edge(i + 1, lo, 0.04),
			up0, up0, up1, up1, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
	_add_mesh(st.commit(), _pit_mat, false)
	# A green bar over the lane's entry and exit, so the lane can be found at speed.
	for i in [start, end]:
		var f := frames[i % n]
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.4, 0.4)
		beam.mesh = box
		beam.material_override = _pit_mat
		var width := track_width * 0.2
		beam.transform = Transform3D(Basis(f.basis.x * width, f.basis.y, f.basis.z), f.origin + f.basis.x * side * track_width * 0.39 + f.basis.y * 4.5)
		add_child(beam)


## Artificial lighting along `lit_sections`: lamp poles on alternating sides every 24 m,
## and a light gantry across the track at the start of each section.
func _add_track_lights() -> void:
	var n := frames.size()
	var pole_spacing := int(24.0 / step)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = light_color
	lamp_mat.emission_enabled = true
	lamp_mat.emission = light_color
	lamp_mat.emission_energy_multiplier = 4.0
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.2, 0.22)
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.5
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.18
	pole_mesh.height = 7.0
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.5, 0.25, 1.4)
	var gantry_mesh := BoxMesh.new()
	gantry_mesh.size = Vector3(1.0, 0.35, 0.35)
	var k := 0
	for section in lit_sections:
		var start := int(section[0] * n)
		var end := int(section[1] * n)
		_add_gantry(frames[start % n], gantry_mesh, lamp_mat, pole_mesh, pole_mat)
		var i := start
		while i < end:
			if in_gap(i) or in_tunnel(i):
				i += pole_spacing
				continue
			var f := frames[i % n]
			var side := -1.0 if k % 2 == 0 else 1.0
			k += 1
			var base := f.origin + f.basis.x * side * (track_width * 0.5 + 0.6)
			var pole := MeshInstance3D.new()
			pole.mesh = pole_mesh
			pole.material_override = pole_mat
			pole.transform = Transform3D(f.basis, base + f.basis.y * 3.5)
			add_child(pole)
			var lamp := MeshInstance3D.new()
			lamp.mesh = lamp_mesh
			lamp.material_override = lamp_mat
			lamp.transform = Transform3D(f.basis, base + f.basis.y * 7.0 - f.basis.x * side * 1.0)
			add_child(lamp)
			var light := OmniLight3D.new()
			light.light_color = light_color
			light.light_energy = 4.0
			light.omni_range = 40.0
			light.omni_attenuation = 1.3
			light.position = base + f.basis.y * 6.6 - f.basis.x * side * 1.5
			add_child(light)
			i += pole_spacing


func _add_gantry(f: Transform3D, beam_mesh: Mesh, lamp_mat: Material, pole_mesh: Mesh, pole_mat: Material) -> void:
	var height := 7.5
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = lamp_mat
	# Scale the beam along the track's own right vector, not the world X axis.
	beam.transform = Transform3D(Basis(f.basis.x * (track_width + 2.0), f.basis.y, f.basis.z), f.origin + f.basis.y * height)
	add_child(beam)
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.material_override = pole_mat
		pole.transform = Transform3D(f.basis, f.origin + f.basis.x * side * (track_width * 0.5 + 0.6) + f.basis.y * 3.75)
		add_child(pole)
	var light := OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = 5.0
	light.omni_range = 45.0
	light.omni_attenuation = 1.2
	light.position = f.origin + f.basis.y * (height - 0.6)
	add_child(light)


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
	_floor_mat.roughness = road_roughness
	_floor_mat.metallic = road_metallic
	_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.1, 0.1, 0.16)
	_wall_mat.roughness = 0.6
	_wall_mat.emission_enabled = true
	_wall_mat.emission = neon_color * 0.6
	_wall_mat.emission_energy_multiplier = 0.25
	_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_strip_mat = StandardMaterial3D.new()
	_strip_mat.albedo_color = neon_color
	_strip_mat.emission_enabled = true
	_strip_mat.emission = neon_color
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

	_tunnel_mat = StandardMaterial3D.new()
	_tunnel_mat.albedo_color = Color(0.11, 0.12, 0.16)
	_tunnel_mat.roughness = 0.45
	_tunnel_mat.metallic = 0.35
	_tunnel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_pit_mat = StandardMaterial3D.new()
	_pit_mat.albedo_color = Color(0.2, 1.0, 0.65)
	_pit_mat.emission_enabled = true
	_pit_mat.emission = Color(0.2, 1.0, 0.65)
	_pit_mat.emission_energy_multiplier = 2.0
	_pit_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
