#version 120
#include "/lib/settings.glsl"

attribute vec4 mc_Entity;

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying float vIsFoliage;
varying vec4 vShadowPos;
varying vec3 vNormal;
varying float vAO;
varying vec3 vViewPos;

uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#define LEAVES_ID 10001.0
#define PLANT_ID  10002.0

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    vNormal     = normalize(gl_NormalMatrix * gl_Normal);
    // AO закодирован в яркости вершинного цвета Minecraft
    vAO         = dot(gl_Color.rgb, vec3(0.333));

    vec4 pos = gl_Vertex;
    float id = mc_Entity.x;
    vIsFoliage = 0.0;
    float t = frameTimeCounter;

    if (id == LEAVES_ID) {
        vIsFoliage = 1.0;
        float sway = sin(pos.x * 1.1 + pos.z * 1.3 + t * 1.2) * 0.028
                   + cos(pos.z * 0.9 - pos.x * 0.7 + t * 0.9) * 0.022;
        pos.x += sway;
        pos.z += sway * 0.6;
        pos.y += sin(pos.x * 0.8 + t * 1.0) * 0.012;
    } else if (id == PLANT_ID) {
        vIsFoliage = 1.0;
        float sway = sin(pos.x * 1.3 + pos.z * 1.7 + t * 1.8) * 0.10
                   + cos(pos.x * 0.7 - pos.z * 1.1 + t * 1.4) * 0.055;
        float heightMix = clamp(fract(pos.y), 0.0, 1.0);
        pos.x += sway * heightMix;
        pos.z += sway * 0.7 * heightMix;
    }

    vec4 viewPos  = gl_ModelViewMatrix * pos;
    vViewPos = viewPos.xyz;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    vShadowPos    = shadowProjection * (shadowModelView * worldPos);

    gl_Position = gl_ProjectionMatrix * viewPos;
}
