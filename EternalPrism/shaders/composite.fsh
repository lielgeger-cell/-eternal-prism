#version 120
#include "/lib/settings.glsl"
#include "/lib/clouds.glsl"
#include "/lib/ssao.glsl"
#include "/lib/godrays.glsl"
#include "/lib/volumetric.glsl"
#include "/lib/atmosphere.glsl"

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1; // флаг воды
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// ---------- аврора ----------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    vec2 u = f*f*(3.0-2.0*f);
    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}
float fbm(vec2 p) {
    float v=0.0, amp=0.5;
    for(int i=0;i<AURORA_OCTAVES;i++){v+=amp*noise(p);p*=2.0;amp*=0.5;}
    return v;
}
vec3 auroraColor(vec3 dir, float time) {
    vec2 p = dir.xz*4.0+vec2(time*0.04,time*0.02)+dir.y*1.4;
    float n1=fbm(p+vec2(0.0,dir.y*2.0)), n2=fbm(p*1.6-vec2(time*0.03,0.0));
    // уже полосы + меньше яркость
    float bands=smoothstep(0.55,0.82,n1)*smoothstep(0.42,0.88,n2);
    return mix(vec3(0.10,0.95,0.55),vec3(0.45,0.30,0.90),n2)*bands*0.38;
}

// 3D хэш для звёзд
float hash3(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// звёздное небо: млечный путь + туманности + мерцающие звёзды
vec3 starField(vec3 dir, float time) {
    vec3 result = vec3(0.0);

    // --- туманности (цветные облака газа) ---
    vec2 nebUV = dir.xz / max(abs(dir.y) + 0.3, 0.1) * 1.2;
    float neb1 = fbm(nebUV * 1.1 + 3.0);
    float neb2 = fbm(nebUV * 1.7 - 5.0);
    vec3 nebColA = vec3(0.35, 0.15, 0.55); // фиолетовая
    vec3 nebColB = vec3(0.10, 0.30, 0.55); // синяя
    float nebMask = smoothstep(0.55, 0.95, neb1) * smoothstep(0.4, 0.9, neb2);
    result += mix(nebColA, nebColB, neb2) * nebMask * 0.18;

    // --- млечный путь (плотная полоса звёзд) ---
    float band = exp(-pow((dir.y - 0.15 + nebUV.x * 0.05) * 2.2, 2.0)) ;
    float milkyNoise = fbm(nebUV * 3.0 + 10.0);
    result += vec3(0.55, 0.60, 0.75) * band * milkyNoise * 0.12;

    // --- звёзды разного размера ---
    vec3 sp = dir * 200.0;
    vec3 cell = floor(sp);
    float star = hash3(cell);
    if (star > 0.985) {
        vec3 starPos = cell + 0.5;
        float d = length(sp - starPos);
        float bright = (star - 0.985) / 0.015; // яркость от 0 до 1
        float size = mix(0.15, 0.45, bright);
        float glow = smoothstep(size, 0.0, d) * bright;
        // мерцание
        float twinkle = 0.7 + 0.3 * sin(time * 3.0 + star * 100.0);
        // цвет звезды (от голубоватой до тёплой)
        vec3 starColor = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.75), hash3(cell + 7.0));
        result += starColor * glow * twinkle * 1.2;
    }

    return result;
}

vec3 getViewDir(vec2 uv) {
    vec4 clip = vec4(uv*2.0-1.0, 1.0, 1.0);
    vec4 vp = gbufferProjectionInverse*clip; vp/=vp.w;
    return normalize(mat3(gbufferModelViewInverse)*normalize(vp.xyz));
}
vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv*2.0-1.0, depth*2.0-1.0, 1.0);
    vec4 vp = gbufferProjectionInverse*clip;
    return vp.xyz/vp.w;
}

// позиция солнца на экране для god rays
vec2 getSunScreenPos() {
    vec4 sp = gbufferProjection * vec4(sunPosition, 1.0);
    sp.xyz /= sp.w;
    return sp.xy * 0.5 + 0.5;
}

