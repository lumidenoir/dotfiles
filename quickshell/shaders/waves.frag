#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 accent;
    vec4 dominant;
    vec4 band0;
    vec4 band1;
    vec4 band2;
};

// Audio spline evaluation
float getBand(int idx) {
    idx = clamp(idx, 0, 11);
    if (idx == 0) return band0.x;
    if (idx == 1) return band0.y;
    if (idx == 2) return band0.z;
    if (idx == 3) return band0.w;
    if (idx == 4) return band1.x;
    if (idx == 5) return band1.y;
    if (idx == 6) return band1.z;
    if (idx == 7) return band1.w;
    if (idx == 8) return band2.x;
    if (idx == 9) return band2.y;
    if (idx == 10) return band2.z;
    return band2.w;
}

// Smooth Catmull-Rom audio spectrum spline for continuous wave deformation
float sampleAudioSpline(float x) {
    float pos = clamp(x, 0.0, 1.0) * 11.0;
    int i = int(floor(pos));
    float t = fract(pos);
    float p0 = getBand(i - 1);
    float p1 = getBand(i);
    float p2 = getBand(i + 1);
    float p3 = getBand(i + 2);
    float c0 = p1;
    float c1 = 0.5 * (p2 - p0);
    float c2 = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3;
    float c3 = 0.5 * (p3 - p0) + 1.5 * (p1 - p2);
    return max(0.0, c0 + c1 * t + c2 * t * t + c3 * t * t * t);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float x = uv.x;
    float y = 1.0 - uv.y; // 0 at bottom, 1 at top

    // Audio energy metrics
    float bass = (band0.x + band0.y + band0.z + band0.w) * 0.25;
    float mid = (band1.x + band1.y + band1.z + band1.w) * 0.25;
    float treble = (band2.x + band2.y + band2.z + band2.w) * 0.25;
    float localAudio = sampleAudioSpline(x);
    float totalEnergy = bass * 0.50 + mid * 0.35 + treble * 0.15;

    // Palette grading - sleek liquid ribbon aesthetic
    vec3 colBase   = dominant.rgb * 0.12;
    vec3 colBody   = mix(dominant.rgb * 0.30, accent.rgb * 0.85, 0.70);
    vec3 colCrest  = mix(accent.rgb, vec3(1.0, 1.0, 1.0), 0.75);
    vec3 colGlow   = mix(dominant.rgb * 0.2, accent.rgb, 0.9);

    float t = time * 0.5;

    // --- 1. Background Ambient Swell ---
    float bgY = 0.14 + sin(x * 2.2 - t * 0.7) * 0.045 + 
                cos(x * 4.2 + t * 0.5) * 0.025 + 
                localAudio * 0.12;
    float bgDist = y - bgY;
    float bgMask = smoothstep(0.04, -0.04, bgDist);

    // --- 2. Midground Liquid Ribbon ---
    float midY = 0.11 + sin(x * 3.5 + t * 0.9) * 0.04 + 
                 cos(x * 6.0 - t * 1.1) * 0.02 + 
                 localAudio * 0.22;
    float midDist = y - midY;
    float midMask = smoothstep(0.025, -0.025, midDist);

    // --- 3. Foreground Primary Audio Wave Ribbon ---
    // Smooth, continuous harmonic waves modulated by audio (no grid, no square noise)
    float waveHarmonic1 = sin(x * 2.8 - t * 1.3) * 0.055;
    float waveHarmonic2 = cos(x * 5.6 + t * 1.7) * 0.028;
    float waveHarmonic3 = sin(x * 11.2 - t * 2.2) * (0.008 + treble * 0.02);

    float fgY = 0.08 + bass * 0.12 + 
                waveHarmonic1 + waveHarmonic2 + waveHarmonic3 + 
                localAudio * (0.34 + bass * 0.15);

    float fgDist = y - fgY;

    // Crisp continuous edge
    float fgMask = smoothstep(0.006, -0.006, fgDist);

    // Water depth gradient inside the wave body
    float depth = clamp((fgY - y) / max(0.01, fgY), 0.0, 1.0);
    vec3 fgBodyColor = mix(colCrest, mix(colBody, colBase, depth), smoothstep(0.0, 0.35, depth));
    float fgBodyAlpha = mix(0.85, 0.35, pow(depth, 0.7));

    // Illuminated Crest Rim (Pure liquid specular line)
    float rimDistance = abs(fgDist);
    float crestGlow = exp(-rimDistance * 45.0) * (0.8 + localAudio * 0.8 + treble * 0.6);
    float crestCore = smoothstep(0.007, 0.0, rimDistance) * 1.2;
    vec3 crestColor = colCrest * (crestCore + crestGlow);

    // Ambient diffuse illumination above the crest
    float mist = exp(-max(0.0, fgDist) * 18.0) * (0.20 + localAudio * 0.35 + mid * 0.25);
    vec3 mistColor = colGlow * mist;

    // Combine foreground
    vec3 fgColor = fgBodyColor * fgMask + crestColor + mistColor;
    float fgAlpha = clamp(fgBodyAlpha * fgMask + (crestGlow + crestCore) * 0.6 + mist * 0.4, 0.0, 1.0);

    // Layer blending: Background + Midground + Foreground
    vec3 finalColor = vec3(0.0);
    float finalAlpha = 0.0;

    // Add background
    if (bgMask > 0.001) {
        vec3 bgCol = mix(colBase * 1.5, colBody * 0.5, 0.5);
        finalColor = bgCol;
        finalAlpha = bgMask * 0.25;
    }

    // Blend midground
    if (midMask > 0.001) {
        vec3 midCol = mix(colBody * 0.7, colGlow * 0.8, 0.4);
        float ma = midMask * 0.35;
        finalColor = mix(finalColor, midCol, ma);
        finalAlpha = max(finalAlpha, ma);
    }

    // Blend foreground on top
    finalColor = mix(finalColor, fgColor, fgAlpha);
    finalAlpha = max(finalAlpha, fgAlpha);

    // Apply overall Qt opacity
    finalAlpha = clamp(finalAlpha, 0.0, 0.78) * qt_Opacity;
    fragColor = vec4(clamp(finalColor, 0.0, 1.0) * qt_Opacity, finalAlpha);
}
