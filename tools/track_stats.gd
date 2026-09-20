extends SceneTree

## Shape statistics per circuit, and a top-down outline dumped as JSON for tools/plot_tracks.py.
##   godot --headless --path . -s tools/track_stats.gd

func _init() -> void:
	var out := {}
	for def in TrackDefs.ALL:
		var tb := TrackBuilder.new()
		tb.load_def(def)
		var n := tb.frames.size()
		var left := 0
		var right := 0
		var straight := 0
		var run := 0
		var longest := 0
		var tightest := INF
		var changes := 0
		var last_sign := 0
		for i in n:
			var a: Vector3 = -tb.frames[(i - 3 + n) % n].basis.z
			var b: Vector3 = -tb.frames[(i + 3) % n].basis.z
			a.y = 0.0
			b.y = 0.0
			var angle := a.normalized().signed_angle_to(b.normalized(), Vector3.UP)
			var radius := (6.0 * tb.step) / maxf(absf(angle), 0.00001)
			if radius > 900.0:
				straight += 1
				run += 1
				longest = maxi(longest, run)
			else:
				run = 0
				tightest = minf(tightest, radius)
				var sgn := 1 if angle > 0.0 else -1
				if sgn > 0:
					left += 1
				else:
					right += 1
				if last_sign != 0 and sgn != last_sign:
					changes += 1
				last_sign = sgn
		print("%-13s %4.0f m | left %2.0f%%  right %2.0f%%  straight %2.0f%% | direction changes %d | tightest radius %3.0f m | longest straight %3.0f m" % [
			def.name, n * tb.step, 100.0 * left / n, 100.0 * right / n, 100.0 * straight / n, changes, tightest, longest * tb.step])
		var pts := []
		for f in tb.frames:
			pts.append([snappedf(f.origin.x, 0.1), snappedf(f.origin.z, 0.1), snappedf(f.origin.y, 0.1)])
		out[def.name] = {"points": pts, "width": tb.track_width, "gaps": tb.gaps, "tunnels": tb.tunnel_ranges}
		tb.free()
	var f := FileAccess.open("res://out/track_outlines.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
	quit()
