class_name HudCanvas
extends Control

## Draws the race HUD as neon glass tubes: white-hot core, coloured halo, unlit glass where
## there is no charge. Same vocabulary as the title sign and the city's billboards.
## All state comes from the owning HUD layer; this node only draws.

const CYAN := Color("4df3ff")
const MAGENTA := Color("ff3ec8")
const AMBER := Color("ffb347")
const RED := Color("ff4b3a")
const GREEN := Color("33ffa6")
const GLASS := Color(0.75, 0.85, 1.0, 0.16)

const MARGIN := 48.0
const TUBE_HALF_WIDTH := 400.0
const TUBE_SAG := 22.0      ## how far the tube's ends rise above its middle

var hud: CanvasLayer

var _base := Transform2D.IDENTITY   ## whole-HUD jitter while glitching; skews compose with it

var _semi: Font = preload("res://assets/fonts/SairaCondensed-SemiBold.ttf")
var _medium: Font = preload("res://assets/fonts/SairaCondensed-Medium.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hud == null or hud.player == null:
		_draw_center()
		return
	_base = Transform2D(0.0, Vector2(randf_range(-7, 7), randf_range(-4, 4)) * hud.glitch)
	draw_set_transform_matrix(_base)
	_draw_vignette()
	_draw_energy()
	_draw_speed()
	_draw_item()
	_draw_position()
	_draw_timing()
	_draw_messages()
	_draw_help()
	_draw_center()


# --- Instruments -------------------------------------------------------------------

func _tube_point(t: float) -> Vector2:
	var cx := size.x * 0.5
	var edge := 2.0 * t - 1.0
	return Vector2(cx + edge * TUBE_HALF_WIDTH, size.y - 96.0 - TUBE_SAG * edge * edge)


func _tube_points(from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(2, int(48.0 * (to - from)) + 2)
	for i in steps:
		pts.append(_tube_point(lerpf(from, to, float(i) / float(steps - 1))))
	return pts


func _draw_energy() -> void:
	var p: Ship = hud.player
	var ratio := clampf(p.energy / p.max_energy, 0.0, 1.0)
	var color := CYAN
	if ratio < 0.5:
		color = AMBER
	if ratio < 0.25:
		color = RED
	if p.recharging:
		color = GREEN
	if p.shield_time > 0.0:
		color = Color("8fd6ff")

	# The whole length in unlit glass, electrode caps at both ends.
	_glass(_tube_points(0.0, 1.0), 12.0)
	for end in [0.0, 1.0]:
		var c := _tube_point(end)
		draw_circle(c, 9.0, Color(0, 0, 0, 0.5))
		draw_circle(c, 6.0, Color(0.6, 0.65, 0.75, 0.7))

	if ratio > 0.005:
		_neon_line(_tube_points(0.0, ratio), color, 11.0, hud.tube_level)
	if p.recharging:
		# A bright slug of charge running up the tube.
		var head := fmod(hud.time * 1.6, 1.0) * ratio
		_neon_line(_tube_points(maxf(head - 0.06, 0.0), head), Color.WHITE.lerp(GREEN, 0.3), 13.0, 1.0)

	var label := "energy  %d" % ceili(ratio * 100.0)
	_neon_text(_medium, Vector2(size.x * 0.5, size.y - 34.0), label, 34, color, HORIZONTAL_ALIGNMENT_CENTER, maxf(hud.tube_level, 0.6))


func _draw_speed() -> void:
	var p: Ship = hud.player
	var x := size.x * 0.5 + TUBE_HALF_WIDTH + 56.0
	var baseline := size.y - 78.0
	var kmh := str(roundi(p.speed * 3.6))
	var over := p.speed > p.max_speed * 1.02
	var color := MAGENTA if over else CYAN
	_skewed(Vector2(x, baseline))
	_neon_text(_semi, Vector2(x, baseline), kmh, 118, color, HORIZONTAL_ALIGNMENT_LEFT, hud.ignite)
	var w := _semi.get_string_size(kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 118).x
	_neon_text(_medium, Vector2(x + w + 12.0, baseline), "km/h", 30, color, HORIZONTAL_ALIGNMENT_LEFT, hud.ignite * 0.8)
	draw_set_transform_matrix(_base)

	# Thrust ticks: one short tube per 5% of top speed, the overdrive ones in magenta.
	var ticks := 26
	var ratio := p.speed / p.max_speed
	for i in ticks:
		var tx := x + 4.0 + i * 12.0
		var lit := float(i) / 20.0 < ratio
		var seg := PackedVector2Array([Vector2(tx + 5.0, size.y - 58.0), Vector2(tx, size.y - 36.0)])
		if lit:
			_neon_line(seg, MAGENTA if i >= 20 else CYAN, 3.5, hud.ignite)
		elif i < 20:
			_glass(seg, 3.5)


func _draw_item() -> void:
	var p: Ship = hud.player
	var center := Vector2(size.x * 0.5 - TUBE_HALF_WIDTH - 110.0, size.y - 112.0)
	if p.item == Items.NONE:
		draw_arc(center, 40.0, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 8.0, true)
		draw_arc(center, 40.0, 0.0, TAU, 48, GLASS, 4.0, true)
		return
	var color: Color = Items.COLORS[p.item]
	# A new pickup strikes on with a flicker.
	var level := 1.0 if hud.item_age > 0.35 else (1.0 if randf() < hud.item_age * 3.0 else 0.2)
	_neon_arc(center, 40.0, color, 4.0, level)
	for stroke in _icon(p.item):
		var pts := PackedVector2Array()
		for v in stroke:
			pts.append(center + v)
		_neon_line(pts, color, 4.5, level)
	if p.item == Items.MINE:
		for dx in [-18.0, 0.0, 18.0]:
			_neon_arc(center + Vector2(dx, 0), 5.0, color, 3.5, level)
	_neon_text(_medium, Vector2(center.x, size.y - 34.0), Items.NAMES[p.item].capitalize(), 34, color, HORIZONTAL_ALIGNMENT_CENTER, level)


## Icon strokes in a 60 px box around the origin.
func _icon(item: int) -> Array:
	match item:
		Items.ROCKET:
			return [[Vector2(-22, 0), Vector2(20, 0)], [Vector2(8, -11), Vector2(22, 0), Vector2(8, 11)], [Vector2(-22, -9), Vector2(-14, 0), Vector2(-22, 9)]]
		Items.MISSILE:
			return [[Vector2(-22, 8), Vector2(14, -8)], [Vector2(2, -13), Vector2(18, -10), Vector2(12, 5)], [Vector2(-8, 18), Vector2(8, 18)], [Vector2(0, 10), Vector2(0, 24)]]
		Items.SHIELD:
			return [[Vector2(0, -24), Vector2(20, -13), Vector2(16, 10), Vector2(0, 24), Vector2(-16, 10), Vector2(-20, -13), Vector2(0, -24)]]
		Items.TURBO:
			return [[Vector2(-20, -16), Vector2(-2, 0), Vector2(-20, 16)], [Vector2(0, -16), Vector2(18, 0), Vector2(0, 16)]]
	return []


func _draw_position() -> void:
	var origin := Vector2(MARGIN + 8.0, 168.0)
	var numeral := str(hud.position)
	_skewed(origin)
	_neon_text(_semi, origin, numeral, 150, MAGENTA, HORIZONTAL_ALIGNMENT_LEFT, hud.ignite)
	var w := _semi.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 150).x
	_neon_text(_medium, origin + Vector2(w + 12.0, -62.0), UiTheme.ordinal(hud.position).substr(numeral.length()), 44, MAGENTA, HORIZONTAL_ALIGNMENT_LEFT, hud.ignite)
	_neon_text(_medium, origin + Vector2(w + 12.0, -12.0), "of %d" % hud.field, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, hud.ignite * 0.75)
	draw_set_transform_matrix(_base)


func _draw_timing() -> void:
	var p: Ship = hud.player
	var right := size.x - MARGIN
	_neon_text(_medium, Vector2(right, 72.0), "Lap %d of %d" % [clampi(p.lap, 1, hud.laps), hud.laps], 36, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, hud.ignite * 0.85)
	_digits(Vector2(right, 140.0), UiTheme.fmt_time(p.lap_time), 66, CYAN, hud.ignite)
	if p.best_lap < INF:
		_neon_text(_medium, Vector2(right - 226.0, 184.0), "best", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 0.7)
		_digits(Vector2(right, 184.0), UiTheme.fmt_time(p.best_lap), 32, Color.WHITE, 0.8)
	if hud.split_age < 4.0 and hud.split_text != "":
		var fade := clampf(4.0 - hud.split_age, 0.0, 1.0)
		_digits(Vector2(right, 226.0), hud.split_text, 34, GREEN if hud.split_faster else AMBER, fade)


func _draw_messages() -> void:
	var cx := size.x * 0.5
	if hud.status_text != "":
		var level: float = 1.0 if not hud.status_blink or fmod(hud.time, 0.42) < 0.3 else 0.3
		var board_w := _semi.get_string_size(hud.status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + (220.0 if hud.pit_side != 0.0 else 72.0)
		_backing_board(Rect2(cx - board_w * 0.5, 68.0, board_w, 68.0))
		_neon_text(_semi, Vector2(cx, 118.0), hud.status_text, 46, hud.status_color, HORIZONTAL_ALIGNMENT_CENTER, level)
		if hud.pit_side != 0.0:
			# Chevrons marching toward the lane.
			var w := _semi.get_string_size(hud.status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
			for i in 3:
				var phase := fmod(hud.time * 2.5 - i * 0.33, 1.0)
				var x: float = cx + hud.pit_side * (w * 0.5 + 40.0 + i * 30.0)
				var d: float = 12.0 * hud.pit_side
				_neon_line(PackedVector2Array([Vector2(x - d, 86.0), Vector2(x + d, 102.0), Vector2(x - d, 118.0)]), GREEN, 4.5, 0.25 + 0.75 * (1.0 - phase))
	if hud.flash_time > 0.0:
		var flash_w := _semi.get_string_size(hud.flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x + 64.0
		_backing_board(Rect2(cx - flash_w * 0.5, 142.0, flash_w, 56.0), clampf(hud.flash_time * 2.0, 0.0, 1.0))
		_neon_text(_semi, Vector2(cx, 182.0), hud.flash_text, 42, hud.flash_color, HORIZONTAL_ALIGNMENT_CENTER, clampf(hud.flash_time * 2.0, 0.0, 1.0))


func _draw_help() -> void:
	if hud.help_alpha <= 0.01:
		return
	var y := 300.0
	for line in hud.help_lines:
		draw_string_outline(_medium, Vector2(MARGIN, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.5 * hud.help_alpha))
		draw_string(_medium, Vector2(MARGIN, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.75 * hud.help_alpha))
		y += 32.0


func _draw_center() -> void:
	if hud == null or hud.center_text == "":
		return
	var text: String = hud.center_text
	var big := text.length() <= 2
	var px := 300 if big else 110
	var color := GREEN if text == "Go" else (RED if text == "Eliminated" else (MAGENTA if big else CYAN))
	# Numerals strike on: a few frames of sputter, then steady.
	var level: float = 1.0 if hud.center_age > 0.18 else (1.0 if randf() < 0.5 else 0.25)
	# Above the ship, not on top of it.
	_neon_text(_semi, Vector2(size.x * 0.5, size.y * 0.34 + px * 0.3), text, px, color, HORIZONTAL_ALIGNMENT_CENTER, level)


## Red at the edges after a weapon hit, green while recharging.
func _draw_vignette() -> void:
	var p: Ship = hud.player
	var amount: float = hud.glitch * 0.55
	var color := RED
	if amount < 0.02 and p.recharging:
		amount = 0.16 + 0.06 * sin(hud.time * 9.0)
		color = GREEN
	if amount < 0.02:
		return
	var depth := size.y * 0.22
	var outer := Color(color, amount)
	var inner := Color(color, 0.0)
	var w := size.x
	var h := size.y
	var quads := [
		[Vector2(0, 0), Vector2(w, 0), Vector2(w, depth), Vector2(0, depth)],
		[Vector2(0, h), Vector2(w, h), Vector2(w, h - depth), Vector2(0, h - depth)],
		[Vector2(0, 0), Vector2(0, h), Vector2(depth, h), Vector2(depth, 0)],
		[Vector2(w, 0), Vector2(w, h), Vector2(w - depth, h), Vector2(w - depth, 0)],
	]
	for q in quads:
		draw_polygon(PackedVector2Array(q), PackedColorArray([outer, outer, inner, inner]))


# --- Neon primitives ---------------------------------------------------------------

## A lit tube: dark backing so it reads against a daylight sky, two halo passes, the coloured
## glass, then the white-hot core.
func _neon_line(pts: PackedVector2Array, color: Color, width: float, level := 1.0) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0, 0, 0, 0.4), width * 2.2, true)
	draw_polyline(pts, Color(color, 0.10 * level), width * 5.0, true)
	draw_polyline(pts, Color(color, 0.22 * level), width * 2.6, true)
	draw_polyline(pts, Color(color, 0.25 + 0.7 * level), width, true)
	draw_polyline(pts, Color(Color.WHITE.lerp(color, 0.2), 0.9 * level), width * 0.38, true)
	for c in [pts[0], pts[pts.size() - 1]]:
		draw_circle(c, width * 0.5, Color(color, 0.25 + 0.7 * level))


func _neon_arc(center: Vector2, radius: float, color: Color, width: float, level := 1.0) -> void:
	draw_arc(center, radius, 0.0, TAU, 48, Color(0, 0, 0, 0.4), width * 2.2, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.10 * level), width * 5.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.22 * level), width * 2.6, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.25 + 0.7 * level), width, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color(Color.WHITE.lerp(color, 0.2), 0.9 * level), width * 0.38, true)


