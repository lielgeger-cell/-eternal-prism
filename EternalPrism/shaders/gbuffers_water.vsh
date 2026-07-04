#version 120
#include "/lib/settings.glsl"

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying vec3 vNormal;
varying vec3 vViewPos;
varying vec4 vShadowPos;
varying float vFoam;

uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// Gerstner wave — физически точная волна с острыми гребнями
vec3 gerstner(vec3 pos, vec2 dir, float freq, float amp, float steep, float speed, float t,
              inout vec3 tangent, inout vec3 binormal) {
    float phase  = dot(dir, pos.xz) * freq + t * speed;
    float sinP   = sin(phase);
    float cosP   = cos(phase);
    float QA     = steep * amp;

    vec3 offset;
    offset.x = dir.x * QA * cosP;
    offset.y = amp * sinP;
    offset.z = dir.y * QA * cosP;

    tangent  += vec3(-dir.x * dir.x * steep * amp * sinP,
                      dir.x * amp * cosP * freq,
                     -dir.x * dir.y * steep * amp * sinP);
    binormal += vec3(-dir.x * dir.y * steep * amp * sinP,
                      dir.y * amp * cosP * freq,
                     -dir.y * dir.y * steep * amp * sinP);
    return offset;
}

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor      = gl_Color;

    vec4 pos = gl_Vertex;
    float t  = frameTimeCounter;

    vec3 tangent  = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);
    float waveHeight = 0.0;

#if WATER_OCTAVES >= 1
    vec3 w1 = gerstner(pos.xyz, normalize(vec2(0.92,  0.38)), 0.45, 0.042*WATER_WAVE_HEIGHT, 0.5, 1.20, t, tangent, binormal);
    pos.xyz += w1; waveHeight += w1.y;
#endif
#if WATER_OCTAVES >= 2
    vec3 w2 = gerstner(pos.xyz, normalize(vec2(-0.55, 0.83)), 0.68, 0.028*WATER_WAVE_HEIGHT, 0.4, 1.55, t, tangent, binormal);
    pos.xyz += w2; waveHeight += w2.y;
#endif
#if WATER_OCTAVES >= 3
    vec3 w3 = gerstner(pos.xyz, normalize(vec2(0.30, -0.95)), 1.10, 0.016*WATER_WAVE_HEIGHT, 0.3, 1.90, t, tangent, binormal);
    pos.xyz += w3; waveHeight += w3.y;
#endif
#if WATER_OCTAVES >= 4
    vec3 w4 = gerstner(pos.xyz, normalize(vec2(-0.82, -0.58)), 1.80, 0.008*WATER_WAVE_HEIGHT, 0.2, 2.40, t, tangent, binormal);
    pos.xyz += w4; waveHeight += w4.y;
#endif

    // микро-рябь — быстрая мелкая
    float micro = sin(pos.x * 4.5 + t * 3.2) * cos(pos.z * 3.8 + t * 2.8) * 0.006;
    pos.y += micro;

    // нормаль из касательных Gerstner волн
    vec3 worldNormal = normalize(cross(binormal, tangent));
    vNormal = normalize(gl_NormalMatrix * worldNormal);

    // пена только на самых острых гребнях — очень тонко
    vFoam = smoothstep(0.055, 0.085, waveHeight);

    vec4 viewPos  = gl_ModelViewMatrix * pos;
    vViewPos      = viewPos.xyz;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    vShadowPos    = shadowProjection * (shadowModelView * worldPos);
    gl_Position   = gl_ProjectionMatrix * viewPos;
}
