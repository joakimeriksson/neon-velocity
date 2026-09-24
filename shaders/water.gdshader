// Lake, fjord and stream surface: two scrolling normal maps, a deep blue-green body and a
// low roughness so it carries the sky (and, in Forward+, screen-space reflections).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D wave_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.03, 0.12, 0.16);
uniform vec3 shallow : source_color = vec3(0.1, 0.3, 0.32);
uniform float flow = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec3 na = texture(wave_a, uv * 0.012 + TIME * vec2(0.006, 0.004) * flow).xyz;
	vec3 nb = texture(wave_b, uv * 0.035 - TIME * vec2(0.005, 0.009) * flow).xyz;
	NORMAL_MAP = normalize(na + nb - 1.0);
	NORMAL_MAP_DEPTH = 0.55;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(shallow, deep, facing);
	ROUGHNESS = 0.06;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
