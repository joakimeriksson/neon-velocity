// Track barrier: dark armoured panels, a neon light tube along the top with pulses running
// the way the lap goes, and amber chevrons that march along the outside wall of a tight
// corner. UV.x is height (0 at the road, 1 at the top), UV.y runs along in wall heights.
// COLOR.r = how hard the corner ahead is (0..1), on the outside wall only.
shader_type spatial;
render_mode cull_disabled;

uniform float wall_height = 2.5;
uniform vec3 base_color : source_color = vec3(0.1, 0.1, 0.16);
uniform vec3 neon : source_color = vec3(0.1, 0.9, 1.0);
uniform vec3 warn : source_color = vec3(1.0, 0.62, 0.12);
uniform float glow = 1.0;

varying float corner;

float grid_line(float x, float period, float half, float fw) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	return 1.0 - smoothstep(half - fw, half + fw, d);
}

void vertex() {
	corner = COLOR.r;
}

void fragment() {
	float h = UV.x;
	float along = UV.y * wall_height;   // metres
	float fw_a = fwidth(along);
	float fw_h = fwidth(h);
	float detail = 1.0 - smoothstep(0.15, 0.9, fw_a);

	float seam = grid_line(along, 4.0, 0.04, fw_a) * detail;
	float groove = (1.0 - smoothstep(0.012, 0.012 + fw_h, abs(h - 0.5))) * detail;
	vec3 albedo = base_color * (1.0 - 0.55 * max(seam, groove));
	// Lighter kick plate along the bottom.
	albedo = mix(albedo, base_color * 1.6, (1.0 - smoothstep(0.1, 0.1 + fw_h, h)) * 0.6);

	// The tube along the top, with a pulse every 60 m travelling forward.
	float tube = smoothstep(0.9 - fw_h, 0.9 + fw_h, h);
	float pulse = pow(1.0 - fract(along / 60.0 - TIME * 1.4), 6.0);
	vec3 emission = neon * tube * (0.9 + 2.0 * pulse) * glow;
	// The road's edge strips light the foot of the wall.
	emission += neon * (1.0 - smoothstep(0.0, 0.5, h)) * 0.14 * glow;

	// Corner warning: >>> marching the way the track turns.
	float body = smoothstep(0.16, 0.2, h) * (1.0 - smoothstep(0.78, 0.82, h));
	float arrow = fract((along - abs(h - 0.47) * wall_height * 1.1) / 2.4 - TIME * 2.2);
	float chevrons = step(arrow, 0.42) * body * corner;
	emission += warn * chevrons * 2.4 * glow;
	albedo = mix(albedo, warn * 0.6, chevrons * 0.7);

	ALBEDO = albedo;
	ROUGHNESS = 0.55;
	METALLIC = 0.3;
	EMISSION = emission;
}
