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
    vec4 tex = texture2D(texture, vTexCoord);

    vec4 light = texture2D(lightmap, vLightCoord);
    vec3 col   = tex.rgb * vColor.rgb;

    // насыщенность стёкол/партиклов
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, 1.20);

    col *= light.rgb;
    gl_FragColor = vec4(col, tex.a * vColor.a);
}
