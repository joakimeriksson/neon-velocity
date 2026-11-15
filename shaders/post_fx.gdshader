// Full-screen pass between the 3D view and the HUD: the picture streaks outward from the
// vanishing point as the ship gathers speed, the colours split at the edges on a boost,
// a weapon hit tears the frame for a moment, and the corners darken a little.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float speed = 0.0;      // 0..1.3, the ship's speed against its top speed
uniform float boost = 0.0;      // 1 right after a boost, decaying
uniform float hit = 0.0;        // 1 right after a weapon hit, decaying
uniform float draft = 0.0;      // 0..1 in a slipstream
uniform float vignette = 0.35;
uniform vec2 centre = vec2(0.5, 0.46);

float hash(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_centre = centre - uv;
	float dist = length(to_centre * vec2(1.0, 0.6));
	// Nothing near the middle, where the ship and the road ahead are.
	float edge = smoothstep(0.16, 0.62, dist);

	// A weapon hit shears a few scanline bands sideways.
	float band = floor(uv.y * 24.0 + TIME * 30.0);
	uv.x += (hash(band) - 0.5) * 0.05 * hit * step(0.55, hash(band + 3.0));

	float amount = (max(speed - 0.45, 0.0) * 0.05 + boost * 0.045 + draft * 0.012) * edge;
	vec3 col = vec3(0.0);
	float total = 0.0;
	float jitter = hash(uv.x * 71.0 + uv.y * 131.0 + TIME);
	for (int i = 0; i < 8; i++) {
		float t = (float(i) + jitter) / 8.0;
		float w = 1.0 - t * 0.6;
		col += texture(screen, uv + to_centre * amount * t).rgb * w;
		total += w;
	}
	col /= total;

	// Colour fringes pulled apart along the same rays.
	float split = (boost * 0.01 + hit * 0.01 + max(speed - 1.0, 0.0) * 0.006) * edge;
	if (split > 0.0002) {
		col.r = mix(col.r, texture(screen, uv + to_centre * (amount + split)).r, 0.8);
		col.b = mix(col.b, texture(screen, uv + to_centre * (amount - split)).b, 0.8);
	}

	// Boost lifts the edges toward white-blue for a moment.
	col += vec3(0.25, 0.45, 0.6) * boost * edge * 0.35;
	col *= 1.0 - vignette * smoothstep(0.35, 0.95, dist) * (1.0 + 0.6 * clamp(speed, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
