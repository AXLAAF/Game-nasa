shader_type canvas_item;
render_mode unshaded;

uniform int planet_type : hint_range(0, 4) = 0;
uniform float pixels = 96.0;
uniform float halo_scale = 1.28;
uniform float seed = 4.2;
uniform vec2 light_dir = vec2(-0.707, -0.707);
uniform float spin_speed = 0.04;
uniform vec4 col_a : source_color = vec4(0.11, 0.31, 0.56, 1.0);
uniform vec4 col_b : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform vec4 col_c : source_color = vec4(0.96, 0.92, 0.85, 1.0);
uniform vec4 col_atmo : source_color = vec4(0.22, 0.74, 0.97, 0.45);
uniform vec4 col_night : source_color = vec4(0.031, 0.047, 0.086, 1.0);
uniform float ring = 0.0; // 1.0 dibuja anillos; el rectangulo debe cubrir 2.27 radios (halo_scale)
uniform vec4 col_ring : source_color = vec4(0.93, 0.84, 0.62, 1.0);
uniform float eclipse : hint_range(0.0, 1.0) = 0.0; // 1 aplasta el dia a la noche
uniform float sun_energy : hint_range(0.0, 3.0) = 1.0; // sube en llamarada para que el glow HDR florezca

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

// Anillo: giro de 15 grados y coseno de inclinacion 0.3, el mismo que aplasta la elipse al dibujarla.
const float RING_C = 0.9659258;
const float RING_S = 0.2588190;
const float RING_TAN = 3.179797;
const vec3 RING_N = vec3(0.0, 0.9539392, 0.3);
const float ATMO_R = 1.24;
const vec3 VIEW_DIR = vec3(0.0, 0.0, 1.0);

// t mas cercano con t > 0. La esfera esta en el origen.
float ray_sphere(vec3 ro, vec3 rd, float radius) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - radius * radius;
	float h = b * b - c;
	if (h < 0.0) {
		return -1.0;
	}
	float s = sqrt(h);
	float t0 = -b - s;
	if (t0 > 0.02) {
		return t0;
	}
	float t1 = -b + s;
	return t1 > 0.02 ? t1 : -1.0;
}

// Entrada y salida. x < 0 si el rayo no toca.
vec2 ray_sphere_span(vec3 ro, vec3 rd, float radius) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - radius * radius;
	float h = b * b - c;
	if (h < 0.0) {
		return vec2(-1.0, -1.0);
	}
	float s = sqrt(h);
	return vec2(-b - s, -b + s);
}

vec3 to_ring(vec3 p) {
	return vec3(p.x * RING_C - p.y * RING_S, p.x * RING_S + p.y * RING_C, p.z);
}

float ring_band(float rad, float dither) {
	if (pixels / halo_scale < 18.0) {
		return rad > 1.3 && rad < 2.27 ? 1.0 : 0.0;
	}
	if (rad > 1.53 && rad < 1.95) {
		return 1.0;
	}
	if (rad > 2.03 && rad < 2.27) {
		return 0.74;
	}
	if (rad > 1.24 && rad <= 1.53 && dither < 0.5) {
		return 0.5;
	}
	return 0.0;
}

// Rayo hacia el sol contra el plano del anillo. 0 fuera, hasta 1 en la banda B.
float ring_occlusion(vec3 p, vec3 L, float dither) {
	if (ring < 0.5) {
		return 0.0;
	}
	vec3 pr = to_ring(p);
	vec3 lr = to_ring(L);
	float denom = dot(RING_N, lr);
	if (abs(denom) < 0.001) {
		return 0.0;
	}
	float t = -dot(RING_N, pr) / denom;
	if (t < 0.04) {
		return 0.0;
	}
	return ring_band(length(pr + lr * t), dither);
}

// Seis muestras entre t0 y t1. rd es (0,0,-1): la camara ortografica mira desde +Z.
vec4 march_air(vec3 ro, float t0, float t1, vec3 L, float dither) {
	vec4 result = vec4(0.0);
	if (t1 <= t0 + 0.0001 || col_atmo.a <= 0.02) {
		return result;
	}
	float scatter = 0.0;
	float dt = (t1 - t0) / 6.0;
	for (int i = 0; i < 6; i++) {
		float t = t0 + (float(i) + 0.5) * dt;
		vec3 p = vec3(ro.xy, ro.z - t);
		float dens = exp(-max(length(p) - 1.0, 0.0) * 18.0);
		float blocked = ray_sphere(p, L, 1.0) > 0.0 ? 1.0 : 0.0;
		float occ = max(blocked, ring_occlusion(p, L, dither));
		float sun = max((1.0 - occ) * (1.0 - eclipse), 0.07);
		float mu = clamp(dot(normalize(p), L), 0.0, 1.0);
		scatter += dens * dt * sun * (0.3 + 0.7 * mu);
	}
	result.rgb = col_atmo.rgb * scatter * 3.6 * sun_energy;
	result.a = col_atmo.a * clamp(scatter * 2.0, 0.0, 1.0);
	return result;
}

