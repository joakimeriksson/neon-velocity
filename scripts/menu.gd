extends Control

## Track select. Number keys or buttons; Esc quits.

var _buttons: Array[Button] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "AG RACER"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "select circuit"
	sub.add_theme_font_size_override("font_size", 22)
	sub.modulate = Color(1, 1, 1, 0.5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	for i in TrackDefs.ALL.size():
		var def := TrackDefs.ALL[i]
		var b := Button.new()
		b.text = "%d   %s\n%s" % [i + 1, def.name, def.blurb]
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", def.neon)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.custom_minimum_size = Vector2(760, 90)
		b.pressed.connect(Game.start_race.bind(i))
		box.add_child(b)
		_buttons.append(b)

	var hint := Label.new()
	hint.text = "1 / 2 / 3 to start      Esc quit"
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_buttons[Game.track_index].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k < KEY_1 + TrackDefs.ALL.size():
			Game.start_race(k - KEY_1)
		elif k == KEY_ESCAPE:
			get_tree().quit()
