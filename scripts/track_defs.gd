class_name TrackDefs

## The circuits. Control points are smoothed into a closed loop by TrackBuilder;
## keep consecutive points far enough apart that the curve can't fold on itself.
## `tools/check_tracks.gd` verifies that.
##
## `setting` shapes the city around the circuit, `open_edges` removes walls, `features` is menu text.
## `music` lists filename prefixes in audio/music/ that make up the circuit's playlist.
## `relief` lists crests, drops and gaps, `tunnels` roofed stretches (see TrackBuilder).
## `env` sets the time of day (Race applies it to the WorldEnvironment and Sun; CityBuilder
## reads `rain` and `window_lit`). `lit_sections` are lap fractions [start, end] that get
## artificial track lighting (poles + gantries) in `light_color`.

const NIGHT_RAIN := {
	"sky_top": Color(0.03, 0.03, 0.06), "sky_horizon": Color(0.42, 0.2, 0.1),
	"sun_color": Color(0.55, 0.65, 0.9), "sun_energy": 0.35, "sun_rotation": Vector3(-35, 40, 0),
	"ambient": 0.45, "fog_color": Color(0.4, 0.2, 0.12), "fog_density": 0.0035,
	"vol_fog": 0.016, "vol_fog_albedo": Color(0.7, 0.55, 0.5), "vol_fog_emission": Color(0.3, 0.13, 0.06),
	"rain": true, "window_lit": 1.0, "exposure": 1.0,
}
const DUSK := {
	"sky_top": Color(0.12, 0.06, 0.2), "sky_horizon": Color(1.0, 0.45, 0.18),
	"sun_color": Color(1.0, 0.6, 0.3), "sun_energy": 1.6, "sun_rotation": Vector3(-8, 110, 0),
	"ambient": 0.6, "fog_color": Color(0.6, 0.3, 0.2), "fog_density": 0.002,
	"vol_fog": 0.008, "vol_fog_albedo": Color(0.9, 0.6, 0.45), "vol_fog_emission": Color(0.35, 0.15, 0.06),
	"rain": false, "window_lit": 0.6, "exposure": 0.95,
}
const DAY := {
	"sky_top": Color(0.22, 0.45, 0.85), "sky_horizon": Color(0.78, 0.85, 0.92),
	"sun_color": Color(1.0, 0.96, 0.9), "sun_energy": 2.6, "sun_rotation": Vector3(-48, 35, 0),
	"ambient": 1.6, "fog_color": Color(0.7, 0.78, 0.9), "fog_density": 0.0012,
	"vol_fog": 0.004, "vol_fog_albedo": Color(0.9, 0.92, 0.95), "vol_fog_emission": Color(0.06, 0.07, 0.08),
	"rain": false, "window_lit": 0.05, "exposure": 0.85,
}
const DAWN := {
	"sky_top": Color(0.3, 0.36, 0.45), "sky_horizon": Color(0.65, 0.62, 0.6),
	"sun_color": Color(0.85, 0.9, 1.0), "sun_energy": 1.3, "sun_rotation": Vector3(-25, -60, 0),
	"ambient": 1.0, "fog_color": Color(0.5, 0.52, 0.56), "fog_density": 0.0045,
	"vol_fog": 0.012, "vol_fog_albedo": Color(0.8, 0.82, 0.85), "vol_fog_emission": Color(0.08, 0.09, 0.1),
	"rain": true, "window_lit": 0.25, "exposure": 0.9,
}