void main() {
    vec3 col   = texture2D(colortex0, texcoord).rgb;
    float depth = texture2D(depthtex0, texcoord).r;

    vec3 sunDir    = normalize(sunPosition);
    vec3 upDir     = normalize(upPosition);
    float sunHeight = clamp(dot(sunDir, upDir), -1.0, 1.0);

    // закатный тон — только когда солнце реально близко к горизонту
    float horizonFactor = pow(clamp(1.0 - abs(sunHeight) * 1.8, 0.0, 1.0), 4.0);
    vec3 sunsetTint = vec3(1.10, 0.88, 0.72);
    col = mix(col, col * sunsetTint, horizonFactor * 0.30 * (1.0 - rainStrength));

    // ---- SSAO — не на воде и не под водой ----
#if ENABLE_SSAO == 1
    if (depth < 1.0) {
        float isWater = texture2D(colortex1, texcoord).r;
        if (isWater < 0.5 && isEyeInWater == 0) {
            float ao = calcSSAO(depthtex0, texcoord, depth,
                                gbufferProjectionInverse, gbufferProjection,
                                viewWidth, viewHeight, frameTimeCounter);
            col *= mix(1.0, ao, 0.65);
        }
    }
#endif

    // ---- небо ----
    if (depth >= 1.0) {
        vec3 dir = getViewDir(texcoord);

        float haze = smoothstep(0.18, -0.05, dir.y);
        float dayFactor = clamp(sunHeight * 2.0, 0.0, 1.0);
        col = mix(col, fogColor, haze * mix(0.08, 0.32, rainStrength) * (1.0 - dayFactor * 0.65));

        // облака
        vec4 cloud = vec4(0.0);
#if ENABLE_CLOUDS == 1
        cloud = getClouds(dir, sunDir, col, frameTimeCounter, rainStrength);
#endif
        col = mix(col, cloud.rgb, cloud.a*(1.0-rainStrength*0.3));

        // аврора ночью
        float night = clamp(-sunHeight*2.2, 0.0, 1.0);
        if (night > 0.0) {
            float skyMask = smoothstep(0.0, 0.45, dir.y);

            // звёздное небо: млечный путь, туманности, мерцающие звёзды
            // (затухает к горизонту и за облаками)
            float starVis = smoothstep(-0.05, 0.3, dir.y) * (1.0 - cloud.a);
#if ENABLE_STARS == 1
            col += starField(dir, frameTimeCounter) * night * starVis * (1.0 - rainStrength) * STAR_BRIGHTNESS;
#endif

#if ENABLE_AURORA == 1
            col += auroraColor(dir, frameTimeCounter)*night*skyMask*(1.0-rainStrength)*(1.0-cloud.a*0.7) * AURORA_BRIGHTNESS;
#endif
        }

        // солнечный диск + широкий ореол
        if (sunHeight > -0.1) {
            float sunDot = clamp(dot(dir, sunDir), 0.0, 1.0);
            // узкий яркий диск
            float disk = pow(sunDot, 800.0) * 12.0;
            // широкий мягкий ореол
            float halo = pow(sunDot, 16.0) * 0.6;
            vec3 sunColor = mix(vec3(1.0, 0.80, 0.50), vec3(1.0, 0.95, 0.85), sunHeight);
            col += sunColor * (disk + halo) * (1.0 - cloud.a * 0.9) * (1.0 - rainStrength);
        }
    }

    // ---- Volumetric Light (объёмные лучи через shadow map) ----
#if ENABLE_VOLUMETRIC == 1
    if (sunHeight > -0.05 && isEyeInWater == 0 && depth < 1.0) {
        vec3 viewPos = getViewPos(texcoord, depth);
        vec3 sunDirView = normalize(sunPosition);
        vec3 vol = volumetricLight(
            viewPos, sunDirView, sunHeight,
            gbufferModelViewInverse, shadowModelView, shadowProjection,
            shadowtex0, gl_FragCoord.xy, rainStrength
        );
        col += vol * VOLUMETRIC_STRENGTH;
    }
#endif
    // дополнительно screen-space god rays для солнца в кадре (усиливает эффект)
    if (sunHeight > 0.20) {
        vec2 sunScreen = getSunScreenPos();
        float rays = godRays(depthtex0, texcoord, sunScreen, sunHeight);
        vec3 rayColor = mix(vec3(1.0, 0.85, 0.6), vec3(1.0, 0.95, 0.9), sunHeight);
        col += rayColor * rays * (1.0 - rainStrength*0.8) * 0.6;
    }

    // ---- Screen-Space Reflections для воды ----
#if ENABLE_SSR == 1
    if (depth < 1.0 && isEyeInWater == 0) {
        vec4 waterData = texture2D(colortex1, texcoord);
        if (waterData.r > 0.5) {
            // декодируем нормаль из colortex1
            vec3 N = normalize(waterData.gba * 2.0 - 1.0);
            vec3 viewPos = getViewPos(texcoord, depth);
            vec3 V = normalize(-viewPos);
            vec3 R = reflect(-V, N); // направление отражения

            float fresnel = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.5);

            // маршируем в screen space
            float stepLen = 0.18;
            vec2 reflUV   = texcoord;
            bool hit      = false;

            for (int i = 1; i <= 16; i++) {
                vec3 sPos = viewPos + R * float(i) * stepLen;
                vec4 proj = gbufferProjection * vec4(sPos, 1.0);
                vec2 sUV  = proj.xy / proj.w * 0.5 + 0.5;

                if (sUV.x < 0.02 || sUV.x > 0.98 || sUV.y < 0.02 || sUV.y > 0.98) break;

                float sDepth = texture2D(depthtex0, sUV).r;
                vec3  sVPos  = getViewPos(sUV, sDepth);

                if (sDepth < 1.0 && sVPos.z > sPos.z + 0.05 && abs(sVPos.z - sPos.z) < 2.5) {
                    reflUV = sUV;
                    hit = true;
                    break;
                }
            }

            if (hit) {
                vec3 reflColor = texture2D(colortex0, reflUV).rgb;
                // смешиваем с текущим цветом воды по Fresnel
                col = mix(col, reflColor, fresnel * 0.65);
            }
        }
    }

