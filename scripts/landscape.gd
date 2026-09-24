class_name Landscape
extends Node3D

## Terrain, water and structures for circuits whose definition has a "landscape": the lap
## runs through zones (city, mountain, cliff road, forest, docks, causeway), each shaping the
## ground beside the road its own way. Where the ground falls away the road stands on piers,
## where a tunnel runs the mountain closes over it.
##
## How the height of a terrain point is found:
##  1. A distance transform over the grid gives every point its nearest track frame.
##  2. Natural ground: lake bottom inside the lap, rolling land outside, a ring of mountains
##     beyond `mountains_from`, plus authored peaks, basins and a ravine under each gap.
##  3. The zone at the nearest frame shapes the ground near the road, per side: a flat bed
##     (`near`, `ledge`), then a blend over `reach` to the natural ground, or up a `wall`.
##  4. Nothing may rise into the road: the ground stays BED below it for a cell and a half
##     beyond the corridor, and from there rises no steeper than CLIFF_SLOPE, so no triangle
##     that reaches over the road can lift above it.

const G := 8.0              ## grid spacing (m)
const MARGIN := 800.0       ## terrain reaches this far beyond the track's bounding box
const BED := 2.5            ## ground under and beside the road sits this far below it
const CLIFF_SLOPE := 2.5    ## steepest rise away from the road (68 degrees)
const BLEND_FRAMES := 40    ## neighbouring zones blend over this many frames (80 m)
const TERRAIN_LAYER := 2    ## physics layer: ships collide with it, their ground ray ignores it

## Zone presets. `mat` is (rock, grass, urban, unused), `trees` a density 0..1, `fog` the tint
## the fog takes while the player is in the zone, `fog_mul` and `mist_mul` scale the fog and the
## valley mist. Sides: `near` "road" (BED below the road) or
## an absolute height; `ledge` flat width beyond the wall; `reach` the blend to natural ground;
## `wall` height above the road the ground climbs to, fading back over `fade`.
const KINDS := {
	"city": {"mat": Color(0.0, 0.2, 0.85, 0.0), "trees": 0.06, "fog": Color(0.82, 0.8, 0.78), "fog_mul": 1.0, "mist_mul": 0.8,
		"left": {"ledge": 30.0, "reach": 60.0}, "right": {"ledge": 30.0, "reach": 60.0}},
	"mountain": {"mat": Color(0.45, 0.55, 0.0, 0.0), "trees": 0.3, "fog": Color(0.78, 0.8, 0.84), "fog_mul": 0.9, "mist_mul": 0.8,
		"left": {"ledge": 6.0, "reach": 40.0}, "right": {"ledge": 6.0, "reach": 40.0}},
	"cliff": {"mat": Color(0.9, 0.1, 0.0, 0.0), "trees": 0.08, "fog": Color(0.86, 0.82, 0.76), "fog_mul": 0.7, "mist_mul": 0.6,
		"left": {"ledge": 4.0, "reach": 40.0, "wall": 55.0, "fade": 160.0}, "right": {"ledge": 0.0, "reach": 22.0}},
	"forest": {"mat": Color(0.05, 1.0, 0.0, 0.0), "trees": 1.0, "fog": Color(0.72, 0.8, 0.82), "fog_mul": 1.5, "mist_mul": 1.3,
		"left": {"ledge": 8.0, "reach": 230.0}, "right": {"ledge": 8.0, "reach": 160.0}},
	"docks": {"mat": Color(0.0, 0.05, 0.95, 0.0), "trees": 0.0, "fog": Color(0.8, 0.76, 0.72), "fog_mul": 1.3, "mist_mul": 1.5,
		"left": {"near": -21.0, "ledge": 30.0, "reach": 10.0}, "right": {"near": -21.0, "ledge": 260.0, "reach": 120.0}},
	"causeway": {"mat": Color(0.2, 0.5, 0.0, 0.0), "trees": 0.08, "fog": Color(0.8, 0.84, 0.9), "fog_mul": 0.8, "mist_mul": 1.3,
		"left": {"near": -46.0, "ledge": 0.0, "reach": 30.0}, "right": {"near": -46.0, "ledge": 0.0, "reach": 30.0}},
}
const SIDE_DEFAULTS := {"near": "road", "ledge": 20.0, "reach": 60.0, "wall": 0.0, "fade": 180.0}

var track: TrackBuilder
var def := {}
var water_level := -26.0
var lake_bottom := -46.0
var snow_line := 200.0
var zones: Array = []            ## [[start fraction, kind, overrides], ...] from the definition
var zone_of := PackedInt32Array()  ## dominant zone per frame (index into `zones`)

# Grid
var origin := Vector2.ZERO       ## world xz of vertex (0, 0)
var W := 0
var H := 0
var heights := PackedFloat32Array()
var labels := PackedInt32Array()   ## nearest frame per vertex
var dists := PackedFloat32Array()  ## distance to that frame's centre point
var mats := PackedColorArray()     ## material weights per vertex
var tree_density := PackedFloat32Array()

