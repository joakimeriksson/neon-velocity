extends Node

## Records each audio bus to its own WAV during an autopilot race, to measure the mix:
##   MIX_OUT=/some/dir AG_AUTOPILOT=1 godot --headless --max-fps 60 --path . tools/mix_probe.tscn
##   for f in music sfx engines master; do ffmpeg -i $MIX_OUT/$f.wav -af ebur128 -f null - 2>&1 | grep "I:" | tail -1; done
## Headless is fine: the dummy audio driver still mixes in real time.

const BUSES := {"Music": "music", "SFX": "sfx", "Engines": "engines", "Master": "master",
	"P_events": "sfx_events", "P_hiss": "sfx_hiss", "P_scrape": "sfx_scrape", "P_voices": "sfx_voices", "P_ambience": "sfx_ambience"}
## With MIX_SPLIT=1 the effects bus is split by source into the P_* buses (SFX then holds the rest).
const SKIP := 9.0      ## countdown and launch
const LENGTH := 45.0

class Recorder extends Node:
	var effects := {}
	var t := 0.0
	var started := false
	func _ready() -> void:
		for bus_name in BUSES:
			if AudioServer.get_bus_index(bus_name) < 0:
				AudioServer.add_bus()
				AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
				AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

	var seen := {}
	var tally := {}   # event name -> [plays, sum of linear gain at the listener, seconds alive]

	func _tally(delta: float) -> void:
		var sfx := get_node("/root/Sfx")
		var cam := get_viewport().get_camera_3d()
		for p in sfx.get_children():
			if not ("stream" in p): continue
			var name := "?"
			for k in sfx._streams:
				if sfx._streams[k] == p.stream: name = k
			if not tally.has(name): tally[name] = [0, 0.0, 0.0]
			tally[name][2] += delta
			if seen.has(p.get_instance_id()): continue
			seen[p.get_instance_id()] = true
			var db: float = p.volume_db
			if p is AudioStreamPlayer3D and cam:
				# Godot's default inverse-distance model: unit_size / distance, capped at max_db.
				db = minf(db + linear_to_db(p.unit_size / maxf(cam.global_position.distance_to(p.global_position), 0.1)), p.max_db)
			tally[name][0] += 1
			tally[name][1] += db_to_linear(db)

	func _split() -> void:
		for p in get_node("/root/Sfx").get_children():
			if "bus" in p: p.bus = &"P_events"
		var scene := get_tree().current_scene
		if scene == null: return
		for ea in scene.find_children("*", "EngineAudio", true, false):
			if ea._hiss: ea._hiss.bus = &"P_hiss"
			if ea._scrape: ea._scrape.bus = &"P_scrape"
		for amb in scene.find_children("*", "Ambience", true, false):
			for p in amb.get_children(): p.bus = &"P_ambience"
		for proj in scene.find_children("*", "Projectile", true, false):
			if proj._voice: proj._voice.bus = &"P_voices"

	func _process(delta: float) -> void:
		t += delta
		if OS.has_environment("MIX_SPLIT"):
			_split()
		if started:
			_tally(delta)
		if not started and t >= SKIP:
			started = true
			for bus_name in BUSES:
				var fx := AudioEffectRecord.new()
				AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), fx)
				fx.set_recording_active(true)
				effects[bus_name] = fx
			print("recording ", LENGTH, " s")
		if started and t >= SKIP + LENGTH:
			var out := OS.get_environment("MIX_OUT")
			for bus_name in effects:
				var fx: AudioEffectRecord = effects[bus_name]
				fx.set_recording_active(false)
				var wav := fx.get_recording()
				print(bus_name, " -> ", wav.save_to_wav(out.path_join(BUSES[bus_name] + ".wav")))
			var names := tally.keys()
			names.sort_custom(func(a, b): return tally[a][1] > tally[b][1])
			for name in names:
				print("event %-15s plays %3d   mean level at listener %6.1f dB   alive %5.1f s" % [name, tally[name][0], linear_to_db(tally[name][1] / maxf(tally[name][0], 1)), tally[name][2]])
			get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Recorder.new())
	Game.start_race.call_deferred(int(OS.get_environment("AG_TRACK")) if OS.has_environment("AG_TRACK") else 0)
