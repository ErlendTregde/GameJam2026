// A slot machine reel: a strip of symbols (icons from an atlas, in the order of `strip`) seen
// through the window, `rows` at a time. reel_offset (per reel, in symbols) scrolls it: as it
// grows the symbols roll down, like a real reel turning toward you.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D icons : source_color, filter_linear_mipmap;
uniform int symbol_count = 6;
// The reel's symbols from top to bottom, as indexes into the icon atlas.
uniform int strip[64];
uniform int strip_length = 21;
uniform float rows = 3.0;
uniform vec3 background : source_color = vec3(0.93, 0.84, 0.64);
instance uniform float reel_offset = 0.0;

void fragment() {
	float p = UV.y * rows - reel_offset;
	int cell = int(mod(floor(p), float(strip_length)));
	float sym = float(strip[cell]);
	vec2 local = (vec2(UV.x, fract(p)) - 0.5) * 1.12 + 0.5;  // a little margin around each icon
	vec4 icon = texture(icons, vec2((sym + clamp(local.x, 0.0, 1.0)) / float(symbol_count), clamp(local.y, 0.0, 1.0)));
	float curve = 0.6 + 0.4 * sin(UV.y * PI);  // darker toward the top and bottom, like a drum
	ALBEDO = mix(background, icon.rgb, icon.a) * curve;
}
