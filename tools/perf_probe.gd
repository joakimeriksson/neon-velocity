extends Node

## Long-run performance probe: races on autopilot in a real window, restarting the race each
## time it finishes, and logs every 10 s. Run with:
##   AG_AUTOPILOT=1 AG_NO_MUSIC=1 godot --path . tools/perf_probe.tscn
## Growth in objects/nodes/memory = a leak. Flat counts with GPU ms rising = thermal throttling.

class PerfLog extends Node:
	var _t := 0.0
	var _next := 10.0
	var _frames := 0
	var _worst := 0.0
	var _gpu_sum := 0.0
	var _cpu_sum := 0.0
	var _races := 0

	func _ready() -> void:
		RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)

	func _process(delta: float) -> void:
		_t += delta
		_frames += 1
		_worst = maxf(_worst, delta)
		var vp := get_tree().root.get_viewport_rid()
		_gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var scene := get_tree().current_scene
		if scene is Race and scene.state == Race.State.FINISHED and scene._results != null:
			_races += 1
			Game.start_race((Game.track_index + 1) % TrackDefs.ALL.size())
		if _t >= _next:
			print("t=%3.0fs track=%d races=%d | fps %5.1f  worst frame %5.1f ms | gpu %5.2f ms  cpu-render %5.2f ms  process %5.2f ms  physics %5.2f ms | objects %d  nodes %d  orphans %d  resources %d | static mem %.0f MB  video mem %.0f MB | draw calls %d  sfx players %d" % [
				_t, Game.track_index, _races, _frames / 10.0, _worst * 1000.0, _gpu_sum / _frames, _cpu_sum / _frames,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), get_node("/root/Sfx").get_child_count()])
			_next += 10.0
			_frames = 0
			_worst = 0.0
			_gpu_sum = 0.0
			_cpu_sum = 0.0


func _ready() -> void:
	get_tree().root.add_child.call_deferred(PerfLog.new())
	Game.start_race.call_deferred(0)
