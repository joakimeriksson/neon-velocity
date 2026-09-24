// Grandstand crowd, drawn procedurally on the steps. UV: u metres along the stand, v two units
// per step (riser 0..0.9, tread 0.9..2). One person per 0.62 m seat: shirt, head, a few empty
// seats, some cheering (bobbing) and the odd camera flash.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 seat : source_color = vec3(0.24, 0.25, 0.3);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float row = floor(UV.y / 2.0);
	float v = mod(UV.y, 2.0);
	float cell_w = 0.62;
	float cell = floor(UV.x / cell_w);
	float cx = fract(UV.x / cell_w);
	float h = hash(vec2(cell, row));
	float present = step(0.12, h);
	float cheer = step(0.72, hash(vec2(cell * 1.3, row + 7.0)));
	float bob = cheer * 0.22 * max(0.0, sin(TIME * 7.0 + h * 40.0));
	float body = step(0.16, cx) * step(cx, 0.84) * step(0.25 + bob, v) * step(v, 1.45 + bob);
	vec2 hp = vec2((cx - 0.5) * 2.4, (v - (1.68 + bob)) * 3.2);
	float head = step(length(hp), 0.65);
	vec3 shirt = 0.5 + 0.5 * cos(6.2832 * (h * 3.7 + vec3(0.0, 0.33, 0.67)));
	vec3 skin = mix(vec3(0.95, 0.78, 0.62), vec3(0.38, 0.24, 0.16), hash(vec2(cell, row + 3.0)));
	vec3 c = seat;
	c = mix(c, shirt * 0.85, body * present);
	c = mix(c, skin, head * present * (1.0 - body * 0.0));
	float flash = step(0.9985, hash(vec2(cell, row + floor(TIME * 4.0)))) * present;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0) * flash * 3.0;
}
