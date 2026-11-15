// Energy shield bubble: bright at the rim, a honeycomb that crawls over the surface, and a
// flare when something hits it. `level` fades it in and out.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.3, 0.8, 1.0);
uniform float level = 1.0;
uniform float flare = 0.0;

float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float cells = 1.0 - smoothstep(0.0, 0.12, hex(UV * vec2(26.0, 13.0) + vec2(TIME * 0.6, 0.0)));
	float sweep = 0.5 + 0.5 * sin(UV.y * 18.0 - TIME * 6.0);
	float a = (rim * 0.9 + cells * (0.12 + 0.2 * sweep) + flare * 0.6) * level;
	ALBEDO = mix(color, vec3(1.0), flare * 0.5) * a * 2.2;
	ALPHA = clamp(a, 0.0, 1.0);
}
