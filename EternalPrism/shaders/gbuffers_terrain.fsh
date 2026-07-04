#version 120
#include "/lib/settings.glsl"

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying float vIsFoliage;
varying vec4 vShadowPos;
varying vec3 vNormal;
varying float vAO;
varying vec3 vViewPos;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;

// Poisson disk — равномерные точки для мягких теней
const vec2 poisson[16] = vec2[16](
    vec2(-0.94,  0.00), vec2( 0.95, -0.05), vec2(-0.09, -0.93), vec2( 0.05,  0.99),
    vec2(-0.50,  0.51), vec2( 0.52,  0.49), vec2(-0.55, -0.49), vec2( 0.50, -0.52),
    vec2(-0.20,  0.18), vec2( 0.22, -0.16), vec2(-0.78,  0.30), vec2( 0.78, -0.32),
    vec2( 0.30,  0.77), vec2(-0.32, -0.78), vec2(-0.30,  0.78), vec2( 0.32, -0.77)
);

float rand(vec2 c) { return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453); }

// PCSS — мягкие тени с размытием
float getShadowSoft(float dither) {
    vec3 sPos = vShadowPos.xyz / vShadowPos.w * 0.5 + 0.5;
    if (any(lessThan(sPos.xy, vec2(0.0))) || any(greaterThan(sPos.xy, vec2(1.0))) || sPos.z > 1.0)
        return 1.0;

    float bias = 0.0010;

#if SOFT_SHADOWS == 1
    // 1) ищем среднюю глубину блокеров для определения размера полутени
    float blockerDepth = 0.0;
    int   blockerCount = 0;
    float searchR = 2.5 / SHADOWMAP_RES;
    for (int i = 0; i < 8; i++) {
        vec2 o = poisson[i] * searchR;
        float sd = texture2D(shadowtex0, sPos.xy + o).r;
        if (sd < sPos.z - bias) { blockerDepth += sd; blockerCount++; }
    }
    if (blockerCount == 0) return 1.0; // полностью освещено

    blockerDepth /= float(blockerCount);
    // чем дальше блокер — тем мягче тень (как в реальности)
    float penumbra = clamp((sPos.z - blockerDepth) * 35.0, 0.6, 4.5);
    float filterR  = penumbra / SHADOWMAP_RES;

    // 2) PCF с вращением Poisson по дизерингу
    float angle = dither * 6.2832;
    float ca = cos(angle), sa = sin(angle);
    float sum = 0.0;
    for (int i = 0; i < PCSS_SAMPLES; i++) {
        vec2 p = poisson[i];
        vec2 r = vec2(p.x*ca - p.y*sa, p.x*sa + p.y*ca) * filterR;
        float sd = texture2D(shadowtex0, sPos.xy + r).r;
        sum += (sPos.z - bias <= sd) ? 1.0 : 0.0;
    }
    return sum / float(PCSS_SAMPLES);
#else
    float texel = 1.2 / SHADOWMAP_RES, sum = 0.0;
    for (int i = 0; i < 4; i++) {
        float sd = texture2D(shadowtex0, sPos.xy + poisson[i] * texel).r;
        sum += (sPos.z - bias <= sd) ? 1.0 : 0.0;
    }
    return sum / 4.0;
#endif
}

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.1) discard;

    vec4 light  = texture2D(lightmap, vLightCoord);
    vec3 albedo = tex.rgb * vColor.rgb;
    vec3 N      = normalize(vNormal);
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir  = normalize(upPosition);

    float sunHeight  = clamp(dot(sunDir, upDir), -1.0, 1.0);
    float dayFactor  = clamp(sunHeight * 3.0, 0.0, 1.0);
    float nightFactor = clamp(-sunHeight * 2.2, 0.0, 1.0);

    // --- обработка альбедо ---
    if (vIsFoliage > 0.5) {
        float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
        albedo = mix(vec3(lum), albedo, 1.45);
        albedo *= vec3(0.95, 1.08, 0.90);
    } else {
        float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
        albedo = mix(vec3(lum), albedo, 1.22);
        albedo *= vec3(1.04, 1.02, 0.97);
    }

    float skyLight   = vLightCoord.y;
    float blockLight = vLightCoord.x;

    // --- мягкая тень ---
    float dither = rand(gl_FragCoord.xy);
    float shadow = getShadowSoft(dither);

    // диффуз по нормали (свет солнца под углом = объём)
    float NdotL = clamp(dot(N, sunDir), 0.0, 1.0);
    float directLight = NdotL * shadow * dayFactor;

    // --- ДВУХЦВЕТНОЕ освещение: тёплое солнце + холодное небо ---
    vec3 sunColor = vec3(SUN_TINT_R, SUN_TINT_G, SUN_TINT_B);
    vec3 skyColor = vec3(SKY_AMBIENT_R, SKY_AMBIENT_G, SKY_AMBIENT_B);

    // прямой свет (тёплый, только освещённые солнцем места)
    vec3 directContrib = sunColor * directLight * 1.15;
    // ambient из неба (холодный, везде где видно небо)
    vec3 ambientContrib = skyColor * skyLight * mix(0.55, 0.30, nightFactor);
    // на закате ambient теплеет
    float horizonFactor = pow(clamp(1.0 - abs(sunHeight) * 1.8, 0.0, 1.0), 2.0);
    ambientContrib = mix(ambientContrib, vec3(0.7, 0.5, 0.4) * skyLight * 0.5, horizonFactor * 0.5);

    // SSS листвы (просвет солнца сквозь листья)
    vec3 sssContrib = vec3(0.0);
    if (vIsFoliage > 0.5) {
        float backLight = clamp(-dot(N, sunDir), 0.0, 1.0);
        sssContrib = vec3(0.20, 0.55, 0.10) * backLight * skyLight * 0.6 * dayFactor * shadow;
    }

    // лунный свет ночью (серебристый)
    float moonAmount = (vIsFoliage > 0.5) ? 0.05 : 0.14;
    vec3 moonContrib = vec3(0.70, 0.80, 1.0) * nightFactor * skyLight * moonAmount * MOON_LIGHT;

    // блочный свет (факелы) — тёплый
    vec3 torchColor = vec3(1.0, 0.65, 0.32);
    vec3 torchContrib = torchColor * blockLight * blockLight * 1.4;

    // минимальный ambient в пещерах
    float caveAmbient = (1.0 - skyLight) * 0.06;

    // --- WETNESS: мокрые поверхности в дождь ---
    float upFacing = clamp(dot(N, upDir), 0.0, 1.0);
    float wetness  = 0.0;
