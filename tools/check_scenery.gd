extends SceneTree

## For every circuit with a landscape: no scenery mesh may reach into the space a ship drives
## through. Scenery has no collision, so anything there is a ghost the ship flies through.
## Checks every vertex of every scenery instance near the road against the nearest frame:
## inside the road's width (plus a little) and from just under the surface to DRIVE_HEIGHT
## above it is a failure. Things built to span the road overhead (the arch, the start gantry,
## the boards) sit above DRIVE_HEIGHT and pass on their own.
##   godot --headless --path . -s tools/check_scenery.gd

const DRIVE_HEIGHT := 12.0   ## ships, jumps and the chase camera live below this
const EDGE := 1.0            ## beyond the road edge that still counts as "on the track"


func _init() -> void:
	var failed := false
	for def in TrackDefs.ALL:
		if not def.has("landscape"):
			continue
		var tb := TrackBuilder.new()
		tb.load_def(def)
		var land := Landscape.new()
		land.build(tb, def)
		var scenery := Scenery.new()
		scenery.build(tb, land)
		var half := tb.track_width * 0.5
		var hits := {}      # label -> instances intruding
		var worst := {}     # label -> deepest intrusion (m inside the road edge)
		var where := {}     # label -> [frame, zone, mesh class] of the deepest one
		for node in _meshes(scenery):
			var label := _label(node)
			for pair in _instances(node):
				var mesh: Mesh = pair[0]
				var xform: Transform3D = pair[1]
				var o := xform.origin
				# Cheap reject: no scenery piece here is 80 m across.
				if land.distance_at(o.x, o.z) > half + 80.0:
					continue
				var hit := _intrusion(tb, land, mesh, xform, half)
				var depth: float = hit[0]
				if depth > 0.0:
					hits[label] = hits.get(label, 0) + 1
					if depth > worst.get(label, 0.0):
						worst[label] = depth
						where[label] = [hit[1], land.zone_kind(hit[1]), hit[2]]
		var ok := hits.is_empty()
		failed = failed or not ok
		if ok:
			print("%-13s scenery clear of the road  OK" % def.name)
		else:
			for label in hits:
				print("%-13s %-12s %3d in the road, deepest %.1f m inside the edge (frame %d, %s zone, %.1f m up)  SCENERY IN THE ROAD" % [
					def.name, label, hits[label], worst[label], where[label][0], where[label][1], (where[label][2] as Vector3).y])
		scenery.free()
		land.free()
		tb.free()
	quit(1 if failed else 0)


## The nearest ancestor with a real name ("Docks", "Rocks"), not "@MeshInstance3D@458".
func _label(node: Node) -> String:
	if node.has_meta("label"):
		return node.get_meta("label")
	while node != null and not (node is Scenery):
		if not String(node.name).begins_with("@"):
			return String(node.name)
		node = node.get_parent()
	return "(unnamed)"


func _meshes(root: Node) -> Array:
	var out := []
	for child in root.get_children():
		if child is MultiMeshInstance3D or child is MeshInstance3D:
			out.append(child)
		out.append_array(_meshes(child))
	return out


## [mesh, world transform] for each instance a node draws.
func _instances(node: Node3D) -> Array:
	var out := []
	var base := _world(node)
	if node is MultiMeshInstance3D:
		var mm: MultiMesh = node.multimesh
		if mm == null or mm.mesh == null:
			return out
		# Scenery keeps the transforms as metadata: headless runs have no real renderer, and
		# the dummy one returns zero transforms, which would all land on the start line.
		var xforms: Array = node.get_meta("xforms", [])
		for xform: Transform3D in xforms:
			out.append([mm.mesh, base * xform])
	elif node.mesh != null:
		out.append([node.mesh, base])
	return out


## Transform relative to the scenery root (the scene tree isn't running, so walk parents).
func _world(node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while node is Node3D and not (node is Scenery):
		t = (node as Node3D).transform * t
		node = node.get_parent()
	return t


## How far (m) the deepest vertex reaches inside the road edge (0 if none does), with the
## frame it is at and its position in that frame (x across, y up from the road).
func _intrusion(tb: TrackBuilder, land: Landscape, mesh: Mesh, xform: Transform3D, half: float) -> Array:
	var deepest := 0.0
	var at := [-1, Vector3.ZERO]
	var n := tb.frames.size()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p := xform * v
			var hint := land.frame_at(p.x, p.z)
			if hint < 0:
				continue
			# Refine to the frame whose cross-section the point lies in.
			var best := hint
			var best_z := INF
			for di in range(-6, 7):
				var i := posmod(hint + di, n)
				var z := absf((tb.frames[i].affine_inverse() * p).z)
				if z < best_z:
					best_z = z
					best = i
			if tb.in_gap(best):
				continue
			var local := tb.frames[best].affine_inverse() * p
			if local.y < -1.0 or local.y > DRIVE_HEIGHT:
				continue
			var inside := half + EDGE - absf(local.x)
			if inside > deepest:
				deepest = inside
				at = [best, local]
	return [deepest, at[0], at[1]]
