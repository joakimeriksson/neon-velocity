// An expanding shock ring on a quad: `progress` 0..1 grows the radius and thins it out.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.5, 0.9, 1.0);
uniform float progress = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float radius = mix(0.12, 0.92, 1.0 - pow(1.0 - progress, 2.0));
	float thickness = mix(0.16, 0.03, progress);
	float ringv = 1.0 - smoothstep(0.0, thickness, abs(r - radius));
	// A faint disc inside the ring while it is young.
	float disc = (1.0 - smoothstep(0.0, radius, r)) * 0.25 * (1.0 - progress);
	float a = (ringv + disc) * pow(1.0 - progress, 1.5);
	ALBEDO = color * a * 3.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