#if ENABLE_WETNESS == 1
    wetness = rainStrength * skyLight * upFacing;
    if (wetness > 0.01) {
        // мокрая поверхность темнеет и насыщается (как реальный мокрый асфальт/земля)
        albedo *= mix(1.0, 0.72, wetness);
        float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
        albedo = mix(albedo, mix(vec3(lum), albedo, 1.3), wetness);
    }
#endif

    // --- SPECULAR: блик солнца на поверхностях ---
    vec3 V = normalize(-vViewPos);
    vec3 H = normalize(sunDir + V);
    float NdotH = clamp(dot(N, H), 0.0, 1.0);

    // базовый блеск: вода/лёд/мокрое блестит сильно, обычные блоки слабо
    float glossiness = wetness * 0.8 + 0.04; // сухие чуть блестят, мокрые сильно
    float specPower  = mix(8.0, 90.0, glossiness);
    float specular   = pow(NdotH, specPower) * shadow * dayFactor * (glossiness + 0.05);
    vec3  specContrib = sunColor * specular * 2.0;
    // на закате блик краснее
    specContrib = mix(specContrib, vec3(1.0, 0.6, 0.35) * specular * 2.0, horizonFactor * 0.6);

    // --- собираем освещение ---
    vec3 lighting = directContrib + ambientContrib + sssContrib + moonContrib + torchContrib + caveAmbient;

    // fake AO от вершин
    float ao = mix(0.55, 1.0, vAO);
    lighting *= ao;

    vec3 col = albedo * lighting + specContrib;

    // подмешиваем ванильную карту освещения мягко (для совместимости с источниками света)
    col = mix(col, albedo * light.rgb, 0.15);

    gl_FragColor = vec4(col, tex.a * vColor.a);
}
