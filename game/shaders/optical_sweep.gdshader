shader_type canvas_item;

// Barrido optico en contrainclinacion (-13 deg) sobre paneles y tarjetas al desplegarse.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 beam_color : source_color = vec4(0.75, 0.90, 1.0, 0.28);
uniform float skew_tan = -0.230868;

void fragment() {
	if (progress <= 0.001 || progress >= 0.999) {
		COLOR = vec4(0.0);
	} else {
		float half_skew = 0.5 * abs(skew_tan) + 0.16;
		float edge = mix(-half_skew, 1.0 + half_skew, progress);
		float sx = UV.x + (UV.y - 0.5) * skew_tan;
		float dist = sx - edge;
		float main_beam = exp(-(dist * dist) / 0.012);
		float laser_line = exp(-(dist * dist) / 0.00045);
		float fade = sin(progress * 3.14159265);
		float a = (main_beam * beam_color.a + laser_line * beam_color.a * 1.15) * fade;
		COLOR = vec4(beam_color.rgb, clamp(a, 0.0, 0.55));
	}
}
