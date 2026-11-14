shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.043, 0.055, 0.090, 1.0);
uniform float outline_width = 1.5;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}

	vec2 step_uv = SCREEN_PIXEL_SIZE * outline_width;
	float a_up = textureLod(screen_texture, SCREEN_UV + vec2(0.0, -step_uv.y), 0.0).a;
	float a_dn = textureLod(screen_texture, SCREEN_UV + vec2(0.0, step_uv.y), 0.0).a;
	float a_lt = textureLod(screen_texture, SCREEN_UV + vec2(-step_uv.x, 0.0), 0.0).a;
	float a_rt = textureLod(screen_texture, SCREEN_UV + vec2(step_uv.x, 0.0), 0.0).a;
	float neighbor = max(max(a_up, a_dn), max(a_lt, a_rt));

	if (c.a < 0.25 && neighbor > 0.35) {
		COLOR = outline_color;
	} else {
		COLOR = c;
	}
}
