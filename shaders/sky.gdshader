// Stylized anime-style sky: soft gradient, glowing sun, painted clouds shaded from the sun side.
shader_type sky;
// Drawn at half resolution and upscaled: the soft sky and clouds look the same, at a quarter of the cost.
render_mode use_half_res_pass;

group_uniforms gradient;
uniform vec3 top_color : source_color = vec3(0.1, 0.36, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.86, 0.98);
uniform vec3 below_color : source_color = vec3(0.25, 0.5, 0.7); // under the horizon (seen in reflections)
uniform float gradient_curve : hint_range(0.1, 2.0) = 0.45;

group_uniforms sun;
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.78);
uniform float sun_size : hint_range(0.0, 0.2) = 0.035;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.7;

group_uniforms clouds;
uniform sampler2D cloud_shape : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_detail : filter_linear_mipmap, repeat_enable;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.55, 0.64, 0.86);
uniform float coverage : hint_range(0.0, 1.0) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.06;
uniform float cloud_scale = 0.35;
uniform vec2 wind = vec2(0.004, 0.0015);
uniform float shade_offset = 0.08; // how far toward the sun to look for thicker cloud

float cloud_noise(vec2 uv) {
	return texture(cloud_shape, uv).r * 0.75 + texture(cloud_detail, uv * 3.0 + TIME * wind).r * 0.25;
}

vec3 sky_color(vec3 dir, vec3 sun_dir) {
	vec3 color = dir.y > 0.0
			? mix(horizon_color, top_color, pow(dir.y, gradient_curve))
			: mix(horizon_color, below_color, pow(clamp(-dir.y * 4.0, 0.0, 1.0), 0.5));

	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float glow = pow(sun_dot, 48.0) * 0.8 + pow(sun_dot, 6.0) * 0.25;
	color += sun_color * glow * sun_glow;
	float sun_disk = 1.0 - smoothstep(sun_size * 0.85, sun_size, distance(dir, sun_dir));
	color = mix(color, sun_color * 4.0, sun_disk);

	if (dir.y > 0.0) {
		// Project onto a flat cloud layer; dividing by height makes clouds shrink toward the horizon.
		vec2 uv = dir.xz / (dir.y + 0.12) * cloud_scale + TIME * wind;
		float n = cloud_noise(uv);
		float d = smoothstep(1.0 - coverage, 1.0 - coverage + edge_softness, n);
		// Darker where the cloud gets thicker toward the sun (simple self-shadowing).
		float toward_sun = cloud_noise(uv + normalize(sun_dir.xz + 0.0001) * shade_offset);
		float lit = clamp(0.6 + (n - toward_sun) * 8.0, 0.0, 1.0);
		vec3 cloud = mix(cloud_shade_color, cloud_color, lit) + sun_color * glow * 0.6;
		d *= smoothstep(0.0, 0.12, dir.y); // fade into the horizon haze
		color = mix(color, cloud, d);
	}
	return color;
}

void sky() {
	// The full-resolution pass only upscales the half-resolution result.
	COLOR = (AT_CUBEMAP_PASS || AT_HALF_RES_PASS) ? sky_color(EYEDIR, LIGHT0_DIRECTION) : HALF_RES_COLOR.rgb;
}
