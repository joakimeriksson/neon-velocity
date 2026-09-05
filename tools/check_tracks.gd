extends SceneTree

## Sanity-check every circuit in TrackDefs: builds it and reports length, and flags
## places where two distant parts of the lap come within a track width of each other
## (a fold or crossing).
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
		for i in n:
			for j in range(i + 30, n):
				if n - (j - i) < 30:
					continue  # wrap-around neighbours
				var d := tb.frames[i].origin.distance_to(tb.frames[j].origin)
				if d < min_d:
					min_d = d
					where = i
		var ok := min_d > tb.track_width * 1.5
		var lows := INF
		var highs := -INF
		for f in tb.frames:
			lows = minf(lows, f.origin.y)
			highs = maxf(highs, f.origin.y)
		print("%-14s %5.0f m  width %2.0f  elev %4.0f..%3.0f  closest approach %5.1f m at frame %d  %s" % [
			def.name, length, tb.track_width, lows, highs, min_d, where, "OK" if ok else "TOO CLOSE"])
		failed = failed or not ok
		tb.free()
	quit(1 if failed else 0)
