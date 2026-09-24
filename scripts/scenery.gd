class_name Scenery
extends Node3D

## Trackside and landscape props for landscape circuits, placed zone by zone on the terrain:
## pine forest, rock outcrops and sea stacks, a rock arch over the cliff road, docks (container
## stacks, gantry cranes, tanks, chimneys with smoke, sheds), grandstands with a crowd at the
## start, sponsor boards, and boats, buoys and a lighthouse on the water.
## Everything numerous is a MultiMesh; nothing here collides (ships only ever touch the track
## and, off it, the terrain).

const TEAMS := ["HALCYON", "VOSS DYNAMICS", "KESTREL AERO", "MIRAGE", "SABLE-9", "TESSERA", "AG LEAGUE", "NEON VELOCITY"]
const TEAM_COLORS := [Color(1.0, 0.8, 0.1), Color(0.2, 0.9, 0.4), Color(1.0, 0.5, 0.1), Color(0.7, 0.3, 1.0), Color(0.2, 0.6, 1.0), Color(0.95, 0.95, 0.95), Color(1.0, 0.3, 0.7), Color(0.3, 0.95, 1.0)]
const CONTAINER_COLORS := [Color(0.62, 0.16, 0.1), Color(0.12, 0.28, 0.55), Color(0.1, 0.42, 0.22), Color(0.85, 0.45, 0.1), Color(0.55, 0.56, 0.58), Color(0.85, 0.85, 0.82), Color(0.6, 0.12, 0.35), Color(0.9, 0.72, 0.1)]

var track: TrackBuilder
var land: Landscape
var _rng := RandomNumberGenerator.new()
var _boats: Array[Node3D] = []
var _t := 0.0
var _counts := {}


func build(p_track: TrackBuilder, p_land: Landscape) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	track = p_track
	land = p_land
	_rng.seed = 424242
	_boats.clear()
	_add_forest()
	_add_rocks()
	_add_arch()
	_add_docks()
	_add_start()
	_add_boards()
	_add_water_life()
	if OS.has_environment("AG_LANDSCAPE_LOG"):
		print("Scenery: ", _counts)


func _process(delta: float) -> void:
	_t += delta
	for k in _boats.size():
		var b := _boats[k]
		var base: Vector3 = b.get_meta("base")
		b.position.y = base.y + sin(_t * 0.9 + k * 1.7) * 0.25
		b.rotation.z = sin(_t * 0.7 + k) * 0.05
		b.rotation.x = sin(_t * 0.55 + k * 2.3) * 0.03


# --- Helpers --------------------------------------------------------------------------

