shader_type canvas_item;

uniform int planet_type : hint_range(0, 4) = 0;
uniform float pixels = 96.0;
uniform float seed = 4.2;
uniform vec2 light_dir = vec2(-0.707, -0.707);
uniform float spin_speed = 0.04;
uniform vec4 col_a : source_color = vec4(0.11, 0.31, 0.56, 1.0);
uniform vec4 col_b : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform vec4 col_c : source_color = vec4(0.96, 0.92, 0.85, 1.0);
uniform vec4 col_atmo : source_color = vec4(0.22, 0.74, 0.97, 0.45);
uniform vec4 col_night : source_color = vec4(0.031, 0.047, 0.086, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

float bayer4(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int idx = x + y * 4;
	if (idx == 0) return 0.0 / 16.0;
	if (idx == 1) return 8.0 / 16.0;
	if (idx == 2) return 2.0 / 16.0;
	if (idx == 3) return 10.0 / 16.0;
	if (idx == 4) return 12.0 / 16.0;
	if (idx == 5) return 4.0 / 16.0;
	if (idx == 6) return 14.0 / 16.0;
	if (idx == 7) return 6.0 / 16.0;
	if (idx == 8) return 3.0 / 16.0;
	if (idx == 9) return 11.0 / 16.0;
	if (idx == 10) return 1.0 / 16.0;
	if (idx == 11) return 9.0 / 16.0;
	if (idx == 12) return 15.0 / 16.0;
	if (idx == 13) return 7.0 / 16.0;
	if (idx == 14) return 13.0 / 16.0;
	return 5.0 / 16.0;
}

void fragment() {
	vec2 px = floor(UV * pixels);
	vec2 uv = (px + 0.5) / pixels;
	vec2 d = (uv - 0.5) * 2.0;
	float r2 = dot(d, d);
	float r_lim = 1.0;

	if (planet_type == 4) {
		float ang = atan(d.y, d.x);
		float rock = fbm(vec2(cos(ang) * 1.8 + seed, sin(ang) * 1.8 - seed));
		r_lim = 0.68 + 0.24 * rock;
	}

	if (r2 > r_lim) {
		if (planet_type == 4) {
			COLOR = vec4(0.0);
		} else {
			float dist = sqrt(r2);
			float dither = bayer4(px);
			float rim = smoothstep(1.14, 0.98, dist);
			float quant = step(dither * 0.65, rim);
			COLOR = vec4(col_atmo.rgb, col_atmo.a * quant * 0.42);
		}
	} else {
		float nr2 = clamp(r2 / max(r_lim, 0.001), 0.0, 1.0);
		float z = sqrt(max(1.0 - nr2, 0.0));
		vec3 normal = normalize(vec3(d.x, d.y, z));
		float lon = atan(d.x, z) + TIME * spin_speed;
		float lat = asin(clamp(d.y, -1.0, 1.0));
		vec2 sphere_uv = vec2(lon * 1.4, lat * 2.2);

		float n = 0.0;
		if (planet_type == 3) {
			// Gigante gaseoso (Jupiter): bandas zonales turbulentas + vortice
			float turb = fbm(sphere_uv * 2.1);
			float band = sin(lat * 15.0 + turb * 3.4) * 0.5 + 0.5;
			float storm_d = length(vec2(mod(lon + 1.2, 6.28318) - 3.14159, (lat - 0.35) * 2.2));
			float spot = smoothstep(0.45, 0.12, storm_d);
			n = mix(mix(band, fbm(vec2(lon * 2.6, lat * 6.5)), 0.32), 0.15, spot * 0.75);
		} else if (planet_type == 1) {
			// Luna: mares basalticos y crateres anulares
			n = fbm(sphere_uv * 2.3);
			float c_cell = noise(sphere_uv * 7.5);
			float crater_floor = smoothstep(0.64, 0.72, c_cell);
			float crater_rim = smoothstep(0.58, 0.63, c_cell) * (1.0 - crater_floor);
			n = clamp(n - crater_floor * 0.28 + crater_rim * 0.22, 0.0, 1.0);
		} else if (planet_type == 2) {
			// Marte: planicies oxidadas, cañon ecuatorial y casquetes polares
			n = fbm(sphere_uv * 2.6);
			float canyon = smoothstep(0.18, 0.03, abs(lat + 0.12 * sin(lon * 2.0)));
			n = clamp(n - canyon * 0.26, 0.0, 1.0);
			if (abs(lat) > 1.12 + 0.08 * noise(sphere_uv * 4.0)) {
				n = 0.94;
			}
		} else if (planet_type == 4) {
			// Asteroide NEO: regolito gris/terroso y crateres profundos
			n = fbm(sphere_uv * 3.1);
			float cr = smoothstep(0.60, 0.72, noise(sphere_uv * 6.5));
			n = clamp(n - cr * 0.32, 0.0, 1.0);
		} else {
			// Tierra: oceanos, continentes y capa de nubes independiente
			n = fbm(sphere_uv * 2.4);
			float clouds = fbm(sphere_uv * 3.8 + vec2(TIME * spin_speed * 0.65, 0.4));
			if (clouds > 0.63) {
				n = 0.95;
			}
		}

		vec3 surf = col_a.rgb;
		if (n > 0.76) {
			surf = col_c.rgb;
		} else if (n > 0.46) {
			surf = col_b.rgb;
		}

		vec3 l3 = normalize(vec3(light_dir.x, light_dir.y, 0.55));
		float ndl = clamp(dot(normal, l3), 0.0, 1.0);
		float dither = bayer4(px);

		vec3 lit = col_night.rgb;
		if (ndl > 0.68 + dither * 0.14) {
			lit = surf * 1.10;
		} else if (ndl > 0.36 + dither * 0.16) {
			lit = surf * 0.78;
		} else if (ndl > 0.15 + dither * 0.16) {
			lit = mix(col_night.rgb, surf * 0.45, 0.85);
		} else {
			lit = mix(col_night.rgb, surf * 0.18, 0.35);
		}

		if (planet_type != 4) {
			float fresnel = pow(1.0 - z, 2.4) * smoothstep(-0.08, 0.55, ndl);
			lit = mix(lit, col_atmo.rgb, clamp(fresnel * col_atmo.a * 1.5, 0.0, 0.75));
		}

		COLOR = vec4(lit, 1.0);
	}
}
