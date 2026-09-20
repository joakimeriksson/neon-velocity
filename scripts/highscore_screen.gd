extends Node

## High-score table per circuit. If Game.last_result qualifies, starts with arcade-style
## three-letter initials entry (Up/Down change letter, Left/Right move, Cross/Enter confirm; keys type).

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "

var _ui: CanvasLayer
var _entry_box: VBoxContainer
var _table_box: VBoxContainer
var _letter_labels: Array[Label] = []
var _initials := [0, 0, 0]
var _cursor := 0
var _entering := false
var _track := 0
var _highlight := -1
var _table_title: Label
var _grid: GridContainer
var _t := 0.0


func _ready() -> void:
	_track = Game.track_index
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(bg)

	_entry_box = _box()
	_table_box = _box()
	_build_entry()
	_build_table()

	var r: Dictionary = Game.last_result
	_entering = not r.is_empty() and int(r.score.total) > 0 and Highscores.qualifies(r.track, int(r.score.total))
	_entry_box.visible = _entering
	_table_box.visible = not _entering
	if not _entering and not r.is_empty():
		Game.last_result = {}


func _process(delta: float) -> void:
	_t += delta
	if _entering:
		for i in 3:
			_letter_labels[i].modulate.a = 1.0 if i != _cursor else 0.5 + 0.5 * absf(sin(_t * 4.0))


func _build_entry() -> void:
	var r: Dictionary = Game.last_result
	_entry_box.add_child(UiTheme.glow_label("NEW HIGH SCORE", 64, UiTheme.PINK))
	if not r.is_empty():
		_entry_box.add_child(UiTheme.label("%s  ·  %s  ·  %d points" % [r.track, UiTheme.ordinal(r.position), r.score.total], 26))
	_entry_box.add_child(UiTheme.label("enter your initials", 20, UiTheme.DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	for i in 3:
		var l := UiTheme.glow_label("A", 120, UiTheme.NEON)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		_letter_labels.append(l)
	_entry_box.add_child(row)
	_entry_box.add_child(UiTheme.label("Up/Down letter    Left/Right move    %s confirm" % UiTheme.accept_hint(), 18, UiTheme.DIM))


func _build_table() -> void:
	_table_title = UiTheme.glow_label("", 56, UiTheme.NEON)
	_table_box.add_child(_table_title)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 36)
	_grid.add_theme_constant_override("v_separation", 6)
	_table_box.add_child(_grid)
	_table_box.add_child(UiTheme.label("Left/Right / L1 R1 circuit      %s / Circle title" % UiTheme.accept_hint(), 18, UiTheme.DIM))
	_refresh_table()


func _refresh_table() -> void:
	var def := TrackDefs.ALL[_track]
	_table_title.text = "HIGH SCORES  ·  " + def.name
	_table_title.add_theme_color_override("font_color", def.neon)
	for c in _grid.get_children():
		c.queue_free()
	for h in ["#", "NAME", "SCORE", "TIME", "BEST LAP"]:
		_grid.add_child(UiTheme.label(h, 18, UiTheme.DIM))
	var rows: Array = Highscores.top(def.name)
	for i in Highscores.MAX_ENTRIES:
		var col := Color.WHITE
		if i == _highlight:
			col = UiTheme.PINK
		elif i >= rows.size():
			col = Color(1, 1, 1, 0.25)
		var e: Dictionary = rows[i] if i < rows.size() else {}
		_grid.add_child(UiTheme.label(str(i + 1), 24, col, HORIZONTAL_ALIGNMENT_RIGHT))
		_grid.add_child(UiTheme.label(e.get("name", "---"), 24, col, HORIZONTAL_ALIGNMENT_LEFT))
		_grid.add_child(UiTheme.label(str(int(e.get("score", 0))) if e else "---", 24, col, HORIZONTAL_ALIGNMENT_RIGHT))
		_grid.add_child(UiTheme.label(UiTheme.fmt_time(float(e.get("time", 0.0))), 24, col, HORIZONTAL_ALIGNMENT_RIGHT))
		_grid.add_child(UiTheme.label(UiTheme.fmt_time(float(e.get("best_lap", 0.0))), 24, col, HORIZONTAL_ALIGNMENT_RIGHT))


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_pressed() and not event.is_echo()):
		return
	if _entering:
		_entry_input(event)
	else:
		if event.is_action("ui_left") or event.is_action("airbrake_left"):
			_track = posmod(_track - 1, TrackDefs.ALL.size())
			_highlight = -1
			_refresh_table()
		elif event.is_action("ui_right") or event.is_action("airbrake_right"):
			_track = posmod(_track + 1, TrackDefs.ALL.size())
			_highlight = -1
			_refresh_table()
		elif event.is_action("ui_accept") or event.is_action("ui_cancel") or event.is_action("pause"):
			Game.to_title()


func _entry_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: int = event.keycode
		if k >= KEY_A and k <= KEY_Z:
			_initials[_cursor] = k - KEY_A
			_cursor = mini(_cursor + 1, 2)
			_update_letters()
			return
		if k == KEY_BACKSPACE:
			_cursor = maxi(_cursor - 1, 0)
			_update_letters()
			return
	if event.is_action("ui_up"):
		_initials[_cursor] = posmod(_initials[_cursor] - 1, LETTERS.length())
	elif event.is_action("ui_down"):
		_initials[_cursor] = posmod(_initials[_cursor] + 1, LETTERS.length())
	elif event.is_action("ui_left"):
		_cursor = maxi(_cursor - 1, 0)
	elif event.is_action("ui_right"):
		_cursor = mini(_cursor + 1, 2)
	elif event.is_action("ui_accept"):
		if _cursor < 2:
			_cursor += 1
		else:
			_submit()
			return
	_update_letters()
	Sfx.play("countdown_tick", 1.5, -8.0)


func _update_letters() -> void:
	for i in 3:
		_letter_labels[i].text = LETTERS[_initials[i]]


func _submit() -> void:
	var r: Dictionary = Game.last_result
	var name := ""
	for i in 3:
		name += LETTERS[_initials[i]]
	_highlight = Highscores.add(r.track, {
		"name": name.strip_edges(),
		"score": int(r.score.total),
		"time": r.time,
		"best_lap": r.best_lap,
		"position": r.position,
	})
	Game.last_result = {}
	_entering = false
	_entry_box.visible = false
	_table_box.visible = true
	_refresh_table()
	Sfx.play("finish")


func _box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_ui.add_child(box)
	return box
