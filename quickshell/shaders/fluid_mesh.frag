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

// Photographic micro-grain hash for tactile texture
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Quintic Hermite Value Noise (smooth, organic, continuous)
float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Multi-octave FBM for layered liquid currents
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    mat2 rot = mat2(0.85, 0.52, -0.52, 0.85);
    for (int i = 0; i < 4; i++) {
        v += a * noise2D(p);
        p = rot * p * 1.95 + vec2(1.7, 3.4);
        a *= 0.50;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    
    // --- AUDIO ENERGY INTEGRATION ---
    float bass = (band0.x + band0.y + band0.z + band0.w) * 0.25;
    float mid = (band1.x + band1.y + band1.z + band1.w) * 0.25;
    float treble = (band2.x + band2.y + band2.z + band2.w) * 0.25;
    
    // Audio-driven fluid parameters
    float audioEnergy = bass + mid * 0.5;
    float audioSwell = 0.65 + bass * 0.75 + mid * 0.35;
    float audioBright = 0.70 + bass * 0.40 + mid * 0.25 + treble * 0.15;
    
    // Dynamic Viscosity & Turbulence: High energy = fast/sharp, Low = thick/slow
    // Toned down sensitivity so it remains fluid and viscous like ink
    float t = time * (0.030 + audioEnergy * 0.025);
    float turbulence = 1.0 + audioEnergy * 0.45;
    
    // Coordinate space centered with natural diagonal flow skew
    vec2 p = uv * vec2(2.0, 1.6);
    p.x += (uv.y - 0.5) * 0.45; // Gentle sweeping diagonal
    
    // --- HYBRID LIQUID FLOW DOMAIN WARPING ---
    // Layer 1: Broad viscous liquid currents
    vec2 flow1 = vec2(
        fbm(p * 0.8 * turbulence + vec2(t * 0.5, -t * 0.35)),
        fbm(p * 0.8 * turbulence + vec2(-t * 0.35, t * 0.45) + vec2(3.7, 8.1))
    );
    
    // Layer 2: Secondary organic fluid displacement (audio-reactive wave folds)
    vec2 pWarped = p + (flow1 - 0.5) * (0.95 * audioSwell);
    vec2 flow2 = vec2(
        fbm(pWarped * 1.2 * turbulence + vec2(-t * 0.4, -t * 0.2) + vec2(5.2, 1.3)),
        fbm(pWarped * 1.2 * turbulence + vec2(t * 0.3, t * 0.5) + vec2(2.1, 6.4))
    );
    pWarped += (flow2 - 0.5) * (0.65 * audioSwell);
    
    // --- SILKY LIQUID FOLD SCULPTING (Natural S-Curves, No Pinwheels) ---
    // Smooth harmonic fluid waves flowing across the warped domain
    float wave1 = sin(pWarped.y * 2.6 + pWarped.x * 1.6 + t * 0.8) * 0.5 + 0.5;
    float wave2 = cos(pWarped.x * 2.2 - pWarped.y * 1.8 - t * 0.6) * 0.5 + 0.5;
    float wave3 = sin((pWarped.x + pWarped.y) * 2.0 + t * 1.1) * 0.5 + 0.5;
    
    // Composite into deep, broad liquid folds
    float fluidDensity = wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20;
    
    // Soft luminous silk ridge
    float ridge = 1.0 - abs(fluidDensity * 2.0 - 1.0);
    ridge = pow(smoothstep(0.05, 0.95, ridge), 1.6);
    
    float fluidField = clamp(fluidDensity * 0.55 + ridge * 0.50, 0.0, 1.0) * audioBright;
    
    // --- COLOR PALETTE & LIGHTING (Derived from Album Art) ---
    // Deep velvety background in the crevices, rich saturated tone in mid-folds, soft luminous crest
    vec3 colDeep = dominant.rgb * 0.07;
    vec3 colMid = mix(dominant.rgb * 0.40, accent.rgb * 0.85, 0.72);
    vec3 colCrest = mix(accent.rgb, vec3(1.0, 0.98, 0.92), 0.24);
    
    // 3-Stage Smooth Volumetric Gradient (Branchless GPU ramp)
    vec3 colLow = mix(colDeep, colMid, smoothstep(0.0, 0.45, fluidField));
    vec3 colHigh = mix(colMid, colCrest, smoothstep(0.45, 1.0, fluidField));
    vec3 finalColor = mix(colLow, colHigh, step(0.45, fluidField));
    
    // Caustic Light Shafts: Subtle, silky pearlescent sheen
    float caustic = pow(abs(sin((flow2.x - flow2.y) * 8.0 + t * 2.0)), 8.0) * (0.10 + treble * 0.50);
    finalColor += mix(accent.rgb, vec3(1.0, 0.98, 0.95), 0.30) * caustic * smoothstep(0.42, 0.90, ridge);
    
    // Non-intrusive atmospheric alpha: deep velvety crevices, luminous folds
    float alpha = clamp(0.28 + fluidField * 0.55 + bass * 0.12, 0.0, 1.0) * qt_Opacity;
    
    fragColor = vec4(clamp(finalColor, 0.0, 1.0) * alpha, alpha);
}
