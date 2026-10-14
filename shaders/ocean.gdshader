// Ocean: Gerstner waves (mirrored on the CPU in ocean.gd), depth-based absorption,
// screen-space refraction, fresnel and crest/shore foam.
shader_type spatial;
// cull_disabled: surface is visible from under water. shadows_disabled: no per-pixel shadow lookups.
render_mode world_vertex_coords, cull_disabled, shadows_disabled;

group_uniforms waves;
// dir.x, dir.y, steepness, wavelength (m). Keep the steepness sum below 1. ocean.gd reads these.
uniform vec4 wave_a = vec4(1.0, 0.0, 0.08, 60.0);
uniform vec4 wave_b = vec4(0.7, 0.6, 0.10, 31.0);
uniform vec4 wave_c = vec4(-0.3, 1.0, 0.10, 18.0);
uniform vec4 wave_d = vec4(0.2, -0.8, 0.08, 11.0);
uniform float wave_time = 0.0; // set by ocean.gd so CPU and GPU agree

group_uniforms color;
uniform vec3 deep_color : source_color = vec3(0.0, 0.05, 0.09);
uniform vec3 absorption = vec3(0.45, 0.12, 0.1); // per meter; red fades first
uniform vec3 sss_color : source_color = vec3(0.05, 0.4, 0.35);
uniform float sss_strength : hint_range(0.0, 2.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.04;
uniform vec3 underside_color : source_color = vec3(0.15, 0.45, 0.5); // surface seen from under water

group_uniforms detail;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 0.05; // uv per meter
uniform float normal_strength : hint_range(0.0, 2.0) = 0.5;
uniform vec2 scroll_a = vec2(0.012, 0.006);
uniform vec2 scroll_b = vec2(-0.008, 0.014);
uniform float refraction : hint_range(0.0, 0.2) = 0.03;

group_uniforms foam;
uniform sampler2D foam_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 foam_color : source_color = vec3(0.95);
uniform float shore_foam_depth = 1.5;
uniform float crest_foam_height = 0.85;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear; // no mipmaps: skips a full-screen mip chain every frame
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;
varying float wave_height;

vec3 gerstner(vec4 w, vec2 p, inout vec3 tangent, inout vec3 binormal) {
	float k = TAU / w.w;
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p) - sqrt(9.8 / k) * wave_time);
	float a = w.z / k;
	float s = w.z * sin(f);
	float c = w.z * cos(f);
	tangent += vec3(-d.x * d.x * s, d.x * c, -d.x * d.y * s);
	binormal += vec3(-d.x * d.y * s, d.y * c, -d.y * d.y * s);
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec2 p = VERTEX.xz;
	vec3 disp = gerstner(wave_a, p, tangent, binormal) + gerstner(wave_b, p, tangent, binormal)
			+ gerstner(wave_c, p, tangent, binormal) + gerstner(wave_d, p, tangent, binormal);
	VERTEX += disp;
	NORMAL = normalize(cross(binormal, tangent));
	TANGENT = normalize(tangent);
	BINORMAL = normalize(binormal);
	world_pos = VERTEX;
	wave_height = disp.y;
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 uv = world_pos.xz * normal_scale;
	vec3 na = texture(normal_a, uv + wave_time * scroll_a).rgb;
	vec3 nb = texture(normal_b, uv * 1.9 + wave_time * scroll_b).rgb;
	NORMAL_MAP = (na + nb) * 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	// Refraction: offset the screen lookup, but not onto things in front of the water.
	float surface = -VERTEX.z;
	vec2 ruv = clamp(SCREEN_UV + (na.xy + nb.xy - 1.0) * refraction, 0.002, 0.998);
	float depth = linear_depth(ruv, INV_PROJECTION_MATRIX) - surface;
	if (depth < 0.0) {
		ruv = SCREEN_UV;
		depth = linear_depth(ruv, INV_PROJECTION_MATRIX) - surface;
	}
	depth = max(depth, 0.0);
	vec3 transmittance = exp(-absorption * depth);
	vec3 under = texture(screen_tex, ruv).rgb * transmittance + deep_color * (1.0 - transmittance);

	float foam_noise = texture(foam_tex, uv * 9.0 + wave_time * scroll_a * 2.0).r;
	float shore = 1.0 - smoothstep(0.0, shore_foam_depth, depth);
	float crest = smoothstep(crest_foam_height, crest_foam_height + 0.6, wave_height) * 0.7;
	float foam = smoothstep(0.45, 0.75, foam_noise * (shore + crest) * 1.5);

	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	EMISSION = under * (1.0 - fresnel) * (1.0 - foam);
	ALBEDO = mix(sss_color * sss_strength * clamp(wave_height, 0.0, 1.0), foam_color, foam);
	ROUGHNESS = mix(roughness, 0.8, foam);
	if (!FRONT_FACING) {
		EMISSION = underside_color;
		ALBEDO = vec3(0.0);
	}
}