const ALL: Array[Dictionary] = [
	{
		"name": "Neon Descent",
		"blurb": "Flowing and fast, with one S-bend. Learn the airbrakes here.",
		"width": 18.0,
		"bank_strength": 22.0,
		"neon": Color(0.1, 0.9, 1.0),
		"par_lap": 33.5,
		"env": NIGHT_RAIN,
		"light_color": Color(0.8, 0.9, 1.0),
		"lit_sections": [[0.2, 0.32], [0.55, 0.62], [0.85, 0.95]],
		"features": "S-bend, gap jump, tunnel, drop",
		"music": ["04_", "05_"],
		"points": [
			Vector3(0, 0, 0), Vector3(260, 0, -30), Vector3(480, 10, -170), Vector3(530, 28, -420),
			Vector3(380, 42, -570), Vector3(250, 40, -470), Vector3(110, 32, -560), Vector3(-60, 20, -770),
			Vector3(-330, 5, -710), Vector3(-450, -15, -430), Vector3(-340, -8, -140), Vector3(-180, -2, -20),
		],
		"boost_pads": [0.12, 0.38, 0.6, 0.83],
		"relief": [["gap", 0.17, 6.0, 60.0, 46.0], ["drop", 0.66, 15.0, 44.0]],
		"tunnels": [[0.4, 0.54]],
	},
	{
		"name": "Undertow",
		"blurb": "Down in the street canyon: hairpins, chicanes, a long tunnel.",
		"width": 14.0,
		"bank_strength": 16.0,
		"neon": Color(1.0, 0.3, 0.85),
		"par_lap": 30.5,
		"env": DUSK,
		"light_color": Color(1.0, 0.6, 0.25),
		"lit_sections": [[0.1, 0.22], [0.45, 0.55], [0.75, 0.9]],
		"features": "street canyon, hairpins, long tunnel",
		"setting": {"drop": 9.0, "gap": 12.0, "count": 1500, "height": 1.3},
		"music": ["fire1_", "fire3_"],
		"points": [
			Vector3(0, 0, 0), Vector3(170, 0, 0), Vector3(310, -4, -40), Vector3(350, -10, -170),
			Vector3(240, -16, -240), Vector3(120, -20, -180), Vector3(30, -24, -260), Vector3(90, -28, -390),
			Vector3(-40, -30, -470), Vector3(-180, -24, -400), Vector3(-140, -16, -270), Vector3(-270, -8, -190),
			Vector3(-340, 0, -70), Vector3(-230, 4, 10), Vector3(-110, 2, 0),
		],
		"boost_pads": [0.2, 0.55, 0.78],
		"relief": [["crest", 0.3, 4.0, 44.0], ["drop", 0.62, 11.0, 38.0]],   # too twisty for a gap
		"tunnels": [[0.36, 0.56]],
	},
	{
		"name": "Chrome Riot",
		"blurb": "Above the skyline: long straights, a wall-less sweeper, one hard stop.",
		"width": 22.0,
		"bank_strength": 30.0,
		"neon": Color(1.0, 0.6, 0.15),
		"par_lap": 44.0,
		"env": DAWN,
		"light_color": Color(0.6, 0.8, 1.0),
		"lit_sections": [[0.02, 0.1], [0.38, 0.48], [0.68, 0.76]],
		"features": "700 m straights, open-edge sweeper, gap, above the skyline",
		"setting": {"drop": 150.0, "count": 1100, "height": 0.8, "reach": 700.0},
		"open_edges": [[0.3, 0.37, 1.0]],
		"music": ["fire2_", "fire4_", "06_"],
		"points": [
			Vector3(0, 0, 0), Vector3(350, 0, 0), Vector3(700, 5, 0), Vector3(960, 20, -90),
			Vector3(1080, 45, -330), Vector3(960, 65, -570), Vector3(700, 70, -650), Vector3(350, 55, -650),
			Vector3(0, 35, -650), Vector3(-300, 15, -650), Vector3(-480, 2, -560), Vector3(-470, -10, -380),
			Vector3(-330, -18, -300), Vector3(-390, -12, -160), Vector3(-300, -4, -30), Vector3(-150, 0, 0),
		],
		"boost_pads": [0.1, 0.3, 0.5, 0.7, 0.9],
		"relief": [["gap", 0.36, 7.0, 70.0, 56.0], ["crest", 0.58, 5.0, 56.0], ["drop", 0.78, 17.0, 48.0]],
		"tunnels": [[0.14, 0.26]],
	},
	{
		"name": "Solar Wake",
		"blurb": "A figure-eight over the harbour. The bridge has no rails.",
		"width": 20.0,
		"bank_strength": 26.0,
		"neon": Color(1.0, 0.92, 0.55),
		"par_lap": 36.5,
		"env": DAY,
		"light_color": Color(1.0, 0.95, 0.85),
		"lit_sections": [],
		"features": "figure-eight, rail-less bridge with a gap, harbour",
		"setting": {"drop": 16.0, "count": 450, "height": 0.7, "gap": 60.0, "water": true},
		"open_edges": [[0.44, 0.58, 0.0]],
		"music": ["afro"],
		"points": [
			Vector3(0, 0, 0), Vector3(250, 0, 0), Vector3(450, 2, -60), Vector3(560, 6, -250),
			Vector3(470, 10, -440), Vector3(260, 14, -500), Vector3(40, 18, -440), Vector3(-90, 21, -280),
			Vector3(-110, 22, -100), Vector3(-110, 22, 60), Vector3(-130, 15, 220), Vector3(-280, 8, 330),
			Vector3(-480, 3, 300), Vector3(-600, 0, 160), Vector3(-560, 0, 30), Vector3(-420, 0, 0),
			Vector3(-200, 0, 0),
		],
		"boost_pads": [0.15, 0.42, 0.66, 0.88],
		"relief": [["crest", 0.22, 5.0, 56.0], ["gap", 0.5, 5.5, 56.0, 44.0], ["drop", 0.74, 13.0, 42.0]],
		"tunnels": [[0.3, 0.42]],
	},
]
