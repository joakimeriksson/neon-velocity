class_name LicencesMenu
extends OverlayMenu

## Licence texts and third-party notices, assembled at runtime so they match the build:
## the game's own licence, Godot's licence and the components it bundles (from the engine
## itself), the crates gamesynth is built from, and the font's licence.
## Up / Down, the D-pad or the stick scroll it.

const GAME := "Neon Velocity\\nCopyright (c) 2026 Joakim Eriksson\\n\\nThe game's code is released under the MIT licence. The ship models, logo and soundtrack were generated with AI tools for this project and are part of the game, not a reusable asset pack."

var _scroll: ScrollContainer
var _speed := 0.0


func _heading() -> String:
	return "Licences"


func _build(box: VBoxContainer) -> Control:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(1040, 560)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_font_size_override("bold_font_size", 24)
	text.add_theme_color_override("default_color", Color(1, 1, 1, 0.8))
	text.text = _compose()
	_scroll.add_child(text)
	box.add_child(UiTheme.label("Up / Down scroll", 18, UiTheme.DIM))
	return null


func _process(delta: float) -> void:
	var push := Input.get_axis("ui_up", "ui_down")
	_speed = lerpf(_speed, push * 1400.0, minf(10.0 * delta, 1.0))
	if absf(_speed) > 1.0:
		_scroll.scroll_vertical += int(_speed * delta)


func _compose() -> String:
	var out := PackedStringArray()
	out.append(_title("Neon Velocity"))
	out.append(GAME.replace("\\n", "\n"))

	out.append(_title("Godot Engine"))
	out.append(Engine.get_license_text())

	out.append(_title("Components bundled with Godot Engine"))
	var used := {}
	for component in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in component.parts:
			for holder in part.copyright:
				lines.append("(c) " + holder)
			lines.append("Licence: " + part.license)
			for id in part.license.replace(" and ", " ").replace(" or ", " ").split(" ", false):
				used[id] = true
		out.append("[b]%s[/b]\n%s" % [_plain(component.name), _plain("\n".join(lines))])

	out.append(_title("gamesynth and the Rust crates it is built from"))
	out.append("gamesynth (c) 2026 Joakim Eriksson, MIT or Apache-2.0. godot-rust is under the Mozilla Public License 2.0; its source is at github.com/godot-rust/gdext.\n")
	out.append(_plain(_read("res://addons/gamesynth/THIRD_PARTY.txt")))

	out.append(_title("Saira Condensed"))
	out.append(_plain(_read("res://assets/fonts/OFL.txt")))

	out.append(_title("Music"))
	out.append("Generated with ACE-Step 1.5 XL, (c) 2026 ACEStep, MIT licence.")

	out.append(_title("Licence texts"))
	var texts := Engine.get_license_info()
	var ids := used.keys()
	ids.sort()
	for id in ids:
		if texts.has(id):
			out.append("[b]%s[/b]\n%s" % [id, _plain(texts[id])])
	return "\n\n".join(out)


func _title(text: String) -> String:
	return "[color=#ff59cc][b]%s[/b][/color]" % text.to_upper()


## Licence texts are full of square brackets; keep them from being read as markup.
static func _plain(text: String) -> String:
	return text.replace("[", "[lb]")


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "(%s is missing from this build)" % path
