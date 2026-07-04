//================================================================
// Eternal Prism — Volumetric Clouds
// 3D объёмные облака с самозатенением (ULTRA/SUPER_HIGH)
// + быстрые 2D облака (LOW/HIGH)
//================================================================

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float hash31(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i),              hash21(i + vec2(1,0)), u.x),
        mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x),
        u.y
    );
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash31(i + vec3(0,0,0)), hash31(i + vec3(1,0,0)), f.x),
            mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
            mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y),
        f.z);
}

float cloudFBM(vec2 p) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    for (int i = 0; i < CLOUD_OCTAVES; i++) {
        v += amp * noise2D(p * freq);
        freq *= 2.1; amp *= 0.48;
    }
    return v;
}

// плотность облака в 3D точке (для ray marching)
float cloudDensity3D(vec3 p, float time) {
    p.xz += time * 0.6;
    float base = 0.0, amp = 0.5, freq = 1.0;
    for (int i = 0; i < CLOUD_OCTAVES; i++) {
        base += amp * noise3D(p * freq * 0.15);
        freq *= 2.2; amp *= 0.5;
    }
    // вертикальный профиль — облако плотнее в середине по высоте
    float heightGrad = 1.0 - abs(p.y - 0.5) * 2.0;
    heightGrad = clamp(heightGrad, 0.0, 1.0);
    float d = base * heightGrad;
    return smoothstep(0.45, 0.75, d);
}

// быстрые 2D облака (LOW/HIGH)
vec4 getClouds2D(vec3 viewDir, vec3 sunDir, vec3 skyCol, float time, float rain) {
    if (viewDir.y < 0.02) return vec4(0.0);
    float cloudH = 1.0 / max(viewDir.y, 0.02);
    vec2 uv = viewDir.xz * cloudH * 0.18 + vec2(time * 0.012, time * 0.007);

    float density = cloudFBM(uv);
    density = smoothstep(0.48, 0.82, density + rain * 0.22);
    if (density < 0.01) return vec4(0.0);

    float sunDot = clamp(dot(normalize(vec3(viewDir.x,0,viewDir.z)), normalize(vec3(sunDir.x,0,sunDir.z))), 0.0, 1.0);
    float sunHeight = clamp(sunDir.y, 0.0, 1.0);

    vec3 litColor = mix(vec3(0.92,0.88,0.82), vec3(1.0,0.97,0.93), sunHeight);
    vec3 shadowColor = mix(skyCol * 0.7, vec3(0.55,0.58,0.65), 0.4);
    float silver = pow(clamp(1.0-sunDot,0.0,1.0), 6.0) * sunHeight;
    vec3 col = mix(shadowColor, litColor, clamp(sunDot*sunHeight+0.3, 0.0, 1.0));
    col += silver * 0.4;

    float horizonFactor = pow(clamp(1.0-abs(sunDir.y)*2.5,0.0,1.0), 2.0);
    vec3 sunsetTint = mix(vec3(1.3,0.7,0.5), vec3(1.1,0.6,0.7), sunDot*0.5);
    col = mix(col, col*sunsetTint, horizonFactor*0.55*(1.0-rain));

    float fade = smoothstep(0.02, 0.12, viewDir.y);
    return vec4(col, density * fade);
}

// объёмные облака через ray marching (ULTRA/SUPER_HIGH)
vec4 getCloudsVolumetric(vec3 viewDir, vec3 sunDir, vec3 skyCol, float time, float rain) {
    if (viewDir.y < 0.03) return vec4(0.0);

    // слой облаков на "высоте"
    float cloudBottom = 1.0;
    float cloudTop    = 2.2;
    vec3  rayStart = viewDir * (cloudBottom / viewDir.y);
    vec3  rayEnd   = viewDir * (cloudTop / viewDir.y);

    int STEPS = 12;
    vec3 step = (rayEnd - rayStart) / float(STEPS);
    vec3 pos  = rayStart;

    float transmittance = 1.0;
    vec3  scatteredLight = vec3(0.0);
    float sunHeight = clamp(sunDir.y, 0.0, 1.0);

    vec3 litColor = mix(vec3(0.95,0.90,0.84), vec3(1.0,0.98,0.95), sunHeight);
    vec3 shadowColor = mix(skyCol*0.6, vec3(0.45,0.50,0.62), 0.4);

    for (int i = 0; i < STEPS; i++) {
        float density = cloudDensity3D(pos * vec3(1.0, 2.0, 1.0), time);
        density *= (1.0 + rain * 0.4);

        if (density > 0.01) {
            // самозатенение — сэмплируем плотность в сторону солнца
            float shadowDens = cloudDensity3D((pos + sunDir * 0.15) * vec3(1.0,2.0,1.0), time);
            float lightAmount = exp(-shadowDens * 3.0);

            vec3 sampleColor = mix(shadowColor, litColor, lightAmount);

            // закатная окраска
            float horizonFactor = pow(clamp(1.0-abs(sunDir.y)*2.5,0.0,1.0), 2.0);
            sampleColor = mix(sampleColor, sampleColor * vec3(1.3,0.75,0.55), horizonFactor*0.5*(1.0-rain));

            float dt = density * 0.5;
            scatteredLight += transmittance * sampleColor * dt;
            transmittance *= 1.0 - dt;
            if (transmittance < 0.05) break;
        }
        pos += step;
    }

    float alpha = 1.0 - transmittance;
    float fade = smoothstep(0.03, 0.15, viewDir.y);
    return vec4(scatteredLight, alpha * fade);
}

// главная функция — выбирает метод по качеству
vec4 getClouds(vec3 viewDir, vec3 sunDir, vec3 skyCol, float time, float rain) {
#if CLOUD_MARCH == 1
    return getCloudsVolumetric(viewDir, sunDir, skyCol, time, rain);
#else
    return getClouds2D(viewDir, sunDir, skyCol, time, rain);
#endif
}