func _frames_of(kind: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in track.frames.size():
		if land.zone_kind(i) == kind:
			out.append(i)
	return out


## Flat right and forward vectors of a frame.
func _axes(i: int) -> Array:
	var f := track.frames[posmod(i, track.frames.size())]
	var right := Vector3(f.basis.x.x, 0.0, f.basis.x.z).normalized()
	var fwd := Vector3(-f.basis.z.x, 0.0, -f.basis.z.z).normalized()
	return [right, fwd]


func _ground(p: Vector3) -> float:
	return land.height_at(p.x, p.z)


## Clear of every part of the road by `margin` metres beyond its edge.
func _clear_of_road(p: Vector3, margin: float) -> bool:
	return land.distance_at(p.x, p.z) > track.track_width * 0.5 + margin


func _material(color: Color, roughness := 0.8, metallic := 0.0, cull := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if not cull:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := _material(color)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, xform: Transform3D, material: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.transform = xform
	parent.add_child(mi)
	return mi


func _cylinder(radius: float, height: float, xform: Transform3D, material: Material, parent: Node = self, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius if top < 0.0 else top
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 20
	mi.mesh = c
	mi.material_override = material
	mi.transform = xform
	parent.add_child(mi)
	return mi


## Adds a triangle that faces away from `inner` (Godot's front faces are clockwise), with a
## flat normal: the low-poly look.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inner: Vector3, color := Color.WHITE) -> void:
	var n := (b - a).cross(c - a)
	var out := (a + b + c) / 3.0 - inner
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var normal := (-n).normalized()
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)


func _multimesh(label: String, mesh: Mesh, xforms: Array[Transform3D], material: Material, colors: Array = [], shadows := true, range_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if not colors.is_empty():
			mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = 150.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	_counts[label] = _counts.get(label, 0) + xforms.size()
	return mmi


# --- Forest ---------------------------------------------------------------------------

func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var trunk := Color(0.32, 0.22, 0.15)
	# Trunk: a thin tapered prism.
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		_tri(st, p0 * 0.35, p1 * 0.35, p1 * 0.25 + Vector3.UP * 4.0, Vector3(0, 2, 0), trunk)
		_tri(st, p0 * 0.35, p1 * 0.25 + Vector3.UP * 4.0, p0 * 0.25 + Vector3.UP * 4.0, Vector3(0, 2, 0), trunk)
	# Three tiers of needles, darker at the bottom.
	var tiers := [[2.5, 3.4, 6.5], [6.0, 2.6, 5.5], [9.2, 1.7, 5.0]]
	for t in tiers.size():
		var y0: float = tiers[t][0]
		var r: float = tiers[t][1]
		var h: float = tiers[t][2]
		var col := Color(0.05, 0.13, 0.07).lerp(Color(0.1, 0.22, 0.09), t / 2.0)
		var apex := Vector3(0, y0 + h, 0)
		for k in sides:
			var a0 := TAU * (k + 0.5 * t) / sides
			var a1 := TAU * (k + 1 + 0.5 * t) / sides
			var b0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var b1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			_tri(st, b0, b1, apex, Vector3(0, y0 + h * 0.3, 0), col)
			_tri(st, b0, b1, Vector3(0, y0, 0), Vector3(0, y0 + 1.0, 0), col.darkened(0.3))
	return st.commit()


func _broadleaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.36, 0.26, 0.18)
	var sides := 6
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		_tri(st, p0 * 0.4, p1 * 0.4, p1 * 0.3 + Vector3.UP * 5.0, Vector3(0, 2, 0), trunk)
		_tri(st, p0 * 0.4, p1 * 0.3 + Vector3.UP * 5.0, p0 * 0.3 + Vector3.UP * 5.0, Vector3(0, 2, 0), trunk)
	# Canopy: a squashed, jittered icosahedron.
	var c := Vector3(0, 8.0, 0)
	var ico := _icosphere(1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 9
	var scaled := PackedVector3Array()
	for v in ico[0]:
		scaled.append(c + Vector3(v.x * 4.2, v.y * 3.4, v.z * 4.2) * jitter.randf_range(0.85, 1.15))
	var idx: PackedInt32Array = ico[1]
	for k in range(0, idx.size(), 3):
		var col := Color(0.1, 0.22, 0.06).lerp(Color(0.2, 0.32, 0.08), jitter.randf())
		_tri(st, scaled[idx[k]], scaled[idx[k + 1]], scaled[idx[k + 2]], c, col)
	return st.commit()


## Unit icosphere: [vertices, indices].
static func _icosphere(subdivisions: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for k in verts.size():
		verts[k] = verts[k].normalized()
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _s in subdivisions:
		var next := []
		var cache := {}
		for f in faces:
			var m := []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not cache.has(key):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			next.append([f[0], m[0], m[2]])
			next.append([f[1], m[1], m[0]])
			next.append([f[2], m[2], m[1]])
			next.append([m[0], m[1], m[2]])
		faces = next
	var out_v := PackedVector3Array(verts)
	var out_i := PackedInt32Array()
	for f in faces:
		out_i.append(f[0])
		out_i.append(f[1])
		out_i.append(f[2])
	return [out_v, out_i]


func _tree_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tree.gdshader")
	return m


## Trees wherever the zone and the ground allow: dense in the forest, in parks in the city,
## thinning out up the mountains. Chunked along the lap so the camera can cull most of them.
func _add_forest() -> void:
	var n := track.frames.size()
	var pine := _pine_mesh()
	var broad := _broadleaf_mesh()
	var mask := FastNoiseLite.new()
	mask.seed = 77
	mask.frequency = 0.006
	var chunks := {}   # chunk index -> [pine xforms, pine colors, broad xforms, broad colors]
	var attempts := 60000
	var placed := 0
	for _a in attempts:
		var i := _rng.randi_range(0, n - 1)
		var ax := _axes(i)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var dist := track.track_width * 0.5 + 7.0 + 420.0 * pow(_rng.randf(), 1.6)
		var p: Vector3 = track.frames[i].origin + ax[0] * side * dist + ax[1] * _rng.randf_range(-6.0, 6.0)
		var density := land.tree_density_at(p.x, p.z)
		# Clearings and groves.
		density *= smoothstep(-0.35, 0.25, mask.get_noise_2d(p.x, p.z))
		if _rng.randf() > density:
			continue
		if not _clear_of_road(p, 6.0):
			continue
		var h := _ground(p)
		if h < land.water_level + 1.2 or h > land.snow_line - 25.0:
			continue
		if land.normal_at(p.x, p.z).y < 0.8:
			continue
		var is_broad := _rng.randf() < (0.35 if h < land.water_level + 25.0 else 0.08)
		var s := _rng.randf_range(0.75, 1.45)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s))
		var xform := Transform3D(basis, Vector3(p.x, h - 0.3, p.z))
		var tint := Color(1, 1, 1).lerp(Color(_rng.randf_range(0.8, 1.1), _rng.randf_range(0.85, 1.15), _rng.randf_range(0.8, 1.0)), 0.8)
		var chunk := i / 120
		if not chunks.has(chunk):
			chunks[chunk] = [[], [], [], []]
		var slot: int = 2 if is_broad else 0
		chunks[chunk][slot].append(xform)
		chunks[chunk][slot + 1].append(tint)
		placed += 1
		if placed >= 7000:
			break
	var mat := _tree_material()
	for chunk in chunks:
		var c: Array = chunks[chunk]
		for slot in [0, 2]:
			if c[slot].is_empty():
				continue
			var typed: Array[Transform3D] = []
			typed.assign(c[slot])
			_multimesh("Pines" if slot == 0 else "Broadleaf", pine if slot == 0 else broad, typed, mat, c[slot + 1], true, 1600.0)


# --- Rock -----------------------------------------------------------------------------

func _rock_mesh(seed_value: int, stretch := Vector3.ONE) -> ArrayMesh:
	var ico := _icosphere(1)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9
	var verts: PackedVector3Array = ico[0]
	var shaped := PackedVector3Array()
	for v in verts:
		var k := 1.0 + 0.32 * noise.get_noise_3dv(v * 1.3)
		shaped.append(Vector3(v.x * stretch.x, v.y * stretch.y, v.z * stretch.z) * k)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = ico[1]
	for k in range(0, idx.size(), 3):
		# Vertex colour red = rock for the terrain shader.
		_tri(st, shaped[idx[k]], shaped[idx[k + 1]], shaped[idx[k + 2]], Vector3.ZERO, Color(1, 0, 0, 0))
	return st.commit()


## Outcrops along the rock zones' walls, boulders in the forest, and sea stacks out in the
## fjord below the cliff road.
func _add_rocks() -> void:
	var meshes := [_rock_mesh(1), _rock_mesh(2, Vector3(1.3, 0.8, 1.0)), _rock_mesh(3, Vector3(0.9, 1.2, 1.1))]
	var sets := [[], [], []]
	var add := func(p: Vector3, size: Vector3, sink: float) -> void:
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2)).scaled(size)
		sets[_rng.randi_range(0, 2)].append(Transform3D(basis, p - Vector3.UP * sink))
	var rocky := {"cliff": 1.0, "mountain": 0.6, "forest": 0.25, "causeway": 0.2}
	var n := track.frames.size()
	for i in range(0, n, 3):
		var kind := land.zone_kind(i)
		if not rocky.has(kind) or _rng.randf() > float(rocky[kind]):
			continue
		var ax := _axes(i)
		for _k in 2:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var dist := track.track_width * 0.5 + _rng.randf_range(9.0, 110.0)
			var p: Vector3 = track.frames[i].origin + ax[0] * side * dist + ax[1] * _rng.randf_range(-4.0, 4.0)
			if not _clear_of_road(p, 7.0):
				continue
			var h := _ground(p)
			var slope := 1.0 - land.normal_at(p.x, p.z).y
			if h < land.water_level - 2.0:
				# Sea stack: a tall pillar rising out of the water (cliff and causeway only).
				if kind in ["cliff", "causeway"] and _rng.randf() < 0.5:
					var w := _rng.randf_range(6.0, 14.0)
					var top := land.water_level + _rng.randf_range(12.0, 55.0)
					var tall := top - h
					add.call(Vector3(p.x, h + tall * 0.5, p.z), Vector3(w, tall * 0.55, w * _rng.randf_range(0.8, 1.2)), 0.0)
				continue
			var size := _rng.randf_range(2.0, 6.0) if kind == "forest" else _rng.randf_range(4.0, 16.0) * (1.0 + slope)
			add.call(Vector3(p.x, h, p.z), Vector3(size, size * _rng.randf_range(0.5, 1.1), size * _rng.randf_range(0.7, 1.3)), size * 0.3)
	for k in 3:
		if not sets[k].is_empty():
			var typed: Array[Transform3D] = []
			typed.assign(sets[k])
			_multimesh("Rocks", meshes[k], typed, land.terrain_material(), [], true, 2000.0)


