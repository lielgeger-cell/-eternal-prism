#version 120

varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    // усиливаем яркость звёзд (они передаются как вершинный цвет с маленьким alpha)
    vec4 c = gl_Color;
    if (c.a < 0.3 && c.r > 0.5) {
        // это звезда — делаем ярче
        c.rgb *= 1.6;
    }
    vColor = c;
}
