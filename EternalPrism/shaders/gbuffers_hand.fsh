#version 120
#include "/lib/settings.glsl"

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 upPosition;

void main() {
    vec4 tex  = texture2D(texture, vTexCoord);
    if (tex.a < 0.1) discard;

    vec4 light = texture2D(lightmap, vLightCoord);
    vec3 col   = tex.rgb * vColor.rgb;

    // тёплый факельный свет через blocklight (vLightCoord.x)
    float blockLight = vLightCoord.x;
    vec3 torchTint   = mix(vec3(1.0), vec3(1.25, 0.95, 0.70), blockLight * 0.6);
    col *= torchTint;
    col *= light.rgb;

    gl_FragColor = vec4(col, tex.a * vColor.a);
}
