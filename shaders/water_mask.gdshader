// Invisible lid over a hull opening: writes depth only, so the ocean (drawn after it,
// render_priority -1 < 0) is hidden inside the boat but untouched everywhere else.
shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, shadows_disabled;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
