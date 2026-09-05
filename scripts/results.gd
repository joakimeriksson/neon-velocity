class_name Results
extends CanvasLayer

## End-of-race overlay: the player's placing, time, score breakdown and the field's times.
## Stays live while the remaining AI ships finish.

var _race: Node
var _panel: PanelContainer
var _table: GridContainer
var _hint: Label
var _armed := false


func show_results(race: Node) -> void:
	_race = race
	layer = 20
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_panel = UiTheme.panel()
	box.add_child(_panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	_panel.add_child(inner)

	var r: Dictionary = Game.last_result
	inner.add_child(UiTheme.glow_label("RACE COMPLETE", 48, UiTheme.NEON))
	inner.add_child(UiTheme.label("%s  ·  %s" % [r.track, UiTheme.ordinal(r.position)], 30, UiTheme.PINK))
	inner.add_child(UiTheme.label("Time %s     Best lap %s" % [UiTheme.fmt_time(r.time), UiTheme.fmt_time(r.best_lap)], 22))

	var s: Dictionary = r.score
	var score_line := HBoxContainer.new()
	score_line.alignment = BoxContainer.ALIGNMENT_CENTER
	score_line.add_theme_constant_override("separation", 30)
	score_line.add_child(UiTheme.label("Position %d" % s.position, 20, UiTheme.DIM))
	score_line.add_child(UiTheme.label("Time bonus %d" % s.time, 20, UiTheme.DIM))
	score_line.add_child(UiTheme.label("Fast lap %d" % s.lap, 20, UiTheme.DIM))
	inner.add_child(score_line)
	inner.add_child(UiTheme.glow_label("SCORE  %d" % s.total, 44, Color.WHITE))

	_table = GridContainer.new()
	_table.columns = 4
	_table.add_theme_constant_override("h_separation", 28)
	_table.add_theme_constant_override("v_separation", 4)
	inner.add_child(_table)
	refresh()

	_hint = UiTheme.label("%s continue" % UiTheme.accept_hint(), 20, UiTheme.DIM)
	inner.add_child(_hint)
	# Swallow the button press that may still be held from racing.
	get_tree().create_timer(0.8).timeout.connect(func(): _armed = true)


func refresh() -> void:
	for c in _table.get_children():
		c.queue_free()
	var ships: Array = _race.ships.duplicate()
	ships.sort_custom(func(a, b): return _race._position_of(a) < _race._position_of(b))
	for ship in ships:
		var col := Color.WHITE if ship == _race.player else UiTheme.DIM
		_table.add_child(UiTheme.label(UiTheme.ordinal(_race._position_of(ship)), 20, col, HORIZONTAL_ALIGNMENT_RIGHT))
		_table.add_child(UiTheme.label(ship.ship_name, 20, col, HORIZONTAL_ALIGNMENT_LEFT))
		var t: String
		if ship.get_meta("dnf", false):
			t = "DNF"
		elif ship.finished:
			t = UiTheme.fmt_time(ship.finish_time)
		else:
			t = "racing..."
		_table.add_child(UiTheme.label(t, 20, col, HORIZONTAL_ALIGNMENT_RIGHT))
		_table.add_child(UiTheme.label("lap " + UiTheme.fmt_time(ship.best_lap) if ship.best_lap < INF else "", 20, col, HORIZONTAL_ALIGNMENT_LEFT))


func _unhandled_input(event: InputEvent) -> void:
	if _armed and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		Game.to_highscores()
