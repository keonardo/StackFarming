shader_type canvas_item;
render_mode blend_mix;

uniform float moisture_level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 water_color : source_color = vec4(0.20, 0.55, 1.0, 0.70);
uniform float wave_speed : hint_range(0.5, 5.0, 0.1) = 1.5;

void fragment() {
	// Sin waves along the perimeter — 每边独立波纹
	float wave_top    = sin(UV.x * 18.0 + TIME * wave_speed) * 0.006;
	float wave_bottom = sin(UV.x * 18.0 + TIME * wave_speed * 0.8 + 1.0) * 0.006;
	float wave_left   = sin(UV.y * 20.0 + TIME * wave_speed * 0.6 + 2.0) * 0.006;
	float wave_right  = sin(UV.y * 20.0 + TIME * wave_speed * 0.9 + 3.0) * 0.006;

	// Distance to nearest edge (with wave displacement)
	float dx = min(UV.x + wave_left, 1.0 - UV.x + wave_right);
	float dy = min(UV.y + wave_top, 1.0 - UV.y + wave_bottom);
	float edge = min(dx, dy);

	// Border mask: 1 = border area, 0 = interior (透明让 Panel 透出)
	float border_width = 0.055;
	float border_mask = 1.0 - smoothstep(0.0, border_width, edge);

	// Shimmer / 波光粼粼
	float shimmer = 0.55 + 0.45 * sin((UV.x + UV.y) * 14.0 + TIME * 2.2);

	// Inner glow band — 紧贴边框内侧的渐变光带
	float inner_glow = (1.0 - smoothstep(border_width, border_width * 2.5, edge)) * 0.25;

	float alpha = (border_mask + inner_glow) * moisture_level * shimmer;
	COLOR = vec4(water_color.rgb, clamp(alpha, 0.0, 1.0) * water_color.a);
}
