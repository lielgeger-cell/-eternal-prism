#version 120
#include "/lib/settings.glsl"

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying vec3 vNormal;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 upPosition;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.1) discard;

    vec4 light = texture2D(lightmap, vLightCoord);
    vec3 col   = tex.rgb * vColor.rgb;

    // лёгкое направленное освещение по нормали
    vec3 sunDir = normalize(sunPosition);
    float NdotL = clamp(dot(normalize(vNormal), sunDir) * 0.5 + 0.5, 0.0, 1.0);
    col *= mix(0.65, 1.0, NdotL);

    // лунное освещение ночью
    float sunHeight = clamp(dot(sunDir, normalize(upPosition)), -1.0, 1.0);
    float nightFactor = clamp(-sunHeight * 2.0, 0.0, 1.0);
    col += col * vec3(0.3, 0.4, 0.7) * nightFactor * vLightCoord.y * 0.2;

    col *= light.rgb;
    gl_FragColor = vec4(col, tex.a * vColor.a);
}
