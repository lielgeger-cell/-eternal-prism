#version 120

varying vec2 vTexCoord;

uniform sampler2D texture;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);

    // альфа-тест — чтобы листва/трава отбрасывали резную, а не сплошную блочную тень
    if (tex.a < 0.5) discard;

    gl_FragColor = vec4(1.0);
}
