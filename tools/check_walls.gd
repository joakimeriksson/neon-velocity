extends SceneTree

## Verify both walls stop a ship on every circuit: casts rays from the track centre outward
## through each wall. Trimesh collision is one-sided, so a wall wound the wrong way looks
## fine and blocks nothing.
##   godot --headless --path . -s tools/check_walls.gd

func _init():
	await process_frame
	var failed := false
	for t in TrackDefs.ALL.size():
		var tb := TrackBuilder.new()
		root.add_child(tb)
		tb.load_def(TrackDefs.ALL[t])
		await physics_frame
		await physics_frame
		var space := tb.get_world_3d().direct_space_state
		var res := {"left": 0, "right": 0}
		var n := 0
		for i in range(0, tb.frames.size(), 10):
			var f: Transform3D = tb.frames[i]
			var from := f.origin + f.basis.y * 1.0
			n += 1
			for side in [["left", -1.0], ["right", 1.0]]:
				var to: Vector3 = from + f.basis.x * side[1] * (tb.track_width * 0.5 + 4.0)
				var q := PhysicsRayQueryParameters3D.create(from, to)
				if not space.intersect_ray(q).is_empty():
					res[side[0]] += 1
		var ok: bool = res.left == n and res.right == n
		failed = failed or not ok
		print("%-13s samples=%d  left wall blocks=%d  right wall blocks=%d  %s" % [TrackDefs.ALL[t].name, n, res.left, res.right, "OK" if ok else "LEAKS"])
		tb.queue_free()
	quit(1 if failed else 0)
