// Tower facade: procedural window grid with randomly lit, warm/cool, occasionally
// flickering windows, plus grime streaks. Per instance: COLOR = tint,
// INSTANCE_CUSTOM.x = seed, .y = fraction of windows lit, .z = base height.
shader_type spatial;
render_mode cull_back;

uniform float window_w = 2.8;
uniform float window_h = 3.4;
uniform float emission_strength = 1.6;
uniform sampler2D grime : filter_linear, repeat_enable;
uniform float ground_y = 0.0;
// Daylight circuits: a lighter concrete body and dark blue glass in the unlit windows.
uniform float body_brightness = 1.0;
uniform vec3 glass : source_color = vec3(0.015, 0.015, 0.02);
uniform float glass_roughness = 0.8;

varying vec3 wpos;
varying vec3 wnormal;
varying vec4 cdata;
varying vec3 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	cdata = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 n = abs(wnormal);
	vec3 albedo = tint * 0.3 * body_brightness;
	float window_glass = 0.0;
	vec3 emission = vec3(0.0);
	vec2 pc;
	if (n.y > 0.5) {
		pc = wpos.xz;
		albedo *= 0.6;
	} else {
		bool x_face = n.x > n.z;
		pc = x_face ? wpos.zy : wpos.xy;
		float side = x_face ? sign(wnormal.x) : sign(wnormal.z);
		vec2 cell = floor(pc / vec2(window_w, window_h));
		vec2 f = fract(pc / vec2(window_w, window_h));
		float inside = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
		float seed = cdata.x * 97.0 + (x_face ? 13.0 : 29.0) * side;
		float r = hash(cell + seed);
		// Whole floors go dark now and then (empty offices, power cuts).
		float floor_dark = step(0.78, hash(vec2(cell.y, seed)));
		float lit = step(r, cdata.y) * (1.0 - floor_dark);
		float warmth = hash(cell * 1.7 + seed + 5.0);
		vec3 wc = mix(vec3(0.45, 0.8, 1.0), vec3(1.0, 0.7, 0.4), step(0.55, warmth));
		wc = mix(wc, vec3(0.6, 1.0, 0.7), step(0.93, warmth));
		float flick = 1.0;
		if (hash(cell + seed + 9.0) > 0.94) {
			flick = 0.4 + 0.6 * step(0.5, fract(TIME * (1.5 + r * 5.0)));
		}
		float glow = inside * lit * flick * (0.5 + 0.5 * hash(cell + seed + 3.0));
		emission = wc * glow;
		albedo = mix(albedo, glass, inside * (1.0 - lit));
		window_glass = inside * (1.0 - lit);
	}
	// Grime: streaky dirt running down the facade, heavier near the ground.
	float g = texture(grime, pc * vec2(0.03, 0.006) + cdata.x).r;
	// INSTANCE_CUSTOM.z is the tower's base height (its own ground on landscape circuits).
	float low = clamp(1.0 - (wpos.y - cdata.z) / 40.0, 0.0, 1.0);
	albedo *= mix(0.45, 1.1, g) * (1.0 - 0.4 * low);
	// Sodium haze creeping up from street level.
	emission += vec3(0.5, 0.22, 0.06) * low * low * 0.25 * mix(0.6, 1.0, g);
	emission *= mix(0.7, 1.0, g);
	ALBEDO = albedo;
	EMISSION = emission * emission_strength;
	ROUGHNESS = mix(0.8, glass_roughness, window_glass);
	METALLIC = 0.05;
}