## A natural rock arch over the road on the cliff zone, its feet on the wall and in the fjord.
func _add_arch() -> void:
	var cliff := _frames_of("cliff")
	if cliff.is_empty():
		return
	var i: int = cliff[mini(cliff.size() - 1, 60)]
	var f := track.frames[i]
	var ax := _axes(i)
	var right: Vector3 = ax[0]
	var fwd: Vector3 = ax[1]
	var half := track.track_width * 0.5
	var foot_l := f.origin - right * (half + 18.0)
	foot_l.y = _ground(foot_l) - 4.0
	var foot_r := f.origin + right * (half + 30.0)
	foot_r.y = _ground(foot_r) - 4.0
	var apex := f.origin + Vector3.UP * 34.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 28
	var ring := 9
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.15
	var rings: Array = []
	for s in segs + 1:
		var t := float(s) / segs
		# Quadratic Bezier through the apex (control point lifted so the curve reaches it).
		var ctrl := apex * 2.0 - (foot_l + foot_r) * 0.5
		var c := foot_l.lerp(ctrl, t).lerp(ctrl.lerp(foot_r, t), t)
		var tangent := (ctrl - foot_l).lerp(foot_r - ctrl, t).normalized()
		var side_a := fwd
		var side_b := tangent.cross(side_a).normalized()
		var radius := lerpf(11.0, 6.5, sin(t * PI))
		var pts := PackedVector3Array()
		for r in ring:
			var a := TAU * r / ring
			var offset := side_a * cos(a) * radius * 1.3 + side_b * sin(a) * radius
			var k := 1.0 + 0.3 * noise.get_noise_3dv(c + offset)
			pts.append(c + offset * k)
		rings.append([c, pts])
	for s in segs:
		var a_c: Vector3 = rings[s][0]
		var b_c: Vector3 = rings[s + 1][0]
		var a: PackedVector3Array = rings[s][1]
		var b: PackedVector3Array = rings[s + 1][1]
		for r in ring:
			var r1 := (r + 1) % ring
			_tri(st, a[r], a[r1], b[r1], (a_c + b_c) * 0.5, Color(1, 0, 0, 0))
			_tri(st, a[r], b[r1], b[r], (a_c + b_c) * 0.5, Color(1, 0, 0, 0))
	var mi := MeshInstance3D.new()
	mi.name = "RockArch"
	mi.mesh = st.commit()
	mi.material_override = land.terrain_material()
	add_child(mi)
	_counts["arch"] = 1


