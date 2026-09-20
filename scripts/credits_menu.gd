class_name CreditsMenu
extends OverlayMenu

## Who and what made the game. Edit CREDITS; each entry is [role, credit, detail].

const CREDITS := [
	["A game by", "Joakim Eriksson", ""],
	["Design, code, circuits, HUD", "Joakim Eriksson with Claude Code", "Claude Fable 5.1, Anthropic"],
	["Ship models", "Codex Astra", "five anti-gravity craft, from a concept sheet to glTF"],
	["Music", "ACE-Step 1.5 XL on an NVIDIA DGX Spark", "open-weight music model, MIT licence. Prompted with Claude Code, every track picked by ear"],
	["Sound", "gamesynth", "a Rust synthesiser by Joakim Eriksson, built with Claude Code. Engines, impacts and explosions are synthesised live; there are no samples"],
	["Engine", "Godot Engine 4.7", "(c) Juan Linietsky, Ariel Manzur and contributors, MIT licence. godot-rust, MPL 2.0"],
	["Type", "Saira Condensed", "Omnibus-Type, SIL Open Font Licence"],
	["With thanks to", "the anti-gravity racers of the 1990s", ""],
]


func _heading() -> String:
	return "Credits"


func _build(box: VBoxContainer) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for entry in CREDITS:
		var role := UiTheme.label(entry[0], 22, UiTheme.PINK, HORIZONTAL_ALIGNMENT_RIGHT)
		role.custom_minimum_size = Vector2(300, 0)
		role.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		role.size_flags_vertical = Control.SIZE_FILL
		grid.add_child(role)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		column.add_child(UiTheme.label(entry[1], 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		if entry[2] != "":
			var detail := UiTheme.label(entry[2], 19, UiTheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size = Vector2(620, 0)
			column.add_child(detail)
		grid.add_child(column)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)
	var licences := UiTheme.button("Licences and third-party notices", 22, UiTheme.DIM)
	licences.custom_minimum_size = Vector2(420, 46)
	licences.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	licences.pressed.connect(func(): open_child(LicencesMenu.new(), licences))
	box.add_child(licences)
	return null
