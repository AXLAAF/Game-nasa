shader_type canvas_item;

uniform float pixel_size = 2.0;
uniform vec2 scroll_offset = vec2(0.0, 0.0);
uniform float nebula_intensity = 0.40;
uniform vec4 bg_void : source_color = vec4(0.024, 0.039, 0.071, 1.0);
uniform vec4 nebula_col : source_color = vec4(0.086, 0.15, 0.27, 1.0);
uniform vec4 nebula_accent : source_color = vec4(0.14, 0.24, 0.42, 1.0);

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
	vec2 coord = px * 0.0075 + scroll_offset * 0.0018;

	// Nebulosa PixelSpace cuantizada con trama ordenada Bayer 4x4 (pin_11 + pin_14)
	float neb = fbm(coord * 1.45);
	float dither = bayer4(px);
	float band = smoothstep(0.42, 0.88, neb);
	vec3 col = bg_void.rgb;
	if (band > 0.58 + dither * 0.34) {
		col = mix(bg_void.rgb, nebula_accent.rgb, nebula_intensity);
	} else if (band > 0.24 + dither * 0.34) {
		col = mix(bg_void.rgb, nebula_col.rgb, nebula_intensity * 0.78);
	}

	// Capa 1: estrellas de fondo lejanas con paralaje lento
	vec2 px_far = px + floor(scroll_offset * 0.18);
	float s_far = hash21(px_far);
	if (s_far > 0.9945) {
		col = mix(col, vec3(0.55, 0.61, 0.71), 0.65);
	}

	// Capa 2: estrellas cercanas con paralaje medio y parpadeo
	vec2 px_near = px + floor(scroll_offset * 0.42);
	float s_near = hash21(px_near + vec2(17.0, 31.0));
	if (s_near > 0.9972) {
		float twinkle = 0.72 + 0.28 * sin(TIME * 2.4 + s_near * 120.0);
		col = mix(col, vec3(0.957, 0.922, 0.851), twinkle);
	}

	// Capa 3: estrellas en cruz de 4 puntas (pin_11 + pin_15)
	vec2 cell = floor(px_near / 28.0);
	vec2 local_p = mod(px_near, 28.0);
	float c_hash = hash21(cell + vec2(91.3, 47.7));
	if (c_hash > 0.91) {
		vec2 star_pos = vec2(
			6.0 + floor(hash21(cell + vec2(3.1, 7.2)) * 16.0),
			6.0 + floor(hash21(cell + vec2(11.4, 2.9)) * 16.0)
		);
		vec2 delta = abs(local_p - star_pos);
		float arm = c_hash > 0.965 ? 3.0 : 2.0;
		bool is_center = delta.x < 0.5 && delta.y < 0.5;
		bool is_arm = (delta.x < 0.5 && delta.y <= arm) || (delta.y < 0.5 && delta.x <= arm);
		if (is_center || is_arm) {
			float tw = 0.75 + 0.25 * sin(TIME * 3.0 + c_hash * 90.0);
			vec3 star_col = c_hash > 0.96 ? vec3(0.22, 0.74, 0.97) : vec3(0.957, 0.922, 0.851);
			col = mix(col, star_col, is_center ? tw : tw * 0.68);
		}
	}

	COLOR = vec4(col, 1.0);
}
