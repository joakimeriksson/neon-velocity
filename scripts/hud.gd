extends CanvasLayer

var player: Ship
var laps := 3
var center_text := ""
var position_text := ""

var _speed_label: Label
var _lap_label: Label
var _center_label: Label
var _help_label: Label


func _ready() -> void:
	_speed_label = _make_label(64, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_lap_label = _make_label(28, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_help_label = _make_label(18, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_center_label = _make_label(96, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label.text = "W/S or ↑/↓  thrust / brake\nA/D or ←/→  steer\nQ / E  airbrakes\nR / △  respawn   Esc / Options  pause"
	_help_label.modulate = Color(1, 1, 1, 0.6)


func _process(_delta: float) -> void:
	_center_label.text = center_text
	if not player:
		return
	_speed_label.text = "%d km/h" % roundi(player.speed * 3.6)
	var best := "--:--.---" if player.best_lap == INF else format_time(player.best_lap)
	_lap_label.text = "%s\nLAP %d/%d   %s\nBEST %s" % [position_text, mini(player.lap, laps), laps, format_time(player.lap_time), best]


func format_time(t: float) -> String:
	return "%d:%06.3f" % [int(t / 60.0), fmod(t, 60.0)]


func _make_label(size: int, preset: int, grow_h: int, grow_v: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if grow_h == Control.GROW_DIRECTION_END else HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 24)
	label.grow_horizontal = grow_h
	label.grow_vertical = grow_v
	add_child(label)
	return label