void fragment() {
	vec2 px = floor(UV * pixels);
	vec2 uv = (px + 0.5) / pixels;
	vec2 d = (uv - 0.5) * 2.0 * halo_scale;
	float r2 = dot(d, d);
	float r_lim = 1.0;
	vec2 sun_dir = normalize(light_dir + vec2(0.0001, 0.0));

	if (planet_type == 4) {
		float ang = atan(d.y, d.x);
		float rock = fbm(vec2(cos(ang) * 1.8 + seed, sin(ang) * 1.8 - seed));
		r_lim = 0.68 + 0.24 * rock;
	}

	if (r2 > r_lim) {
		if (planet_type == 4) {
			COLOR = vec4(0.0);
		} else {
			float dither = bayer4(px);
			vec3 L = normalize(vec3(sun_dir, 0.55));
			vec3 ro = vec3(d, 4.0);
			vec2 span = ray_sphere_span(ro, vec3(0.0, 0.0, -1.0), ATMO_R);
			if (span.x < 0.0) {
				COLOR = vec4(0.0);
			} else {
				vec4 air = march_air(ro, span.x, span.y, L, dither);
				float quant = air.a > 0.001 ? step(dither * 0.5, air.a) : 0.0;
				COLOR = vec4(air.rgb, clamp(air.a, 0.0, 1.0) * quant);
			}
		}
	} else {
		float nr2 = clamp(r2 / max(r_lim, 0.001), 0.0, 1.0);
		float z = sqrt(max(1.0 - nr2, 0.0));
		float lon = atan(d.x, z) + TIME * spin_speed;
		float lat = asin(clamp(d.y, -1.0, 1.0));
		vec2 sphere_uv = vec2(lon * 1.4, lat * 2.2);

		float n = 0.0;
		if (planet_type == 3) {
			// Gigante gaseoso (Jupiter): bandas zonales turbulentas + vortice
			float turb = fbm(sphere_uv * 2.1);
			float band = sin(lat * 15.0 + turb * 3.4) * 0.5 + 0.5;
			float storm_d = length(vec2(mod(lon + 1.2, 6.28318) - 3.14159, (lat - 0.35) * 2.2));
			float spot = smoothstep(0.45, 0.12, storm_d);
			n = mix(mix(band, fbm(vec2(lon * 2.6, lat * 6.5)), 0.32), 0.15, spot * 0.75);
		} else if (planet_type == 1) {
			// Luna: mares basalticos y crateres anulares
			n = fbm(sphere_uv * 2.3);
			float c_cell = noise(sphere_uv * 7.5);
			float crater_floor = smoothstep(0.64, 0.72, c_cell);
			float crater_rim = smoothstep(0.58, 0.63, c_cell) * (1.0 - crater_floor);
			n = clamp(n - crater_floor * 0.28 + crater_rim * 0.22, 0.0, 1.0);
		} else if (planet_type == 2) {
			// Marte: planicies oxidadas, cañon ecuatorial y casquetes polares
			n = fbm(sphere_uv * 2.6);
			float canyon = smoothstep(0.18, 0.03, abs(lat + 0.12 * sin(lon * 2.0)));
			n = clamp(n - canyon * 0.26, 0.0, 1.0);
			if (abs(lat) > 1.12 + 0.08 * noise(sphere_uv * 4.0)) {
				n = 0.94;
			}
		} else if (planet_type == 4) {
			// Asteroide NEO: regolito gris/terroso y crateres profundos
			n = fbm(sphere_uv * 3.1);
			float cr = smoothstep(0.60, 0.72, noise(sphere_uv * 6.5));
			n = clamp(n - cr * 0.32, 0.0, 1.0);
		} else {
			// Tierra: oceanos, continentes y capa de nubes independiente
			n = fbm(sphere_uv * 2.4);
			float clouds = fbm(sphere_uv * 3.8 + vec2(TIME * spin_speed * 0.65, 0.4));
			if (clouds > 0.63) {
				n = 0.95;
			}
		}

		vec3 surf = col_a.rgb;
		if (n > 0.76) {
			surf = col_c.rgb;
		} else if (n > 0.46) {
			surf = col_b.rgb;
		}

		vec3 L = normalize(vec3(sun_dir, 0.55));
		float dither = bayer4(px);
		vec3 hit = vec3(d, sqrt(max(r_lim * r_lim - r2, 0.0)));
		vec3 normal = normalize(hit);
		// Rayo de sombra: la esfera se tapa sola; el anillo se cruza con el plano inclinado.
		float ndl_raw = clamp(dot(normal, L), 0.0, 1.0);
		if (ray_sphere(hit + normal * 0.04, L, max(r_lim, 0.2)) > 0.0) {
			ndl_raw = 0.0;
		}
		vec3 side = normalize(cross(L, normal) + vec3(0.0001, 0.0, 0.0));
		float occ = ring_occlusion(hit + normal * 0.05, L, dither);
		occ += ring_occlusion(hit + side * 0.07 + normal * 0.05, L, dither);
		occ += ring_occlusion(hit - side * 0.07 + normal * 0.05, L, dither);
		occ /= 3.0;
		ndl_raw *= 1.0 - occ * 0.85;
		float ndl = ndl_raw * (1.0 - eclipse);

		vec3 lit = col_night.rgb;
		if (ndl > 0.68 + dither * 0.14) {
			lit = surf * 1.12 * sun_energy;
		} else if (ndl > 0.36 + dither * 0.16) {
			lit = surf * 0.88 * mix(1.0, sun_energy, 0.65);
		} else if (ndl > 0.15 + dither * 0.16) {
			lit = mix(col_night.rgb, surf * 0.54, 0.85);
		} else {
			lit = mix(col_night.rgb, surf * 0.22, 0.40);
		}

		// Fisuras incandescentes en mundos volcanicos (col_c HDR > 1.0) visibles incluso de noche
		float lava_glow = max(max(col_c.r, col_c.g), col_c.b);
		if (planet_type == 2 && lava_glow > 1.05 && n > 0.78) {
			lit = max(lit, col_c.rgb * 1.65);
		}

		// Reflejo solar. El medio vector usa la camara en +Z, no una luz inventada.
		vec3 half_dir = normalize(L + VIEW_DIR);
		float spec = pow(max(dot(normal, half_dir), 0.0), 24.0);
		if (planet_type == 0 && n <= 0.46) {
			lit += vec3(1.45, 1.85, 2.35) * spec * smoothstep(0.2, 0.8, ndl) * sun_energy;
		}

		// Aire entre la camara y el suelo: el limbo es el tramo largo del mismo rayo.
		if (planet_type != 4 && col_atmo.a > 0.02) {
			vec3 ro = vec3(d, 4.0);
			vec2 span = ray_sphere_span(ro, vec3(0.0, 0.0, -1.0), ATMO_R);
			float t_hit = 4.0 - hit.z;
			if (span.x > 0.0 && t_hit > span.x) {
				vec4 air = march_air(ro, span.x, t_hit, L, dither);
				lit = mix(lit, max(lit, air.rgb), clamp(air.a, 0.0, 0.82));
			}
		} else if (planet_type != 4) {
			float fresnel = pow(1.0 - z, 2.2) * smoothstep(-0.08, 0.55, ndl_raw) * (1.0 - eclipse);
			lit = mix(lit, col_c.rgb * 1.65 * sun_energy, clamp(fresnel * 0.55, 0.0, 0.45));
		}

		COLOR = vec4(lit, 1.0);
	}

	// Anillos: elipse inclinada 15 grados; la mitad lejana queda oculta tras el disco.
	// [DIS] radios en radios planetarios, aproximados a los anillos C, B y A de Saturno.
	if (ring > 0.5) {
		vec2 q = vec2(d.x * 0.966 - d.y * 0.259, d.x * 0.259 + d.y * 0.966);
		float rr = length(vec2(q.x, q.y / 0.3));
		float shade = 0.0;
		if (pixels / halo_scale < 18.0) {
			// Con pocos texeles las bandas no caben: un solo anillo macizo.
			shade = rr > 1.3 && rr < 2.27 ? 1.0 : 0.0;
		} else if (rr > 1.53 && rr < 1.95) {
			shade = 1.0;
		} else if (rr > 2.03 && rr < 2.27) {
			shade = 0.74;
		} else if (rr > 1.24 && rr <= 1.53 && bayer4(px) < 0.5) {
			shade = 0.5;
		}
		if (shade > 0.0 && (r2 > 1.0 || q.y > 0.0)) {
			vec3 Lr = to_ring(normalize(vec3(sun_dir, 0.55)));
			vec3 pr = vec3(q, -q.y * RING_TAN);
			if (ray_sphere(pr + Lr * 0.04, Lr, 1.0) > 0.0) {
				shade *= 0.22;
			}
			shade *= mix(1.0, 0.22, eclipse);
			float face = clamp(dot(normalize(pr + vec3(0.0001)), Lr) * 0.5 + 0.5, 0.0, 1.0);
			vec3 ring_col = col_ring.rgb * shade * mix(0.28, 1.5, face);
			ring_col *= mix(1.0, sun_energy, face);
			COLOR = vec4(ring_col, 1.0);
		}
	}
}
