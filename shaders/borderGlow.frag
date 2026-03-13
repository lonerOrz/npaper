#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float innerRadius;   // Inner corner radius (pixels)
    float innerWidth;    // Inner Rectangle width
    float innerHeight;   // Inner Rectangle height
};

float roundedRectSDF(vec2 p, vec2 b, float r){
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) - r + min(max(q.x, q.y), 0.0);
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec2 p = (uv - 0.5) * vec2(innerWidth, innerHeight);
    vec2 halfSize = vec2(innerWidth, innerHeight) * 0.5;

    float borderOffset = 0.0;  // No offset, align border with outer Rectangle
    float radius = innerRadius + borderOffset;
    float borderWidth = 3.0;

    // Core: half-size minus corner radius for complete corners
    float d = roundedRectSDF(p, halfSize - radius, radius);

    // Border smoothing
    float border = 1.0 - smoothstep(0.0, borderWidth, abs(d));

    if(border < 0.01){
        fragColor = vec4(0.0);
        return;
    }

    float angle = atan(p.y, p.x);
    float flow = fract(angle / 6.2831853 + time * 0.05);
    vec3 color = vec3(0.5 + 0.5 * sin(flow * 6.283 + 0.0),
                      0.5 + 0.5 * sin(flow * 6.283 + 2.0),
                      0.5 + 0.5 * sin(flow * 6.283 + 4.0));

    fragColor = vec4(color, border) * qt_Opacity;
}
