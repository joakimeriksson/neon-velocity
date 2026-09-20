extends CanvasLayer

var player: Ship
var laps := 3
var center_text := ""
var position_text := ""
## Set by Race each frame: "" or "RIGHT"/"LEFT" when the pit lane entry is coming up.
var pit_ahead := ""

var _speed_label: Label
var _lap_label: Label
var _center_label: Label
var _help_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _energy_label: Label
var _item_label: Label
var _status_label: Label
var _flash_label: Label
var _flash_time := 0.0
var _beep_time := 0.0
var _tick_time := 0.0
var _t := 0.0


func _ready() -> void:
	_speed_label = _make_label(64, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_lap_label = _make_label(28, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_help_label = _make_label(18, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_center_label = _make_label(96, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label.text = "W/S or Up/Down  thrust / brake\nA/D or Left/Right  steer\nQ / E  airbrakes\nSpace / Square  fire     F / Circle  absorb\nR / Triangle  respawn   Esc / Options  pause"
	_help_label.modulate = Color(1, 1, 1, 0.6)

	# Top centre, where the eyes already are: energy bar, item slot, status line, then
	# weapon hit / kill messages underneath.
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(660, 34)
	_energy_bar.show_percentage = false
	_energy_bar.max_value = 100.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.border_color = Color(1, 1, 1, 0.5)
	back.set_border_width_all(2)
	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = Color(0.2, 1.0, 0.65)
	_energy_bar.add_theme_stylebox_override("background", back)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	box.add_child(_energy_bar)
	_energy_label = _styled_label(24)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_energy_bar.add_child(_energy_label)
	_item_label = _styled_label(40)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_item_label)
	_status_label = _styled_label(34)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	_flash_label = _styled_label(40)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_flash_label)


func _process(delta: float) -> void:
	_t += delta
	_center_label.text = center_text
	_flash_time = maxf(_flash_time - delta, 0.0)
	_flash_label.modulate.a = clampf(_flash_time * 2.0, 0.0, 1.0)
	if not player:
		return
	_speed_label.text = "%d km/h" % roundi(player.speed * 3.6)
	var best := "--:--.---" if player.best_lap == INF else format_time(player.best_lap)
	_lap_label.text = "%s\nLAP %d/%d   %s\nBEST %s" % [position_text, mini(player.lap, laps), laps, format_time(player.lap_time), best]
	_update_combat(delta)


func _update_combat(delta: float) -> void:
	var ratio := player.energy / player.max_energy
	_energy_bar.value = ratio * 100.0
	_energy_label.text = "ENERGY  %d" % ceili(ratio * 100.0)
	var low := ratio < 0.25 and not player.is_eliminated
	var color := Color(0.2, 1.0, 0.65)
	if ratio < 0.5:
		color = Color(1.0, 0.8, 0.2)
	if low:
		color = Color(1.0, 0.25, 0.2) if fmod(_t, 0.5) < 0.3 else Color(0.5, 0.1, 0.1)
	if player.shield_time > 0.0:
		color = Items.COLORS[Items.SHIELD]
	_energy_fill.bg_color = color

	if player.item == Items.NONE:
		_item_label.text = "[ - ]"
		_item_label.modulate = Color(1, 1, 1, 0.35)
	else:
		_item_label.text = "[ %s ]" % Items.NAMES[player.item]
		_item_label.modulate = Items.COLORS[player.item]

	if player.recharging:
		_status_label.text = "RECHARGING"
		_status_label.modulate = Color(0.2, 1.0, 0.65)
		_tick_time -= delta
		if _tick_time <= 0.0:
			_tick_time = 0.22
			Sfx.play("recharge", 0.8 + ratio * 0.8, -6.0)
	elif player.shield_time > 0.0:
		_status_label.text = "SHIELD %.1f" % player.shield_time
		_status_label.modulate = Items.COLORS[Items.SHIELD]
	elif pit_ahead != "" and ratio < 0.6:
		# The moment it matters: say where to go, and blink so it can't be missed.
		_status_label.text = "PIT LANE AHEAD  -  KEEP %s" % pit_ahead
		_status_label.modulate = Color(0.2, 1.0, 0.65, 1.0 if fmod(_t, 0.4) < 0.28 else 0.35)
	elif low:
		_status_label.text = "ENERGY LOW  -  PIT BEFORE THE START LINE"
		_status_label.modulate = Color(1.0, 0.3, 0.25, 1.0 if fmod(_t, 0.5) < 0.3 else 0.4)
		_beep_time -= delta
		if _beep_time <= 0.0 and player.controls_enabled:
			_beep_time = 0.9
			Sfx.play("energy_low", 1.0, -4.0)
	else:
		_status_label.text = ""


## Short message for weapon hits and eliminations.
func flash(text: String, color := Color.WHITE) -> void:
	_flash_label.text = text
	_flash_label.add_theme_color_override("font_color", color)
	_flash_time = 1.8


func format_time(t: float) -> String:
	return "%d:%06.3f" % [int(t / 60.0), fmod(t, 60.0)]


func _styled_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", maxi(3, size / 10))
	return label


func _make_label(size: int, preset: int, grow_h: int, grow_v: int) -> Label:
	var label := _styled_label(size)
	# Readable against a bright daylight sky as well as the night city.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if grow_h == Control.GROW_DIRECTION_END else HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 24)
	label.grow_horizontal = grow_h
	label.grow_vertical = grow_v
	add_child(label)
	return label
