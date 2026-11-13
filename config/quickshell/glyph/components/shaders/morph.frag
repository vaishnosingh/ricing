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

float sampleBlur(vec2 uv, float blurPx, vec2 invAtlasSize) {
    if (blurPx < 0.2) {
        return texture(source, uv).a;
    }
    vec2 r = blurPx * invAtlasSize;
    float a = texture(source, uv).a * 0.20;
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_INNER[i] * r).a * 0.06;
    }
    for (int i = 0; i < 8; ++i) {
        a += texture(source, uv + OFFSETS_OUTER[i] * r).a * 0.04;
    }
    return a;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 invAtlasSize = vec2(0.5 / size.x, 1.0 / size.y);
    
    float p = clamp(progress, 0.0, 1.0);
    
    vec2 uv1 = vec2(uv.x * 0.5, uv.y);
    vec2 uv2 = vec2(uv.x * 0.5 + 0.5, uv.y);
    
    if (p <= 0.001) {
        float a = texture(source, uv1).a;
        fragColor = vec4(vec3(a), a) * qt_Opacity;
        return;
    }
    if (p >= 0.999) {
        float a = texture(source, uv2).a;
        fragColor = vec4(vec3(a), a) * qt_Opacity;
        return;
    }
    
    float inv_p = 1.0 - p;
    float env = sin(p * 3.14159265);
    float blurPx = 10.0 * env;
    
    float a1 = sampleBlur(uv1, blurPx, invAtlasSize);
    float a2 = sampleBlur(uv2, blurPx, invAtlasSize);
    
    float combined = a1 * inv_p + a2 * p;
    
    // Calibrated Metaball Isosurface:
    // Core strokes stay 100% visible throughout the entire transition.
    // Liquid bridge smoothly forms between strokes.
    float threshold = 0.25;
    float spread = 0.08;
    float finalAlpha = smoothstep(threshold - spread, threshold + spread, combined);
    
    // Premultiplied alpha: keeps background dots 100% off
    fragColor = vec4(vec3(finalAlpha), finalAlpha) * qt_Opacity;
}
