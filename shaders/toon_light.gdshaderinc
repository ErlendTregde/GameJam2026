// The shared stylized lighting, included by every world shader (toon, terrain) so all surfaces
// light the same way. The look comes from global uniforms (Project Settings > Shader Globals).
global uniform vec4 style_shadow_color; // shadowed side is lit by this tint instead of going black
global uniform float style_shadow_softness; // width of the light/shadow edge (0 = hard cel edge)
global uniform float style_rim_strength;
global uniform float style_saturation;

vec3 stylize(vec3 color) {
	return mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, style_saturation);
}

void light() {
	float lit = smoothstep(-style_shadow_softness, style_shadow_softness, dot(NORMAL, LIGHT)) * ATTENUATION;
	vec3 light = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += mix(style_shadow_color.rgb, vec3(1.0), lit) * light;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * lit;
	SPECULAR_LIGHT += rim * style_rim_strength * light * ALBEDO;
}
