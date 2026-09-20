extends CanvasLayer

## Race HUD: holds the state, runs the timers and warning sounds. HudCanvas draws it.

# --- Set by Race
var player: Ship
var laps := 3
var center_text := "":
	set(value):
		if value != center_text:
			center_age = 0.0
		center_text = value
var position := 1
var field := 5
var position_text := ""      ## kept for callers that still set it; the canvas uses `position`
## "" or "RIGHT"/"LEFT" when the pit lane entry is coming up.
var pit_ahead := ""

# --- Read by HudCanvas
var time := 0.0
var ignite := 0.0            ## 0..1, the tubes striking on at the start
var tube_level := 1.0        ## energy tube brightness: sputters when low, blinks out when hit
var glitch := 0.0            ## 1 right after a weapon hit, decays
var item_age := 0.0
var center_age := 0.0
var status_text := ""
var status_color := Color.WHITE
var status_blink := false
var pit_side := 0.0
var flash_text := ""
var flash_color := Color.WHITE
var flash_time := 0.0
var split_text := ""
var split_faster := false
var split_age := 99.0
var help_alpha := 1.0
var help_lines := [
	"W / S   thrust, brake",
	"A / D   steer",
	"Q / E   airbrakes",
	"Space or Square   fire",
	"F or Circle   absorb for energy",
	"R or Triangle   respawn",
	"Esc or Options   pause",
]

var _canvas: HudCanvas
var _age := 0.0
var _sputter := 0.0
var _beep_time := 0.0
var _tick_time := 0.0
var _last_item := Items.NONE
var _connected := false


func _ready() -> void:
	_canvas = HudCanvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func _process(delta: float) -> void:
	time += delta
	center_age += delta
	flash_time = maxf(flash_time - delta, 0.0)
	glitch = maxf(glitch - delta * 3.0, 0.0)
	split_age += delta
	if not player:
		return
	if not _connected:
		_connected = true
		player.hit_taken.connect(func(_damage: float, _by: String, _weapon: String): glitch = 1.0)

	# The tubes strike on over the first second, the way a sign does.
	_age += delta
	ignite = 1.0 if _age > 1.1 else (1.0 if randf() < _age * 0.8 else 0.15)
	# Controls fade once the race is under way.
	if player.controls_enabled:
		help_alpha = maxf(help_alpha - delta / 6.0, 0.0) if _age > 9.0 else 1.0

	if player.item != _last_item:
		_last_item = player.item
		item_age = 0.0
	item_age += delta
	_update_status(delta)


func _update_status(delta: float) -> void:
	var ratio := player.energy / player.max_energy
	var low := ratio < 0.25 and not player.is_eliminated

	# A dying tube: mostly on, with short sputters that get more frequent as energy falls.
	_sputter -= delta
	tube_level = ignite
	if low:
		if _sputter <= 0.0 and randf() < 0.06 + (0.25 - ratio) * 0.6:
			_sputter = randf_range(0.04, 0.14)
		if _sputter > 0.0:
			tube_level = 0.2 + 0.4 * randf()
	if glitch > 0.75:
		tube_level = 0.05

	status_blink = false
	pit_side = 0.0
	if player.recharging:
		status_text = "Recharging"
		status_color = HudCanvas.GREEN
		_tick_time -= delta
		if _tick_time <= 0.0:
			_tick_time = 0.22
			Sfx.play("recharge", 0.8 + ratio * 0.8, -6.0)
	elif player.shield_time > 0.0:
		status_text = "Shield  %.1f" % player.shield_time
		status_color = Color("8fd6ff")
	elif pit_ahead != "" and ratio < 0.6:
		status_text = "Pit lane ahead, keep %s" % pit_ahead.to_lower()
		status_color = HudCanvas.GREEN
		status_blink = true
		pit_side = 1.0 if pit_ahead == "RIGHT" else -1.0
	elif low:
		status_text = "Energy low. Pit before the start line"
		status_color = HudCanvas.RED
		status_blink = true
		_beep_time -= delta
		if _beep_time <= 0.0 and player.controls_enabled:
			_beep_time = 0.9
			Sfx.play("energy_low", 1.0, -4.0)
	else:
		status_text = ""


## Short message for weapon hits and eliminations.
func flash(text: String, color := Color.WHITE) -> void:
	flash_text = text
	flash_color = color
	flash_time = 2.0


## Called by Race when the player crosses the line: shows the lap against the previous best.
func lap_completed(lap_time: float, previous_best: float) -> void:
	split_age = 0.0
	if previous_best == INF:
		split_text = UiTheme.fmt_time(lap_time)
		split_faster = true
	else:
		var diff := lap_time - previous_best
		split_faster = diff < 0.0
		split_text = "%s%.3f" % ["-" if split_faster else "+", absf(diff)]


func format_time(t: float) -> String:
	return UiTheme.fmt_time(t)
