// Afterburner flame cone. Nozzle end is hot blue-white, cooling through violet to red at the
// tail; scrolling noise makes it flicker; faint Mach diamonds ride down the core.
// `intensity` follows throttle, `boost` flares it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float boost : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec3 hot_color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 mid_color : source_color = vec3(0.75, 0.35, 1.0);
uniform vec3 tail_color : source_color = vec3(1.0, 0.32, 0.06);

varying float along;

void vertex() {
	// Cylinder mesh: nozzle at the bottom (v = 1), tail at the top (v = 0).
	along = 1.0 - UV.y;
}

void fragment() {
	float n = texture(noise, vec2(UV.x * 2.0 + TIME * 0.3, along * 2.5 - TIME * 7.0)).r;
	float n2 = texture(noise, vec2(UV.x * 3.0 - TIME * 0.2, along * 4.0 - TIME * 11.0)).r;
	float flicker = 0.55 + 0.45 * (n * 0.6 + n2 * 0.4);

	vec3 col = mix(hot_color * 3.0, mid_color * 1.6, smoothstep(0.0, 0.45, along));
	col = mix(col, tail_color * 1.1, smoothstep(0.35, 1.0, along));
	// Boost pushes the hot core further down the flame.
	col = mix(col, hot_color * 3.5, boost * (1.0 - smoothstep(0.0, 0.8, along)));

	// Mach diamonds: bright bands near the nozzle.
	float diamonds = pow(0.5 + 0.5 * sin(along * 34.0 - TIME * 3.0), 10.0);
	col += hot_color * 2.0 * diamonds * (1.0 - smoothstep(0.0, 0.6, along)) * (0.4 + boost);

	// Fade along the length; only a light touch of silhouette softening so the cone still
	// reads when seen end-on from the chase camera.
	float edge = 0.55 + 0.45 * clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float body = pow(1.0 - along, 1.3);
	float alpha = body * flicker * edge * intensity;

	ALBEDO = vec3(0.0);
	EMISSION = col * alpha;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
