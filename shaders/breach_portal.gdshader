shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// The face of a breach: a spiral of light pulled into a dark eye, with a
// crackling, ragged rim. Drawn on a quad; UV (0.5, 0.5) is the centre.

uniform vec4 tint : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform float open = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.6;
	p.y *= 0.82;  // a little taller than wide
	float r = length(p);
	float a = atan(p.y, p.x);
	// Ragged, flickering edge.
	float edge = 0.86 + 0.08 * noise(vec2(a * 3.0, TIME * 2.5)) + 0.04 * sin(a * 9.0 + TIME * 6.0);
	edge *= open;
	if (r > edge + 0.12) {
		discard;
	}
	// Spiral arms swirling inwards.
	float swirl = a * 3.0 + log(max(r, 0.02)) * 4.5 + TIME * 3.2;
	float arms = 0.5 + 0.5 * sin(swirl);
	float wisps = noise(vec2(swirl * 0.8, r * 6.0 - TIME * 1.5));
	float body = smoothstep(edge, edge - 0.25, r);
	float rim = smoothstep(edge + 0.12, edge, r) * smoothstep(edge - 0.18, edge, r);
	float eye = smoothstep(0.32, 0.0, r);
	vec3 col = tint.rgb * (0.35 + 0.9 * arms * wisps) * body;
	col += mix(tint.rgb, vec3(1.0), 0.6) * rim * 2.2;
	col += vec3(0.9, 0.95, 1.0) * eye * 1.4;
	ALBEDO = col;
}