# Per frame, blended between zones: index 0 = left side, 1 = right side
var _near := [PackedFloat32Array(), PackedFloat32Array()]
var _ledge := [PackedFloat32Array(), PackedFloat32Array()]
var _reach := [PackedFloat32Array(), PackedFloat32Array()]
var _wall := [PackedFloat32Array(), PackedFloat32Array()]
var _fade := [PackedFloat32Array(), PackedFloat32Array()]
var _mat := PackedColorArray()
var _trees := PackedFloat32Array()
var _fog := PackedColorArray()
var _fog_mul := PackedFloat32Array()
var _mist_mul := PackedFloat32Array()

var _inside_sign := -1.0         ## lateral sign of the lap's interior: -1 left, +1 right
var _hills := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _carves: Array = []          ## [centre (Vector2), along (Vector2), floor at centre, ...]
var _outside_level := 6.0
var _hills_amp := 22.0
var _mountains_from := 430.0
var _mountain_height := 330.0
var _peaks: Array = []
var _basins: Array = []
var _build_ms := {}


func build(p_track: TrackBuilder, p_def: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	track = p_track
	def = p_def.get("landscape", {})
	water_level = def.get("water_level", -26.0)
	lake_bottom = def.get("lake_bottom", -46.0)
	snow_line = def.get("snow_line", 200.0)
	zones = def.get("zones", [])
	_outside_level = def.get("outside_level", 6.0)
	_hills_amp = def.get("hills", 22.0)
	_mountains_from = def.get("mountains_from", 430.0)
	_mountain_height = def.get("mountain_height", 330.0)
	_peaks = def.get("peaks", [])
	_basins = def.get("basins", [])
	_setup_noise()
	var t := Time.get_ticks_msec()
	_plan_zones()
	_plan_carves()
	_build_ms["zones"] = Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	_distance_field()
	_build_ms["distance"] = Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	_compute_heights()
	_build_ms["heights"] = Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	_add_terrain()
	_add_water()
	_add_streams()
	_add_supports()
	_add_tunnel_mountains()
	_build_ms["meshes"] = Time.get_ticks_msec() - t
	if OS.has_environment("AG_LANDSCAPE_LOG"):
		print("Landscape: grid %dx%d (%d vertices), build ms %s" % [W, H, W * H, _build_ms])


# --- Queries --------------------------------------------------------------------------

## Terrain height at a world position (bilinear).
func height_at(x: float, z: float) -> float:
	var gx := clampf((x - origin.x) / G, 0.0, W - 1.001)
	var gz := clampf((z - origin.y) / G, 0.0, H - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var k := iz * W + ix
	var a := lerpf(heights[k], heights[k + 1], fx)
	var b := lerpf(heights[k + W], heights[k + W + 1], fx)
	return lerpf(a, b, fz)


## Surface normal at a world position.
func normal_at(x: float, z: float) -> Vector3:
	var dx := height_at(x + G, z) - height_at(x - G, z)
	var dz := height_at(x, z + G) - height_at(x, z - G)
	return Vector3(-dx, 2.0 * G, -dz).normalized()


## Nearest track frame to a world position (from the distance transform).
func frame_at(x: float, z: float) -> int:
	var ix := clampi(roundi((x - origin.x) / G), 0, W - 1)
	var iz := clampi(roundi((z - origin.y) / G), 0, H - 1)
	return labels[iz * W + ix]


func distance_at(x: float, z: float) -> float:
	var ix := clampi(roundi((x - origin.x) / G), 0, W - 1)
	var iz := clampi(roundi((z - origin.y) / G), 0, H - 1)
	return dists[iz * W + ix]


func zone_kind(frame: int) -> String:
	if zone_of.is_empty():
		return ""
	return zones[zone_of[posmod(frame, zone_of.size())]][1]


func tree_density_at(x: float, z: float) -> float:
	var ix := clampi(roundi((x - origin.x) / G), 0, W - 1)
	var iz := clampi(roundi((z - origin.y) / G), 0, H - 1)
	return tree_density[iz * W + ix]


## Fog tint, fog density multiplier and valley-mist multiplier at a frame, for Race to apply.
func atmosphere(frame: int) -> Array:
	var i := posmod(frame, _fog.size())
	return [_fog[i], _fog_mul[i], _mist_mul[i]]


## Weight 0..1 of a zone kind around a frame (for ambience beds).
func zone_weight(frame: int, kind: String) -> float:
	var n := zone_of.size()
	var hits := 0
	for k in range(-BLEND_FRAMES, BLEND_FRAMES + 1, 8):
		if zones[zone_of[posmod(frame + k, n)]][1] == kind:
			hits += 1
	return hits / float(BLEND_FRAMES * 2 / 8 + 1)


func is_inside(x: float, z: float) -> bool:
	var i := frame_at(x, z)
	var f := track.frames[i]
	var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
	return signf((Vector3(x, 0.0, z) - Vector3(f.origin.x, 0.0, f.origin.z)).dot(right)) == _inside_sign


# --- Zones -----------------------------------------------------------------------------

func _setup_noise() -> void:
	var seed_base: int = def.get("seed", 11)
	_hills.seed = seed_base
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.004
	_hills.fractal_octaves = 4
	_ridge.seed = seed_base + 1
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.0028
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 5
	_detail.seed = seed_base + 2
	_detail.frequency = 0.035
	_detail.fractal_octaves = 3


func _resolved(zone_index: int) -> Dictionary:
	var entry: Array = zones[zone_index]
	var kind: String = entry[1]
	var base: Dictionary = KINDS.get(kind, KINDS["city"])
	var over: Dictionary = entry[2] if entry.size() > 2 else {}
	var out := base.duplicate(true)
	for key in over:
		if key in ["left", "right"]:
			continue
		out[key] = over[key]
	for side in ["left", "right"]:
		var s: Dictionary = SIDE_DEFAULTS.duplicate()
		s.merge(base.get(side, {}), true)
		s.merge(over.get(side, {}), true)
		out[side] = s
	return out


## Per-frame zone parameters, box-filtered along the lap so zones blend over BLEND_FRAMES.
func _plan_zones() -> void:
	var frames := track.frames
	var n := frames.size()
	zone_of.resize(n)
	var resolved: Array = []
	for z in zones.size():
		resolved.append(_resolved(z))
	for i in n:
		var fraction := float(i) / n
		var zi := 0
		for z in zones.size():
			if fraction >= float(zones[z][0]):
				zi = z
		zone_of[i] = zi

	var raw := {}
	for key in ["near0", "near1", "ledge0", "ledge1", "reach0", "reach1", "wall0", "wall1", "fade0", "fade1", "trees", "fog_mul", "mist_mul",
			"m0", "m1", "m2", "m3", "f0", "f1", "f2"]:
		var a := []   # a plain Array is shared by reference, so raw[key][i] = v writes through
		a.resize(n)
		raw[key] = a
	for i in n:
		var r: Dictionary = resolved[zone_of[i]]
		var ry := frames[i].origin.y
		for side in 2:
			var s: Dictionary = r["left" if side == 0 else "right"]
			var near = s["near"]
			raw["near%d" % side][i] = (ry - BED) if near is String else float(near)
			raw["ledge%d" % side][i] = s["ledge"]
			raw["reach%d" % side][i] = s["reach"]
			raw["wall%d" % side][i] = s["wall"]
			raw["fade%d" % side][i] = s["fade"]
		raw["trees"][i] = r["trees"]
		raw["fog_mul"][i] = r["fog_mul"]
		raw["mist_mul"][i] = r["mist_mul"]
		var m: Color = r["mat"]
		raw["m0"][i] = m.r
		raw["m1"][i] = m.g
		raw["m2"][i] = m.b
		raw["m3"][i] = m.a
		var fog: Color = r["fog"]
		raw["f0"][i] = fog.r
		raw["f1"][i] = fog.g
		raw["f2"][i] = fog.b
	for key in raw:
		raw[key] = _smooth(PackedFloat32Array(raw[key]), BLEND_FRAMES)

	for side in 2:
		_near[side] = raw["near%d" % side]
		_ledge[side] = raw["ledge%d" % side]
		_reach[side] = raw["reach%d" % side]
		_wall[side] = raw["wall%d" % side]
		_fade[side] = raw["fade%d" % side]
	_trees = raw["trees"]
	_fog_mul = raw["fog_mul"]
	_mist_mul = raw["mist_mul"]
	_mat.resize(n)
	_fog.resize(n)
	for i in n:
		_mat[i] = Color(raw["m0"][i], raw["m1"][i], raw["m2"][i], raw["m3"][i])
		_fog[i] = Color(raw["f0"][i], raw["f1"][i], raw["f2"][i])

	# Which side of the road is the inside of the lap: the side the lap turns towards overall.
	var turning := 0.0
	for i in n:
		var a := -frames[i].basis.z
		var b := -frames[(i + 1) % n].basis.z
		turning += a.cross(b).y
	_inside_sign = -1.0 if turning > 0.0 else 1.0


## Circular moving average of width `span` (a box filter, via prefix sums).
static func _smooth(values: PackedFloat32Array, span: int) -> PackedFloat32Array:
	var n := values.size()
	var half := span / 2
	var prefix := PackedFloat64Array()
	prefix.resize(n * 3 + 1)
	prefix[0] = 0.0
	for k in n * 3:
		prefix[k + 1] = prefix[k] + values[k % n]
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a := n + i - half
		var b := n + i + half + 1
		out[i] = (prefix[b] - prefix[a]) / float(b - a)
	return out


## A ravine under every gap, running across the road: deep in the middle of the gap, falling
## towards the inside of the lap (to the water) and rising gently to the outside.
func _plan_carves() -> void:
	_carves.clear()
	for g in track.gaps:
		var c: int = (int(g[0]) + int(g[1])) / 2
		var f := track.frames[c]
		var fwd := Vector2(-f.basis.z.x, -f.basis.z.z).normalized()
		var right := Vector2(fwd.y, -fwd.x)
		_carves.append({"centre": Vector2(f.origin.x, f.origin.z), "along": right, "across": fwd, "floor": f.origin.y - 50.0,
			"width": 14.0, "side": 1.6, "length": 520.0})


# --- Distance transform ---------------------------------------------------------------

func _distance_field() -> void:
	var frames := track.frames
	var n := frames.size()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var fx := PackedFloat32Array()
	var fz := PackedFloat32Array()
	fx.resize(n)
	fz.resize(n)
	for i in n:
		var p := frames[i].origin
		fx[i] = p.x
		fz[i] = p.z
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	origin = (lo - Vector2(MARGIN, MARGIN)).snapped(Vector2(G, G))
	W = int(ceil((hi.x - origin.x + MARGIN) / G)) + 1
	H = int(ceil((hi.y - origin.y + MARGIN) / G)) + 1
	var count := W * H
	dists.resize(count)
	dists.fill(1e9)
	labels.resize(count)
	labels.fill(-1)

	# Seed the cells around every frame with exact distances.
	for i in n:
		var cx := roundi((fx[i] - origin.x) / G)
		var cz := roundi((fz[i] - origin.y) / G)
		for dz in range(-2, 3):
			var z := cz + dz
			if z < 0 or z >= H:
				continue
			for dx in range(-2, 3):
				var x := cx + dx
				if x < 0 or x >= W:
					continue
				var k := z * W + x
				var vx := origin.x + x * G - fx[i]
				var vz := origin.y + z * G - fz[i]
				var d := sqrt(vx * vx + vz * vz)
				if d < dists[k]:
					dists[k] = d
					labels[k] = i

	# Two sweeps propagating the nearest frame (and its exact distance) to every cell.
	var forward := [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var backward := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
	for pass_index in 2:
		var offsets: Array = forward if pass_index == 0 else backward
		var z_range := range(H) if pass_index == 0 else range(H - 1, -1, -1)
		for z: int in z_range:
			var vz: float = origin.y + z * G
			var x_range := range(W) if pass_index == 0 else range(W - 1, -1, -1)
			for x: int in x_range:
				var k: int = z * W + x
				var best: float = dists[k]
				var lab: int = labels[k]
				var vx: float = origin.x + x * G
				for o: Vector2i in offsets:
					var nx: int = x + o.x
					var nz: int = z + o.y
					if nx < 0 or nx >= W or nz < 0 or nz >= H:
						continue
					var li: int = labels[nz * W + nx]
					if li < 0 or li == lab:
						continue
					var ddx := vx - fx[li]
					var ddz := vz - fz[li]
					var d := sqrt(ddx * ddx + ddz * ddz)
					if d < best:
						best = d
						lab = li
				dists[k] = best
				labels[k] = lab


# --- Heights --------------------------------------------------------------------------

## Natural ground at (x, z): what the land would be without the road.
func _natural(x: float, z: float, d: float, inside: bool) -> float:
	var h: float
	if inside:
		h = lake_bottom + _detail.get_noise_2d(x, z) * 3.0
	else:
		h = _outside_level + _hills.get_noise_2d(x, z) * _hills_amp
		var ring := smoothstep(_mountains_from, _mountains_from + 420.0, d)
		if ring > 0.0:
			var r := 0.5 + 0.5 * _ridge.get_noise_2d(x, z)
			h += ring * _mountain_height * (0.45 + 0.75 * r)
	# Authored masses: [x, z, radius, height]. An irregular radius keeps outlines natural.
	if not _peaks.is_empty() or not _basins.is_empty():
		var wobble := 1.0 + 0.35 * _hills.get_noise_2d(x * 3.0 + 400.0, z * 3.0)
		for p in _peaks:
			var dist := Vector2(x - p[0], z - p[1]).length() * wobble
			if dist < p[2]:
				var k := 1.0 - smoothstep(0.0, p[2], dist)
				var land := lerpf(h, maxf(h, _outside_level), smoothstep(0.0, 0.3, k))
				var r := 0.5 + 0.5 * _ridge.get_noise_2d(x * 1.4, z * 1.4)
				h = maxf(h, land + p[3] * pow(k, 1.15) * (0.45 + 1.1 * r))
		# Basins sit at full depth over the inner half of their radius, then shelve up.
		for b in _basins:
			var dist := Vector2(x - b[0], z - b[1]).length() * wobble
			if dist < b[2]:
				h = lerpf(h, b[3], 1.0 - smoothstep(b[2] * 0.5, b[2], dist))
	return h


func _carve(x: float, z: float, h: float) -> float:
	for c in _carves:
		var centre: Vector2 = c["centre"]
		var q := Vector2(x, z) - centre
		var along: float = q.dot(c["along"])
		if absf(along) > c["length"]:
			continue
		var across: float = absf(q.dot(c["across"]))
		# The floor drops towards the lap's inside (the water) and rises gently outward.
		var to_inside: float = along * -_inside_sign
		var floor_h: float = c["floor"] - maxf(0.0, to_inside) * 0.14 + maxf(0.0, -to_inside) * 0.12
		floor_h = maxf(floor_h, lake_bottom)
		var walls: float = floor_h + maxf(0.0, across - c["width"] * 0.5) * c["side"]
		# Fade out at the ends so the ravine doesn't stop at a wall.
		var end_fade := smoothstep(c["length"] * 0.8, c["length"], absf(along))
		h = minf(h, lerpf(walls, h, end_fade))
	return h


func _compute_heights() -> void:
	var frames := track.frames
	var n := frames.size()
	var count := W * H
	heights.resize(count)
	mats.resize(count)
	tree_density.resize(count)
	var edge := track.track_width * 0.5 + 2.0
	var bound_from := edge + 1.5 * G
	var natural_mat := Color(0.2, 0.8, 0.0, 0.0)
	for z in H:
		var wz := origin.y + z * G
		for x in W:
			var k := z * W + x
			var wx := origin.x + x * G
			var i: int = labels[k]
			var d: float = dists[k]
			var f := frames[i]
			var ry := f.origin.y
			var right := Vector2(f.basis.x.x, f.basis.x.z).normalized()
			var lateral := Vector2(wx - f.origin.x, wz - f.origin.z).dot(right)
			var side := 0 if lateral < 0.0 else 1
			var inside := signf(lateral) == _inside_sign
			var nat := _natural(wx, wz, d, inside)

			var near: float = _near[side][i]
			var ledge_end: float = edge + _ledge[side][i]
			var reach: float = maxf(_reach[side][i], 1.0)
			var h: float
			if d <= ledge_end:
				h = near
			else:
				var t := smoothstep(ledge_end, ledge_end + reach, d)
				var target := nat
				var wall: float = _wall[side][i]
				if wall > 0.0:
					var hold := ledge_end + reach + 20.0
					var wt := 1.0 - smoothstep(hold, hold + _fade[side][i], d)
					var crest := ry + wall * (0.8 + 0.4 * (0.5 + 0.5 * _ridge.get_noise_2d(wx * 2.0, wz * 2.0)))
					target = maxf(nat, lerpf(nat, crest, wt))
				h = lerpf(near, target, t)
				# Hills and rock detail grow with distance from the road.
				h += _detail.get_noise_2d(wx, wz) * 4.0 * t
			# The road is banked: its low edge can sit metres below the centre, so measure the
			# bed from the road surface at this lateral position (clamped to the road's edges).
			var road_h := ry + clampf(lateral, -edge, edge) * f.basis.x.y
			h = minf(h, minf(road_h, ry) - BED + maxf(0.0, d - bound_from) * CLIFF_SLOPE)
			h = _carve(wx, wz, h)
			heights[k] = h

			# Materials: the zone's near the road, fading to natural ground beyond its reach.
			var zone_k := 1.0 - smoothstep(ledge_end + reach, ledge_end + reach + 160.0, d)
			mats[k] = natural_mat.lerp(_mat[i], zone_k)
			tree_density[k] = lerpf(0.35 if not inside else 0.2, _trees[i], zone_k)


# --- Meshes ---------------------------------------------------------------------------

func _add_terrain() -> void:
	var count := W * H
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	for z in H:
		for x in W:
			var k := z * W + x
			verts[k] = Vector3(origin.x + x * G, heights[k], origin.y + z * G)
			var hl := heights[k - 1] if x > 0 else heights[k]
			var hr := heights[k + 1] if x < W - 1 else heights[k]
			var hu := heights[k - W] if z > 0 else heights[k]
			var hd := heights[k + W] if z < H - 1 else heights[k]
			normals[k] = Vector3(hl - hr, 2.0 * G, hu - hd).normalized()
			colors[k] = mats[k]
	var indices := PackedInt32Array()
	indices.resize((W - 1) * (H - 1) * 6)
	var j := 0
	for z in H - 1:
		for x in W - 1:
			var a := z * W + x
			var b := a + 1
			var c := a + W
			var d := c + 1
			# Clockwise from above is front-facing in Godot.
			indices[j] = a
			indices[j + 1] = b
			indices[j + 2] = d
			indices[j + 3] = a
			indices[j + 4] = d
			indices[j + 5] = c
			j += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = terrain_material()
	add_child(mi)

	# Collision on its own layer: a ship that leaves the road hits rock, but its ground ray
	# (layer 1) never mistakes the hillside for track.
	var map := PackedFloat32Array()
	map.resize(count)
	for k in count:
		map[k] = heights[k] / G
	var shape := HeightMapShape3D.new()
	shape.map_width = W
	shape.map_depth = H
	shape.map_data = map
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (TERRAIN_LAYER - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(G, G, G)
	cs.position = Vector3(origin.x + (W - 1) * G * 0.5, 0.0, origin.y + (H - 1) * G * 0.5)
	body.add_child(cs)
	add_child(body)


var _terrain_mat: ShaderMaterial


func terrain_material() -> ShaderMaterial:
	if _terrain_mat:
		return _terrain_mat
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	tex.generate_mipmaps = true
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = load("res://shaders/terrain.gdshader")
	_terrain_mat.set_shader_parameter("detail", tex)
	_terrain_mat.set_shader_parameter("water_level", water_level)
	_terrain_mat.set_shader_parameter("snow_line", snow_line)
	return _terrain_mat


var _water_mat: ShaderMaterial


func water_material() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	for key in ["wave_a", "wave_b"]:
		var noise := FastNoiseLite.new()
		noise.seed = 21 if key == "wave_a" else 37
		noise.frequency = 0.03 if key == "wave_a" else 0.06
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.noise = noise
		tex.seamless = true
		tex.as_normal_map = true
		tex.bump_strength = 6.0
		tex.width = 256
		tex.height = 256
		tex.generate_mipmaps = true
		_water_mat.set_shader_parameter(key, tex)
	return _water_mat


func _add_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2((W - 1) * G, (H - 1) * G)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = water_material()
	mi.position = Vector3(origin.x + (W - 1) * G * 0.5, water_level, origin.y + (H - 1) * G * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A stream along the bottom of each ravine, where it's above the lake.
func _add_streams() -> void:
	for c in _carves:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along: Vector2 = c["along"]
		var across: Vector2 = c["across"]
		var centre: Vector2 = c["centre"]
		var half := 3.5
		var added := 0
		var step := 8.0
		var s := -float(c["length"]) * 0.8
		while s < float(c["length"]) * 0.8:
			var p0 := centre + along * s
			var p1 := centre + along * (s + step)
			var h0 := height_at(p0.x, p0.y) + 0.35
			var h1 := height_at(p1.x, p1.y) + 0.35
			if h0 > water_level + 0.5 and h1 > water_level + 0.5:
				var a := Vector3(p0.x - across.x * half, h0, p0.y - across.y * half)
				var b := Vector3(p0.x + across.x * half, h0, p0.y + across.y * half)
				var cc := Vector3(p1.x + across.x * half, h1, p1.y + across.y * half)
				var d := Vector3(p1.x - across.x * half, h1, p1.y - across.y * half)
				for v in [a, cc, b, a, d, cc]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
				added += 1
			s += step
		if added == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = water_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Piers under the road wherever the ground falls well away, and a deck edge (fascia) so the
## road reads as a bridge from the side.
func _add_supports() -> void:
	var frames := track.frames
	var n := frames.size()
	var half := track.track_width * 0.5
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.6, 0.58)
	concrete.roughness = 0.85
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	var columns: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	var fascia := SurfaceTool.new()
	fascia.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deep := PackedByteArray()
	deep.resize(n)
	for i in n:
		var p := frames[i].origin
		deep[i] = 1 if (p.y - height_at(p.x, p.z) > 4.0 and not track.in_gap(i) and not track.in_tunnel(i)) else 0
	for i in n:
		if deep[i] == 0 or deep[(i + 1) % n] == 0:
			continue
		var f0 := frames[i]
		var f1 := frames[(i + 1) % n]
		for s in [-1.0, 1.0]:
			var a0: Vector3 = f0.origin + f0.basis.x * s * (half + 0.3)
			var a1: Vector3 = f1.origin + f1.basis.x * s * (half + 0.3)
			var b0: Vector3 = a0 - f0.basis.y * 1.8
			var b1: Vector3 = a1 - f1.basis.y * 1.8
			var nrm: Vector3 = f0.basis.x * s
			for v in ([a0, b1, b0, a0, a1, b1] if s > 0.0 else [a0, b0, b1, a0, b1, a1]):
				fascia.set_normal(nrm)
				fascia.add_vertex(v)
		# Underside, so the deck isn't a paper strip from below.
		var l0: Vector3 = f0.origin - f0.basis.x * (half + 0.3) - f0.basis.y * 1.8
		var r0: Vector3 = f0.origin + f0.basis.x * (half + 0.3) - f0.basis.y * 1.8
		var l1: Vector3 = f1.origin - f1.basis.x * (half + 0.3) - f1.basis.y * 1.8
		var r1: Vector3 = f1.origin + f1.basis.x * (half + 0.3) - f1.basis.y * 1.8
		for v in [l0, l1, r1, l0, r1, r0]:
			fascia.set_normal(-f0.basis.y)
			fascia.add_vertex(v)
		if i % 18 == 0:
			var f := frames[i]
			var up := Vector3.UP
			var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
			var fwd := right.cross(up)
			for s in [-1.0, 1.0]:
				var foot: Vector3 = f.origin + right * s * half * 0.55
				var ground := height_at(foot.x, foot.z) - 2.0
				var top: float = foot.y - 2.2
				if top - ground < 1.0:
					continue
				var mid := Vector3(foot.x, (top + ground) * 0.5, foot.z)
				columns.append(Transform3D(Basis(right * 3.2, up * (top - ground), right.cross(up) * 3.2), mid))
			beams.append(Transform3D(Basis(right * (track.track_width + 2.0), up * 1.6, right.cross(up) * 3.6), f.origin - f.basis.y * 2.2 - up * 0.2))
	var deck := MeshInstance3D.new()
	deck.name = "BridgeDeck"
	deck.mesh = fascia.commit()
	deck.material_override = concrete
	add_child(deck)
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.42
	column_mesh.bottom_radius = 0.5
	column_mesh.height = 1.0
	column_mesh.radial_segments = 12
	_add_multimesh("Piers", column_mesh, columns, concrete)
	_add_multimesh("PierBeams", BoxMesh.new(), beams, concrete)


func _add_multimesh(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Where a tunnel runs under high ground, close the mountain over it: a rock cap over the
## carved corridor and a portal face at each end, so it reads as bored through the hill.
func _add_tunnel_mountains() -> void:
	var frames := track.frames
	var n := frames.size()
	var half := track.track_width * 0.5
	var roof := 7.0
	for range_ in track.tunnel_ranges:
		var first: int = range_[0]
		var last: int = range_[1]
		var mid := frames[(first + last) / 2]
		var r := Vector3(mid.basis.x.x, 0.0, mid.basis.x.z).normalized()
		var lp: Vector3 = mid.origin - r * 70.0
		var rp: Vector3 = mid.origin + r * 70.0
		if minf(height_at(lp.x, lp.z), height_at(rp.x, rp.z)) < mid.origin.y + roof + 8.0:
			continue   # not under a mountain: leave the plain tunnel shell
		var cap_h := PackedFloat32Array()
		var span_l := PackedFloat32Array()
		var span_r := PackedFloat32Array()
		for i in range(first, last + 1):
			var f := frames[i % n]
			var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
			var ry := f.origin.y
			# Low enough to meet the cutting's walls a few metres out; the mountain rises behind.
			var h := ry + roof + 9.0
			cap_h.append(h)
			span_l.append(_reach_height(f.origin, -right, h))
			span_r.append(_reach_height(f.origin, right, h))
		cap_h = _smooth_open(cap_h, 12)
		span_l = _smooth_open(span_l, 8)
		span_r = _smooth_open(span_r, 8)

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var across := 10
		var rows: Array = []
		for k in cap_h.size():
			var f := frames[(first + k) % n]
			var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
			var row := PackedVector3Array()
			for c in across + 1:
				var u := float(c) / across
				var lat := lerpf(-span_l[k], span_r[k], u)
				var p := f.origin + right * lat
				var edge_k := minf(u, 1.0 - u) * 2.0   # 0 at the edges, 1 in the middle
				var h: float = cap_h[k] + _detail.get_noise_2d(p.x * 2.0, p.z * 2.0) * 5.0 * edge_k
				if absf(lat) < half + 6.0:
					h = maxf(h, f.origin.y + roof + 3.0)
				var ground := height_at(p.x, p.z)
				h = lerpf(maxf(ground, h - 1.0), h, smoothstep(0.0, 0.25, edge_k))
				row.append(Vector3(p.x, h, p.z))
			rows.append(row)
		for k in rows.size() - 1:
			var r0: PackedVector3Array = rows[k]
			var r1: PackedVector3Array = rows[k + 1]
			for c in across:
				var a := r0[c]
				var b := r0[c + 1]
				var c1 := r1[c + 1]
				var d := r1[c]
				var nrm := (b - a).cross(d - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				st.set_color(Color(0.7, 0.3, 0.0, 0.0))
				for v in [a, c1, b, a, d, c1]:
					st.set_normal(nrm)
					st.add_vertex(v)
		# Portal faces: the cap's cross-section down to the ground, with the tunnel cut out.
		for end in [0, cap_h.size() - 1]:
			var f := frames[(first + end) % n]
			var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
			var fwd := -Vector3(f.basis.z.x, 0.0, f.basis.z.z).normalized()
			var face_n := -fwd if end == 0 else fwd
			var o := f.origin
			var ry := o.y
			var top: float = cap_h[end]
			var profile := [Vector2(-1.0, 0.0), Vector2(-1.0, 4.2), Vector2(-0.62, roof), Vector2(0.62, roof), Vector2(1.0, 4.2), Vector2(1.0, 0.0)]
			st.set_color(Color(0.55, 0.25, 0.2, 0.0))
			for p_i in profile.size() - 1:
				var p0: Vector2 = profile[p_i]
				var p1: Vector2 = profile[p_i + 1]
				var a := o + right * p0.x * (half + 0.3) + Vector3.UP * p0.y
				var b := o + right * p1.x * (half + 0.3) + Vector3.UP * p1.y
				var at := Vector3(a.x, top, a.z)
				var bt := Vector3(b.x, top, b.z)
				_face(st, a, b, bt, at, face_n)
			for s in [-1.0, 1.0]:
				var inner: Vector3 = o + right * s * (half + 0.3)
				var outer: Vector3 = o + right * s * (span_l[end] if s < 0.0 else span_r[end])
				var lo := ry - 30.0
				_face(st, Vector3(inner.x, lo, inner.z), Vector3(outer.x, lo, outer.z), Vector3(outer.x, top, outer.z), Vector3(inner.x, top, inner.z), face_n)
		var mi := MeshInstance3D.new()
		mi.name = "TunnelMountain"
		mi.mesh = st.commit()
		mi.material_override = terrain_material()
		add_child(mi)
		_add_portal_trim(first, last)


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	# Two-sided by material; wind so the face points along `normal`.
	var order := [a, b, c, a, c, d] if (b - a).cross(d - a).dot(normal) < 0.0 else [a, c, b, a, d, c]
	for v in order:
		st.set_normal(normal)
		st.add_vertex(v)


## Concrete lip and a neon line round each portal, so the mouth reads at speed.
func _add_portal_trim(first: int, last: int) -> void:
	var frames := track.frames
	var n := frames.size()
	var half := track.track_width * 0.5 + 0.3
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.7, 0.68, 0.66)
	concrete.roughness = 0.7
	var glow := StandardMaterial3D.new()
	glow.albedo_color = track.neon_color
	glow.emission_enabled = true
	glow.emission = track.neon_color
	glow.emission_energy_multiplier = 3.0
	for end in [first, last]:
		var f := frames[end % n]
		var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
		var fwd := -Vector3(f.basis.z.x, 0.0, f.basis.z.z).normalized()
		var out := -fwd if end == first else fwd
		var profile := [Vector2(-1.0, 0.0), Vector2(-1.0, 4.2), Vector2(-0.62, 7.0), Vector2(0.62, 7.0), Vector2(1.0, 4.2), Vector2(1.0, 0.0)]
		for p_i in profile.size() - 1:
			var p0: Vector2 = profile[p_i]
			var p1: Vector2 = profile[p_i + 1]
			var a := f.origin + right * p0.x * half + Vector3.UP * p0.y + out * 0.8
			var b := f.origin + right * p1.x * half + Vector3.UP * p1.y + out * 0.8
			var seg := b - a
			var seg_len := seg.length()
			if seg_len < 0.1:
				continue
			var dir := seg / seg_len
			var mid := (a + b) * 0.5
			# Outward from the opening, and a right-handed basis (a mirrored one turns boxes inside out).
			var normal := out.cross(dir).normalized()
			if normal.dot(mid - (f.origin + Vector3.UP * 3.5)) < 0.0:
				normal = -normal
			var zaxis := dir.cross(normal)
			var slab := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(seg_len + 1.6, 1.6, 2.4)
			slab.mesh = box
			slab.material_override = concrete
			slab.transform = Transform3D(Basis(dir, normal, zaxis), mid + normal * 0.8)
			add_child(slab)
			var line := MeshInstance3D.new()
			var strip := BoxMesh.new()
			strip.size = Vector3(seg_len, 0.25, 0.25)
			line.mesh = strip
			line.material_override = glow
			line.transform = Transform3D(Basis(dir, normal, zaxis), mid - normal * 0.1 + out * 1.25)
			add_child(line)


func _natural_at(p: Vector3) -> float:
	var d := distance_at(p.x, p.z)
	return _natural(p.x, p.z, d, is_inside(p.x, p.z))


## Distance out along `dir` at which the terrain reaches height `h` (capped).
func _reach_height(from: Vector3, dir: Vector3, h: float) -> float:
	var s := track.track_width * 0.5 + 4.0
	while s < 56.0:
		var p := from + dir * s
		if height_at(p.x, p.z) >= h - 1.0:
			return s + 6.0
		s += 4.0
	return 56.0


static func _smooth_open(values: PackedFloat32Array, span: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for i in values.size():
		var total := 0.0
		var count := 0
		for k in range(maxi(0, i - span / 2), mini(values.size(), i + span / 2 + 1)):
			total += values[k]
			count += 1
		out[i] = total / count
	return out
