extends Node

## Autoload. Plays whatever audio files are in res://audio/music/ on shuffle,
## crossfading one track into the next. Drop generated tracks (ogg/wav/mp3)
## into that folder and they play automatically — no scene wiring needed.
##
## Optional: call `attach_ship(ship)` to make the mix open up with speed
## (a low-pass on the Music bus that lifts as the ship approaches top speed).

const MUSIC_DIR := "res://audio/music"
## Playlists by filename prefix: the title's theme, and what shuffles during races.
const INTRO := ["intro_"]
const RACE := ["afrodnb", "fire"]
const SILENT_DB := -60.0

@export var volume_db := -3.0
@export var crossfade_time := 3.0

@export_group("Speed response")
@export var speed_response := true
@export var cutoff_idle := 900.0        ## Hz at a standstill
@export var cutoff_flat_out := 20000.0  ## Hz at top speed
@export var cutoff_smoothing := 2.5

var _tracks: Array[String] = []   ## the current playlist, in play order
var _library: Array[String] = []  ## everything in MUSIC_DIR
var _prefixes: Array = []
var _current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade: Tween
var _ship: Ship
var _filter: AudioEffectLowPassFilter
var _cutoff := cutoff_flat_out
var _handover_done := false


func _ready() -> void:
	# Two players so a track can fade out while the next fades in.
	var bus: StringName = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = SILENT_DB
		add_child(p)
		# Safety net only: normally the handover happens before `finished`.
		p.finished.connect(_on_finished.bind(i))
		_players.append(p)
	_filter = _find_music_lowpass()
	if OS.has_environment("AG_NO_MUSIC"):
		return  # dev: listen to engine/SFX alone
	_scan()
	# Deferred: the first scene usually sets its playlist in _ready, and that starts the music.
	_start.call_deferred()


func _start() -> void:
	if _current == "":
		play_next()


func _process(delta: float) -> void:
	_check_handover()
	if not speed_response or _filter == null or not is_instance_valid(_ship):
		return
	# Ease the cutoff toward the ship's speed so the mix breathes with the throttle.
	var t := clampf(_ship.speed / maxf(_ship.max_speed, 1.0), 0.0, 1.0)
	var target := lerpf(cutoff_idle, cutoff_flat_out, ease(t, 0.45))
	_cutoff = lerpf(_cutoff, target, clampf(delta * cutoff_smoothing, 0.0, 1.0))
	_filter.cutoff_hz = _cutoff


## Let the soundtrack react to this ship's speed. Safe to call with null.
func attach_ship(ship: Ship) -> void:
	_ship = ship


func _exit_tree() -> void:
	# Release the streams so Godot doesn't report them as leaked at exit.
	for p in _players:
		p.stop()
		p.stream = null


func _scan() -> void:
	_library.clear()
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Exported builds list imported files as "name.ogg.import".
		var name := file.trim_suffix(".import")
		if name.get_extension() in ["ogg", "wav", "mp3"]:
			var path := MUSIC_DIR.path_join(name)
			if not _library.has(path):
				_library.append(path)
	_tracks.assign(_library)
	_tracks.shuffle()


## Narrow the shuffle to files whose names start with one of `prefixes` (a circuit's own
## music, the title's theme). An empty list means everything. If what's playing doesn't
## belong to the new playlist, crossfade to something that does.
func set_playlist(prefixes: Array) -> void:
	if prefixes == _prefixes:
		return
	_prefixes = prefixes.duplicate()
	_tracks.clear()
	for path in _library:
		var file := path.get_file()
		var wanted := prefixes.is_empty()
		for prefix in prefixes:
			if file.begins_with(prefix):
				wanted = true
		if wanted:
			_tracks.append(path)
	if _tracks.is_empty():
		_tracks.assign(_library)
	_tracks.shuffle()
	if not _tracks.has(_current):
		play_next()


func play_next() -> void:
	if _tracks.is_empty():
		return
	var path: String = _tracks.pop_front()
	_tracks.append(path)
	_current = path
	var stream := load(path) as AudioStream
	if stream == null:
		return

	var incoming := 1 - _active
	_players[incoming].stream = stream
	_players[incoming].volume_db = SILENT_DB
	_players[incoming].play()

	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel()
	_fade.tween_property(_players[incoming], ^"volume_db", volume_db, crossfade_time)
	var outgoing := _players[_active]
	if outgoing.playing:
		_fade.tween_property(outgoing, ^"volume_db", SILENT_DB, crossfade_time)
	_active = incoming
	_handover_done = false
	print("Music: ", path.get_file())


## Bring the next track in while the current one is still sounding, so the
## two actually overlap for `crossfade_time` instead of meeting at silence.
func _check_handover() -> void:
	if _handover_done or _tracks.size() < 2:
		return
	var p := _players[_active]
	if not p.playing or p.stream == null:
		return
	var length := p.stream.get_length()
	if length <= 0.0:
		return  # unknown length (streamed): fall back to the `finished` signal
	if p.get_playback_position() >= length - crossfade_time:
		_handover_done = true
		play_next()


func _on_finished(which: int) -> void:
	# Only the audible track advances the playlist; the one we faded out
	# also emits finished and must not queue a second crossfade.
	if which == _active and not _handover_done:
		play_next()


func _find_music_lowpass() -> AudioEffectLowPassFilter:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return null
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectLowPassFilter:
			return fx
	return null
