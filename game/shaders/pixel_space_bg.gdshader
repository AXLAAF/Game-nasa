shader_type canvas_item;

uniform float pixel_size = 2.0;
uniform vec2 scroll_offset = vec2(0.0, 0.0);
uniform vec2 nebula_shift = vec2(0.0, 0.0);
uniform float nebula_intensity = 0.72;
uniform float stars = 1.0; // 0 = cielo de dia: sin estrellas ni nebulosa
uniform vec4 bg_void : source_color = vec4(0.024, 0.039, 0.085, 1.0);
uniform vec4 nebula_col : source_color = vec4(0.09, 0.17, 0.34, 1.0);
uniform vec4 nebula_accent : source_color = vec4(0.14, 0.42, 0.54, 1.0);
uniform vec4 nebula_warm : source_color = vec4(0.28, 0.12, 0.34, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
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
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor((UV * res) / max(pixel_size, 1.0));
	vec2 coord = px * 0.0075 + scroll_offset * 0.0018 + nebula_shift;

	// Nebulosa PixelSpace cuantizada con trama ordenada Bayer 4x4, niebla suave y nucleos HDR
	float neb = fbm(coord * 1.45);
	float neb_warm = fbm(coord * 1.15 + vec2(11.3, -7.1) - nebula_shift * 0.35);
	float mist_a = fbm(coord * 0.72 + vec2(TIME * 0.014, -TIME * 0.009));
	float mist_b = fbm(coord * 0.95 + vec2(-TIME * 0.011 + 4.2, TIME * 0.012));
	float mist_mask = smoothstep(0.32, 0.84, mist_a * 0.6 + mist_b * 0.4);
	float dither = bayer4(px);
	float band = smoothstep(0.32, 0.86, neb);
	float warm_band = smoothstep(0.44, 0.90, neb_warm);
	vec3 mist_tint = mix(nebula_col.rgb, nebula_accent.rgb, smoothstep(0.35, 0.75, mist_b));
	vec3 col = mix(bg_void.rgb, mist_tint * 1.15, mist_mask * 0.48 * nebula_intensity * stars);
	if (band > 0.72 + dither * 0.24) {
		col = mix(col, nebula_accent.rgb * 2.35, nebula_intensity * stars);
	} else if (band > 0.50 + dither * 0.30) {
		col = mix(col, nebula_accent.rgb * 1.45, nebula_intensity * stars);
	} else if (band > 0.18 + dither * 0.32) {
		col = mix(col, nebula_col.rgb * 1.18, nebula_intensity * 0.85 * stars);
	}
	if (warm_band > 0.66 + dither * 0.26) {
		col = mix(col, nebula_warm.rgb * 2.15, nebula_intensity * 0.78 * stars);
	} else if (warm_band > 0.42 + dither * 0.32) {
		col = mix(col, nebula_warm.rgb * 1.35, nebula_intensity * 0.65 * stars);
	}

	// Capa 1: estrellas de fondo lejanas con paralaje lento y tinte espectral
	vec2 px_far = px + floor(scroll_offset * 0.18);
	float s_far = hash21(px_far);
	if (s_far > 0.9968) {
		float hue_pick = hash21(px_far + vec2(3.7, 9.1));
		vec3 far_col = hue_pick > 0.65 ? vec3(0.68, 0.88, 1.22) : (hue_pick < 0.25 ? vec3(1.18, 0.92, 0.68) : vec3(0.88, 0.95, 1.08));
		col = mix(col, far_col, 0.78 * stars);
	}

	// Capa 2: estrellas cercanas con paralaje medio, color espectral y brillo HDR para bloom
	vec2 px_near = px + floor(scroll_offset * 0.42);
	float s_near = hash21(px_near + vec2(17.0, 31.0));
	if (s_near > 0.9983) {
		float twinkle = 0.75 + 0.25 * sin(TIME * 2.4 + s_near * 120.0);
		float sp = hash21(px_near + vec2(51.0, 19.0));
		vec3 near_col = sp > 0.7 ? vec3(0.85, 1.22, 1.60) : (sp < 0.28 ? vec3(1.52, 1.12, 0.68) : vec3(1.42, 1.36, 1.22));
		col = mix(col, near_col, twinkle * stars);
	}

	// Capa 3: estrellas en cruz de 4 puntas (pin_11 + pin_15) con nucleo HDR
	vec2 cell = floor(px_near / 28.0);
	vec2 local_p = mod(px_near, 28.0);
	float c_hash = hash21(cell + vec2(91.3, 47.7));
	if (c_hash > 0.90) {
		vec2 star_pos = vec2(
			6.0 + floor(hash21(cell + vec2(3.1, 7.2)) * 16.0),
			6.0 + floor(hash21(cell + vec2(11.4, 2.9)) * 16.0)
		);
		vec2 delta = abs(local_p - star_pos);
		float arm = c_hash > 0.962 ? 3.0 : 2.0;
		bool is_center = delta.x < 0.5 && delta.y < 0.5;
		bool is_arm = (delta.x < 0.5 && delta.y <= arm) || (delta.y < 0.5 && delta.x <= arm);
		if (is_center || is_arm) {
			float tw = 0.78 + 0.22 * sin(TIME * 3.0 + c_hash * 90.0);
			vec3 star_col = c_hash > 0.965 ? vec3(0.75, 1.35, 1.85) : (c_hash < 0.925 ? vec3(1.75, 1.25, 0.72) : vec3(1.60, 1.50, 1.35));
			col = mix(col, star_col, (is_center ? tw : tw * 0.6) * stars);
		}
	}

	// Capa 4: motas de polvo cosmico flotando lentamente
	vec2 px_dust = px + floor(scroll_offset * 0.65 + vec2(TIME * 2.2, -TIME * 1.1));
	float s_dust = hash21(px_dust + vec2(73.1, 13.7));
	if (s_dust > 0.9978) {
		float drift = 0.32 + 0.30 * sin(TIME * 1.5 + s_dust * 60.0);
		vec3 dust_col = mix(nebula_accent.rgb, nebula_warm.rgb, fract(s_dust * 37.0)) * 1.55;
		col = mix(col, dust_col, drift * stars);
	}

	COLOR = vec4(col, 1.0);
}
