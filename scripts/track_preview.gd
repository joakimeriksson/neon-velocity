class_name TrackPreview
extends Control

## Circuit outline for the select screen, drawn as a neon tube: gaps left dark, tunnels and
## bridges marked, start line and direction shown. Built from the control points alone, so
## no meshes are generated.

var _outline := PackedVector2Array()
var _heights := PackedFloat32Array()
var _gaps: Array = []
var _tunnels: Array = []
var _color := Color.WHITE
var _caption := ""
var _font: Font = preload("res://assets/fonts/SairaCondensed-Medium.ttf")


func show_circuit(def: Dictionary) -> void:
	var tb := TrackBuilder.new()
	tb.step = 6.0
	tb.control_points.assign(def.points)
	tb.track_width = def.get("width", 18.0)
	tb.relief = def.get("relief", [])
	tb.tunnels = def.get("tunnels", [])
	tb.frames = tb._sample_frames(tb._make_curve())
	tb._plan_tunnels()
	_outline.clear()
	_heights.clear()
	for f in tb.frames:
		_outline.append(Vector2(f.origin.x, f.origin.z))
		_heights.append(f.origin.y)
	_gaps = tb.gaps.duplicate()
	_tunnels = tb.tunnel_ranges.duplicate()
	_color = def.get("neon", Color.WHITE)
	_caption = "%.1f km    %s" % [tb.frames.size() * tb.step / 1000.0, def.get("features", "")]
	tb.free()
	queue_redraw()


func _draw() -> void:
	if _outline.size() < 3:
		return
	var bounds := Rect2(_outline[0], Vector2.ZERO)
	for p in _outline:
		bounds = bounds.expand(p)
	var room := size - Vector2(40, 90)
	var k := minf(room.x / bounds.size.x, room.y / bounds.size.y)
	var offset := Vector2(20, 20) + (room - bounds.size * k) * 0.5 - bounds.position * k
	var n := _outline.size()

	# Runs of road between gaps, each as one tube.
	var run := PackedVector2Array()
	for i in n + 1:
		var idx := i % n
		var in_gap := false
		for g in _gaps:
			if idx >= g[0] and idx < g[1]:
				in_gap = true
		if in_gap:
			_tube(run, _color, 5.0)
			run = PackedVector2Array()
		else:
			run.append(_outline[idx] * k + offset)
	_tube(run, _color, 5.0)

	for t in _tunnels:
		var roof := PackedVector2Array()
		for i in range(t[0], t[1]):
			roof.append(_outline[i % n] * k + offset)
		if roof.size() > 1:
			draw_polyline(roof, Color(0, 0, 0, 0.75), 9.0, true)
			draw_polyline(roof, Color(1, 1, 1, 0.55), 2.0, true)

	# Start line and direction of travel.
	var start := _outline[0] * k + offset
	var ahead := _outline[4 % n] * k + offset
	var dir := (ahead - start).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_line(start - side * 11.0, start + side * 11.0, Color.WHITE, 4.0, true)
	draw_polyline(PackedVector2Array([start + dir * 12.0 - side * 7.0, start + dir * 24.0, start + dir * 12.0 + side * 7.0]), Color.WHITE, 3.0, true)

	var w := _font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(_font, Vector2((size.x - w) * 0.5, size.y - 24.0), _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.8))


func _tube(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(color, 0.10), width * 5.0, true)
	draw_polyline(pts, Color(color, 0.25), width * 2.4, true)
	draw_polyline(pts, Color(color, 0.95), width, true)
	draw_polyline(pts, Color(Color.WHITE.lerp(color, 0.2), 0.9), width * 0.35, true)
