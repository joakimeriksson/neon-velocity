// City air traffic: each instance is one craft that slides along its lane (the instance's
// -Z axis) and wraps round. INSTANCE_CUSTOM = (phase 0..1, speed m/s, lane length m).
shader_type spatial;
render_mode unshaded, world_vertex_coords, shadows_disabled, fog_disabled;

uniform float energy = 3.0;

varying vec3 tint;

void vertex() {
	vec3 dir = normalize(MODEL_MATRIX[2].xyz) * -1.0;
	float len = INSTANCE_CUSTOM.z;
	float s = fract(INSTANCE_CUSTOM.x + TIME * INSTANCE_CUSTOM.y / len) - 0.5;
	VERTEX += dir * s * len;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint * energy;
}
