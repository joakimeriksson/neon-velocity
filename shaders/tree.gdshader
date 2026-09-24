// Low-poly trees (per-vertex colour times the instance tint), swaying a little in the wind:
// the higher the vertex, the more it moves, each tree on its own phase.
shader_type spatial;
render_mode cull_back;

uniform float sway = 1.0;

varying vec3 col;

void vertex() {
	col = COLOR.rgb;
	vec3 at = MODEL_MATRIX[3].xyz;
	float phase = at.x * 0.05 + at.z * 0.07;
	float bend = max(VERTEX.y - 2.0, 0.0) / 12.0;
	VERTEX.x += sin(TIME * 1.3 + phase) * bend * bend * 0.35 * sway;
	VERTEX.z += cos(TIME * 1.05 + phase) * bend * bend * 0.25 * sway;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
