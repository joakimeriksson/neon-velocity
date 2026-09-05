class_name PauseMenu
extends CanvasLayer

## Esc / Options: pause with resume, restart, quit to title.

var _box: VBoxContainer
var _resume: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	_box.add_child(UiTheme.glow_label("PAUSED", 64, UiTheme.NEON))
	_resume = _add("Resume", func(): set_paused(false))
	_add("Restart race", func(): Game.start_race(Game.track_index))
	_add("Quit to title", Game.to_title)
	_box.add_child(UiTheme.label("○ / Esc resume", 18, UiTheme.DIM))


func _add(text: String, on_pressed: Callable) -> Button:
	var b := UiTheme.button(text, 28)
	b.custom_minimum_size = Vector2(420, 56)
	b.pressed.connect(on_pressed)
	_box.add_child(b)
	return b


func set_paused(paused: bool) -> void:
	visible = paused
	get_tree().paused = paused
	if paused:
		_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		set_paused(false)
