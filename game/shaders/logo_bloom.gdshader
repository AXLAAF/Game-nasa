shader_type canvas_item;

uniform float animate = 1.0;
uniform float tex_scale = 0.82;
uniform vec2 center_offset = vec2(0.013, -0.008);
uniform vec4 star_glow : source_color = vec4(0.62, 0.90, 1.0, 1.0);
uniform vec4 orb_glow : source_color = vec4(0.18, 0.56, 1.0, 1.0);

float inside_uv(vec2 p) {
	vec2 b = abs(p - vec2(0.5));
	return step(b.x, 0.5) * step(b.y, 0.5);
}

void fragment() {
	vec2 uv = (UV - vec2(0.5)) / tex_scale + vec2(0.5) + center_offset;
	vec4 base = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * inside_uv(uv);

	float t = TIME * animate;
	float pulse = 0.5 + 0.5 * sin(t * 2.2);

	// Halo multi-muestra alrededor de las zonas brillantes y del planeta azul
	vec3 bloom = vec3(0.0);
	float bloom_alpha = 0.0;
	for (int ring = 1; ring <= 3; ring++) {
		float radius = float(ring) * 0.020;
		float weight = 0.11 / float(ring);
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.78539816 + float(ring) * 0.39;
			vec2 suv = uv + vec2(cos(angle), sin(angle)) * radius;
			vec4 s = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0))) * inside_uv(suv);
			float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			float blue_mask = clamp((s.b - s.r) * 2.2, 0.0, 1.0);
			float energy = (smoothstep(0.28, 0.95, lum) * 0.9 + blue_mask * 0.85) * s.a;
			vec3 tint = mix(star_glow.rgb, orb_glow.rgb, blue_mask);
			bloom += tint * energy * weight;
			bloom_alpha += energy * weight;
		}
	}

	// Brillo radial sutil en el centro de la estrella
	float center_dist = length(UV - vec2(0.5));
	float core_halo = exp(-center_dist * 7.2) * (0.28 + 0.08 * pulse);
	bloom += star_glow.rgb * core_halo;
	bloom_alpha += core_halo * 0.55;

	// Realce de la mitad oscura del anillo para que no se pierda sobre el cielo negro
	vec3 fg = base.rgb;
	float is_dark_ring = base.a * (1.0 - smoothstep(0.14, 0.42, max(fg.r, max(fg.g, fg.b))));
	fg = mix(fg, vec3(0.24, 0.36, 0.46), is_dark_ring * 0.85);

	// Emision HDR para activar el bloom de WorldEnvironment sobre la estrella y el punto azul
	float base_lum = dot(fg, vec3(0.299, 0.587, 0.114));
	float orb_mask = clamp((fg.b - fg.r) * 2.0, 0.0, 1.0) * base.a;
	float glint = smoothstep(0.75, 1.0, cos((UV.x + UV.y) * 5.0 - t * 1.4)) * step(0.5, animate);
	float hdr_boost = smoothstep(0.72, 0.98, base_lum) * (0.22 + 0.10 * pulse + 0.12 * glint);
	fg += fg * hdr_boost + orb_glow.rgb * (orb_mask * (0.35 + 0.14 * pulse));

	// Fundido suave hacia los bordes para evitar cortes en el rectangulo del nodo
	float edge_fade = smoothstep(0.50, 0.36, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	vec3 final_rgb = mix(bloom * 1.25, fg + bloom * 0.42, base.a);
	float final_a = clamp(max(base.a, bloom_alpha * 0.82), 0.0, 1.0) * edge_fade;

	COLOR = vec4(final_rgb, final_a);
}
