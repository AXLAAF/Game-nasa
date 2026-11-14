shader_type canvas_item;

// Fondo procedural: tres capas de estrellas con parallax y una nebulosa suave.
uniform vec2 offset = vec2(0.0);
uniform float stars = 1.0;
uniform vec4 sky : source_color = vec4(0.015, 0.02, 0.05, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 star_layer(vec2 uv, float scale, float speed, float density) {
	vec2 p = uv * scale + offset * speed;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(cell);
	if (h > density) {
		return vec3(0.0);
	}
	vec2 jitter = vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5;
	float d = length(f - jitter * 0.7);
	float twinkle = 0.6 + 0.4 * sin(TIME * (1.0 + h * 40.0) + h * 50.0);
	float s = smoothstep(0.09, 0.0, d) * twinkle;
	vec3 c = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), hash(cell + 3.3));
	return c * s;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = (UV - 0.5) * vec2(aspect, 1.0);
	vec3 col = sky.rgb;
	vec2 n_uv = uv + offset * 0.00005;
	float n = sin(n_uv.x * 3.1 + 1.7) * cos(n_uv.y * 2.3 - 0.4) + 0.5 * sin(n_uv.x * 7.0 + n_uv.y * 5.0);
	col += vec3(0.06, 0.02, 0.10) * smoothstep(0.3, 1.4, n) * stars;
	col += vec3(0.0, 0.03, 0.06) * smoothstep(0.5, 1.5, -n) * stars;
	vec3 s = star_layer(uv, 70.0, 0.0004, 0.10) * 0.5;
	s += star_layer(uv, 38.0, 0.0012, 0.07) * 0.9;
	s += star_layer(uv, 18.0, 0.003, 0.045) * 1.6;
	col += s * stars;
	COLOR = vec4(col, 1.0);
}
