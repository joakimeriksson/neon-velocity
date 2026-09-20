class_name UiTheme

## Small helpers so every screen shares one neon look without a theme resource.

const NEON := Color(0.3, 0.95, 1.0)
const PINK := Color(1.0, 0.35, 0.8)
const DIM := Color(1, 1, 1, 0.5)
const PANEL := Color(0.02, 0.01, 0.04, 0.82)


static func label(text: String, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func glow_label(text: String, size: int, color: Color) -> Label:
	var l := label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(color, 0.35))
	l.add_theme_constant_override("outline_size", int(size * 0.12))
	return l


static func button(text: String, size := 26, color := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(NEON, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", style)
	return p


static func fmt_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.---"
	return "%d:%06.3f" % [int(t / 60.0), fmod(t, 60.0)]


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 not in [11, 12, 13]:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix


static func accept_hint() -> String:
	return "Cross / Enter" if Input.get_connected_joypads().size() > 0 else "Enter"


## A lit neon tube along `pts`, drawn on `item` from inside its _draw(): dark backing, two halo
## passes, the coloured glass and a white-hot core.
static func tube(item: CanvasItem, pts: PackedVector2Array, color: Color, width: float, level := 1.0) -> void:
	if pts.size() < 2:
		return
	item.draw_polyline(pts, Color(0, 0, 0, 0.4), width * 2.2, true)
	item.draw_polyline(pts, Color(color, 0.10 * level), width * 5.0, true)
	item.draw_polyline(pts, Color(color, 0.22 * level), width * 2.6, true)
	item.draw_polyline(pts, Color(color, 0.25 + 0.7 * level), width, true)
	item.draw_polyline(pts, Color(Color.WHITE.lerp(color, 0.2), 0.9 * level), width * 0.38, true)


## Unlit glass tube.
static func glass(item: CanvasItem, pts: PackedVector2Array, width: float) -> void:
	item.draw_polyline(pts, Color(0, 0, 0, 0.4), width * 1.8, true)
	item.draw_polyline(pts, Color(0.75, 0.85, 1.0, 0.16), width, true)
	item.draw_polyline(pts, Color(1, 1, 1, 0.10), width * 0.3, true)

