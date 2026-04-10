#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float distortion;
    float hoverMix;
    vec4 tintColor;
    vec2 resolution;
};

layout(binding = 1) uniform sampler2D bgSource;

float circleSDF(vec2 uv) {
    return length(uv - vec2(0.5)) * 2.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float d = circleSDF(uv);
    
    if (d > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Offset from center
    vec2 offset = uv - vec2(0.5);
    
    // Lens Refraction (bend UVs outward near the edge)
    // d is 0 at center, 1 at edge
    float lensCurve = pow(d, 2.0); // parabolic curve
    vec2 refractUV = uv + offset * lensCurve * (distortion * (1.0 + hoverMix * 0.2));
    
    // Chromatic aberration
    float chrom = 0.005 * (1.0 + hoverMix * 0.5);
    float r = texture(bgSource, refractUV + offset * chrom).r;
    float g = texture(bgSource, refractUV).g;
    float b = texture(bgSource, refractUV - offset * chrom).b;
    vec3 baseColor = vec3(r, g, b);

    // Fresnel / Edge glow (darker/tinted at edges)
    float fresnel = pow(d, 3.0);
    
    // Specular highlight (simulating a glossy surface light reflection)
    // A nice soft light from the top
    float highlight = smoothstep(0.5, 0.0, uv.y) * 
                      smoothstep(0.0, 0.5, 1.0 - abs(uv.x - 0.5)*2.0);
    // Make the highlight curve like a sphere
    float spec = pow(highlight, 2.5) * (0.8 + hoverMix * 0.4);

    // Inner shadow (to give it depth)
    float innerShadow = smoothstep(0.8, 1.0, d) * 0.3;

    // Tinting (mix base refraction with tintColor)
    float tintStrength = 0.4 + hoverMix * 0.3;
    vec3 liquid = mix(baseColor, tintColor.rgb, tintStrength);
    
    // Composite
    liquid -= innerShadow; // depth
    liquid += spec;        // glossy top
    liquid += tintColor.rgb * fresnel * 0.6; // coloured rim light
    liquid += fresnel * 0.15; // standard white rim reflection

    // Smooth Anti-aliased Edge
    float alpha = (0.7 + hoverMix * 0.2) * (1.0 - smoothstep(0.95, 1.0, d));
    
    fragColor = vec4(liquid, alpha) * qt_Opacity;
}
