// Track surface: composite panels with seams, a dashed centre line, edge lines and forward
// chevrons in the circuit's neon, and standing water on the wet circuits (smooth patches that
// carry the reflections). UV.x runs across the road 0..1, UV.y along it in track widths.
shader_type spatial;
render_mode cull_disabled;

uniform float width = 18.0;
uniform vec3 base_color : source_color = vec3(0.13, 0.13, 0.16);
uniform vec3 neon : source_color = vec3(0.1, 0.9, 1.0);
uniform float roughness_base = 0.35;
uniform float metallic_base = 0.4;
uniform float line_glow = 1.0;   // how much the painted lines emit (night) rather than just show (day)
uniform float wet = 1.0;         // 0 = dry, 1 = rain-soaked

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 on a line every `period`, `half` wide either side, antialiased by the pixel footprint `fw`.
float grid_line(float x, float period, float half, float fw) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	return 1.0 - smoothstep(half - fw, half + fw, d);
}

float band(float x, float centre, float half, float fw) {
	return 1.0 - smoothstep(half - fw, half + fw, abs(x - centre));
}

void fragment() {
	vec2 m = vec2((UV.x - 0.5) * width, UV.y * width);   // metres: across, along
	vec2 fw = fwidth(m);
	float footprint = max(fw.x, fw.y);
	// Fine detail dissolves with distance instead of shimmering.
	float detail = 1.0 - smoothstep(0.12, 0.7, footprint);

	// Panels: 8 m long, staggered between the three lanes.
	float lane = floor((m.x / width + 0.5) * 3.0);
	float seams = grid_line(m.y + lane * 2.7, 8.0, 0.035, fw.y);
	seams = max(seams, grid_line(m.x + width * 0.5, width / 3.0, 0.035, fw.x));
	float mottle = vnoise(m * 0.33) * 0.6 + vnoise(m * 1.7) * 0.4;
	float grain = hash21(floor(m * 14.0));

	vec3 albedo = base_color * (0.78 + 0.4 * mottle) * (1.0 + (grain - 0.5) * 0.16 * detail);
	albedo *= 1.0 - 0.5 * seams * detail;

	// Paint.
	float half_w = width * 0.5;
	float centre = band(m.x, 0.0, 0.07, fw.x) * step(fract(m.y / 12.0), 0.5);
	float edges = band(abs(m.x), half_w - 1.9, 0.05, fw.x);
	// A chevron every 48 m, pointing the way the lap runs.
	float cy = (fract(m.y / 48.0) - 0.5) * 48.0;
	float chev = band(cy + abs(m.x) * 0.9, 0.0, 0.1, fw.y + fw.x) * (1.0 - smoothstep(1.7, 1.9, abs(m.x)));
	chev = max(chev, band(cy + 1.3 + abs(m.x) * 0.9, 0.0, 0.1, fw.y + fw.x) * (1.0 - smoothstep(1.7, 1.9, abs(m.x))));
	float paint = clamp(centre * 0.8 + edges * 0.5 + chev * 0.45, 0.0, 1.0);
	// Paint wears: it thins where the mottle is dark.
	paint *= 0.55 + 0.45 * smoothstep(0.25, 0.6, mottle);
	paint *= mix(0.35, 1.0, detail);

	vec3 paint_color = mix(vec3(0.9), neon, 0.55);
	albedo = mix(albedo, paint_color * 0.75, paint * 0.8);

	// Standing water gathers in the low-frequency hollows.
	float puddle = smoothstep(0.52, 0.72, vnoise(m * 0.07 + 11.0) * 0.7 + vnoise(m * 0.21) * 0.3) * wet;

	ALBEDO = albedo * (1.0 - 0.35 * puddle);
	ROUGHNESS = clamp(mix(roughness_base + (mottle - 0.5) * 0.18, 0.04, puddle * 0.85), 0.03, 1.0);
	METALLIC = clamp(metallic_base + puddle * 0.25, 0.0, 1.0);
	EMISSION = neon * paint * line_glow * 0.4;
}
