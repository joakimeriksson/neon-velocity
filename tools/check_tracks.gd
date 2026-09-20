extends SceneTree

## Sanity-check every circuit in TrackDefs: builds it and reports length, and flags
## places where two distant parts of the lap come within a track width of each other
## (a fold). One road passing at least 12 m over another is reported as a bridge instead.
##   godot --headless --path . -s tools/check_tracks.gd

func _init() -> void:
	var failed := false
	for def in TrackDefs.ALL:
		var tb := TrackBuilder.new()
		tb.load_def(def)
		var n := tb.frames.size()
		var length := n * tb.step
		var min_d := INF
		var where := -1
		var bridges := 0
		var bridge_clearance := INF
		var in_bridge := false
		for i in n:
			var crossing := false
			for j in range(i + 30, n):
				if n - (j - i) < 30:
					continue  # wrap-around neighbours
				var a: Vector3 = tb.frames[i].origin
				var b: Vector3 = tb.frames[j].origin
				var flat := Vector2(a.x - b.x, a.z - b.z).length()
				# One road passing well over another is a bridge, not a fold.
				if flat < tb.track_width and absf(a.y - b.y) >= 12.0:
					crossing = true
					bridge_clearance = minf(bridge_clearance, absf(a.y - b.y))
					continue
				var d := a.distance_to(b)
				if d < min_d:
					min_d = d
					where = i
			if crossing and not in_bridge:
				bridges += 1
			in_bridge = crossing
		var ok := min_d > tb.track_width * 1.5
		var lows := INF
		var highs := -INF
		for f in tb.frames:
			lows = minf(lows, f.origin.y)
			highs = maxf(highs, f.origin.y)
		var bridge_note := "" if bridges == 0 else "  bridge clearance %.0f m" % bridge_clearance
		print("%-14s %5.0f m  width %2.0f  elev %4.0f..%3.0f  closest approach %5.1f m at frame %d  %s%s" % [
			def.name, length, tb.track_width, lows, highs, min_d, where, "OK" if ok else "TOO CLOSE", bridge_note])
		failed = failed or not ok
		tb.free()
	quit(1 if failed else 0)
