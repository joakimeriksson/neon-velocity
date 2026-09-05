class_name TrackDefs

## The circuits. Control points are smoothed into a closed loop by TrackBuilder;
## keep consecutive points far enough apart that the curve can't fold on itself.
## `tools/check_tracks.gd` verifies that.

const ALL: Array[Dictionary] = [
	{
		"name": "Neon Descent",
		"blurb": "Flowing, banked, fast. Learn the airbrakes here.",
		"width": 18.0,
		"bank_strength": 22.0,
		"neon": Color(0.1, 0.9, 1.0),
		"par_lap": 26.0,
		"points": [
			Vector3(0, 0, 0), Vector3(220, 0, -150), Vector3(380, 25, -420), Vector3(280, 45, -720),
			Vector3(0, 20, -820), Vector3(-280, 0, -700), Vector3(-420, -20, -380), Vector3(-300, -5, -100),
		],
		"boost_pads": [0.12, 0.38, 0.6, 0.83],
	},
	{
		"name": "Undertow",
		"blurb": "Narrow and technical: hairpins, drops, no room for mistakes.",
		"width": 14.0,
		"bank_strength": 16.0,
		"neon": Color(1.0, 0.3, 0.85),
		"par_lap": 26.0,
		"points": [
			Vector3(0, 0, 0), Vector3(180, 0, -90), Vector3(260, -12, -260), Vector3(150, -28, -380),
			Vector3(-20, -32, -330), Vector3(-90, -18, -190), Vector3(-260, -6, -230), Vector3(-380, 14, -90),
			Vector3(-280, 32, 90), Vector3(-90, 18, 110),
		],
		"boost_pads": [0.2, 0.55, 0.78],
	},
	{
		"name": "Chrome Riot",
		"blurb": "Wide and brutal: long straights, huge sweepers, a blind crest.",
		"width": 22.0,
		"bank_strength": 30.0,
		"neon": Color(1.0, 0.6, 0.15),
		"par_lap": 35.0,
		"points": [
			Vector3(0, 0, 0), Vector3(420, 0, -110), Vector3(720, 30, -380), Vector3(620, 70, -740),
			Vector3(260, 40, -900), Vector3(-160, 10, -840), Vector3(-470, -12, -560), Vector3(-520, -24, -200),
			Vector3(-300, 0, -20),
		],
		"boost_pads": [0.1, 0.3, 0.5, 0.7, 0.9],
	},
]
