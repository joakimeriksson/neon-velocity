extends Node

## Title screen and circuit select, drawn over an attract-mode race (the AI drives).

enum Page { TITLE, SELECT }

var page := Page.TITLE
var _ui: CanvasLayer
var _title_box: VBoxContainer
var _select_box: VBoxContainer
var _pad_label: Label
var _press_start: Label
var _logo: TextureRect
var _flicker_t := 0.0
var _buttons: Array[Button] = []
var _t := 0.0


func _ready() -> void:
	Game.attract = true
	Game.track_index = randi() % TrackDefs.ALL.size()
	add_child(load("res://scenes/main.tscn").instantiate())

	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)

	_title_box = _centered_box()
	# The neon sign carries the name and the league strapline.
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/ui/neon-velocity-neon-sign.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(1180, 472)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_box.add_child(_logo)
	_title_box.add_child(_spacer(40))
	_press_start = UiTheme.label("PRESS START", 34, Color.WHITE)
	_title_box.add_child(_press_start)
	_title_box.add_child(_spacer(120))
	_pad_label = UiTheme.label("", 18, UiTheme.DIM)
	_title_box.add_child(_pad_label)

	_select_box = _centered_box()
	_select_box.add_child(UiTheme.glow_label("SELECT CIRCUIT", 56, UiTheme.NEON))
	_select_box.add_child(_spacer(20))
	for i in TrackDefs.ALL.size():
		var def := TrackDefs.ALL[i]
		var b := UiTheme.button("%d   %s\n%s" % [i + 1, def.name, def.blurb], 26, def.neon)
		b.custom_minimum_size = Vector2(820, 92)
		b.pressed.connect(Game.start_race.bind(i))
		_select_box.add_child(b)
		_buttons.append(b)
	var hs := UiTheme.button("High scores", 22, UiTheme.DIM)
	hs.custom_minimum_size = Vector2(820, 50)
	hs.pressed.connect(Game.to_highscores)
	_select_box.add_child(hs)
	_buttons.append(hs)
	_select_box.add_child(_spacer(10))
	_select_box.add_child(UiTheme.label("Up/Down / D-pad select     %s start     Circle / Esc back" % UiTheme.accept_hint(), 18, UiTheme.DIM))

	Input.joy_connection_changed.connect(func(_d, _c): _update_pad())
	_update_pad()
	_show_page(Page.TITLE)


func _process(delta: float) -> void:
	_t += delta
	_press_start.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
	# Neon flicker: mostly steady, with an occasional short stutter and a slow breathe.
	_flicker_t -= delta
	var level := 0.92 + 0.08 * sin(_t * 1.7)
	if _flicker_t <= 0.0:
		if randf() < 0.012:
			_flicker_t = randf_range(0.04, 0.12)
		level = 0.55 if _flicker_t > 0.0 else level
	elif _flicker_t > 0.0:
		level = 0.55 + 0.35 * randf()
	_logo.modulate = Color(level, level, level, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	match page:
		Page.TITLE:
			if event.is_action("ui_cancel"):
				get_tree().quit()
			else:
				_show_page(Page.SELECT)
				get_viewport().set_input_as_handled()
		Page.SELECT:
			if event.is_action("ui_cancel"):
				_show_page(Page.TITLE)
				get_viewport().set_input_as_handled()
			elif event is InputEventKey:
				var k: int = event.physical_keycode
				if k >= KEY_1 and k < KEY_1 + TrackDefs.ALL.size():
					Game.start_race(k - KEY_1)


func _show_page(p: Page) -> void:
	page = p
	_title_box.visible = p == Page.TITLE
	_select_box.visible = p == Page.SELECT
	if p == Page.SELECT:
		_buttons[0].grab_focus()


func _update_pad() -> void:
	var pad := Game.controller_name()
	_pad_label.text = "%s connected" % pad if pad != "" else "Keyboard: W/S thrust, A/D steer, Q/E airbrakes   ·   plug in a PlayStation controller for the full experience"


func _centered_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_ui.add_child(box)
	return box


static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
