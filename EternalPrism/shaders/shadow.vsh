#version 120
#include "/lib/settings.glsl"

// специальные константы — Iris читает их именно отсюда для настройки карты теней
#if SHADER_QUALITY == ULTRA
    const int   shadowMapResolution = 4096;
    const float shadowDistance = 200.0;
#elif SHADER_QUALITY == SUPER_HIGH
    const int   shadowMapResolution = 2048;
    const float shadowDistance = 140.0;
#elif SHADER_QUALITY == HIGH
    const int   shadowMapResolution = 1536;
    const float shadowDistance = 100.0;
#else // LOW
    const int   shadowMapResolution = 1024;
    const float shadowDistance = 64.0;
#endif

attribute vec4 mc_Entity;

varying vec2 vTexCoord;

uniform float frameTimeCounter;

#define LEAVES_ID 10001.0
#define PLANT_ID  10002.0

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    // та же анимация ветра, что в gbuffers_terrain — чтобы тень совпадала с видимой геометрией
    vec4 pos = gl_Vertex;
    float id = mc_Entity.x;
    float t = frameTimeCounter;

    if (id == LEAVES_ID) {
        float sway = sin(pos.x * 1.1 + pos.z * 1.3 + t * 1.2) * 0.025
                   + cos(pos.z * 0.9 - pos.x * 0.7 + t * 0.9) * 0.02;
        pos.x += sway;
        pos.z += sway * 0.6;
    } else if (id == PLANT_ID) {
        float sway = sin(pos.x * 1.3 + pos.z * 1.7 + t * 1.8) * 0.09
                   + cos(pos.x * 0.7 - pos.z * 1.1 + t * 1.4) * 0.05;
        float heightMix = clamp(fract(pos.y), 0.0, 1.0);
        pos.x += sway * heightMix;
        pos.z += sway * 0.7 * heightMix;
    }

    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * pos;
}
