extends SceneTree

## For every circuit with a landscape: the terrain must stay below the road everywhere a ship
## can drive (across the full width, outside gaps; tunnels included, since the corridor is
## carved under them), and it must not rise above the walls just beyond the road edge.
##   godot --headless --path . -s tools/check_landscape.gd

func _init() -> void:
	var failed := false
	for def in TrackDefs.ALL:
		if not def.has("landscape"):
			continue
		var tb := TrackBuilder.new()
		tb.load_def(def)
		var land := Landscape.new()
		land.build(tb, def)
		var half := tb.track_width * 0.5
		var worst_road := INF
		var worst_edge := INF
		var at_road := -1
		var at_edge := -1
		var bad := 0
		for i in tb.frames.size():
			if tb.in_gap(i):
				continue
			var f: Transform3D = tb.frames[i]
			for s in range(-int(half), int(half) + 1):
				var p: Vector3 = f.origin + f.basis.x * float(s)
				var clearance: float = p.y - land.height_at(p.x, p.z)
				if clearance < worst_road:
					worst_road = clearance
					at_road = i
				if clearance < 1.0:
					bad += 1
			for side in [-1.0, 1.0]:
				var e: Vector3 = f.origin + f.basis.x * side * (half + 2.0)
				var over: float = land.height_at(e.x, e.z) - (f.origin.y + tb.wall_height)
				if -over < worst_edge:
					worst_edge = -over
					at_edge = i
		var ok := bad == 0 and worst_edge > 0.0
		failed = failed or not ok
		print("%-13s road clearance >= %.2f m (frame %d), wall-top clearance >= %.2f m (frame %d), road points under 1 m: %d  %s" % [
			def.name, worst_road, at_road, worst_edge, at_edge, bad, "OK" if ok else "TERRAIN IN THE ROAD"])
		land.free()
		tb.free()
	quit(1 if failed else 0)
