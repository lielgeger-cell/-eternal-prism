//================================================
// Eternal Prism — Volumetric Light
// Настоящие объёмные лучи через ray marching по shadow map
//================================================

// dither-паттерн чтобы убрать полосы (banding) при малом числе сэмплов
float bayerDither(vec2 pos) {
    // 4x4 Bayer через арифметику, без массива (совместимо с GLSL 120)
    vec2 p = floor(mod(pos, 4.0));
    float x = p.x, y = p.y;
    // битовая перестановка Bayer 4x4
    float b = mod(x, 2.0) * 8.0
            + mod(y, 2.0) * 4.0
            + mod(floor(x / 2.0), 2.0) * 2.0
            + mod(floor(y / 2.0), 2.0);
    return b / 16.0;
}

// Главная функция: марш луча от камеры к фрагменту,
// на каждом шаге проверяем освещён ли он солнцем (по shadow map)
vec3 volumetricLight(
    vec3 viewPos,           // позиция фрагмента в view space
    vec3 sunDir,            // направление к солнцу (view space)
    float sunHeight,        // высота солнца
    mat4 gbufferModelViewInverse,
    mat4 shadowModelView,
    mat4 shadowProjection,
    sampler2D shadowtex,
    vec2 screenPos,
    float rainStrength
) {
    if (sunHeight < -0.05) return vec3(0.0);

    int STEPS = GODRAYS_SAMPLES / 2;
    if (STEPS < 8) STEPS = 8;
    if (STEPS > 32) STEPS = 32;

    // марш от камеры (0) к фрагменту (viewPos)
    float maxDist = min(length(viewPos), 64.0);
    vec3 rayDir   = normalize(viewPos);
    float stepLen = maxDist / float(STEPS);

    // dither сдвигает старт каждого пикселя — убирает полосы
    float jitter = bayerDither(screenPos);

    float accum = 0.0;
    for (int i = 0; i < STEPS; i++) {
        float t = (float(i) + jitter) * stepLen;
        vec3 samplePos = rayDir * t;

        // переводим точку в shadow space
        vec4 worldPos = gbufferModelViewInverse * vec4(samplePos, 1.0);
        vec4 sPos     = shadowProjection * (shadowModelView * worldPos);
        sPos.xyz = sPos.xyz / sPos.w * 0.5 + 0.5;

        if (sPos.x > 0.0 && sPos.x < 1.0 && sPos.y > 0.0 && sPos.y < 1.0) {
            float shadowDepth = texture2D(shadowtex, sPos.xy).r;
            // точка освещена если она перед тенью
            float lit = (sPos.z - 0.0008 <= shadowDepth) ? 1.0 : 0.0;
            accum += lit;
        } else {
            accum += 1.0; // вне shadow map — считаем освещённым
        }
    }
    accum /= float(STEPS);

    // сила эффекта зависит от высоты солнца и погоды
    float strength = smoothstep(-0.05, 0.3, sunHeight);
    // на закате/рассвете лучи сильнее (свет идёт горизонтально сквозь воздух)
    float horizonBoost = pow(clamp(1.0 - abs(sunHeight) * 1.5, 0.0, 1.0), 2.0) * 1.5 + 0.5;

    // цвет лучей — тёплый, на закате краснее
    vec3 rayColor = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.65, 0.35),
                        pow(clamp(1.0 - abs(sunHeight) * 2.0, 0.0, 1.0), 2.0));

    return rayColor * accum * strength * horizonBoost * (1.0 - rainStrength * 0.6) * 0.35;
}
