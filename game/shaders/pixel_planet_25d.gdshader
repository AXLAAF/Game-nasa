shader_type canvas_item;

uniform int planet_type : hint_range(0, 3) = 0;
uniform float pixels = 96.0;
uniform float seed = 4.2;
uniform vec2 light_dir = vec2(-0.707, -0.707);
uniform float spin_speed = 0.04;
uniform vec4 col_a : source_color = vec4(0.11, 0.31, 0.56, 1.0);
uniform vec4 col_b : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform vec4 col_c : source_color = vec4(0.96, 0.92, 0.85, 1.0);
uniform vec4 col_atmo : source_color = vec4(0.22, 0.74, 0.97, 0.45);

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

	if (r2 > 1.0) {
		float rim = smoothstep(1.12, 0.96, sqrt(r2));
		COLOR = vec4(col_atmo.rgb, col_atmo.a * rim * 0.45);
	} else {
		float z = sqrt(max(1.0 - r2, 0.0));
		vec3 normal = normalize(vec3(d.x, d.y, z));
		// Proyeccion esferica simple + rotacion
		float lon = atan(d.x, z) + TIME * spin_speed;
		float lat = asin(clamp(d.y, -1.0, 1.0));
		vec2 sphere_uv = vec2(lon * 1.4, lat * 2.2);

		float n = 0.0;
		if (planet_type == 3) {
			// Gigante gaseoso (Jupiter): bandas horizontales turbulentas
			float band = sin(lat * 14.0 + fbm(sphere_uv * 2.0) * 3.0) * 0.5 + 0.5;
			n = mix(band, fbm(vec2(lon * 2.5, lat * 6.0)), 0.35);
		} else if (planet_type == 1) {
			// Luna: mares y crateres de alto contraste
			n = fbm(sphere_uv * 2.2);
			float cr = smoothstep(0.62, 0.72, noise(sphere_uv * 8.0));
			n = clamp(n - cr * 0.25, 0.0, 1.0);
		} else if (planet_type == 2) {
			// Marte: planicies oxidadas, casquetes y cañon
			n = fbm(sphere_uv * 2.6);
			if (abs(lat) > 1.15) {
				n = 0.92;
			}
		} else {
			// Tierra / Terran: oceanos, continentes y nubes
			n = fbm(sphere_uv * 2.4);
			float clouds = fbm(sphere_uv * 3.8 + vec2(TIME * spin_speed * 0.6, 0.0));
			if (clouds > 0.64) {
				n = 0.95;
			}
		}

		vec3 surf = col_a.rgb;
		if (n > 0.78) {
			surf = col_c.rgb;
		} else if (n > 0.48) {
			surf = col_b.rgb;
		}

		vec3 l3 = normalize(vec3(light_dir.x, light_dir.y, 0.55));
		float ndl = clamp(dot(normal, l3), 0.0, 1.0);
		float dither = bayer4(px);
		float shade = 0.14;
		if (ndl > 0.68 + dither * 0.14) {
			shade = 1.08;
		} else if (ndl > 0.35 + dither * 0.16) {
			shade = 0.76;
		} else if (ndl > 0.14 + dither * 0.16) {
			shade = 0.42;
		}

		vec3 final_col = surf * shade;
		// Rim atmosferico del lado iluminado
		float fresnel = pow(1.0 - z, 2.4) * smoothstep(-0.1, 0.5, ndl);
		final_col = mix(final_col, col_atmo.rgb, clamp(fresnel * col_atmo.a * 1.6, 0.0, 0.75));
		COLOR = vec4(final_col, 1.0);
	}
}
