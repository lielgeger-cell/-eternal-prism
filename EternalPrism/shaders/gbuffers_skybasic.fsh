#version 120
#include "/lib/settings.glsl"

varying vec4 vColor;

uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;

void main() {
    vec3 col = vColor.rgb;
    float lum = clamp(dot(col, vec3(0.333)), 0.0, 1.0);

    float sunHeight = clamp(dot(normalize(sunPosition), normalize(upPosition)), -1.0, 1.0);
    float nightFactor = clamp(-sunHeight * 2.0, 0.0, 1.0);
    float dayFactor   = clamp( sunHeight * 2.0, 0.0, 1.0);

    // день — насыщенный синий
    vec3 zenith  = col * vec3(0.72, 0.88, 1.35);
    vec3 horizon = col * vec3(1.12, 1.06, 0.95);
    vec3 dayCol  = mix(zenith, horizon, pow(lum, 0.7));

    // ночь — глубокий космический градиент (зенит почти чёрный)
    vec3 nightZenith  = col * vec3(0.25, 0.35, 0.75) + vec3(0.004, 0.008, 0.025);
    vec3 nightHorizon = col * vec3(0.60, 0.72, 1.05) + vec3(0.015, 0.025, 0.065);
    vec3 nightCol = mix(nightZenith, nightHorizon, pow(lum, 0.6));

    col = mix(nightCol, dayCol, dayFactor);
    col = mix(col, fogColor, rainStrength * 0.55);

    // насыщенность неба (настройка)
    float skyLum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(skyLum), col, SKY_SATURATION);

    gl_FragColor = vec4(col, vColor.a);
}
