class_name SettingRow
extends Control

## One row of the settings screen, drawn as neon: a label, then either a tube slider or a
## choice with arrows. Left / right changes the value (keyboard, D-pad, stick); the mouse can
## click or drag the tube and click the arrows. Up / down moves between rows as usual.

signal value_changed(value)

const HEIGHT := 58.0

var text := ""
var color := UiTheme.NEON
var options: Array = []       ## empty = slider (value 0..1), else a choice (value = index)
var value = 0.0
var step := 0.05

var _font: Font = preload("res://assets/fonts/SairaCondensed-Medium.ttf")
var _dragging := false


static func slider(label: String, start: float, tint := UiTheme.NEON) -> SettingRow:
	var row := SettingRow.new()
	row.text = label
	row.value = start
	row.color = tint
	return row


static func choice(label: String, choices: Array, start: int, tint := UiTheme.NEON) -> SettingRow:
	var row := SettingRow.new()
	row.text = label
	row.options = choices
	row.value = start
	row.color = tint
	return row


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(860, HEIGHT)
	mouse_entered.connect(grab_focus)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _tube_rect() -> Rect2:
	return Rect2(330.0, size.y * 0.5 - 6.0, size.x - 330.0 - 110.0, 12.0)


func _nudge(direction: int) -> void:
	if options.is_empty():
		_assign(clampf(snappedf(float(value) + step * direction, step), 0.0, 1.0))
	else:
		_assign(posmod(int(value) + direction, options.size()))


func _assign(v) -> void:
	if v == value:
		return
	value = v
	queue_redraw()
	value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		_nudge(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		_nudge(1)
		accept_event()
	elif event.is_action_pressed("ui_accept") and not options.is_empty():
		_nudge(1)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if options.is_empty():
			_dragging = event.pressed
			if event.pressed:
				_drag_to(event.position.x)
		elif event.pressed:
			_nudge(-1 if event.position.x < size.x * 0.72 else 1)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_to(event.position.x)
		accept_event()


func _drag_to(x: float) -> void:
	var tube := _tube_rect()
	_assign(clampf(snappedf((x - tube.position.x) / tube.size.x, step), 0.0, 1.0))


func _draw() -> void:
	var focused := has_focus()
	var level := 1.0 if focused else 0.55
	if focused:
		var board := StyleBoxFlat.new()
		board.bg_color = Color(color, 0.08)
		board.border_color = Color(color, 0.5)
		board.set_border_width_all(2)
		board.set_corner_radius_all(8)
		draw_style_box(board, Rect2(Vector2.ZERO, size))
	var baseline := size.y * 0.5 + 10.0
	draw_string(_font, Vector2(22.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.95 if focused else 0.7))

	if options.is_empty():
		var tube := _tube_rect()
		var y := tube.position.y + tube.size.y * 0.5
		var from := Vector2(tube.position.x, y)
		var to := Vector2(tube.end.x, y)
		UiTheme.glass(self, PackedVector2Array([from, to]), 10.0)
		var v := float(value)
		if v > 0.001:
			UiTheme.tube(self, PackedVector2Array([from, from.lerp(to, v)]), color, 9.0, level)
		draw_circle(from.lerp(to, v), 9.0 if focused else 7.0, Color.WHITE if focused else Color(1, 1, 1, 0.7))
		var shown := "Off" if v <= 0.001 else str(roundi(v * 100.0))
		draw_string(_font, Vector2(size.x - 92.0, baseline), shown, HORIZONTAL_ALIGNMENT_RIGHT, 70, 30, Color(Color.WHITE.lerp(color, 0.4), 0.5 + 0.5 * level))
	else:
		var label: String = str(options[int(value)])
		var centre := 330.0 + (size.x - 330.0 - 22.0) * 0.5
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(_font, Vector2(centre - w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(Color.WHITE.lerp(color, 0.4), 0.5 + 0.5 * level))
		if focused:
			var y := size.y * 0.5
			for side in [-1.0, 1.0]:
				var x: float = centre + side * 170.0
				UiTheme.tube(self, PackedVector2Array([Vector2(x - side * 9.0, y - 11.0), Vector2(x + side * 5.0, y), Vector2(x - side * 9.0, y + 11.0)]), color, 3.5, 1.0)
