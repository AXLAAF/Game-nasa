shader_type canvas_item;

// Vidrio liquido para paneles de interfaz (Ui.glass): desenfoca lo que hay detras, le sube un poco
// la saturacion (el vidrio recoge el color de lo que tiene alrededor) y lo tine con el color del estilo.
// COLOR.a del estilo es la opacidad del tinte: el resto del pixel es fondo desenfocado.
// Godot copia la pantalla una vez por capa: un vidrio anidado en otro no veria a su padre,
// por eso solo los paneles de primer nivel llevan este material.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur_px = 12.0; // radio del desenfoque en pixeles de pantalla
uniform float saturation = 1.3;
uniform float lift = 0.015; // aclarado leve del fondo: el vidrio se lee como superficie, no como hueco

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_px;
	vec3 acc = texture(screen_tex, SCREEN_UV).rgb;
	// Espiral de angulo aureo: 16 muestras repartidas en el disco sin patron visible.
	for (int i = 1; i < 16; i++) {
		float r = sqrt(float(i) / 15.0);
		float a = float(i) * 2.39996;
		acc += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r * step_uv).rgb;
	}
	vec3 blur = acc / 16.0;
	float luma = dot(blur, vec3(0.2126, 0.7152, 0.0722));
	blur = max(mix(vec3(luma), blur, saturation), vec3(0.0)) + lift;
	// Alfa casi nula = panel desvaneciendose (modulate) o borde exterior: no se pinta vidrio.
	COLOR = vec4(mix(blur, COLOR.rgb, COLOR.a), smoothstep(0.0, 0.08, COLOR.a));
}