# --- Docks ----------------------------------------------------------------------------

## The yard side of the docks zone: container stacks in rows, sheds, a tank farm and two
## chimneys; the water side: gantry cranes along the quay with their booms over the lake.
func _add_docks() -> void:
	var docks := _frames_of("docks")
	if docks.is_empty():
		return
	var half := track.track_width * 0.5
	var yard_level: float = -21.0
	var container_xforms: Array[Transform3D] = []
	var container_colors: Array = []
	var yard_side := -_inside_side()
	var quay_side := _inside_side()
	# Container blocks.
	for k in range(0, docks.size(), 22):
		var i: int = docks[k]
		var ax := _axes(i)
		var right: Vector3 = ax[0]
		var fwd: Vector3 = ax[1]
		var o := track.frames[i].origin
		for block in 3:
			var lateral := half + 28.0 + block * 34.0 + _rng.randf_range(0.0, 10.0)
			var corner: Vector3 = o + right * yard_side * lateral
			for row in 4:
				for col in 3:
					var p: Vector3 = corner + fwd * (col * 13.0 - 13.0) + right * yard_side * row * 2.8
					var g := _ground(p)
					if absf(g - yard_level) > 2.0 or not _clear_of_road(p, 10.0):
						continue
					var stack := _rng.randi_range(0, 4)
					for level in stack:
						var pos := Vector3(p.x, g + 1.3 + level * 2.6, p.z)
						container_xforms.append(Transform3D(Basis(fwd * 12.2, Vector3.UP * 2.6, right * 2.45), pos))
						container_colors.append(CONTAINER_COLORS[_rng.randi_range(0, CONTAINER_COLORS.size() - 1)])
	if not container_xforms.is_empty():
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/container.gdshader")
		_multimesh("Containers", BoxMesh.new(), container_xforms, m, container_colors, true, 1800.0)

	# Gantry cranes on the quay, booms out over the water.
	var crane_paint := _material(Color(0.95, 0.62, 0.1), 0.6, 0.2)
	var steel := _material(Color(0.28, 0.3, 0.33), 0.5, 0.6)
	var warn := _glow(Color(1.0, 0.1, 0.05), 5.0)
	var cranes := 0
	for k in range(10, docks.size(), 55):
		var i: int = docks[k]
		var ax := _axes(i)
		var right: Vector3 = ax[0]
		var fwd: Vector3 = ax[1]
		var base: Vector3 = track.frames[i].origin + right * quay_side * (half + 24.0)
		base.y = _ground(base)
		if absf(base.y - yard_level) > 3.0:
			continue
		var crane := Node3D.new()
		crane.name = "Crane"
		var cx: Vector3 = right * quay_side
		crane.transform = Transform3D(Basis(cx, Vector3.UP, cx.cross(Vector3.UP)), base)
		add_child(crane)
		var legs_h := 38.0
		for lx in [-7.0, 7.0]:
			for lz in [-8.0, 8.0]:
				_box(Vector3(1.4, legs_h, 1.4), Transform3D(Basis(), Vector3(lx, legs_h * 0.5, lz)), crane_paint, crane)
			_box(Vector3(1.2, 1.2, 17.0), Transform3D(Basis(), Vector3(lx, legs_h * 0.55, 0)), crane_paint, crane)
		_box(Vector3(15.0, 1.2, 1.2), Transform3D(Basis(), Vector3(0, 12.0, -8.0)), crane_paint, crane)
		# The boom runs along the crane's local x: back over the yard, far out over the water.
		_box(Vector3(78.0, 3.2, 3.6), Transform3D(Basis(), Vector3(22.0, legs_h + 1.6, -4.0)), crane_paint, crane)
		_box(Vector3(78.0, 3.2, 3.6), Transform3D(Basis(), Vector3(22.0, legs_h + 1.6, 4.0)), crane_paint, crane)
		_box(Vector3(10.0, 6.0, 9.0), Transform3D(Basis(), Vector3(-10.0, legs_h + 6.2, 0)), steel, crane)
		_box(Vector3(4.0, 3.0, 5.0), Transform3D(Basis(), Vector3(30.0, legs_h - 2.0, 0)), steel, crane)
		_box(Vector3(0.2, 22.0, 0.2), Transform3D(Basis(), Vector3(30.0, legs_h - 14.0, 0)), steel, crane)
		_box(Vector3(0.8, 0.8, 0.8), Transform3D(Basis(), Vector3(60.0, legs_h + 3.6, 0)), warn, crane)
		_box(Vector3(0.8, 0.8, 0.8), Transform3D(Basis(), Vector3(-12.0, legs_h + 9.6, 0)), warn, crane)
		cranes += 1
	_counts["cranes"] = cranes

	# Tank farm and chimneys, deeper in the yard.
	var tank_white := _material(Color(0.88, 0.88, 0.86), 0.5, 0.2)
	var stripe := _material(Color(0.1, 0.35, 0.75), 0.5, 0.2)
	var red := _material(Color(0.75, 0.12, 0.1), 0.6)
	var white := _material(Color(0.92, 0.92, 0.9), 0.6)
	var mid: int = docks[docks.size() / 2]
	var ax := _axes(mid)
	var right: Vector3 = ax[0]
	var fwd: Vector3 = ax[1]
	var farm: Vector3 = track.frames[mid].origin + right * yard_side * (half + 165.0)
	var tanks := 0
	for t in 5:
		var p: Vector3 = farm + fwd * (t % 3 - 1) * 30.0 + right * yard_side * (t / 3) * 30.0
		var g := _ground(p)
		if absf(g - yard_level) > 3.0:
			continue
		var r := _rng.randf_range(9.0, 12.0)
		var h := _rng.randf_range(12.0, 17.0)
		_cylinder(r, h, Transform3D(Basis(), Vector3(p.x, g + h * 0.5, p.z)), tank_white)
		_cylinder(r + 0.05, 1.6, Transform3D(Basis(), Vector3(p.x, g + h * 0.72, p.z)), stripe)
		var dome := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * 0.5
		sphere.is_hemisphere = true
		dome.mesh = sphere
		dome.material_override = tank_white
		dome.position = Vector3(p.x, g + h, p.z)
		add_child(dome)
		tanks += 1
	_counts["tanks"] = tanks
	for c in 2:
		var p: Vector3 = farm + fwd * (c * 70.0 - 35.0) + right * yard_side * 70.0
		var g := _ground(p)
		if g < land.water_level + 2.0:
			continue
		var h := 70.0 + c * 12.0
		for band in 7:
			var bh := h / 7.0
			_cylinder(2.8 - band * 0.12, bh, Transform3D(Basis(), Vector3(p.x, g + bh * (band + 0.5), p.z)), red if band % 2 == 0 else white, self, 2.8 - (band + 1) * 0.12)
		_add_smoke(Vector3(p.x, g + h + 1.0, p.z))
	# Sheds along the yard edge.
	var shed := _material(Color(0.42, 0.5, 0.58), 0.7, 0.3)
	var roof := _material(Color(0.3, 0.33, 0.37), 0.6, 0.4)
	for k in range(30, docks.size(), 70):
		var i: int = docks[k]
		var sax := _axes(i)
		var p: Vector3 = track.frames[i].origin + sax[0] * yard_side * (half + 120.0)
		var g := _ground(p)
		if absf(g - yard_level) > 3.0:
			continue
		var sx: Vector3 = sax[1]
		var basis := Basis(sx, Vector3.UP, sx.cross(Vector3.UP))
		_box(Vector3(64.0, 12.0, 26.0), Transform3D(basis, Vector3(p.x, g + 6.0, p.z)), shed)
		var prism := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(26.0, 5.0, 64.0)
		prism.mesh = pm
		prism.material_override = roof
		var px: Vector3 = sax[0] * yard_side
		prism.transform = Transform3D(Basis(px, Vector3.UP, px.cross(Vector3.UP)), Vector3(p.x, g + 14.5, p.z))
		add_child(prism)


