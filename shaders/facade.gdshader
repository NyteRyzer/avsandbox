// Building facades: world-space box mapping of a window texture, with lit
// windows that glow at night. Glass is glossier than the wall and picks up
// a little sky at grazing angles; which windows are lit changes from one
// 32 m block of facade to the next. Works with MultiMesh instances.
shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D facade : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lights : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 32.0;
uniform float night = 0.0;
uniform float roughness_value = 0.8;
uniform float metallic_value = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > 0.7) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	uv = uv / tile;
	uv.y = -uv.y;
	vec3 tex = texture(facade, uv).rgb;
	// Glass is the dark part of the texture.
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float glass = n.y > 0.7 ? 0.0 : smoothstep(0.5, 0.3, lum);
	vec3 wall = tex * tint.rgb;
	vec3 pane = mix(tex * mix(vec3(1.0), tint.rgb, 0.25), vec3(0.45, 0.58, 0.72), 0.25);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	pane = mix(pane, vec3(0.62, 0.74, 0.88), fres * 0.6 * (1.0 - night));
	ALBEDO = mix(wall, pane, glass);
	ROUGHNESS = mix(roughness_value, 0.12, glass);
	METALLIC = mix(metallic_value, 0.55, glass);
	// A different set of lit windows in each 32 m block of facade.
	vec2 block = floor(uv);
	vec2 shift = floor(vec2(hash(block), hash(block + 7.3)) * 8.0) / 8.0;
	vec3 glow = texture(lights, uv + shift).rgb;
	if (n.y > 0.7) {
		glow = vec3(0.0);
	}
	EMISSION = glow * night * 1.6 * glass;
}
