// Neon advertising panel: bright frame around glyph-like bars, in the instance colour,
// with a faint mains buzz and the odd dead tube.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float strength = 4.0;

varying vec4 col;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void vertex() {
	col = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float seed = col.a * 37.0;
	float inner = step(0.06, uv.x) * step(uv.x, 0.94) * step(0.12, uv.y) * step(uv.y, 0.88);
	float rows = 2.0 + floor(hash(seed) * 2.0);
	float row = floor(uv.y * rows);
	float ry = fract(uv.y * rows);
	float cols = 5.0 + floor(hash(seed + row) * 5.0);
	float col_i = floor(uv.x * cols);
	float rx = fract(uv.x * cols);
	float glyph = step(0.35, hash(seed + row * 11.0 + col_i * 3.0)) * step(0.2, rx) * step(rx, 0.8) * step(0.25, ry) * step(ry, 0.75);
	float dead = step(0.9, hash(seed + row * 7.0 + col_i * 5.0 + 1.0));
	float pattern = mix(1.0, glyph * (1.0 - dead * 0.9), inner);
	float buzz = 0.9 + 0.1 * sin(TIME * 40.0 + seed);
	vec3 c = col.rgb;
	ALBEDO = c * pattern;
	EMISSION = c * pattern * strength * buzz;
	ALPHA = max(pattern, 0.08);
}
