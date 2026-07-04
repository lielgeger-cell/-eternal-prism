#version 120

varying vec4 vColor;
varying vec2 vTexCoord;

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform vec3 upPosition;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    vec3 col = tex.rgb * vColor.rgb;

    float sunHeight = clamp(dot(normalize(sunPosition), normalize(upPosition)), -1.0, 1.0);
    float nightFactor = clamp(-sunHeight * 2.5, 0.0, 1.0);

    // солнце — тёплый яркий диск
    float glow = smoothstep(0.0, 1.0, tex.a);
    vec3 sunGlow = col * mix(vec3(1.0, 0.85, 0.65), vec3(1.0, 0.95, 0.85), max(sunHeight, 0.0));
    col += sunGlow * glow * 1.2 * (1.0 - nightFactor);

    // луна — серебристая с холодным свечением
    float moonGlow = glow * nightFactor;
    col += col * moonGlow * 0.9;
    col = mix(col, col * vec3(0.88, 0.92, 1.05), moonGlow * 0.6);

    gl_FragColor = vec4(col, tex.a * vColor.a);
}
