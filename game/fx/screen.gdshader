shader_type canvas_item;

// Degradacion de pantalla ligada a los canales de la nave.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vision = 1.0;
uniform float light = 1.0;
uniform float plasma = 0.0;
uniform float heat = 0.0;
uniform float damage = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float bad = clamp(1.0 - vision, 0.0, 1.0);
	uv.x += sin(uv.y * 60.0 + TIME * 7.0) * 0.003 * heat;
	uv.y += cos(uv.x * 50.0 + TIME * 5.0) * 0.002 * heat;
	float glitch = step(0.985 - bad * 0.1 - damage * 0.05, hash(vec2(floor(uv.y * 90.0), floor(TIME * 12.0))));
	uv.x += glitch * (hash(vec2(TIME, uv.y)) - 0.5) * 0.05 * (bad + damage);
	float ab = bad * 0.006 + damage * 0.012;
	vec3 col;
	col.r = textureLod(screen_tex, uv + vec2(ab, 0.0), 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - vec2(ab, 0.0), 0.0).b;
	vec3 blur = textureLod(screen_tex, uv, 2.5 * bad).rgb;
	col = mix(col, blur, bad * 0.6);
	float scan = 0.95 + 0.05 * sin(SCREEN_UV.y * 1100.0);
	col *= mix(1.0, scan, bad);
	col += (hash(SCREEN_UV * vec2(TIME * 61.0 + 1.0, TIME * 37.0 + 1.0)) - 0.5) * (0.008 + bad * 0.25);
	vec2 d = SCREEN_UV - 0.5;
	float vig = smoothstep(0.9, 0.2, length(d) * (1.0 + (1.0 - light) * 1.6));
	col *= mix(1.0, vig, 0.3 + (1.0 - light) * 0.6);
	col *= 0.3 + 0.7 * light;
	col = mix(col, col * vec3(1.4, 0.7, 0.4) + vec3(0.3, 0.1, 0.0), plasma * 0.55);
	col = mix(col, vec3(1.0, 0.1, 0.05), damage * 0.22);
	COLOR = vec4(col, 1.0);
}
