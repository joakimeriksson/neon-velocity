class_name TrackDefs

## The circuits. Control points are smoothed into a closed loop by TrackBuilder;
## keep consecutive points far enough apart that the curve can't fold on itself.
## `tools/check_tracks.gd` verifies that.
##
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
		"blurb": "Flowing, banked, fast. Learn the airbrakes here.",
		"width": 18.0,
		"bank_strength": 22.0,
		"neon": Color(0.1, 0.9, 1.0),
		"par_lap": 26.0,
		"env": NIGHT_RAIN,
		"light_color": Color(0.8, 0.9, 1.0),
		"lit_sections": [[0.2, 0.32], [0.55, 0.62], [0.85, 0.95]],
		"points": [
			Vector3(0, 0, 0), Vector3(220, 0, -150), Vector3(380, 25, -420), Vector3(280, 45, -720),
			Vector3(0, 20, -820), Vector3(-280, 0, -700), Vector3(-420, -20, -380), Vector3(-300, -5, -100),
		],
		"boost_pads": [0.12, 0.38, 0.6, 0.83],
		"relief": [["crest", 0.17, 5.0, 56.0], ["drop", 0.66, 15.0, 44.0]],
	},
	{
		"name": "Undertow",
		"blurb": "Narrow and technical: hairpins, drops, no room for mistakes.",
		"width": 14.0,
		"bank_strength": 16.0,
		"neon": Color(1.0, 0.3, 0.85),
		"par_lap": 26.0,
		"env": DUSK,
		"light_color": Color(1.0, 0.6, 0.25),
		"lit_sections": [[0.1, 0.22], [0.45, 0.55], [0.75, 0.9]],
		"points": [
			Vector3(0, 0, 0), Vector3(180, 0, -90), Vector3(260, -12, -260), Vector3(150, -28, -380),
			Vector3(-20, -32, -330), Vector3(-90, -18, -190), Vector3(-260, -6, -230), Vector3(-380, 14, -90),
			Vector3(-280, 32, 90), Vector3(-90, 18, 110),
		],
		"boost_pads": [0.2, 0.55, 0.78],
		"relief": [["crest", 0.3, 4.0, 44.0], ["drop", 0.62, 11.0, 38.0]],
	},
	{
		"name": "Chrome Riot",
		"blurb": "Wide and brutal: long straights, huge sweepers, a blind crest.",
		"width": 22.0,
		"bank_strength": 30.0,
		"neon": Color(1.0, 0.6, 0.15),
		"par_lap": 35.0,
		"env": DAWN,
		"light_color": Color(0.6, 0.8, 1.0),
		"lit_sections": [[0.02, 0.1], [0.38, 0.48], [0.68, 0.76]],
		"points": [
			Vector3(0, 0, 0), Vector3(420, 0, -110), Vector3(720, 30, -380), Vector3(620, 70, -740),
			Vector3(260, 40, -900), Vector3(-160, 10, -840), Vector3(-470, -12, -560), Vector3(-520, -24, -200),
			Vector3(-300, 0, -20),
		],
		"boost_pads": [0.1, 0.3, 0.5, 0.7, 0.9],
		"relief": [["crest", 0.36, 7.0, 70.0], ["crest", 0.58, 5.0, 56.0], ["drop", 0.78, 17.0, 48.0]],
	},
	{
		"name": "Solar Wake",
		"blurb": "Broad daylight: long sweepers and a fast chicane, nowhere to hide.",
		"width": 20.0,
		"bank_strength": 26.0,
		"neon": Color(1.0, 0.92, 0.55),
		"par_lap": 28.0,
		"env": DAY,
		"light_color": Color(1.0, 0.95, 0.85),
		"lit_sections": [],
		"points": [
			Vector3(0, 0, 0), Vector3(260, 0, -90), Vector3(430, 18, -300), Vector3(370, 34, -570),
			Vector3(160, 12, -720), Vector3(-130, -8, -730), Vector3(-340, 4, -560), Vector3(-270, 24, -330),
			Vector3(-440, 12, -150), Vector3(-230, 0, 30),
		],
		"boost_pads": [0.15, 0.42, 0.66, 0.88],
		"relief": [["crest", 0.22, 5.0, 56.0], ["crest", 0.5, 4.0, 48.0], ["drop", 0.74, 13.0, 42.0]],
	},
]
