//================================================================
// Eternal Prism — Atmosphere & Weather
// Высотный туман, погодные настроения, атмосферная перспектива
//================================================================

// Ground fog — туман стелется у земли, гуще в низинах (как утренний туман)
float groundFog(float worldY, float dist, float rain, float sunHeight) {
    // высота тумана — ниже уровня моря гуще
    float heightFactor = clamp((70.0 - worldY) / 40.0, 0.0, 1.0);
    // утренний/вечерний туман сильнее
    float timeFactor = pow(clamp(1.0 - abs(sunHeight) * 2.0, 0.0, 1.0), 1.5) * 0.5 + 0.3;
    // дистанционный набор плотности
    float distFactor = 1.0 - exp(-dist * 0.012 * FOG_DENSITY);
    // дождь усиливает
    float rainBoost = 1.0 + rain * 0.8;

    return clamp(heightFactor * timeFactor * distFactor * rainBoost, 0.0, 0.85);
}

// цвет тумана в зависимости от времени суток
vec3 fogColorByTime(vec3 baseFog, float sunHeight, float rain) {
    float day   = clamp(sunHeight * 2.5, 0.0, 1.0);
    float night = clamp(-sunHeight * 2.5, 0.0, 1.0);
    float golden = pow(clamp(1.0 - abs(sunHeight) * 2.2, 0.0, 1.0), 1.5);

    vec3 dayFog    = baseFog * vec3(1.0, 1.02, 1.08);
    vec3 goldenFog = mix(baseFog, vec3(1.0, 0.72, 0.48), 0.5);
    vec3 nightFog  = baseFog * vec3(0.35, 0.42, 0.65) + vec3(0.02, 0.03, 0.08);

    vec3 result = dayFog;
    result = mix(result, goldenFog, golden * 0.7);
    result = mix(result, nightFog, night * 0.8);
    result = mix(result, baseFog * 0.8, rain * 0.5); // дождь делает серее

    return result;
}

// Rayleigh-подобное рассеяние для атмосферной перспективы
// далёкие объекты приобретают цвет неба
vec3 aerialPerspective(vec3 col, vec3 fogCol, float dist, float sunHeight) {
    float amount = 1.0 - exp(-dist * 0.006 * FOG_DENSITY);
    // синеватый сдвиг на дистанции днём
    float day = clamp(sunHeight * 2.0, 0.0, 1.0);
    vec3 aerial = mix(fogCol, fogCol * vec3(0.85, 0.92, 1.15), day * 0.4);
    return mix(col, aerial, amount * 0.6);
}
