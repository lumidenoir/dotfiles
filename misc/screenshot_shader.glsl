#version 300 es
precision mediump float;
in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);

    // Slight desaturation — keeps colours real, just a touch muted
    // macOS dims to ~72% with barely any hue shift
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 desat  = mix(color.rgb, vec3(luma), 0.07);

    // Core dim — 72% brightness, matching macOS screenshot overlay feel
    vec3 dimmed = desat * 0.72;

    // Very soft vignette — just deepens the corners slightly
    vec2  c   = v_texcoord - 0.5;
    float vig = 1.0 - dot(c, c) * 0.28;
    dimmed   *= vig;

    fragColor = vec4(dimmed, color.a);
}
