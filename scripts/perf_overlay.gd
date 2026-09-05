extends CanvasLayer

## Autoload. F3 toggles a performance readout: FPS, frame time, render resolution,
## object/node counts, live audio players. For diagnosing slowdowns.

var _label: Label
var _frame_times: Array[float] = []


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(16, 160)
	add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_frame_times.append(delta)
	if _frame_times.size() > 120:
		_frame_times.pop_front()
	var worst := 0.0
	for t in _frame_times:
		worst = maxf(worst, t)
	var vp := get_viewport()
	var scale := vp.scaling_3d_scale
	var size := vp.get_visible_rect().size * vp.get_window().content_scale_factor if vp.get_window() else Vector2.ZERO
	var players := 0
	for node in get_tree().get_nodes_in_group(&"_all_audio"):
		players += 1
	_label.text = "FPS %d   frame %.1f ms (worst %.1f)\n3D render %dx%d (scale %.2f)   window %dx%d\ndraw calls %d   primitives %dk   objects %d   nodes %d   orphans %d\naudio players %d   mem %.0f MB" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		worst * 1000.0,
		int(size.x * scale), int(size.y * scale), scale, int(size.x), int(size.y),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		_count_audio_players(get_tree().root),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]


func _count_audio_players(node: Node) -> int:
	var n := 1 if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node.playing else 0
	for c in node.get_children():
		n += _count_audio_players(c)
	return n
