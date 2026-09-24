// Shipping containers (a unit BoxMesh scaled to 12.2 x 2.6 x 2.45): instance colour, vertical
// corrugation on the long sides, door lines on the ends, grime towards the bottom.
shader_type spatial;
render_mode cull_back;

varying vec3 lpos;
varying vec3 lnorm;
varying vec3 col;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
	col = COLOR.rgb;
}

void fragment() {
	float long_side = step(0.5, abs(lnorm.z));
	float end_face = step(0.5, abs(lnorm.x));
	float ribs = 0.5 + 0.5 * sin(lpos.x * 12.2 * 6.2832 / 0.45);
	float doors = step(0.47, abs(fract(lpos.z * 2.0) - 0.5)) * end_face;
	vec3 c = col * (0.82 + 0.18 * ribs * long_side) * (1.0 - 0.35 * doors);
	c *= mix(0.72, 1.0, smoothstep(-0.5, -0.15, lpos.y));
	float rust = step(0.8, hash(floor(lpos.xz * vec2(24.0, 6.0) + lpos.y * 3.0)));
	c = mix(c, vec3(0.35, 0.18, 0.1), rust * 0.25);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	METALLIC = 0.25;
}
