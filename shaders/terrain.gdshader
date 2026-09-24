// Landscape ground. Vertex colour carries the zone's material weights (r rock, g grass,
// b urban); on top of that steep ground turns to rock with strata, ground near the water
// to sand (and darker below it), and high ground to snow.
shader_type spatial;
render_mode cull_back;

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float water_level = -26.0;
uniform float snow_line = 200.0;
uniform vec3 grass_a : source_color = vec3(0.19, 0.29, 0.12);
uniform vec3 grass_b : source_color = vec3(0.34, 0.4, 0.17);
uniform vec3 rock_a : source_color = vec3(0.25, 0.24, 0.23);
uniform vec3 rock_b : source_color = vec3(0.56, 0.52, 0.47);
uniform vec3 urban : source_color = vec3(0.33, 0.33, 0.35);
uniform vec3 sand : source_color = vec3(0.64, 0.57, 0.44);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 0.99);

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 mat;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mat = COLOR;
}

void fragment() {
	vec3 n = normalize(wnorm);
	float n1 = texture(detail, wpos.xz * 0.004).r;
	float n2 = texture(detail, wpos.xz * 0.04).r;
	float slope = 1.0 - n.y;

	// Rock: three planar projections blended by the normal, with horizontal strata.
	vec3 an = abs(n);
	an /= (an.x + an.y + an.z);
	float rt = texture(detail, wpos.zy * 0.025).r * an.x + texture(detail, wpos.xz * 0.025).r * an.y + texture(detail, wpos.xy * 0.025).r * an.z;
	float strata = 0.5 + 0.5 * sin(wpos.y * 0.55 + rt * 7.0);
	float fine = texture(detail, wpos.zy * 0.06).r * an.x + texture(detail, wpos.xz * 0.06).r * an.y + texture(detail, wpos.xy * 0.06).r * an.z;
	vec3 rock = mix(rock_a, rock_b, clamp(rt * 1.1 + strata * 0.35 - 0.25, 0.0, 1.0));
	// Cracks and cavities: darken where the fine noise dips.
	rock *= 0.8 + 0.28 * smoothstep(0.25, 0.7, fine);

	vec3 grass = mix(grass_a, grass_b, n1) * (0.82 + 0.36 * n2);
	float lot = step(0.93, fract(wpos.x * 0.05)) + step(0.93, fract(wpos.z * 0.05));
	vec3 paved = urban * (0.78 + 0.3 * n2) * (1.0 - 0.18 * clamp(lot, 0.0, 1.0));
	vec3 ground = mix(grass, paved, clamp(mat.b, 0.0, 1.0));

	float rockiness = clamp(mat.r * 0.8 + smoothstep(0.3, 0.55, slope + (n2 - 0.5) * 0.2), 0.0, 1.0);
	vec3 albedo = mix(ground, rock, rockiness);

	float shore = 1.0 - smoothstep(water_level + 0.6, water_level + 3.5 + n2 * 2.5, wpos.y);
	albedo = mix(albedo, sand * (0.8 + 0.35 * n2), shore * (1.0 - rockiness * 0.5) * (1.0 - clamp(mat.b, 0.0, 1.0)));
	float under = smoothstep(water_level + 0.3, water_level - 4.0, wpos.y);
	albedo = mix(albedo, albedo * vec3(0.32, 0.42, 0.42), under);

	float snow_amount = smoothstep(snow_line - 25.0, snow_line + 25.0, wpos.y + (n1 - 0.5) * 70.0) * smoothstep(0.62, 0.38, slope);
	albedo = mix(albedo, snow * (0.92 + 0.08 * n2), snow_amount);

	// Rock relief: tilt the normal by the fine noise's gradient on the dominant plane.
	float e = 0.6;
	vec3 bump = vec3(0.0);
	bump.x = (texture(detail, (wpos.xz + vec2(e, 0.0)) * 0.11).r - texture(detail, (wpos.xz - vec2(e, 0.0)) * 0.11).r);
	bump.z = (texture(detail, (wpos.xz + vec2(0.0, e)) * 0.11).r - texture(detail, (wpos.xz - vec2(0.0, e)) * 0.11).r);
	bump.y = (texture(detail, (wpos.zy + vec2(0.0, e)) * 0.11).r - texture(detail, (wpos.zy - vec2(0.0, e)) * 0.11).r) * an.x
		+ (texture(detail, (wpos.xy + vec2(0.0, e)) * 0.11).r - texture(detail, (wpos.xy - vec2(0.0, e)) * 0.11).r) * an.z;
	vec3 wn = normalize(n - bump * 1.4 * rockiness * (1.0 - snow_amount));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = clamp(0.92 - snow_amount * 0.35 - shore * 0.35, 0.3, 1.0);
	SPECULAR = 0.3;
}
