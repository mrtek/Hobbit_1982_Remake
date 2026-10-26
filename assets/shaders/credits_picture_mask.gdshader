shader_type canvas_item;

uniform float edge_softness : hint_range(0.01, 0.3) = 0.08;
uniform float edge_margin : hint_range(0.01, 0.3) = 0.06;
uniform float noise_roughness : hint_range(0.0, 0.1) = 0.035;
uniform float vignette_darkness : hint_range(0.0, 1.0) = 0.4;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    v += 0.5 * noise(p); p *= 2.02;
    v += 0.25 * noise(p); p *= 2.03;
    v += 0.125 * noise(p);
    return v;
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    float dx = min(UV.x, 1.0 - UV.x);
    float dy = min(UV.y, 1.0 - UV.y);
    float dist = min(dx, dy);
    
    vec2 noise_coords = UV * 16.0;
    float n = (fbm(noise_coords) - 0.5) * 2.0;
    
    float ragged_dist = dist + n * noise_roughness;
    float alpha = smoothstep(edge_margin, edge_margin + edge_softness, ragged_dist);
    
    float vignette = smoothstep(edge_margin, edge_margin + edge_softness * 2.2, ragged_dist);
    col.rgb = mix(col.rgb * (1.0 - vignette_darkness), col.rgb, vignette);
    
    col.a *= alpha * COLOR.a;
    COLOR = col;
}
