#version 120
#include "/lib/settings.glsl"

/* DRAWBUFFERS:01 */

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying vec3 vNormal;
varying vec3 vViewPos;
varying vec4 vShadowPos;
varying float vFoam;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform vec3 sunPosition;
uniform vec3 fogColor;
uniform vec3 upPosition;
uniform float frameTimeCounter;

float getShadow() {
    vec3 s = vShadowPos.xyz / vShadowPos.w * 0.5 + 0.5;
    if (any(lessThan(s.xy, vec2(0.0))) || any(greaterThan(s.xy, vec2(1.0))) || s.z > 1.0)
        return 1.0;
    return (s.z - 0.0015 <= texture2D(shadowtex0, s.xy).r) ? 1.0 : 0.0;
}

// органические каустики
float caustic(vec2 uv, float t) {
    vec2 a = vec2(uv.x * 1.3 + uv.y * 0.7 + t * 0.9,
                  uv.y * 1.1 - uv.x * 0.5 + t * 0.7);
    float c = sin(a.x * 6.2) * cos(a.y * 5.1)
            + sin((a.x - a.y) * 4.8 + t * 0.4) * 0.6;
    return smoothstep(0.25, 1.0, c * 0.5 + 0.5);
}

void main() {
    vec4 tex   = texture2D(texture, vTexCoord);
    vec4 light = texture2D(lightmap, vLightCoord);
    float t    = frameTimeCounter;

    vec3 N  = normalize(vNormal);
    vec3 V  = normalize(-vViewPos);
    vec3 L  = normalize(sunPosition);
    vec3 up = normalize(upPosition);

    float sunHeight   = clamp(dot(normalize(sunPosition), up), -1.0, 1.0);
    float skyLight    = vLightCoord.y;
    float nightFactor = clamp(-sunHeight * 2.5, 0.0, 1.0);

    // ---- глубина через нормаль ----
    float depthApprox = pow(clamp(1.0 - N.y, 0.0, 1.0), 0.5);
    vec3 shallowColor = mix(vec3(0.22, 0.70, 0.85), vec3(0.06, 0.16, 0.40), nightFactor);
    vec3 deepColor    = mix(vec3(0.02, 0.12, 0.35), vec3(0.01, 0.05, 0.20), nightFactor);
    vec3 col = mix(shallowColor, deepColor, depthApprox * 0.75);

    // ---- Fresnel ----
    float NdotV  = clamp(dot(N, V), 0.0, 1.0);
    float fresnel = pow(1.0 - NdotV, FRESNEL_POWER);

    // ---- небо-отражение (будет заменено SSR в composite если попадёт на объект) ----
    float horizFactor = pow(clamp(1.0 - abs(sunHeight) * 1.8, 0.0, 1.0), 2.0);
    vec3 sunsetRefl   = vec3(1.0, 0.58, 0.28);
    vec3 nightRefl    = vec3(0.04, 0.08, 0.28);
    vec3 skyRefl = mix(
        mix(fogColor * 1.15, sunsetRefl, horizFactor * 0.6),
        nightRefl,
        nightFactor * 0.75
    );
    col = mix(col, skyRefl, fresnel * 0.82);

    // ---- каустики ----
#if WATER_CAUSTICS == 1
    if (skyLight > 0.3 && nightFactor < 0.6) {
        float caust = caustic(vTexCoord * 3.2, t);
        col += mix(vec3(0.85, 0.97, 1.0), vec3(0.5, 0.85, 1.0), depthApprox)
               * caust * skyLight * (1.0 - nightFactor) * 0.22;
    }
#endif

    // ---- солнечный блик ----
    float shadow = getShadow();
    vec3 H = normalize(L + V);
    float NdotH = clamp(dot(N, H), 0.0, 1.0);
    float spec  = pow(NdotH, SPEC_POWER) * shadow * (1.0 - nightFactor);
    col += mix(vec3(1.0, 0.88, 0.65), vec3(1.0, 0.97, 0.90), sunHeight) * spec * 1.3;

    // ИРИДЕСЦЕНЦИЯ — радужное преломление на воде (тема Prism)
#if ENABLE_IRIDESCENCE == 1
    float irisAngle = dot(N, V) + sin(vTexCoord.x * 8.0 + frameTimeCounter * 0.5) * 0.1;
    float irisBand  = fresnel * (1.0 - nightFactor) * skyLight;
    vec3 iris = vec3(
        sin(irisAngle * 6.28 + 0.0) * 0.5 + 0.5,
        sin(irisAngle * 6.28 + 2.09) * 0.5 + 0.5,
        sin(irisAngle * 6.28 + 4.18) * 0.5 + 0.5
    );
    col += iris * irisBand * 0.07;
#endif

    // ---- лунный блик ----
    float specNight = pow(NdotH, SPEC_POWER * 0.25) * nightFactor * 0.4;
    col += vec3(0.7, 0.82, 1.0) * specNight;

    // пена — очень тонкий намёк на гребнях
    if (vFoam > 0.0) {
        col = mix(col, vec3(0.88, 0.94, 1.0), vFoam * 0.22);
    }

    col *= light.rgb * mix(0.55, 1.0, shadow);
    col *= vColor.rgb;

    float alpha = clamp(mix(0.55, 0.92, fresnel) * tex.a * vColor.a * WATER_OPACITY, 0.0, 1.0);

    gl_FragData[0] = vec4(col, alpha);
    // записываем нормаль + флаг воды для SSR в composite
    gl_FragData[1] = vec4(1.0, N * 0.5 + 0.5);
}
