class_name Items

## Pickups. One slot per ship: collect from an item pad, fire with `fire`, or absorb for energy.

enum { NONE, ROCKET, MISSILE, MINE, SHIELD, TURBO }

const NAMES := ["", "ROCKET", "MISSILE", "MINES", "SHIELD", "TURBO"]
const COLORS := [
	Color(1, 1, 1), Color(1.0, 0.55, 0.15), Color(1.0, 0.25, 0.3),
	Color(1.0, 0.9, 0.2), Color(0.3, 0.8, 1.0), Color(0.5, 1.0, 0.5),
]
const ABSORB_ENERGY := 18.0


## Weighted by race position: leaders get defensive items, the back of the field gets
## the means to catch up.
static func roll(position: int, field: int) -> int:
	var t := float(position - 1) / maxf(field - 1, 1.0)   # 0 = leading, 1 = last
	var weights := {
		ROCKET: 3.0,
		MISSILE: 1.0 + 3.0 * t,
		MINE: 3.0 - 2.2 * t,
		SHIELD: 2.0,
		TURBO: 1.0 + 2.0 * t,
	}
	var total := 0.0
	for w in weights.values():
		total += w
	var pick := randf() * total
	for item in weights:
		pick -= weights[item]
		if pick <= 0.0:
			return item
	return ROCKET
