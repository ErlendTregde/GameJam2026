// Shared stylized surface for every model, so assets from different sources look like one world.
// Per-material: textures and tint. The lighting is in toon_light.gdshaderinc.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_map = false;
uniform float normal_strength = 0.5;
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_color = false;
// Use world x/z as UV (for ground that moves with the camera, like the seabed).
uniform bool world_uv = false;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (world_uv ? world_xz : UV) * uv_scale;
	vec3 color = texture(albedo_tex, uv).rgb * albedo_color.rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	ALBEDO = stylize(color);
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
