#version 120
#include "/lib/settings.glsl"

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferProjectionInverse;

// ACES Filmic tone mapping (Narkowicz приближение)
vec3 aces(vec3 x) {
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

float grainNoise(vec2 uv, float t) {
    return fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
}

// Цветокоррекция по времени суток — придаёт настроение каждому времени
vec3 timeOfDayGrade(vec3 col, float sunHeight) {
    // утро/вечер (солнце низко) — тёплый оранжевый
    // день (солнце высоко) — нейтральный, чуть тёплый
    // ночь — холодный синий
    float dayAmount   = clamp(sunHeight * 2.5, 0.0, 1.0);
    float nightAmount = clamp(-sunHeight * 2.5, 0.0, 1.0);
    float goldenAmount = pow(clamp(1.0 - abs(sunHeight) * 2.2, 0.0, 1.0), 1.5);

    // дневной грейд — лёгкая тёплая нейтраль
    vec3 dayGrade = col * vec3(1.02, 1.00, 0.97);
    // золотой час — тёплый, поднимаем красный/жёлтый
    vec3 goldenGrade = col * vec3(1.12, 0.98, 0.82);
    // ночь — холодный синий, приглушённый
    float lumN = dot(col, vec3(0.2126, 0.7152, 0.0722));
    vec3 nightGrade = mix(col, vec3(lumN), 0.25) * vec3(0.80, 0.88, 1.15);

    vec3 result = dayGrade;
    result = mix(result, goldenGrade, goldenAmount * 0.6);
    result = mix(result, nightGrade, nightAmount * 0.7);
    return result;
}

void main() {
    vec2 texel = vec2(1.0/viewWidth, 1.0/viewHeight);

    float sunHeight = clamp(dot(normalize(sunPosition), normalize(upPosition)), -1.0, 1.0);

    // --- Depth of Field: далёкие объекты слегка размываются (киношная глубина) ---
    float depth = texture2D(depthtex0, texcoord).r;
    // линеаризуем глубину
    vec4 vp = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    float linearDist = length(vp.xyz / vp.w);
    // резкость в среднем плане, размытие вдали (начиная с ~48 блоков)
    float dofBlur = smoothstep(48.0, 140.0, linearDist);

    // --- хроматическая аберрация: каналы расходятся к краям ---
    vec3 col;
#if ENABLE_CHROMATIC == 1
    vec2 caDir = (texcoord - 0.5);
    float caAmount = dot(caDir, caDir) * 0.004;
    col.r = texture2D(colortex0, texcoord - caDir * caAmount).r;
    col.g = texture2D(colortex0, texcoord).g;
    col.b = texture2D(colortex0, texcoord + caDir * caAmount).b;
#else
    col = texture2D(colortex0, texcoord).rgb;
#endif

    // применяем DoF — мягкое размытие далёких пикселей
#if ENABLE_DOF == 1
    if (dofBlur > 0.01) {
        vec3 blurCol = vec3(0.0);
        float r = dofBlur * 2.5;
        for (int i = 0; i < 8; i++) {
            float a = float(i) * 0.785; // 8 направлений
            vec2 off = vec2(cos(a), sin(a)) * r * texel;
            blurCol += texture2D(colortex0, texcoord + off).rgb;
        }
        blurCol /= 8.0;
        col = mix(col, blurCol, dofBlur * 0.7);
    }
#endif

    // --- многоступенчатый bloom (3 уровня размытия) ---
    vec3 bloom = vec3(0.0);
    float bw = 0.0;
    for (int i = 1; i <= 3; i++) {
        float r = float(i) * 2.0;
        float w = 1.0 / float(i);
        vec3 b = texture2D(colortex0, texcoord + vec2( r,  r) * texel).rgb
               + texture2D(colortex0, texcoord + vec2(-r,  r) * texel).rgb
               + texture2D(colortex0, texcoord + vec2( r, -r) * texel).rgb
               + texture2D(colortex0, texcoord + vec2(-r, -r) * texel).rgb;
        bloom += b * 0.25 * w;
        bw += w;
    }
    bloom /= bw;
#if ENABLE_BLOOM == 1
    float bloomLum = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
    bloom *= smoothstep(0.45, 1.0, bloomLum);
    col += bloom * (BLOOM_STRENGTH + 0.08);
#endif

    // --- экспозиция + ACES ---
    col = aces(col * TONEMAP_EXPOSURE * BRIGHTNESS);

    // --- насыщенность (с пользовательской настройкой) ---
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, 1.32 * SATURATION);

    // --- color grading: тени холоднее, света теплее (киношный look) ---
    col += (1.0 - lum) * vec3(-0.020, -0.008, 0.030);
    col += lum         * vec3( 0.022,  0.010, -0.012);

    // --- цветокоррекция по времени суток (настроение) ---
    col = timeOfDayGrade(col, sunHeight);

    // --- контраст S-кривой (с настройкой) ---
    col = mix(col, col * col * (3.0 - 2.0 * col), 0.20 * CONTRAST);
    col = mix(vec3(dot(col, vec3(0.333))), col, 1.0); // keep
    col = (col - 0.5) * CONTRAST + 0.5;

    // --- виньетка ---
    vec2 d = texcoord - 0.5;
    d.x *= viewWidth / viewHeight;
    float vig = 1.0 - dot(d, d) * 0.45;
    col *= vig;

    // --- sharpen (unsharp mask) ---
    vec3 blur = (texture2D(colortex0, texcoord + vec2( texel.x,  texel.y)).rgb
               + texture2D(colortex0, texcoord + vec2(-texel.x,  texel.y)).rgb
               + texture2D(colortex0, texcoord + vec2( texel.x, -texel.y)).rgb
               + texture2D(colortex0, texcoord + vec2(-texel.x, -texel.y)).rgb) / 4.0;
    blur = aces(blur * TONEMAP_EXPOSURE * BRIGHTNESS);
    col += (col - blur) * 0.35;

    // --- film grain ---
#if ENABLE_GRAIN == 1
    float grain = grainNoise(texcoord * vec2(viewWidth, viewHeight) * 0.5, frameTimeCounter);
    float lumG  = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float grainStrength = mix(0.035, 0.008, lumG);
    col += (grain - 0.5) * grainStrength;
#endif

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
