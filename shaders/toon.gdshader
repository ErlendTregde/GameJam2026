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
// Per object, set from code (HitFlash): red flash when hit, alpha = strength.
instance uniform vec4 hit_tint : source_color = vec4(1.0, 0.0, 0.0, 0.0);

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
	ALBEDO = mix(stylize(color), hit_tint.rgb, hit_tint.a);
	EMISSION = hit_tint.rgb * hit_tint.a * 0.4;  // still reads red in the dark under water
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
