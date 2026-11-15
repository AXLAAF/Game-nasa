shader_type canvas_item;

// Cortina diagonal a 13 grados con haz optico al abrir y cerrar entre fases.
uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec4 curtain_color : source_color = vec4(0.035, 0.045, 0.075, 1.0);
uniform vec4 beam_color : source_color = vec4(0.68, 0.88, 1.0, 1.0);
uniform float skew_tan = 0.230868;

void fragment() {
	if (progress <= 0.001 || progress >= 1.999) {
		COLOR = vec4(0.0);
	} else {
		float half_skew = 0.5 * abs(skew_tan) + 0.06;
		float min_sx = -half_skew;
		float max_sx = 1.0 + half_skew;
		float sx = UV.x + (UV.y - 0.5) * skew_tan;
		bool closing = progress <= 1.0;
		float t = closing ? clamp(progress, 0.0, 1.0) : clamp(progress - 1.0, 0.0, 1.0);
		float edge = mix(min_sx, max_sx, t);
		float cover = closing ? (1.0 - smoothstep(edge - 0.012, edge + 0.006, sx)) : smoothstep(edge - 0.006, edge + 0.012, sx);
		float dist = abs(sx - edge);
		float beam = exp(-(dist * dist) / (closing ? 0.0022 : 0.0042));
		float hairline = exp(-(dist * dist) / 0.00018);
		float echo = exp(-pow((sx - (edge - 0.075)) / 0.025, 2.0)) * (closing ? 0.35 : 0.55);
		float edge_fade = sin(t * 3.14159265);
		vec3 col = curtain_color.rgb + beam_color.rgb * (beam * 0.42 + hairline * 0.65 + echo * 0.25) * edge_fade;
		float alpha = clamp(max(cover, (beam * 0.68 + hairline * 0.85) * edge_fade), 0.0, 1.0);
		COLOR = vec4(col, alpha);
	}
}