## The dark board a sign is mounted on, so messages stay readable against a daylight sky.
func _backing_board(rect: Rect2, alpha := 1.0) -> void:
	var board := StyleBoxFlat.new()
	board.bg_color = Color(0.02, 0.03, 0.06, 0.55 * alpha)
	board.set_corner_radius_all(int(rect.size.y * 0.5))
	board.border_color = Color(1, 1, 1, 0.10 * alpha)
	board.set_border_width_all(2)
	draw_style_box(board, rect)


## Unlit glass.
func _glass(pts: PackedVector2Array, width: float) -> void:
	draw_polyline(pts, Color(0, 0, 0, 0.4), width * 1.8, true)
	draw_polyline(pts, GLASS, width, true)
	draw_polyline(pts, Color(1, 1, 1, 0.10), width * 0.3, true)


func _neon_text(font: Font, pos: Vector2, text: String, px: int, color: Color, align: HorizontalAlignment, level := 1.0) -> void:
	var at := pos
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		at.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x -= w
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(5, int(px * 0.2)), Color(0, 0, 0, 0.6))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(6, int(px * 0.34)), Color(color, 0.09 * level))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(3, int(px * 0.12)), Color(color, 0.30 * level))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Color.WHITE.lerp(color, 0.45), 0.2 + 0.8 * level))


## Right-aligned time with every digit in a fixed cell, so the numbers don't shimmy as they change.
func _digits(right: Vector2, text: String, px: int, color: Color, level := 1.0) -> void:
	var cell := px * 0.52
	var x := right.x
	for i in range(text.length() - 1, -1, -1):
		var ch := text[i]
		var advance := cell if ch.is_valid_int() else cell * 0.5
		x -= advance
		_neon_text(_semi, Vector2(x + advance * 0.5, right.y), ch, px, color, HORIZONTAL_ALIGNMENT_CENTER, level)


## Slant what follows forward, pivoting on `pivot`'s baseline. Reset with `_base`.
func _skewed(pivot: Vector2) -> void:
	var k := 0.16
	draw_set_transform_matrix(_base * Transform2D(Vector2(1, 0), Vector2(-k, 1), Vector2(k * pivot.y, 0)))