func _inside_side() -> float:
	return land._inside_sign


func _add_smoke(at: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1.0, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(1.2, 0.4, 0.3)
	pm.scale_min = 3.0
	pm.scale_max = 5.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.73, 0.7, 0.0), Color(0.72, 0.7, 0.68, 0.45), Color(0.8, 0.8, 0.8, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	var soft := GradientTexture2D.new()
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	sg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	soft.gradient = sg
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.process_material = pm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 120, 80))
	p.position = at
	add_child(p)


# --- Start: grandstands ---------------------------------------------------------------

## A tiered stand either side of the start line, with a crowd and a roof.
func _add_start() -> void:
	var n := track.frames.size()
	var half := track.track_width * 0.5
	var concrete := _material(Color(0.7, 0.69, 0.67), 0.85, 0.0, false)
	var crowd := ShaderMaterial.new()
	crowd.shader = load("res://shaders/crowd.gdshader")
	var roof_mat := _material(Color(0.8, 0.81, 0.84), 0.7, 0.2)
	var steps := 11
	var rise := 1.1
	var tread := 1.5
	var from := -48   # frames either side of the line (about 100 m)
	var to := 48
	for side in [-1.0, 1.0]:
		var d0 := half + 5.0
		var seats := SurfaceTool.new()
		seats.begin(Mesh.PRIMITIVE_TRIANGLES)
		var shell := SurfaceTool.new()
		shell.begin(Mesh.PRIMITIVE_TRIANGLES)
		var roof := SurfaceTool.new()
		roof.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(from, to):
			var f0 := track.frames[posmod(k, n)]
			var f1 := track.frames[posmod(k + 1, n)]
			var a0 := _axes(k)
			var a1 := _axes(k + 1)
			var base0 := f0.origin.y - 1.0
			var base1 := f1.origin.y - 1.0
			var u0 := float(k - from) * track.step
			var u1 := u0 + track.step
			for s in steps:
				var y := s * rise
				var lat := d0 + s * tread
				# Riser (vertical), then tread (flat), each as a quad with crowd UVs.
				var r_a: Vector3 = f0.origin + a0[0] * side * lat
				var r_b: Vector3 = f1.origin + a1[0] * side * lat
				_quad(seats, Vector3(r_a.x, base0 + y, r_a.z), Vector3(r_b.x, base1 + y, r_b.z), Vector3(r_b.x, base1 + y + rise, r_b.z), Vector3(r_a.x, base0 + y + rise, r_a.z),
					Vector2(u0, s * 2.0), Vector2(u1, s * 2.0), Vector2(u1, s * 2.0 + 0.9), Vector2(u0, s * 2.0 + 0.9))
				var t_a: Vector3 = f0.origin + a0[0] * side * (lat + tread)
				var t_b: Vector3 = f1.origin + a1[0] * side * (lat + tread)
				_quad(seats, Vector3(r_a.x, base0 + y + rise, r_a.z), Vector3(r_b.x, base1 + y + rise, r_b.z), Vector3(t_b.x, base1 + y + rise, t_b.z), Vector3(t_a.x, base0 + y + rise, t_a.z),
					Vector2(u0, s * 2.0 + 0.9), Vector2(u1, s * 2.0 + 0.9), Vector2(u1, s * 2.0 + 2.0), Vector2(u0, s * 2.0 + 2.0))
			# Back wall.
			var back := d0 + steps * tread
			var b_a: Vector3 = f0.origin + a0[0] * side * back
			var b_b: Vector3 = f1.origin + a1[0] * side * back
			_quad(shell, Vector3(b_a.x, base0 - 6.0, b_a.z), Vector3(b_b.x, base1 - 6.0, b_b.z), Vector3(b_b.x, base1 + steps * rise + 1.0, b_b.z), Vector3(b_a.x, base0 + steps * rise + 1.0, b_a.z))
			# Front wall under the first row.
			var fr_a: Vector3 = f0.origin + a0[0] * side * d0
			var fr_b: Vector3 = f1.origin + a1[0] * side * d0
			_quad(shell, Vector3(fr_a.x, base0 - 6.0, fr_a.z), Vector3(fr_b.x, base1 - 6.0, fr_b.z), Vector3(fr_b.x, base1, fr_b.z), Vector3(fr_a.x, base0, fr_a.z))
			# Roof.
			var roof_y0 := base0 + steps * rise + 7.0
			var roof_y1 := base1 + steps * rise + 7.0
			var rf0: Vector3 = f0.origin + a0[0] * side * (d0 - 2.0)
			var rf1: Vector3 = f1.origin + a1[0] * side * (d0 - 2.0)
			# A slab with its own top and underside, so the underside is shaded as one.
			var corners := [Vector3(rf0.x, roof_y0, rf0.z), Vector3(rf1.x, roof_y1, rf1.z), Vector3(b_b.x, roof_y1 + 1.5, b_b.z), Vector3(b_a.x, roof_y0 + 1.5, b_a.z)]
			var mid: Vector3 = (corners[0] + corners[2]) * 0.5
			for layer in [[0.0, mid + Vector3.DOWN * 5.0], [-0.4, mid + Vector3.UP * 5.0]]:
				var dy := Vector3.UP * float(layer[0])
				_tri(roof, corners[0] + dy, corners[1] + dy, corners[2] + dy, layer[1])
				_tri(roof, corners[0] + dy, corners[2] + dy, corners[3] + dy, layer[1])
			if (k - from) % 10 == 0:
				var col_p: Vector3 = b_a
				_box(Vector3(0.6, steps * rise + 14.0, 0.6), Transform3D(Basis(), Vector3(col_p.x, base0 + steps * rise * 0.5 + 1.0, col_p.z)), concrete)
		for pair in [[seats, crowd], [shell, concrete], [roof, roof_mat]]:
			var mi := MeshInstance3D.new()
			mi.mesh = pair[0].commit()
			mi.material_override = pair[1]
			add_child(mi)
		# Neon fascia along the roof edge, in the circuit's colour.
		var strip := _glow(track.neon_color, 2.5)
		for k in range(from, to, 4):
			var f := track.frames[posmod(k, n)]
			var ax := _axes(k)
			var p: Vector3 = f.origin + ax[0] * side * (d0 - 2.0)
			var sx0: Vector3 = ax[0]
			_box(Vector3(0.3, 0.6, track.step * 4.2), Transform3D(Basis(sx0, Vector3.UP, sx0.cross(Vector3.UP)), Vector3(p.x, f.origin.y - 1.0 + steps * rise + 6.7, p.z)), strip)
		# The roof, from below, needs a surface too; the shell material is double-sided.
	_counts["grandstands"] = 2


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua := Vector2.ZERO, ub := Vector2.RIGHT, uc := Vector2.ONE, ud := Vector2.DOWN) -> void:
	var n := (b - a).cross(d - a).normalized()
	for pair in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_normal(n)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


