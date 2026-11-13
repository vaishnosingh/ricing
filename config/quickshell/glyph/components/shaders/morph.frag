#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    // Authentic MagicUI threshold filter: feColorMatrix (255 * alpha - 140)
    // Threshold at 140/255 = 0.549 with smooth anti-aliased edge
    float a = smoothstep(0.48, 0.56, c.a);
    fragColor = color * (a * qt_Opacity);
}
