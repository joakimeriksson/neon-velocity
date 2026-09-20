class_name SettingsMenu
extends OverlayMenu

## Volumes, video and comfort options. Changes apply at once and are saved on the way out.

var _rows := {}   # settings key -> SettingRow
var _blip: AudioStreamPlayer
var _blip_quiet := 0.0


func _heading() -> String:
	return "Settings"


func _build(box: VBoxContainer) -> Control:
	_section(box, "Sound")
	var first := _slider(box, "Master volume", "audio/master", UiTheme.NEON)
	_slider(box, "Music", "audio/music", UiTheme.PINK)
	_slider(box, "Effects", "audio/effects", HudCanvas.AMBER)
	_slider(box, "Engines", "audio/engines", HudCanvas.GREEN)
	_section(box, "Picture")
	if not OS.has_feature("web"):
		_toggle(box, "Fullscreen", "video/fullscreen")
	var names := []
	for q in Settings.QUALITY:
		names.append(q[0])
	var quality := SettingRow.choice("3D resolution", names, Settings.current_quality())
	quality.value_changed.connect(func(v): Settings.set_value("video/quality", int(v)))
	box.add_child(quality)
	_rows["video/quality"] = quality
	_section(box, "Driving")
	_toggle(box, "Controller rumble", "game/rumble")
	_toggle(box, "Camera shake", "game/camera_shake")
	_toggle(box, "Show controls at the start", "game/show_controls")

	var reset := UiTheme.button("Reset to defaults", 22, UiTheme.DIM)
	reset.custom_minimum_size = Vector2(300, 46)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_reset)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	box.add_child(reset)

	# A sound to judge the effects level by; it has to play while the game is paused.
	_blip = AudioStreamPlayer.new()
	_blip.bus = &"SFX"
	_blip.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_blip.volume_db = Sfx.volume_db
	_blip.stream = Sfx._stream_for("pickup")
	add_child(_blip)
	return first


func _process(delta: float) -> void:
	_blip_quiet -= delta


func _section(box: VBoxContainer, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	box.add_child(UiTheme.label(title.to_upper(), 18, UiTheme.PINK, HORIZONTAL_ALIGNMENT_LEFT))


func _slider(box: VBoxContainer, title: String, key: String, tint: Color) -> SettingRow:
	var row := SettingRow.slider(title, Settings.get_value(key), tint)
	row.value_changed.connect(func(v):
		Settings.set_value(key, float(v))
		if key in ["audio/effects", "audio/master"] and _blip_quiet <= 0.0 and _blip.stream:
			_blip_quiet = 0.3
			_blip.play())
	box.add_child(row)
	_rows[key] = row
	return row


func _toggle(box: VBoxContainer, title: String, key: String) -> void:
	var row := SettingRow.choice(title, ["Off", "On"], 1 if Settings.get_value(key) else 0)
	row.value_changed.connect(func(v): Settings.set_value(key, int(v) == 1))
	box.add_child(row)
	_rows[key] = row


func _reset() -> void:
	Settings.reset()
	for key in _rows:
		var row: SettingRow = _rows[key]
		if key == "video/quality":
			row.value = Settings.current_quality()
		elif row.options.is_empty():
			row.value = float(Settings.get_value(key))
		else:
			row.value = 1 if Settings.get_value(key) else 0
		row.queue_redraw()


func _closing() -> void:
	Settings.save()