#endif

    // ---- АТМОСФЕРА: высотный туман + атмосферная перспектива ----
    if (depth < 1.0) {
        vec3 vp = getViewPos(texcoord, depth);
        float dist = length(vp);

        // цвет тумана по времени суток
        vec3 timedFog = fogColorByTime(fogColor, sunHeight, rainStrength);

        // мировая Y-координата фрагмента для высотного тумана
        vec4 worldP = gbufferModelViewInverse * vec4(vp, 1.0);
        float worldY = worldP.y + cameraPosition.y;

        // 1) атмосферная перспектива (далёкое приобретает цвет неба)
        col = aerialPerspective(col, timedFog, dist, sunHeight);

        // 2) высотный туман (стелется у земли, гуще в низинах)
        float gFog = groundFog(worldY, dist, rainStrength, sunHeight);
        col = mix(col, timedFog, gFog);

        // 3) классический дистанционный туман у края прорисовки
        float edgeFog = smoothstep(fogStart, fogEnd, dist) * FOG_DENSITY;
        col = mix(col, timedFog, edgeFog);
    }

    // ---- под водой ----
    if (isEyeInWater == 1) {
        float sunHeight = clamp(dot(normalize(sunPosition), normalize(upPosition)), -1.0, 1.0);
        // тёмно-бирюзовый туман под водой
        vec3 waterFog = mix(vec3(0.02, 0.10, 0.28), vec3(0.10, 0.40, 0.55), clamp(sunHeight, 0.0, 1.0));
        float dist = texture2D(depthtex0, texcoord).r < 1.0
                   ? length(getViewPos(texcoord, texture2D(depthtex0, texcoord).r))
                   : 32.0;
        float fog = clamp(dist / 24.0, 0.0, 1.0);
        col = mix(col, waterFog, fog * 0.85);
        // лёгкий синий оверлей
        col = mix(col, col * vec3(0.55, 0.78, 1.0), 0.25);
        // каустики на потолке под водой
        float t = frameTimeCounter;
        float caust = sin(texcoord.x * 18.0 + t * 1.1) * cos(texcoord.y * 14.0 + t * 0.8) * 0.5 + 0.5;
        col += vec3(0.1, 0.25, 0.4) * caust * 0.08 * clamp(sunHeight, 0.0, 1.0);
    }

    // ---- мокрые поверхности в дождь + капли на экране ----
    if (rainStrength > 0.05) {
        float t = frameTimeCounter;
        // капли на экране — медленно стекают вниз
        vec2 dropUV = vec2(texcoord.x * 3.5, texcoord.y * 2.0 + t * 0.12);
        float drop = sin(dropUV.x * 17.3 + floor(dropUV.y) * 4.7 + t * 2.5)
                   * cos(dropUV.x * 11.1 - floor(dropUV.y) * 3.2 + t * 1.8);
        drop = smoothstep(0.85, 1.0, abs(drop)) * 0.04;
        col += drop * rainStrength * (1.0 - float(isEyeInWater));

        // мокрые поверхности — поверхность темнеет и немного блестит
        if (depth < 1.0) {
            float isWater = texture2D(colortex1, texcoord).r;
            if (isWater < 0.5) {
                col *= mix(1.0, 0.82, rainStrength * 0.6); // темнеет
                float wetSheen = smoothstep(0.7, 1.0, dot(col, vec3(0.333)));
                col += wetSheen * rainStrength * 0.06; // лёгкий блеск
            }
        }
    }

    gl_FragColor = vec4(col, 1.0);
}
