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

float sampleBlurR(vec2 uv, float blurPx, vec2 invSize) {
    if (blurPx < 0.2) {
        return texture(source, uv).r;
    }
    vec2 r = blurPx * invSize;
    float a = texture(source, uv).r * 0.20;
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_INNER[i] * r).r * 0.06;
    }
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_OUTER[i] * r).r * 0.04;
    }
    return a;
}

float sampleBlurG(vec2 uv, float blurPx, vec2 invSize) {
    if (blurPx < 0.2) {
        return texture(source, uv).g;
    }
    vec2 r = blurPx * invSize;
    float a = texture(source, uv).g * 0.20;
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_INNER[i] * r).g * 0.06;
    }
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_OUTER[i] * r).g * 0.04;
    }
    return a;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 invSize = 1.0 / size;
    
    float p = clamp(progress, 0.0, 1.0);
    
    if (p <= 0.001) {
        float a = texture(source, uv).r;
        fragColor = vec4(vec3(a), a) * qt_Opacity;
        return;
    }
    if (p >= 0.999) {
        float a = texture(source, uv).g;
        fragColor = vec4(vec3(a), a) * qt_Opacity;
        return;
    }
    
    float inv_p = 1.0 - p;
    
    // MagicUI blur scaling
    float b1 = min(1.8 * (8.0 / max(inv_p, 0.01) - 8.0), 24.0);
    float b2 = min(1.8 * (8.0 / max(p,     0.01) - 8.0), 24.0);
    
    float op1 = pow(inv_p, 0.4);
    float op2 = pow(p,     0.4);
    
    float a1 = sampleBlurR(uv, b1, invSize) * op1;
    float a2 = sampleBlurG(uv, b2, invSize) * op2;
    
    float combined = a1 + a2;
    
    // MagicUI Threshold Filter: feColorMatrix
    float threshold = 0.50;
    float spread = 0.05;
    float finalAlpha = smoothstep(threshold - spread, threshold + spread, combined);
    
    // Strict premultiplied alpha: RGB * finalAlpha prevents background dot matrix activation
    fragColor = vec4(vec3(finalAlpha), finalAlpha) * qt_Opacity;
}
