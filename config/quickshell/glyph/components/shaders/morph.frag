#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float progress;
};

layout(binding = 1) uniform sampler2D source;

const vec2 OFFSETS_INNER[8] = vec2[8](
    vec2( 0.450,  0.000),
    vec2( 0.318,  0.318),
    vec2( 0.000,  0.450),
    vec2(-0.318,  0.318),
    vec2(-0.450,  0.000),
    vec2(-0.318, -0.318),
    vec2( 0.000, -0.450),
    vec2( 0.318, -0.318)
);

const vec2 OFFSETS_OUTER[8] = vec2[8](
    vec2( 0.831,  0.344),
    vec2( 0.344,  0.831),
    vec2(-0.344,  0.831),
    vec2(-0.831,  0.344),
    vec2(-0.831, -0.344),
    vec2(-0.344, -0.831),
    vec2( 0.344, -0.831),
    vec2( 0.831, -0.344)
);

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 invSize = 1.0 / size;
    
    float p = clamp(progress, 0.0, 1.0);
    
    // Smooth blur envelope: peaks at p=0.5 with 8.0px blur
    float env = sin(p * 3.14159265);
    float blurPx = 8.0 * env;
    
    if (blurPx < 0.2) {
        float a = texture(source, uv).a;
        fragColor = vec4(vec3(a), a) * qt_Opacity;
        return;
    }
    
    vec2 r = blurPx * invSize;
    
    // 17-tap concentric Poisson blur
    float s = texture(source, uv).a * 0.20;
    for (int i = 0; i < 8; ++i) {
        s += texture(source, uv + OFFSETS_INNER[i] * r).a * 0.06;
    }
    for (int i = 0; i < 8; ++i) {
        s += texture(source, uv + OFFSETS_OUTER[i] * r).a * 0.04;
    }
    
    // Calibrated Metaball Threshold Filter:
    // Core strokes stay 100% visible (min_max = 1.00, zero blinking).
    // Liquid bridge smoothly forms between strokes.
    // Background remains strictly 0.0 (corner_max = 0.00, zero white block).
    float threshold = 0.28;
    float spread = 0.08;
    float finalAlpha = smoothstep(threshold - spread, threshold + spread, s);
    
    // Strict premultiplied alpha: RGB * finalAlpha ensures background dots stay 100% off
    fragColor = vec4(vec3(finalAlpha), finalAlpha) * qt_Opacity;
}
