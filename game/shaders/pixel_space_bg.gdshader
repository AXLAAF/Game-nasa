shader_type canvas_item;

uniform float pixel_size = 2.0;
uniform vec2 scroll_offset = vec2(0.0, 0.0);
uniform float nebula_intensity = 0.35;
uniform vec4 bg_void : source_color = vec4(0.024, 0.039, 0.071, 1.0);
uniform vec4 nebula_col : source_color = vec4(0.086, 0.15, 0.27, 1.0);

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

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor((UV * res) / pixel_size);
	vec2 coord = px * 0.008 + scroll_offset * 0.002;

	float neb = fbm(coord * 1.4);
	float band = smoothstep(0.45, 0.85, neb);
	vec3 col = mix(bg_void.rgb, nebula_col.rgb, band * nebula_intensity);

	// Estrellas lejanas y cercanas cuantizadas por pixel
	float s1 = hash21(px + floor(scroll_offset * 0.2));
	if (s1 > 0.9965) {
		float twinkle = 0.72 + 0.28 * sin(TIME * 2.4 + s1 * 120.0);
		col = mix(col, vec3(0.95, 0.92, 0.85), twinkle);
	} else if (s1 > 0.992) {
		col = mix(col, vec3(0.55, 0.61, 0.71), 0.55);
	}

	COLOR = vec4(col, 1.0);
}
