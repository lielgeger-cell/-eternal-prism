#version 120

varying vec4 vColor;
varying vec2 vTexCoord;
varying vec2 vLightCoord;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    gl_Position = ftransform();
}