# --- Sponsor boards -------------------------------------------------------------------

## Big trackside hoardings with team and league names, facing the oncoming ships.
func _add_boards() -> void:
	var n := track.frames.size()
	var font: Font = load("res://assets/fonts/SairaCondensed-SemiBold.ttf")
	var panel := _material(Color(0.05, 0.06, 0.08), 0.6)
	var placed := 0
	var k := 0
	for fraction in [0.035, 0.09, 0.2, 0.3, 0.43, 0.55, 0.64, 0.74, 0.86, 0.95]:
		var i := int(fraction * n)
		if track.in_tunnel(i) or track.in_gap(i):
			continue
		var f := track.frames[i]
		var ax := _axes(i)
		var side := 1.0 if k % 2 == 0 else -1.0
		if track.is_open(i, side):
			side = -side
		var d := track.track_width * 0.5 + 6.0
		var p: Vector3 = f.origin + ax[0] * side * d
		var g := _ground(p)
		var bottom := maxf(g, f.origin.y - 1.0) + 2.5
		var name: String = TEAMS[k % TEAMS.size()]
		var color: Color = TEAM_COLORS[k % TEAM_COLORS.size()]
		k += 1
		# Angled 35 degrees towards the oncoming traffic.
		var facing: Vector3 = (-ax[1]).rotated(Vector3.UP, -side * 0.6)
		var basis := Basis.looking_at(-facing, Vector3.UP)
		var centre := Vector3(p.x, bottom + 3.0, p.z)
		_box(Vector3(22.0, 6.0, 0.6), Transform3D(basis, centre), panel)
		var frame_mat := _glow(color, 2.5)
		for dy in [-3.0, 3.0]:
			_box(Vector3(22.4, 0.25, 0.7), Transform3D(basis, centre + basis.y * dy), frame_mat)
		for post: float in [-8.0, 8.0]:
			var pb: Vector3 = centre + basis.x * post
			var post_h: float = pb.y - (g - 1.0)
			_box(Vector3(0.5, post_h, 0.5), Transform3D(Basis(), Vector3(pb.x, pb.y - post_h * 0.5 - 3.0, pb.z)), panel)
		var label := Label3D.new()
		label.text = name
		label.font = font
		label.font_size = 160
		label.pixel_size = 0.028
		label.modulate = color
		label.outline_size = 0
		label.double_sided = false
		label.shaded = false
		label.transform = Transform3D(basis, centre + basis.z * 0.36)
		add_child(label)
		placed += 1
	_counts["boards"] = placed


