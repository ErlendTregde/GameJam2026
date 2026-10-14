// Island and sea-floor ground: wet sand at the waterline, dry sand on the beach, grass higher
// up on flatter ground. Heights are world heights (m); edges are broken up with a noise texture.
shader_type spatial;

#include "res://shaders/toon_light.gdshaderinc"

group_uniforms sand;
uniform vec3 sand_color : source_color = vec3(0.96, 0.84, 0.55);
uniform vec3 wet_sand_color : source_color = vec3(0.72, 0.6, 0.4);
// Sand below this height is wet / darker (sea level plus a little for the wave wash).
uniform float wet_height = 1.1;

group_uniforms grass;
uniform vec3 grass_color : source_color = vec3(0.44, 0.64, 0.26);
uniform vec3 grass_dark_color : source_color = vec3(0.32, 0.5, 0.2);
// Grass starts around this height and fades in over grass_blend meters.
uniform float grass_height = 2.4;
uniform float grass_blend = 0.6;
// Slopes steeper than this (1 = flat, 0 = vertical) stay sand.
uniform float grass_min_flatness = 0.8;

group_uniforms detail;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.08;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = texture(detail_tex, world_pos.xz * detail_scale).r;
	float fine = texture(detail_tex, world_pos.xz * detail_scale * 5.0).r;

	float wet = 1.0 - smoothstep(wet_height - 0.4, wet_height + 0.3, world_pos.y + (n - 0.5) * 0.6);
	vec3 sand = mix(sand_color, wet_sand_color, wet) * (0.9 + 0.2 * fine);

	float grass = smoothstep(grass_height - grass_blend, grass_height + grass_blend, world_pos.y + (n - 0.5) * 2.0);
	grass *= smoothstep(grass_min_flatness - 0.1, grass_min_flatness + 0.05, world_normal.y);
	vec3 green = mix(grass_dark_color, grass_color, smoothstep(0.3, 0.7, n)) * (0.9 + 0.2 * fine);

	ALBEDO = stylize(mix(sand, green, grass));
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
