// The sky: a gradient from horizon to zenith, the sun (or the moon, on the night circuits:
// whatever the scene's directional light is) with a halo, a cloud deck lit from the light's
// side, and stars where the deck is open and the sky is dark. No TIME, so the radiance map
// is built once.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.03, 0.03, 0.06);
uniform vec3 horizon_color : source_color = vec3(0.42, 0.2, 0.1);
uniform vec3 ground_color : source_color = vec3(0.02, 0.015, 0.02);
uniform float curve = 0.35;
uniform float cloud_cover = 0.5;          // 0 clear .. 1 overcast
uniform vec3 cloud_lit : source_color = vec3(0.9, 0.6, 0.45);
uniform vec3 cloud_dark : source_color = vec3(0.08, 0.06, 0.09);
uniform float stars = 0.0;                // 0 none .. 1 a full night sky
uniform float disc_size = 0.035;          // radians
uniform float disc_energy = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(up, curve));
	} else {
		col = mix(horizon_color, ground_color, pow(min(-up * 6.0, 1.0), 0.6));
	}

	float sun_dot = LIGHT0_ENABLED ? dot(dir, LIGHT0_DIRECTION) : -1.0;
	float sun_angle = acos(clamp(sun_dot, -1.0, 1.0));
	vec3 light = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0);

	// Stars: one per cell of a grid on the sphere, with a few bright ones.
	if (stars > 0.0 && up > 0.0) {
		vec3 p = dir * 190.0;
		vec3 cell = floor(p);
		float h = hash31(cell);
		float d = length(fract(p) - 0.5);
		float star = step(0.992, h) * (1.0 - smoothstep(0.05, 0.3 + 0.2 * hash31(cell + 7.0), d));
		col += vec3(0.85, 0.9, 1.0) * star * stars * (0.4 + 1.6 * hash31(cell + 3.0)) * smoothstep(0.0, 0.25, up);
	}

	// Disc and halo.
	float disc = 1.0 - smoothstep(disc_size * 0.92, disc_size, sun_angle);
	float halo = pow(max(sun_dot, 0.0), 180.0) * 0.5 + pow(max(sun_dot, 0.0), 12.0) * 0.18;
	col += light * (disc * 4.0 + halo) * disc_energy;

	// Cloud deck on a plane overhead, thinning into haze at the horizon.
	if (up > 0.005 && cloud_cover > 0.0) {
		vec2 uv = dir.xz / (up + 0.14) * 1.6;
		float n = fbm(uv);
		float n2 = fbm(uv * 2.7 + 31.0);
		float density = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n * 0.75 + n2 * 0.25 + cloud_cover * 0.25);
		// Lit where the deck is thin and on the light's side of the sky.
		float toward = pow(max(sun_dot, 0.0), 3.0);
		float thin = 1.0 - smoothstep(0.35, 0.8, n);
		vec3 cloud = mix(cloud_dark, cloud_lit, clamp(thin * 0.75 + toward * 0.6, 0.0, 1.0));
		cloud += light * pow(max(sun_dot, 0.0), 24.0) * thin * 0.6 * disc_energy;
		float horizon_fade = smoothstep(0.0, 0.16, up);
		col = mix(col, mix(horizon_color, cloud, horizon_fade), density * (0.25 + 0.75 * horizon_fade));
	}
	COLOR = col;
}