# --- Water ----------------------------------------------------------------------------

## Sailing boats and a lighthouse on the lake, buoys marking the causeway.
func _add_water_life() -> void:
	var n := track.frames.size()
	var hull := _material(Color(0.92, 0.92, 0.9), 0.4)
	var sail := _material(Color(0.97, 0.96, 0.92), 0.8, 0.0, false)
	var mast := _material(Color(0.35, 0.35, 0.36), 0.5, 0.5)
	var boats := 0
	for _a in 400:
		if boats >= 10:
			break
		var i := _rng.randi_range(0, n - 1)
		var ax := _axes(i)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var p: Vector3 = track.frames[i].origin + ax[0] * side * _rng.randf_range(60.0, 320.0)
		if _ground(p) > land.water_level - 4.0 or not _clear_of_road(p, 40.0):
			continue
		var boat := Node3D.new()
		boat.position = Vector3(p.x, land.water_level + 0.2, p.z)
		boat.rotation.y = _rng.randf() * TAU
		boat.set_meta("base", boat.position)
		add_child(boat)
		_box(Vector3(2.6, 1.2, 8.0), Transform3D(Basis(), Vector3(0, 0.3, 0)), hull, boat)
		_box(Vector3(0.18, 11.0, 0.18), Transform3D(Basis(), Vector3(0, 6.2, -0.6)), mast, boat)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(0, 1.4, -0.4), Vector3(0, 11.4, -0.6), Vector3(0, 1.4, 3.4)]:
			st.set_normal(Vector3.RIGHT)
			st.add_vertex(v)
		var sm := MeshInstance3D.new()
		sm.mesh = st.commit()
		sm.material_override = sail
		boat.add_child(sm)
		_boats.append(boat)
		boats += 1
	_counts["boats"] = boats

	# Buoys along the causeway, red to the left and green to the right.
	var causeway := _frames_of("causeway")
	var buoy_xforms: Array[Transform3D] = []
	var buoy_colors: Array = []
	for k in range(0, causeway.size(), 30):
		var i: int = causeway[k]
		var ax := _axes(i)
		for side in [-1.0, 1.0]:
			var p: Vector3 = track.frames[i].origin + ax[0] * side * (track.track_width * 0.5 + 26.0)
			if _ground(p) > land.water_level - 1.5:
				continue
			buoy_xforms.append(Transform3D(Basis().scaled(Vector3(1.4, 2.2, 1.4)), Vector3(p.x, land.water_level + 0.8, p.z)))
			buoy_colors.append(Color(0.85, 0.12, 0.1) if side < 0.0 else Color(0.1, 0.65, 0.25))
	if not buoy_xforms.is_empty():
		var cone := CylinderMesh.new()
		cone.top_radius = 0.1
		cone.bottom_radius = 0.6
		cone.height = 1.0
		var bm := StandardMaterial3D.new()
		bm.vertex_color_use_as_albedo = true
		bm.roughness = 0.5
		_multimesh("Buoys", cone, buoy_xforms, bm, buoy_colors, false, 900.0)

	# A lighthouse on a rock off the causeway's outer side.
	if not causeway.is_empty():
		var i: int = causeway[causeway.size() / 2]
		var ax := _axes(i)
		var p: Vector3 = track.frames[i].origin - ax[0] * _inside_side() * (track.track_width * 0.5 + 90.0)
		var g := _ground(p)
		if g < land.water_level:
			var islet := MeshInstance3D.new()
			islet.mesh = _rock_mesh(7, Vector3(1.4, 0.7, 1.2))
			islet.material_override = land.terrain_material()
			islet.transform = Transform3D(Basis().scaled(Vector3(14, 10, 14)), Vector3(p.x, land.water_level + 1.0, p.z))
			add_child(islet)
			var base_y := land.water_level + 7.0
			var red := _material(Color(0.8, 0.12, 0.1), 0.6)
			var white := _material(Color(0.95, 0.95, 0.93), 0.6)
			for band in 6:
				_cylinder(2.6 - band * 0.18, 4.0, Transform3D(Basis(), Vector3(p.x, base_y + band * 4.0 + 2.0, p.z)), red if band % 2 == 0 else white, self, 2.6 - (band + 1) * 0.18)
			_cylinder(1.6, 3.0, Transform3D(Basis(), Vector3(p.x, base_y + 25.5, p.z)), _glow(Color(1.0, 0.9, 0.6), 4.0))
			_cylinder(2.0, 0.6, Transform3D(Basis(), Vector3(p.x, base_y + 27.3, p.z)), red)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.9, 0.6)
			light.light_energy = 3.0
			light.omni_range = 40.0
			light.position = Vector3(p.x, base_y + 25.5, p.z)
			add_child(light)
			_counts["lighthouse"] = 1
