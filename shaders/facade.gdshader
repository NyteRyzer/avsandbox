// Building facades: world-space box mapping of a window texture, with lit
// windows that glow at night. Works with MultiMesh instances.
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
	ALBEDO = texture(facade, uv).rgb * tint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	vec3 glow = texture(lights, uv).rgb;
	if (n.y > 0.7) {
		glow = vec3(0.0);
	}
	EMISSION = glow * night * 1.6;
}
