// Character surfaces. The mesh is vertex coloured; the colour's alpha carries a
// surface tag (k / 15) that picks the micro-detail: skin pores, hair strands,
// leather grain, quilting, speed-suit scales, fabric weave, knit, ripstop,
// denim twill... Detail is procedural in the mesh's own space (so it moves
// with the limb), bump-mapped from screen-space derivatives (no UVs needed)
// and faded out once it gets smaller than a couple of pixels.

uniform float base_rough = 0.72;
uniform float base_metal = 0.0;
uniform float base_rim = 0.18;
uniform bool srgb_lighting = false;   // set when running on the Compatibility renderer

varying vec3 opos;
varying vec3 onrm;
varying float tagv;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

// Surface coordinates for 2D patterns: wrap around the vertical axis for the
// sides of a limb or torso, and fall back to a top-down plane on caps.
vec2 surf_uv() {
	float up = abs(normalize(onrm).y);
	vec2 side = vec2(atan(opos.x, -opos.z) * length(opos.xz), opos.y);
	return up > 0.8 ? opos.xz : side;
}

// Puffy diamonds with stitched seams, as on a quilted jacket.
float quilt(vec2 uv, float cell) {
	vec2 q = vec2(uv.x + uv.y, uv.x - uv.y) / cell;
	vec2 c = fract(q);
	float d = min(min(c.x, 1.0 - c.x), min(c.y, 1.0 - c.y));
	return smoothstep(0.0, 0.2, d);
}

// Overlapping round scales in offset rows (speedster suits).
float scales(vec2 uv, float cell) {
	vec2 q = uv / cell;
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 c = fract(q) - vec2(0.5, 0.15);
	float d = length(c * vec2(1.0, 1.25));
	return clamp(1.0 - d * 1.6, 0.0, 1.0);
}

