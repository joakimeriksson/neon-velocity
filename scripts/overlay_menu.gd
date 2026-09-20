class_name OverlayMenu
extends CanvasLayer

## Base for full-screen overlays opened from another menu (settings, credits): dims what's
## behind, centres a panel, and closes on Back, Circle or Esc. Works while the game is paused.
## Subclasses override _heading() and _build().

var _on_close := Callable()
var _back: Button
var _centre: CenterContainer
var _child_open := false


func _init() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


## Add the overlay under `parent`; `on_close` runs after it has gone (restore focus there).
func show_over(parent: Node, on_close := Callable()) -> void:
	_on_close = on_close
	parent.add_child(self)


func _heading() -> String:
	return ""


## Fill `box`; return the control that should start with focus (or null for Back).
func _build(_box: VBoxContainer) -> Control:
	return null


func _closing() -> void:
	pass


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_centre = CenterContainer.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_centre)
	var panel := UiTheme.panel()
	_centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.glow_label(_heading(), 52, UiTheme.NEON))
	var first := _build(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	_back = UiTheme.button("Back", 26)
	_back.custom_minimum_size = Vector2(300, 52)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	box.add_child(_back)
	box.add_child(UiTheme.label("Circle / Esc back", 18, UiTheme.DIM))
	_trap_focus(box)
	(first if first else _back).grab_focus.call_deferred()


## Up from the first control wraps to the last and the other way round, and nothing leads
## sideways out of the panel, so focus can't wander onto the menu underneath.
func _trap_focus(box: VBoxContainer) -> void:
	var stops: Array[Control] = []
	for c in box.find_children("*", "Control", true, false):
		if c.focus_mode == Control.FOCUS_ALL:
			stops.append(c)
	for i in stops.size():
		var c := stops[i]
		c.focus_neighbor_top = c.get_path_to(stops[(i - 1 + stops.size()) % stops.size()])
		c.focus_neighbor_bottom = c.get_path_to(stops[(i + 1) % stops.size()])
		if c.focus_neighbor_left.is_empty():
			c.focus_neighbor_left = c.get_path_to(c)
		if c.focus_neighbor_right.is_empty():
			c.focus_neighbor_right = c.get_path_to(c)


## Open another overlay on top of this one; this one hides until it closes.
func open_child(menu: OverlayMenu, opener: Control) -> void:
	_child_open = true
	_centre.visible = false
	menu.layer = layer + 1
	menu.show_over(self, func():
		_child_open = false
		_centre.visible = true
		opener.grab_focus())


func close() -> void:
	_closing()
	queue_free()
	if _on_close.is_valid():
		_on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if _child_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
