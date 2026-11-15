// Lit markings on the road: boost pads (chevrons streaming forward), item pads (a pulsing
// lattice that goes dark when taken), the chequered start line, and the start gantry's banner.
// UV.x runs across 0..1, UV.y along 0..1 in the direction of travel.
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform int kind = 0;            // 0 boost pad, 1 item pad, 2 start line, 3 gantry banner
uniform vec3 color : source_color = vec3(1.0, 0.55, 0.1);
uniform vec3 color_b : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy = 2.5;
uniform float ready = 1.0;       // item pads: 1 live, 0 just taken
uniform vec2 cells = vec2(12.0, 2.0);

void fragment() {
	vec2 uv = UV;
	float lit = 1.0;
	vec3 c = color;
	if (kind == 0) {
		// Three chevrons streaming forward over a dim bed.
		float v = fract(uv.y * 2.0 + abs(uv.x - 0.5) * 1.3 - TIME * 2.6);
		float chev = smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.42, 0.5, v));
		float rim = max(step(uv.x, 0.04), step(0.96, uv.x));
		lit = 0.18 + 0.82 * max(chev, rim);
		c = mix(color, color_b, chev * 0.45);
	} else if (kind == 1) {
		vec2 g = abs(fract(uv * vec2(3.0, 4.0)) - 0.5);
		float diamond = 1.0 - smoothstep(0.3, 0.36, g.x + g.y);
		float rim = max(max(step(uv.x, 0.06), step(0.94, uv.x)), max(step(uv.y, 0.04), step(0.96, uv.y)));
		float breathe = 0.7 + 0.3 * sin(TIME * 5.0 + uv.y * 6.0);
		lit = mix(0.012, max(diamond * breathe, rim), ready) + 0.012;
	} else if (kind == 2) {
		vec2 q = floor(uv * cells);
		float check = mod(q.x + q.y, 2.0);
		c = mix(color, color_b, check);
		lit = 0.55 + 0.45 * check;
	} else {
		// Banner: chequers sweeping sideways between two solid bars.
		vec2 q = floor(vec2(uv.x * cells.x + TIME * 1.5, uv.y * cells.y));
		float check = mod(q.x + q.y, 2.0);
		float bar = max(step(uv.y, 0.1), step(0.9, uv.y));
		c = mix(mix(color * 0.25, color_b, check), color, bar);
		lit = mix(0.35 + 0.65 * check, 1.0, bar);
	}
	ALBEDO = c * lit * energy;
}