vec3 bump(vec3 N, vec3 pos, float h, float amp) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h) * amp;
	float dhy = dFdy(h) * amp;
	vec3 r1 = cross(dpdy, N);
	vec3 r2 = cross(N, dpdx);
	float det = dot(dpdx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * N - g);
}

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
	tagv = COLOR.a;
	if (srgb_lighting) {
		// The Compatibility renderer lights in sRGB space, which washed
		// costume colours out to toy brights; deepen them (skin only slightly).
		if (int(round(COLOR.a * 15.0)) == 0) {
			COLOR.rgb *= 0.96;
		} else {
			COLOR.rgb = pow(COLOR.rgb, vec3(1.5));
		}
	} else {
		// Forward+ / Mobile light in linear space: convert the sRGB colours.
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	float rough = base_rough;
	float metal = base_metal;
	float spec = 0.5;
	float rim = base_rim;
	float rim_tint = 0.5;
	float h = 0.0;
	float amp = 0.0;
	int tag = int(round(tagv * 15.0));
	// Metres per pixel, for fading detail that would only shimmer.
	float px = max(length(fwidth(opos)), 1e-5);
	vec3 p = opos;

	if (tag == 0) {
		// Skin: pores, a little mottling, soft sheen, warm rim.
		float fine = clamp(0.0012 / px - 0.5, 0.0, 1.0);
		h = vnoise(p * 900.0) * 0.6 + vnoise(p * 260.0) * 0.4;
		amp = 0.00025 * fine;
		col *= 0.95 + 0.09 * vnoise(p * 45.0);
		rough = 0.5 - 0.08 * vnoise(p * 30.0);
		spec = 0.38;
		rim = 0.35;
		rim_tint = 0.75;
	} else if (tag == 1) {
		// Hair: fine strands running mostly down the head, with sheen.
		float s = vnoise(vec3(p.x * 520.0, p.y * 40.0, p.z * 520.0));
		float fine = clamp(0.0015 / px - 0.5, 0.0, 1.0);
		h = s;
		amp = 0.0005 * fine;
		col *= mix(1.0, 0.72 + 0.5 * s, fine * 0.8 + 0.2);
		rough = 0.42;
		spec = 0.6;
		rim = 0.3;
	} else if (tag == 2 || tag == 3) {
		// Leather: grain, broad creases and worn patches; quilted panels on top.
		float fine = clamp(0.0016 / px - 0.5, 0.0, 1.0);
		float grain = vnoise(p * 620.0);
		float crease = vnoise(p * vec3(70.0, 16.0, 70.0));
		h = grain * 0.4 * fine + crease * 0.6;
		amp = 0.0008;
		float wear = vnoise(p * 22.0);
		col *= 0.88 + 0.22 * wear;
		rough = 0.36 + 0.22 * grain + 0.12 * (1.0 - wear);
		spec = 0.55;
		rim = 0.28;
		if (tag == 3) {
			float q = quilt(surf_uv(), 0.032);
			float qf = clamp(0.012 / px - 1.0, 0.0, 1.0);
			h = mix(h, q * 2.0 + h * 0.3, qf);
			amp = 0.0024;
			col *= mix(1.0, 0.55 + 0.45 * q, qf);
		}
	} else if (tag == 4) {
		// Speed-suit scales: textured, slightly glossy armour fabric.
		float s = scales(surf_uv(), 0.008);
		float sf = clamp(0.0025 / px - 1.0, 0.0, 1.0);
		h = s;
		amp = 0.0005 * sf;
		col *= mix(1.0, 0.84 + 0.2 * s, sf);
		col *= 0.9 + 0.18 * vnoise(p * 18.0);
		rough = 0.34 + 0.25 * (1.0 - s);
		spec = 0.55;
		rim = 0.3;
	} else if (tag == 5 || tag == 13) {
		// Woven fabric (capes, suits, coats); Kryptonian suits get a fine
		// raised hex-like texture over the weave.
		vec2 uv = surf_uv();
		float f = tag == 13 ? 650.0 : 900.0;
		float w = 0.5 + 0.25 * (sin(uv.x * f) + sin(uv.y * f));
		float fine = clamp((6.2832 / f) / px * 0.5 - 1.0, 0.0, 1.0);
		h = w;
		amp = (tag == 13 ? 0.0004 : 0.0003) * fine;
		col *= 0.94 + 0.1 * vnoise(p * 60.0);
		col *= mix(1.0, 0.92 + 0.12 * w, fine);
		rough = tag == 13 ? 0.55 : 0.84;
		spec = tag == 13 ? 0.45 : 0.3;
	} else if (tag == 6) {
		// Knit: ribs and loops (hoodies, sweaters, beanies).
		vec2 uv = surf_uv();
		float rib = abs(sin(uv.x * 170.0 + abs(fract(uv.y * 90.0) - 0.5) * 2.0));
		float fine = clamp(0.006 / px - 1.0, 0.0, 1.0);
		h = rib;
		amp = 0.0012 * fine;
		col *= mix(1.0, 0.78 + 0.3 * rib, fine);
		rough = 0.92;
		spec = 0.25;
	} else if (tag == 7) {
		// Ripstop tactical fabric: a fine grid and panel noise.
		vec2 uv = surf_uv();
		vec2 g = fract(uv * 150.0);
		float grid = max(step(0.88, g.x), step(0.88, g.y));
		float fine = clamp(0.0067 / px - 1.0, 0.0, 1.0);
		h = (1.0 - grid) * 0.6 + vnoise(p * 300.0) * 0.4;
		amp = 0.0005 * fine;
		col *= mix(1.0, 1.0 - grid * 0.18, fine);
		col *= 0.92 + 0.14 * vnoise(p * 30.0);
		rough = 0.78;
		spec = 0.35;
	} else if (tag == 8) {
		// Denim twill with faded streaks.
		vec2 uv = surf_uv();
		float tw = 0.5 + 0.5 * sin((uv.x + uv.y) * 800.0);
		float fine = clamp(0.004 / px - 1.0, 0.0, 1.0);
		h = tw;
		amp = 0.0004 * fine;
		col *= 0.86 + 0.24 * vnoise(vec3(uv.x * 30.0, uv.y * 220.0, 0.0));
		rough = 0.88;
		spec = 0.28;
	} else if (tag == 9) {
		// Rubberised / synthetic: smooth and satin.
		h = vnoise(p * 200.0);
		amp = 0.0002;
		rough = 0.32;
		spec = 0.5;
		rim = 0.3;
	} else if (tag == 10) {
		// Wet: eyes, lenses.
		rough = 0.08;
		spec = 0.8;
		rim = 0.0;
	} else if (tag == 11 || tag == 12) {
		// Brushed armour; chainmail diamonds for tag 12.
		float b = vnoise(vec3(p.x * 30.0, p.y * 700.0, p.z * 30.0));
		h = b;
		amp = 0.0002;
		col *= 0.9 + 0.2 * vnoise(p * 14.0);
		rough = 0.26 + 0.18 * b;
		metal = max(metal, 0.7);
		spec = 0.6;
		rim = 0.25;
		if (tag == 12) {
			float q = quilt(surf_uv(), 0.016);
			float qf = clamp(0.004 / px - 1.0, 0.0, 1.0);
			h = q;
			amp = 0.0012 * qf;
			col *= mix(1.0, 0.6 + 0.45 * q, qf);
		}
	} else if (tag == 14) {
		// Suede / matte cloth.
		h = vnoise(p * 400.0);
		amp = 0.0003;
		col *= 0.92 + 0.14 * vnoise(p * 50.0);
		rough = 0.95;
		spec = 0.25;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metal;
	SPECULAR = spec;
	RIM = rim;
	RIM_TINT = rim_tint;
	if (amp > 0.0) {
		NORMAL = bump(NORMAL, VERTEX, h, amp);
	}
}
